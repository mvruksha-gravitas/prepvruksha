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

`.github/workflows/deploy-dev.yml` runs after CI passes on `main`, in this
order. A failed step stops the steps after it.

| Changed | Deploys |
|---|---|
| `supabase/**` | `supabase db push --include-seed` to `prepvruksha-dev`, then a check that no migration is left |
| `services/api/**`, `infra/cloudrun/**` | API image → Artifact Registry → Cloud Run `prepvruksha-api`, then checks `/health` |
| `apps/app/**`, `packages/core|ui_kit/**`, `pubspec.*`, `firebase.json` | `flutter build web` → Firebase Hosting target `app`: `prepvruksha-dev.web.app` |
| `apps/console/**`, `packages/core|ui_kit/**`, `pubspec.*`, `firebase.json`, `.firebaserc` | `flutter build web` → Firebase Hosting target `console`: `prepvruksha-dev-console.web.app` |

API, web and console all deploy when the workflow file changes. Run it by hand
from Actions > Deploy dev > Run workflow: `both` (API + web + console), `all`
(database, API, web, console), `database`, `api`, `web` or `console`.

**Seed files run once per project.** `db push --include-seed` runs a seed
file the first time it reaches a project. If the file changes later, the CLI
only records its new hash ("hash update") and does not run it again. So a
change to an existing seed file reaches only fresh databases (local resets,
CI, a new prod project), not dev. Data that must reach dev too goes in by
hand (SQL, as for exam dates) or in a migration. Seed files must still be
safe to re-run (`on conflict`) and must not overwrite what content admins edit.

| Resource | Value |
|---|---|
| API URL | `https://prepvruksha-api-765197352192.asia-south1.run.app` |
| Web app | `https://prepvruksha-dev.web.app` |
| Staff console | `https://prepvruksha-dev-console.web.app` (not indexed: `X-Robots-Tag: noindex`) |
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

# Supabase secret key "apidev" (dashboard: Project Settings > API Keys > Secret keys).
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

### GitHub "dev" environment (database push)

The database step connects with one secret, stored only in the GitHub
environment `dev` (never in the repository or its variables):
`SUPABASE_DB_PASSWORD`, the database password of `prepvruksha-dev`. The job
builds the connection string from it at run time (session pooler
`aws-0-ap-south-1.pooler.supabase.com:5432`, user
`postgres.hzpuxfgfheizghpipmew`) and runs `supabase db push --db-url`.

No Supabase access token is used: `supabase link` would need one that can
read the project's API keys, including the secret keys.

Create the environment once (Settings > Environments > New environment >
`dev`; under Deployment branches choose "Selected branches" and add `main`),
then set the secret from Git Bash. `gh` prompts for the value without
showing it:

```bash
gh secret set SUPABASE_DB_PASSWORD --env dev --repo mvruksha-gravitas/prepvruksha
gh secret list --env dev --repo mvruksha-gravitas/prepvruksha   # names only
```

Database password: the one set when the project was created. If unknown,
reset it under Project Settings > Database (then update the secret). To check
a password without changing anything:

```bash
read -rsp "Dev DB password: " PGPASSWORD; echo; export PGPASSWORD
uv run --no-project --with "psycopg[binary]" python -c "import psycopg; c = psycopg.connect(host='aws-0-ap-south-1.pooler.supabase.com', port=5432, dbname='postgres', user='postgres.hzpuxfgfheizghpipmew', sslmode='require', connect_timeout=10); print('OK: connected as', c.execute('select current_user').fetchone()[0])"
unset PGPASSWORD
```

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

### Staff console (one-time setup)

The console is a second Firebase Hosting site in the same project. The site is
created once by a person (the deployer can deploy to it but does not create
it). `.firebaserc` maps the targets: `app` → `prepvruksha-dev`, `console` →
`prepvruksha-dev-console`.

```powershell
npx --yes firebase-tools@14 login
npx --yes firebase-tools@14 hosting:sites:create prepvruksha-dev-console --project=prepvruksha-dev
```

The API allows the console's origin through `CORS_ORIGIN_REGEX` in
`cloudrun/api-dev.env.yaml`.

**Dev staff** (test numbers only, rule 13): sign in to the console once with
each number, then in the Supabase dashboard (prepvruksha-dev > SQL Editor):

```sql
insert into public.staff_roles (user_id, role)
select id, r.role
from auth.users u
join (values ('919999900002', 'content_admin'),
             ('919999900003', 'reviewer'),
             ('919999900004', 'super_admin')) as r (phone, role)
  on u.phone = r.phone
on conflict do nothing;
```

A number that has not signed in yet gets no row; run it again after it has.
