# Memory Maker Admin

Public release admin mobile app for Memory Maker.

## Codemagic env group
Use `memorymaker_env` with:

SUPABASE_URL
SUPABASE_ANON_KEY
APP_URL
DEMO_MODE=false

## Admin login
Use a Supabase Auth user that has `profiles.role = super_admin` or `sub_admin`, or `profiles.is_super_admin = true`.
