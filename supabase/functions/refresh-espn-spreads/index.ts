// Deploy as a scheduled Supabase Edge Function, with JWT verification enabled.
// Invoke with a service-role JWT from a trusted scheduler, never from the browser.
// ESPN odds are advisory. Missing odds are not guessed.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const mapping: Record<string,string> = {WSH:'WAS',JAC:'JAX',LA:'LAR',OAK:'LV',SD:'LAC',STL:'LAR'};
const norm=(s:string)=>mapping[s]||s;
Deno.serve(async(req)=>{
 if(req.method!=='POST')return new Response('Method not allowed',{status:405});
 const key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
 const url=Deno.env.get('SUPABASE_URL');
 if(!key||!url)return new Response('Server configuration missing',{status:500});
 if(req.headers.get('Authorization')!==`Bearer ${key}`)return new Response('Unauthorized',{status:401});
 const db=createClient(url,key);
 const {data:games,error}=await db.from('league_games').select('id,week,season,home_team,away_team,kickoff_at').eq('season',2026);
 if(error)return new Response('Database error',{status:500});
 const now=Date.now();let updated=0,skipped=0,errors=0;
 const weeks=[...new Set((games||[]).filter(g=>g.kickoff_at&&Date.parse(g.kickoff_at)>now).map(g=>g.week))];
 for(const week of weeks){
  try{
   const res=await fetch(`https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard?dates=2026&seasontype=2&week=${week}&limit=100`,{headers:{Accept:'application/json'}});
   if(!res.ok){errors++;continue;}
   const payload=await res.json();
   for(const event of payload.events||[]){
    const competition=event.competitions?.[0];
    const home=competition?.competitors?.find((x:any)=>x.homeAway==='home');
    const away=competition?.competitors?.find((x:any)=>x.homeAway==='away');
    const game=(games||[]).find(g=>g.week===week&&g.home_team===norm(home?.team?.abbreviation)&&g.away_team===norm(away?.team?.abbreviation));
    if(!game||!game.kickoff_at){skipped++;continue;}
    const kickoff=Date.parse(game.kickoff_at);
    if(!Number.isFinite(kickoff)||kickoff<=Date.now()){skipped++;continue;}
    const odds=competition?.odds?.[0];
    if(!odds){skipped++;continue;}
    let favored:string|null=null,points:number|null=null;
    const details=String(odds.details||'').trim();
    if(/^EVEN|PK|PICK(?:'EM)?$/i.test(details)){points=0;}
    else{
      const match=details.match(/^([A-Z]{2,3})\s+(-?\d+(?:\.\d+)?)$/i);
      if(!match){skipped++;continue;}
      favored=norm(match[1].toUpperCase());points=Math.abs(Number(match[2]));
      if(![game.home_team,game.away_team].includes(favored)||!Number.isFinite(points)){skipped++;continue;}
    }
    // Freeze guard checks database clock and existing frozen snapshot.
    // Serialize updates using the SQL function installed by the migration below.
    const {error:writeError}=await db.rpc('record_espn_spread',{p_game_id:game.id,p_favored_team:favored,p_points:points});
    if(writeError)errors++;else updated++;
   }
  }catch{errors++;}
 }
 return Response.json({updated,skipped,errors,checkedWeeks:weeks});
});
