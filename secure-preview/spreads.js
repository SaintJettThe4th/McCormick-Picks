// Read-only display. Supabase server job refreshes ESPN odds and freezes them at kickoff.
// If the job is not configured, show N/A rather than fabricate a betting line.
import { supabaseClient as db } from './supabase-client.js';
const spreadByGame=new Map();
const names={ARI:'Cardinals',ATL:'Falcons',BAL:'Ravens',BUF:'Bills',CAR:'Panthers',CHI:'Bears',CIN:'Bengals',CLE:'Browns',DAL:'Cowboys',DEN:'Broncos',DET:'Lions',GB:'Packers',HOU:'Texans',IND:'Colts',JAX:'Jaguars',KC:'Chiefs',LAC:'Chargers',LAR:'Rams',LV:'Raiders',MIA:'Dolphins',MIN:'Vikings',NE:'Patriots',NO:'Saints',NYG:'Giants',NYJ:'Jets',PHI:'Eagles',PIT:'Steelers',SEA:'Seahawks',SF:'49ers',TB:'Buccaneers',TEN:'Titans',WAS:'Commanders'};
function format(game){
 const row=spreadByGame.get(game.id);
 if(!row || row.spread_points===null || row.spread_points===undefined)return 'N/A';
 const points=Number(row.spread_points);
 if(!Number.isFinite(points))return 'N/A';
 if(points===0)return 'EVEN';
 if(!row.favored_team || ![game.home,game.away].includes(row.favored_team))return 'N/A';
 return (names[row.favored_team]||row.favored_team)+' -'+points.toFixed(1);
}
window.McCormickSpreads={format};
function paint(){
 document.querySelectorAll('[data-spread-game]').forEach(el=>{
  const id=el.dataset.spreadGame;
  const game=Object.values(schedule).flatMap(w=>w.games).find(g=>g.id===id);
  const label=el.querySelector('span');
  if(label&&game)label.textContent=format(game);
 });
}
async function refresh(){
 if(!db || !app.currentUser)return;
 const {data,error}=await db.from('league_spreads').select('game_id,favored_team,spread_points');
 if(error){console.warn('Spread data unavailable; showing N/A');return;}
 spreadByGame.clear();
 for(const row of data||[])spreadByGame.set(row.game_id,row);
 paint();
}
const oldShowGames=app.showGames.bind(app);
app.showGames=function(){oldShowGames();void refresh();};
const oldLogout=app.logout.bind(app);
app.logout=function(...args){spreadByGame.clear();return oldLogout(...args);};
setInterval(()=>{void refresh();},60*1000);
