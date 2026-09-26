# infra

Deployment scripts and environment templates. **No secrets here.**

| Environment | Supabase | GCP / Firebase | Region |
|---|---|---|---|
| dev | `prepvruksha-dev` (ref `hzpuxfgfheizghpipmew`) | `prepvruksha-dev` | Mumbai / `asia-south1` |
| prod | `prepvruksha-prod` (not yet created) | `prepvruksha-prod` | Mumbai / `asia-south1` |

Secrets live in GCP Secret Manager (services) and git-ignored local files:
`services/*/.env`, `supabase/.env`, `config/*.json`.

Cloud Run deploy scripts are added with the first service that ships.
