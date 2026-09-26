# App configuration

Flutter builds read their settings from a JSON file passed with
`--dart-define-from-file`. Copy an example and fill in the key:

| File | Use |
|---|---|
| `local.json` | Local Supabase (`supabase start`). On the Android emulator use `http://10.0.2.2:54321` as `SUPABASE_URL`. |
| `dev.json` | The `prepvruksha-dev` project. |

The real `*.json` files are git-ignored. Only the publishable key goes here; the
secret / service role key belongs to `services/*` and never to an app.

```
cd apps/app
flutter run --flavor dev --dart-define-from-file=../../config/dev.json      # Android
flutter run -d chrome --dart-define-from-file=../../config/local.json       # web
```
