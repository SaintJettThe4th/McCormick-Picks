// Optional Supabase client bootstrap. Does not modify login, picks, or storage.
// Loaded only by future auth integration, after migration and testing.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const config = window.MCCORMICK_SUPABASE_CONFIG;
export const supabaseClient = config &&
  /^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(config.url) &&
  /^sb_publishable_[A-Za-z0-9_-]+$/.test(config.publishableKey) &&
  config.publishableKey !== 'REPLACE_WITH_SB_PUBLISHABLE_KEY'
    ? createClient(config.url, config.publishableKey)
    : null;
