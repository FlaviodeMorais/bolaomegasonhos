import { createClient } from '@supabase/supabase-js'

const url = process.env.SUPABASE_URL!
const key = process.env.SUPABASE_SERVICE_KEY!

// Todas as tabelas do bolaomegasonhos vivem no schema "sonhos",
// isolado do schema "public" usado pelo bolao-mega no mesmo projeto Supabase.
export const supabase = createClient(url, key, {
  db: { schema: 'sonhos' },
})
