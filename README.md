# Memory Maker Admin App

Admin-only Flutter app for Memory Maker.

## Features
- Super admin / sub admin login using Supabase Auth
- Admin access verification via profiles table
- Dashboard overview
- Support ticket management
- Reply to tickets and create user notifications
- User list and admin role view
- Gallery/event list
- Media count visibility
- Modern rose/ivory glass UI

## Environment
Create `.env` from `.env.example`:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
APP_URL=https://memorymaker.com
DEMO_MODE=false
```

## Build
```
flutter pub get
flutter build apk --release -t lib/main.dart
```

## Codemagic
This package includes codemagic.yaml with no paid linux instance_type.
