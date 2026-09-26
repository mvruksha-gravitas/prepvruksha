# infra

Deployment scripts and environment templates. **No secrets here.**

| Environment | Supabase | GCP / Firebase | Region |
|---|---|---|---|
| dev | `prepvruksha-dev` (ref `hzpuxfgfheizghpipmew`) | `prepvruksha-dev` | Mumbai / `asia-south1` |
| prod | `prepvruksha-prod` (not yet created) | `prepvruksha-prod` | Mumbai / `asia-south1` |

Secrets live in GCP Secret Manager (services) and git-ignored local files:
`services/*/.env`, `supabase/.env`, `config/*.json`.

**No real student or personal data in `prepvruksha-dev`.** Its test phone
numbers and codes are public (in this repo), so anyone can sign in there.

## Always pass `--project`

This machine also has a gcloud configuration for another project. Every
`gcloud` and `firebase` command for PrepVruksha passes
`--project=prepvruksha-dev` (or `-prod`) explicitly; never rely on, or change,
the active configuration.

## Dev deploys

`.github/workflows/deploy-dev.yml` runs after CI passes on `main`:

| Changed | Deploys |
|---|---|
| `services/api/**`, `infra/cloudrun/**` | API image → Artifact Registry → Cloud Run `prepvruksha-api`, then checks `/health` |
| `apps/app/**`, `packages/core|ui_kit/**`, `pubspec.*`, `firebase.json` | `flutter build web` → Firebase Hosting `prepvruksha-dev.web.app` |

Both deploy when the workflow file changes. Redeploy by hand from Actions >
Deploy dev > Run workflow (`both` / `api` / `web`).

| Resource | Value |
|---|---|
| API URL | `https://prepvruksha-api-765197352192.asia-south1.run.app` |
| Web app | `https://prepvruksha-dev.web.app` |
| Image | `asia-south1-docker.pkg.dev/prepvruksha-dev/prepvruksha/api:<commit>` |
| Runtime account | `api-runtime@` — reads the two secrets only |
| Deployer account | `github-deployer@` — Cloud Run developer, Artifact Registry writer (repo `prepvruksha`), act as `api-runtime`, Firebase Hosting admin |
| GitHub sign-in | Workload Identity Federation pool `github`: only `mvruksha-gravitas/prepvruksha`, `refs/heads/main`, `deploy-dev.yml`. No service account keys. |

Plain API settings (dev) are in `cloudrun/api-dev.env.yaml`. Secrets
(`SUPABASE_SECRET_KEY`, `OTP_HMAC_KEY`) are in Secret Manager, stored in
`asia-south1` only.

### One-time setup (done 26 Sep 2026)

`gcp-dev-setup.sh` creates everything above and can be re-run. The Cloud Run
service was created with Google's sample image and made public there
(`allUsers` invoker), because the deployer is not allowed to change IAM. The
API itself checks Supabase tokens.

### Secret values

Run in **Git Bash** (PowerShell adds a newline when piping to `gcloud`).
Values are read from stdin; they never land in a file, the shell history or
the terminal.

```bash
export PATH="$PATH:$LOCALAPPDATA/Google/Cloud SDK/google-cloud-sdk/bin"

# Supabase secret key "api-dev" (dashboard: Project Settings > API Keys > Secret keys).
# Paste it at the prompt (nothing is shown), then Enter.
read -rs KEY && printf %s "$KEY" | gcloud.cmd secrets versions add SUPABASE_SECRET_KEY --project=prepvruksha-dev --data-file=- ; unset KEY

# OTP_HMAC_KEY: generated and stored without being shown.
python -c "import secrets, sys; sys.stdout.write(secrets.token_urlsafe(32))" | gcloud.cmd secrets versions add OTP_HMAC_KEY --project=prepvruksha-dev --data-file=-

# Check: prints only the length (compare with the key in the dashboard; no extra newline).
gcloud.cmd secrets versions access latest --secret=SUPABASE_SECRET_KEY --project=prepvruksha-dev | wc -c
gcloud.cmd secrets versions access latest --secret=OTP_HMAC_KEY --project=prepvruksha-dev | wc -c   # 43
```

Rotating: add a new version the same way, then redeploy the API (it reads
`:latest` at deploy time). Changing `OTP_HMAC_KEY` invalidates pending parent
codes only.

### GitHub repository variables

Settings > Secrets and variables > Actions > **Variables** (none of these are
secret):

| Variable | Value |
|---|---|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/765197352192/locations/global/workloadIdentityPools/github/providers/github` |
| `GCP_DEPLOYER_SA` | `github-deployer@prepvruksha-dev.iam.gserviceaccount.com` |
| `DEV_SUPABASE_URL` | `https://hzpuxfgfheizghpipmew.supabase.co` |
| `DEV_SUPABASE_PUBLISHABLE_KEY` | publishable key (`sb_publishable_…`) from the dashboard |
| `DEV_API_URL` | the API URL above |
