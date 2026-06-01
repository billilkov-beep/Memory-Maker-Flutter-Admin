# Memory Maker Admin

Public beta admin Flutter app for super admins and sub admins.

## Features
- Secure Supabase login
- Public release splash screen
- Super admin and sub admin access check
- Dashboard overview
- Support ticket list and replies
- User list and role management
- Gallery list and upload inspection
- Modern glass UI

## Build
Use Codemagic with env group `memorymaker_env`.

Required variables:
- SUPABASE_URL
- SUPABASE_ANON_KEY
- APP_URL
- DEMO_MODE=false

No paid Linux instance is used in `codemagic.yaml`.
