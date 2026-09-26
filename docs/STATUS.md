# Status — PrepVruksha

Last updated: 26 Sep 2026: **slice 1 done** (PRs #18, #20; staff console live on dev, end-to-end upload verified); next: sub-topics + difficulty (plan proposed); Biology sub-topic draft awaiting the subject expert

Read this at the start of every conversation. Update it at the end of every slice.
Decisions and their reasons go in the decisions log in `docs/ARCHITECTURE.md`.

## 0. Launch blockers

**No real user signs up until all of these are done.** Until then only the test phone numbers are used.

- [ ] **Login provider decided** (see "Login provider" under open decisions), then **real SMS sending (DLT-registered)** for both sign-in OTP (Supabase Auth) and parent consent codes (`services/api`, replacing `LogOtpSender`). The API refuses to start with `APP_ENV=prod` while the log sender or test parent numbers are configured.
- [ ] **Final legal text from a lawyer:** terms of use, privacy policy and parental consent text. Publish it as a new `policy_versions` row (terms + parental) and replace the placeholder in `PolicyScreen` / the `policyPlaceholderBody` strings. A new terms version makes every student accept again.
- [x] Signup and parental-consent flow (PR #3).
- [ ] **Stronger sign-in for production staff** (reviewers, content admins, super admins), e.g. Google sign-in with 2-step verification, in addition to or instead of phone OTP. Staff can publish content and edit answer keys, so a phone OTP alone is not enough in prod. The console's auth is built to allow adding it.

## 1. Done

### Week 1 — Foundations (PR #1, merged to `main`)

- **Repo:** monorepo per `CLAUDE.md`; `.gitattributes` (LF, CRLF for Windows scripts); `.gitignore` covers `config/*.json`, `.env` files and signing keys.
- **Flutter:** Dart pub workspace (`apps/app`, `apps/console`, `packages/core`, `packages/ui_kit`).
  - `apps/app`: phone OTP login (phone screen → OTP screen → home with sign-out), go_router guard on auth state, Riverpod, English + Kannada ARB strings, language button.
  - Android flavors `dev` (`com.mvruksha.prepvruksha.dev`, "PrepVruksha Dev") and `prod` (`com.mvruksha.prepvruksha`). Dev debug APK builds.
  - `apps/console`: placeholder screen only.
- **Config:** `--dart-define-from-file=config/<env>.json` (git-ignored); templates `config/local.example.json`, `config/dev.example.json`. Only the publishable key goes in app config.
- **Supabase:** migrations `20260926000100` – `20260927000100` (helpers, `staff_roles`, `profiles`, `consents`, syllabus, questions, explicit Data API grants).
- **Seed:** NEET-UG, Physics/Chemistry/Botany/Zoology, 100 chapters (81 current, 19 removed from the syllabus but kept for PYQ tagging). Kannada names AI-drafted, `name_kn_reviewed = false`. No topics yet.
- **Services:** `services/api`, `services/pipeline`, `services/seo` scaffolds on Python 3.12 via uv.
- **CI:** `.github/workflows/ci.yml` — Flutter (l10n up to date, format, analyze, tests), Python matrix, database (migrations, lint, pgTAP).
- Login through the running app verified on web (Chrome, local Supabase).

### Signup and parental consent (DPDP) — PR #3, merged to `main`

Order of steps for a signed-in user: **profile → terms → parental consent (under 18 only) → home.** The router sends the user to the first unmet step; the step is decided by the database at the time of asking.

- **Database** (migrations `20260928000100` – `20260928000400`, seed `02_policy_versions.sql`):
  - `audit_log` (append-only; super admins read). First use: date-of-birth corrections.
  - `policy_versions` (`terms`, `parental`; one current per type; `scope` = purpose consented to). Seeded with placeholder versions `2026-10-draft`.
  - `consents` gains `scope` and `request_id`; `parent_otp` consents must reference their request; one active consent per user/type/version.
  - `parental_consent_requests`: parent name/phone, policy version, scope, **HMAC of the code only** (cleared once closed), status, attempts, expiry. No client access.
  - Date of birth **set once**, ages 13–30 at signup (trigger `private.guard_date_of_birth`). Corrections only through `public.correct_date_of_birth(actor, user, dob, reason)` (super admin, audited).
  - `private.signup_status(user, as_of)` derives the step at the time of checking: parental consent stops being required on the 18th birthday (tested); withdrawal sends the user back to the step.
  - Service-role-only RPC functions: `get_signup_state`, `complete_profile`, `accept_terms`, `start_parental_consent`, `verify_parental_consent`, `withdraw_consent`, `correct_date_of_birth`.
  - Parent code limits: 60 s between codes, 5 codes per user and 5 per parent number per rolling 24 h (one parent may consent for several children), 10 min expiry, 5 attempts per code.
- **API** (`services/api`): Supabase JWT verification via JWKS; `GET /me/signup`, `PUT /me/profile`, `POST /me/consents/terms`, `POST /me/consents/parental` (send / resend / change number), `POST /me/consents/parental/verify`, `POST /me/consents/{terms|parental}/withdraw`. Parent codes: 6 digits, HMAC-SHA256 keyed with `OTP_HMAC_KEY` and bound to the user. Dev delivery = `LogOtpSender` (code in the API log); test parent numbers with fixed codes via `PARENT_OTP_TEST_CODES`. CORS for local Flutter web.
- **App:** gate screen (loading / error + retry), profile form (DD/MM/YYYY date of birth with a "can't be changed later" note, exam year, optional category, language), terms screen + placeholder policy page, parent consent screen (form → waiting view with code entry, resend after the wait, change number, sign out), consent withdrawal on home (with confirmation). Language choice saved to `profiles.preferred_language` and restored once the profile is complete. `AppConfig` now requires `API_URL`.
- **Tests:** 244 pgTAP (new `04_signup.test.sql`), API 39 pytest, core 26, app 30, console 1, ui_kit 1. Verified end to end against local Supabase + local API over HTTP (sign in → profile → terms → parent code → verify → withdraw; app clients get 403 on the RPC functions and on writing `date_of_birth`). Clicked through in Chrome on the dev web app on 26 Sep (see Dev deploy below).

### Modular structure — PRs #4 and #5, merged to `main`

Feature-first layout per "Modularity" in `CLAUDE.md`. No behaviour change.

- **API** (`services/api/src/prepvruksha_api/`): `auth/` (JWT verification), `profile/` (`GET /me/signup`, `PUT /me/profile`), `consent/` (terms, parent codes, withdrawal), `shared/` (settings, Supabase RPC, phone numbers, signup state + rule-error mapping). Each feature's `__init__.py` is its public entry. Tests mirror it (`tests/<feature>/`, fakes in `tests/conftest.py`).
- **App** (`apps/app/lib/src/`): `auth/`, `profile/` (profile step, language), `consent/` (signup state, gate, terms, policy, parent consent), `home/`, each with an entry file `<feature>.dart`; `app/` (app, router, config error) and `shared/` (routes, `appConfigProvider`). Tests: `test/<feature>/` and cross-feature `test/flows/`.
- **Boundary checks:** `import-linter` contracts in `services/api/pyproject.toml` (`uv run lint-imports`); `tool/check_import_boundaries.dart` for Dart (`dart run tool/check_import_boundaries.dart`). Both run in CI.
- **CI:** jobs run only when their folders change (`dorny/paths-filter`); **"CI result"** always runs and is the only required status check in `main`'s branch protection.
- Tests: API 39, app 30 (unchanged counts).
- **Consent config** (follow-up PR): parent-code settings (`OTP_HMAC_KEY`, `PARENT_OTP_SENDER`, `PARENT_OTP_TEST_CODES`) and the prod safety check moved to `consent/config.py`; `main.py` still refuses to start prod with the log sender or test parent numbers (tested by starting the app in a subprocess). API tests: 46.

### Dev deploy — PR #6, merged to `main`, verified 26 Sep

Runbook: `infra/README.md`.

- **API image:** `services/api/Dockerfile` (uv, non-root, no dev deps; `.dockerignore` keeps `.env` out). CI job "API image" builds it, checks `/health` and that it refuses to start with `APP_ENV=prod`.
- **GCP (`prepvruksha-dev`, `asia-south1`), created by `infra/gcp-dev-setup.sh`:**
  - Artifact Registry repo `prepvruksha`.
  - Secrets `SUPABASE_SECRET_KEY` and `OTP_HMAC_KEY`, stored in Mumbai only.
  - `api-runtime` account (reads those two secrets only).
  - `github-deployer` account (Cloud Run developer, AR writer on the repo, act as `api-runtime`, Firebase Hosting admin).
  - Workload Identity Federation for `deploy-dev.yml` on `main` only.
  - Cloud Run service `prepvruksha-api` (public; the API checks tokens).
- **`.github/workflows/deploy-dev.yml`:** after CI passes on `main`, deploys the API if `services/api/**` or `infra/cloudrun/**` changed, and the web app if `apps/app/**`, `packages/core|ui_kit/**`, `pubspec.*` or `firebase.json` changed. Also runs by hand.
- **Web:** `firebase.json` (SPA rewrite, `no-cache` for html/js/json/wasm, basic security headers); the build config comes from GitHub repository variables.
- **Settings fix:** `PARENT_OTP_TEST_CODES` from the environment now replaces the `.env` value instead of being merged with it (tested). API tests: 49.
- **Verified on dev (26 Sep):**
  - First Deploy dev run passed (API + web, 3.5 min).
  - `/health` returns `env: dev`, and requests without a token get 401. CORS allows `prepvruksha-dev.web.app`, and direct links work.
  - **Signup clicked through in Chrome on `https://prepvruksha-dev.web.app`** with +91 99999 00001: profile (minor), terms, parent +91 99999 00006 / `123456`, then home. The database has one test profile with two consents.
- **Rule 13 in `CLAUDE.md`:** no real student or personal data in `prepvruksha-dev`.

### Deploy dev: database step — PRs #10 and #11, merged to `main`

- When `supabase/**` changes, Deploy dev first runs `supabase db push --include-seed` against `prepvruksha-dev`. A dry-run is logged first, and a check afterwards confirms nothing is left to push.
- The order is database, then API, then web. A failed or cancelled step stops the steps after it.
- The manual run can target `all`, `database`, `both`, `api` or `web`.
- The only credential is `SUPABASE_DB_PASSWORD`, a secret of the GitHub `dev` environment (limited to `main`). The job connects with `supabase db push --db-url` through the session pooler. No Supabase access token is used, because `supabase link` would need a token that can read the project's API keys (first run failed with `api_gateway_keys_read`).
- Verified: after the #10 and #11 merges, the database step was skipped (nothing under `supabase/**` changed) and the API and web still deployed. The first real database run (merge of #12) passed.
- **Learned on that run: seed files run once per project.** The changed `03_exam_cycles.sql` was not re-run on dev; the CLI only updated its hash, and the "up to date" check still passed. The 2028/2029 rows were then added on dev by hand (SQL, 26 Sep). See `infra/README.md`.

### Exam cycles — PR #8, merged to `main`, on dev

The target exam years at signup come from data, not from a hard-coded month.

- **Database** (migration `20260929000100_exam_cycles.sql`, seed `03_exam_cycles.sql`):
  - `exam_cycles` (exam, year, date, `date_confirmed`): everyone reads, content admins write.
  - `public.target_exam_years(exam_code, as_of)` returns the first sitting whose date is today or later (India time) plus the two years after it, or empty when none is recorded.
  - `complete_profile` and a new `profiles` trigger (`private.guard_target_exam_year`) both use the rule, so direct client updates of `target_exam_year` are checked too. Only changes are checked, so a year chosen earlier stays valid after its exam.
  - Seed: NEET-UG 2027, 2028 and 2029, tentative, on the first Sunday of May (2 May 2027, 7 May 2028, 6 May 2029), `date_confirmed = false`. On dev since 26 Sep (2027 from the seed; 2028 and 2029 added by SQL, because a changed seed file is not re-run).
- **App:** the profile step lists the years from the rule. It shows a retry when they fail to load, and a "signup paused" message when no upcoming date is recorded.
- **Tests:** pgTAP 266 (new `05_exam_cycles.test.sql`; `04_signup` uses its own cycles, independent of the date), app 33.

## 2. Environments

| | Local | `prepvruksha-dev` |
|---|---|---|
| Supabase | `supabase start` (Docker Desktop). Test numbers in `config.toml` | Ref `hzpuxfgfheizghpipmew`, Mumbai. Linked from this repo |
| Migrations | All 13 (via `supabase db reset`) | All 13 applied, up to `20260930000200` (Deploy dev #14, 26 Sep) |
| Seed | Applied on reset | Syllabus (100 chapters), the two `2026-10-draft` policy versions, NEET-UG exam cycles 2027–2029 (2028/2029 added by SQL) |
| Users / staff | Test numbers only | Test users +91 99999 00001–00005 (test numbers only). Staff roles (26 Sep): 00002 content admin, 00003 reviewer, 00004 super admin. Made-up source files from the slice 1 test; 0 questions |
| Phone auth | Works with test numbers (placeholder Twilio in `config.toml`) | Test numbers +91 99999 00001–00005 / `123456` (valid until 31 Dec 2027); placeholder Twilio values; OTP expiry 300 s. The test numbers are public: **no real student or personal data on dev** |
| `services/api` | `uv run uvicorn prepvruksha_api.main:app --reload` with `services/api/.env` (see `.env.example`: secret key, `OTP_HMAC_KEY`, `PARENT_OTP_TEST_CODES`) | Cloud Run `prepvruksha-api`: `https://prepvruksha-api-765197352192.asia-south1.run.app` (deployed from `main` by Deploy dev) |
| GCP / Firebase | — | Project `prepvruksha-dev`, `asia-south1`. Web app: `https://prepvruksha-dev.web.app`. Staff console: `https://prepvruksha-dev-console.web.app`. See `infra/README.md` |
| GitHub | — | Repository variables for the dev build and GCP sign-in; environment `dev` (main only) holds `SUPABASE_DB_PASSWORD`. Branch protection on `main`: "CI result" required |

Privileges are identical locally and on dev, so local tests reflect dev.
`supabase test db --linked` does not work (the CLI's temporary role cannot see pgTAP in `extensions`); verify dev with the Data API or `supabase db query --linked`.

Test parent numbers (fixed code `123456`, nothing sent): +91 99999 00006 and 00007, configured in the API's `PARENT_OTP_TEST_CODES` (not in Supabase Auth).

## 3. Open to-do

- [x] **First super admin** on dev: +91 99999 00004 (26 Sep, with the staff console test).
- [ ] **Remove the unused Supabase token** (security: a live credential nothing uses): delete the `github-deploy-dev` token (supabase.com/dashboard/account/tokens) and the secret (`gh secret delete SUPABASE_ACCESS_TOKEN --env dev --repo mvruksha-gravitas/prepvruksha`).
- [ ] **Budget alerts** on GCP `prepvruksha-dev` and a spend cap on Supabase (Day 1 item in `ROADMAP.md`, not done yet).
- [ ] **Anthropic key in Secret Manager** (`prepvruksha-dev`, Mumbai) before slice 2; today it is only in the local `services/pipeline/.env` (key rotated 26 Sep after it nearly leaked; see slice 1, secret scanning).
- [ ] **Real NEET files test (you + me):** your real NEET files with a rights status and note for each, and a hand-checked answer sheet. Then compare **Opus 5 at `medium` against `high`**; if `medium` has 0 invented answers and no drop in accuracy, make `medium` the default (`PARSE_EFFORT`).
- [ ] **Keep exam dates on record:** NEET-UG 2027, 2028 and 2029 are tentative (first Sunday of May, `date_confirmed = false`). When NTA announces a date, a content admin sets the official `exam_date` and `date_confirmed = true`. Add the 2030 sitting before 6 May 2029, or signup pauses (no years offered). A console screen for exam cycles comes with the review console; until then, use SQL (`supabase/README.md`).
- [ ] **Staff date-of-birth correction** in the console: API endpoint + screen calling `public.correct_date_of_birth` (the function and its audit entry exist; no UI yet). Also offline (paper) parental consent: staff records `method = 'offline_form'` consents collected by pilot colleges.
- [ ] **Account deletion and data erasure requests** (DPDP), a later slice: delete/anonymise user data on request, keep what the law requires (consent records), and decide how long withdrawn accounts are kept.
- [ ] **Content review:**
  - Subject expert: chapter list, removed chapters, Botany/Zoology split (`supabase/seed/01_neet_syllabus.sql`), and the **draft NEET sub-topic tree** (drafted before slice 2; see section 4).
  - Kannada translator: syllabus names (`name_kn`) and app strings (`apps/app/lib/l10n/app_kn.arb`, tracked in `apps/app/lib/l10n/README.md`), now including the signup and consent screens.
- [ ] Choose the DLT-registered SMS/WhatsApp OTP provider (launch blocker above; long-lead item in `ROADMAP.md`).

### Open decisions before launch

- [ ] **Login provider: Firebase Phone Auth vs Supabase Auth + an Indian OTP provider.** Still undecided; research before launch. Today the apps use Supabase Auth (phone OTP); its JWT drives RLS and the API, and users live in Postgres (`auth.users`). Notes so far (26 Sep, to be checked in the research):
  - **Firebase Phone Auth:** Google sends the SMS, which would avoid our own DLT sender and template registration. Parent verification could be a second Firebase phone sign-in on the parent's number, which also creates the parent account needed later (`parent_links`) and could replace our own parent codes.
  - **Cost of Firebase:** reworking login: profiles (keyed to `auth.users` today), access rules (RLS reads Supabase's JWT; Supabase accepts third-party auth JWTs, but every policy and helper must be checked), the API's token check, and the tests. More Firebase lock-in (rule 8: users would live outside Postgres) and data location to confirm (rule 9).
  - **Alternative:** keep Supabase Auth and add one Indian OTP provider that handles DLT (e.g. Twilio Verify, MSG91) for both sign-in and parent codes; nothing already built changes.
  - Still to compare: cost per OTP, delivery rates in India, staff sign-in with Google and 2-step verification (launch blocker), and where each stores user records.
- [ ] **Repository visibility:** the GitHub repository is **public**, while `ROADMAP.md` planned a private one. No secrets are in it (only project IDs, URLs and the public test numbers), but decide whether it should be private.

### Polish list

Minor, non-urgent improvements. Done in batches when asked, not on the side of other work (see "How to work" in `CLAUDE.md`). Security, privacy and correctness items never go here.

- [ ] **Shared Supabase auth adapter:** `SupabaseAuthRepository` is copied in `apps/app` and `apps/console`; move it to a shared Flutter package (e.g. `packages/supabase_adapters`) when a third copy would appear.
- [ ] **Upload progress:** the console shows real progress while hashing, but an indeterminate bar while uploading (the `http` browser client gives no upload progress). Add byte progress if large uploads feel stuck.
- [ ] **One API client in core:** `ApiSignupRepository` has its own copy of the request/error code that `ApiClient` now provides; switch it over.
- [ ] **`StarletteDeprecationWarning` in API tests** ("Using `httpx` with `starlette.testclient` is deprecated; install `httpx2`"): comes from FastAPI's `TestClient`, not our code; switch when FastAPI/Starlette settle on the replacement.
- [ ] **GitHub Actions on Node 20** (deprecated warnings): bump `actions/checkout`, `google-github-actions/auth` and `setup-gcloud` to their Node 24 versions.
- [ ] **import-linter for `services/seo`** once it has feature folders (CI skips the step until then; the API and pipeline have contracts).
- [ ] **Seed "hash update" warning** in Deploy dev (a changed seed file is not re-run on existing projects) and a CLAUDE.md convention that data changes for existing projects go in migrations. Do before prod holds data.
- [ ] **Vector-drawn figures** in PDFs (drawings, not embedded images) are not cut out as assets yet; the page image still carries them.
- [ ] Local signup click-through against the local API (dev is verified): needs `"API_URL": "http://127.0.0.1:8000"` in `config/local.json`.
- [ ] Set `API_URL` in your local `config/dev.json` to the Cloud Run URL (Android dev builds).
- [ ] Log in through the running app on the Android emulator (emulator + local Supabase needs `http://10.0.2.2:54321`).
- [ ] Build the `prod` flavor once, and a release build (needs a signing key; never commit it).

## 4. Current slice: import pipeline + review console (Weeks 2–4 in `ROADMAP.md`)

Plan approved 26 Sep 2026, in five slices, each end to end:

0. **Command-line prototype** (`services/pipeline`, branch `feat/pipeline-prototype`, done). Parses a local folder of samples (`C:\prepvruksha-samples`, never committed; API key from a local `.env` only) with the Claude API into the fixed JSON format, and reports accuracy against a hand-checked answer sheet: per format, formulas, answers, cost per page. For scanned pages it tests Claude reading page images; Mathpix is decided from the results. No database or UI. `extract` and `parse` are reused by the slice 2 worker. How to run: `services/pipeline/README.md`.
   - **First results (26 Sep, 3 NEET-style sample files, 72 questions: Word, text PDF, scanned PDF):**

     | Setting | Found | Format right | Answers right | Answers invented | Cost | Per question |
     |---|---|---|---|---|---|---|
     | Opus 5, effort high | 72/72 | 72/72 | 72/72 (24 via the answer-key table) | 0 | $0.69 | $0.0096 |
     | Sonnet 5, effort high | 72/72 | 71/72 (scanned C Q15 labelled `numerical`) | 72/72 | 0 | $0.29 | $0.0041 |

     - Claude read the scanned pages as well as the text pages with both models ($0.064 a page on Opus, $0.026 on Sonnet), so Mathpix is not needed so far.
     - Formula syntax was OK on 33/33 questions with formulas. Text-PDF subscripts (H2SO4) came back as LaTeX.
     - The two models differ only in layout (match-the-following as a table vs lines; units in LaTeX vs plain).
     - Set A Q22's broken options ("and (d) only") were a flaw in the sample file itself, not the pipeline; both models flagged it `unclear_text`.
   - **Decisions (26 Sep):**
     - **Model and effort are settings** (`PARSE_MODEL`, `PARSE_EFFORT`), default **Opus 5 at `high`**. No more model comparisons on these samples.
     - **Mathpix is not needed:** Claude reads scanned pages directly; scanned-PDF handling moves into slice 2.
     - **Figures:** a text PDF page with embedded images now goes as text plus the page image, and each figure is cut out, numbered and saved as an asset linked to its question (`figure_numbers`); Word images the same way. Re-run of Set B page 2: Q13 linked to its graph, no longer `figure_needed` (page cost $0.071 vs $0.054 as text only). Vector drawings (not embedded images) are not cut out yet; the page image still carries them.
1. **Staff console and uploads** (no AI). **Done 26 Sep 2026** (PRs #18 and #20). On dev: Deploy dev published the console to `prepvruksha-dev-console.web.app` and the API with its CORS origin; staff roles set by SQL; the owner uploaded made-up files as 00002 (an official PYQ with exam and year, and a reference-only file), both `queued`; 00003 (reviewer) saw only the PYQ file and no Upload button. Details of what was built:
   - **Console: done locally (branch `feat/slice1-console`, not pushed).**
     - `packages/core`: `ApiClient`/`ApiFailure`, `StaffMember` + `ApiStaffRepository`, `SourceFile`/`RightsInput` + `ApiContentRepository` (upload PUTs the bytes straight to the signed Storage URL), chunked `sha256Hex` with progress (`crypto`). Core tests: 36.
     - **Hosting (committed locally):** `firebase.json` has two targets (`app`, `console`; the console sends `X-Robots-Tag: noindex`); `.firebaserc` maps `console` → `prepvruksha-dev-console`; Deploy dev has a `console` job (runs when `apps/console/**`, shared packages, `pubspec.*`, `firebase.json` or `.firebaserc` change; manual option `console`); the web job deploys only `hosting:app`; `CORS_ORIGIN_REGEX` allows `prepvruksha-dev-console`. **Before merging:** create the site (`infra/README.md`, "Staff console").
     - `apps/console` features: `auth` (sign-in methods listed from `SignInMethod`, today phone OTP only), `staff` (roles from `GET /staff/me`; "checking access" with retry; "no access" for non-staff), `content` (file list with status and rights filters, rights badge with PYQ exam/year, rights note as tooltip; upload dialog: PDF/Word up to 100 MB, rights status with no default, required note, exam + year for official PYQs; steps hash → record → upload → confirm). Upload button only for content admins and super admins. English ARB strings (`apps/console/lib/l10n/`). Console tests: 10. CI checks the console's generated l10n files too. Done when a staff member signs in to the console on dev, uploads a PDF or Word file with a rights status and rights note, and sees it listed as `queued` with an import job waiting for the slice 2 worker.
   - **Secret scanning first** (security, added after the Anthropic key nearly leaked on 26 Sep): gitleaks in CI on every PR and push, and a simple local pre-commit check if it stays simple. **Done locally (not pushed):** CI job "Secret scan (gitleaks)" (pinned 8.30.1, checksum-verified, full history, part of "CI result") and `.githooks/pre-commit` (enable with `git config core.hooksPath .githooks`). History scan: 48 commits, no leaks.
   - **Database: done locally (not pushed)**, migration `20260930000100_source_files.sql`:
     - `source_files`, `import_jobs`, `import_items`; FK `questions.source_file_id`; private bucket `source-files` (PDF/Word, 100 MB, no client storage policies).
     - RLS: staff read only; `private.can_see_source_file` hides `reference_only` files (and, through them, their items) from reviewers; import jobs visible to content admins only.
     - Service-role functions (content admins and super admins): `create_source_file` (validates type, size, hash, rights; reuses an unfinished upload of the same content; `duplicate_file` otherwise; audited), `complete_source_file_upload` (object must exist in the bucket with the recorded size; marks `queued` and creates the import job in one transaction), `set_source_file_rights` (reason required; audited old/new; only `reference_only` once questions are published, which retires them, audited).
     - Tests: pgTAP 348 (new `06_source_files.test.sql`, privileges matrix updated); lint clean; functions checked as `service_role`.
     - Read functions (migration `20260930000200_source_file_reads.sql`): `get_staff_roles`, `get_source_file`, `list_source_files`, applying the same reference-only rule for the acting staff member (hidden files answer `file_not_found`).
   - **API: done locally (not pushed).** Features `staff` (`GET /staff/me`; `current_staff` is the one dependency for staff endpoints, where a production sign-in rule can be added) and `content` (`GET /content/files?status=&rights_status=`, `POST /content/files` → file + signed upload URL, `POST /content/files/{id}/complete`, `PATCH /content/files/{id}/rights`); `shared/storage.py` creates signed upload URLs (`x-upsert` so a retried upload can replace a partial object). Writes need content admin or super admin (checked in the API and again in the database). CORS allows `PATCH`. API tests: 82. **Verified against local Supabase** (26 Sep): sign in as +91 99999 00002 (content admin) → create → complete before upload refused (`upload_missing`) → PUT to the signed URL → complete → `queued`; same file again → `duplicate_file`; +91 99999 00003 (reviewer) cannot see the reference-only file, cannot upload (403), and cannot read the object or table directly with their own token.
   - **Rights status (approved 26 Sep):**
     - `rights_status` required (`owned_licensed`, `official_pyq`, `reference_only`), no default, recorded in `audit_log` at upload.
     - `official_pyq` files must record the **exam and year** (e.g. NEET_UG 2023: `pyq_exam_id`, `pyq_year`), used later to label their questions (`source_type = 'pyq'`, `pyq_year`).
     - **`reference_only` files and their items are visible only to content admins and super admins**, not reviewers (RLS + API).
     - Content admins and super admins can change the status later (audited: old, new, reason); once a file has published questions it can only move to `reference_only`. The publish block for `reference_only` comes in slice 3.
     - API: `rights_status` (and PYQ exam/year) on `POST /content/files`; returned and filterable on `GET /content/files`; `PATCH /content/files/{id}/rights`. Console: required choice with one-line explanations, exam/year fields for PYQ, badge and filter in the list.
   - **Database** (one migration):
     - `source_files` (name, type `pdf`/`docx`, size, SHA-256, required **rights status** (`owned_licensed`, `official_pyq`, `reference_only`) and rights note, uploaded by, status `awaiting_upload` → `queued` → … `done`/`failed`, error); **identical files rejected** (unique hash).
     - `import_jobs` (queue for the slice 2 worker) and `import_items` (as in `DATA_MODEL.md`); FK `questions.source_file_id`.
     - Private Storage bucket `source-files` (Mumbai): **PDF and Word only, 100 MB limit** (scanned books can be large). No client storage policies; files arrive only through signed upload URLs from the API.
     - Staff read; all writes through service-role functions that take the acting staff member and check the role (like `correct_date_of_birth`). **Upload: content admins and super admins; reviewers only review.** Privileges matrix and pgTAP tests.
   - **API** (`content` feature): `GET /staff/me` (roles; the console's access check); `POST /content/files` (checks type, size, rights note; records the file; returns a short-lived signed upload URL); `POST /content/files/{id}/complete` (confirms the object in Storage with the expected size, marks it `queued`, creates the import job); `GET /content/files` (list by status). Staff endpoints go through one dependency where a production rule (e.g. Google sign-in with 2-step verification) can be enforced later.
   - **Console** (`apps/console`, Flutter web, feature folders + boundary checks): `auth` (phone OTP behind a list of sign-in methods, so Google can be added without changing screens); staff guard ("no access" for non-staff); `content` (file list with status; upload dialog: rights note, SHA-256 in the browser, direct upload to Storage with progress, then confirm). **English only, strings in ARB files** so Kannada can be added later.
   - **Hosting:** new Firebase Hosting site `prepvruksha-dev-console` (create with `firebase hosting:sites:create prepvruksha-dev-console --project=prepvruksha-dev`), deployed by Deploy dev when `apps/console/**` changes; its origin added to the API's CORS setting.
   - **Dev staff:** after first sign-in, by SQL: +91 99999 00002 content admin, 00003 reviewer, 00004 super admin.
   - **Tests:** pgTAP (tables, RLS, functions, bucket), API pytest with a fake Storage, console widget tests with fakes, `core` client tests; an end-to-end upload on dev.
   **Then, before slice 2: sub-topics and difficulty.** Draft the NEET sub-topic tree (subject → chapter → topic → sub-topic) from the official NEET syllabus and NCERT, for the subject expert to review; the migration in `DATA_MODEL.md` section 10.
2. **Worker**: extraction + parsing as a Cloud Run Job started by the API, writing `import_items`, including scanned PDFs (Claude reads the page images) and figures saved to Storage as question assets. Suggests sub-topic and difficulty. Items of `reference_only` files are marked `reference` (corpus only).
3. **Review screen and publishing**: source page beside the parsed question, edit, confirm sub-topic and difficulty, approve (one transaction: question + options + `audit_log`), reject. `reference_only` items cannot be approved.
4. **Similarity and harder answer-key layouts** (no Mathpix), **before launch**. Embeddings: an open model inside the worker (data stays in India). Every new question compared by meaning against the bank and the reference-only corpus; `similarity_flags` above the threshold (set on real data) block publishing until resolved.
5. **Question generator** (new module, **after launch**, following the CBT engine): questions per sub-topic, difficulty and format from chapter content into the review queue (`source_type = 'ai_generated'`); independent second AI solve must agree (else flagged); the subject expert confirms every answer; similarity check on each.

Decisions: staff on dev sign in with test numbers +91 99999 00002–00005 (made staff by SQL); the console's auth is built so a stronger method can be added for production staff (see launch blockers).

### Current slice: sub-topics and difficulty (approved 26 Sep: 1a load the draft, 2a strict publish rule)

Additions approved with it: publish only when the sub-topic is `expert_reviewed`; removed chapters/topics/sub-topics stay in the tree with `is_removed` (old PYQs still get a sub-topic), and practice and mocks exclude removed sub-topics by default; Chemistry and Physics drafts are built from the official NMC NEET-UG syllabus PDF (`C:\prepvruksha-reference\`, never committed) and NCERT contents, and the Biology draft is checked against the PDF (differences listed) **before** it is loaded.

- [x] Schema (branch `feat/subtopics`, local): migration `20261001000100` (`sub_topics`, question sub-topic/difficulty columns, publish guards, `question_topics` dropped). pgTAP 371.
- [x] Loader (local): `uv run prepvruksha-pipeline syllabus-sql` writes a numbered **seed file** from `docs/syllabus/*.md` (migrations run before the chapter seed on fresh databases). Upserts, never deletes; pinned slugs `{old-slug}`; notice for rows the markdown no longer has. Trial-loaded Biology locally: 32 chapters, 170 topics, 355 sub-topics; correction/approval/re-run cases checked. Pipeline tests: 54.
- [x] **Biology draft loaded as it is** (priority change 26 Sep): `supabase/seed/04_syllabus_biology.sql`, 38 chapters (32 current + the 6 removed Biology chapters with one placeholder topic "Whole chapter" each, `is_removed`), 361 sub-topics, all `expert_reviewed = false`. The worker and review screens tag against it; the publish guard keeps unreviewed sub-topics from students. pgTAP 374.
- [ ] **Deferred until the modules and UIs are done** (decided 26 Sep): checking the Biology draft against the official NMC NEET-UG syllabus PDF (list differences, resolve the 9 "Check" items); the Chemistry and Physics trees (from the PDF and NCERT contents, not from memory); the real topics of the 6 removed Biology chapters (and the removed Chemistry/Physics chapters). **Needed from the owner then:** the NMC syllabus PDF and the pre-2023 NCERT contents pages in `C:\prepvruksha-reference\` (never committed). Loading goes through new seed files (`docs/syllabus/README.md`). Until then Chemistry and Physics questions can be imported but not tagged below chapter level, so they cannot be published.

### Build order (revised 26 Sep; weeks in `ROADMAP.md`)

1. Pipeline slice 1: secret scanning, staff console and uploads with rights status (week 2).
   - In parallel: draft the NEET sub-topic tree, one subject at a time, Biology first (separate docs/seed PR) for the subject expert.
2. Sub-topics and difficulty migration (week 3).
3. Pipeline slice 2: worker (weeks 3–4).
4. Pipeline slice 3: review and publishing (week 5).
5. Pipeline slice 4: similarity checks, before launch (weeks 6–7).
6. CBT exam engine (weeks 7–10).
7. Results and error notebook.
8. Practice and search.
9. Public SEO pages.
10. Live mocks (and the pilot).
11. Launch: early to mid January 2027.
12. Question generator, after launch (decided 26 Sep, so launch stays near early January).

## 5. Carry-over notes

- **Children's data:** no behavioural tracking or targeted advertising for users under 18 (rule 12 in `CLAUDE.md`). Any analytics added later (Firebase Analytics, Crashlytics custom keys, marketing SDKs) must respect this; check minor status server-side, and default to off when it is unknown.
- **Blocking access:** today only the app router enforces "signup complete". When student data tables arrive (attempts, practice, bookmarks), their RLS policies and API endpoints must also require `private.signup_status(user) = 'complete'`, so a withdrawn consent blocks data access, not just screens.
- **Policy versions:** a new terms version sends every student back to the terms step. Parental consent is not re-asked on a new parental version (any active parental consent counts); decide when the lawyer's text arrives whether a new parental version needs fresh consent.
- **`.env` in images:** the API image never contains a `.env` (`.dockerignore`); settings come only from the Cloud Run environment and Secret Manager.
- **Deployer permissions:** `github-deployer` cannot change IAM. New public Cloud Run services, or new secrets, are added with the setup script (run by a person), not from GitHub Actions.
- **Parent consent evidence:** `consents` row (parent name, phone, method, policy version, scope, timestamp, `request_id`) + the `parental_consent_requests` row (sent time, attempts, verified time). Raw codes are never stored or logged outside the dev `LogOtpSender`.
- **Withdrawing parental consent** is possible from the student's own account for now. Parent accounts (`parent_links`) come later; the parent should be able to withdraw from their side too.
- **Migration timestamps:** the latest migration is `20260930000200`. New migrations must use later timestamps (the machine clock has been behind the migration dates; check what `supabase migration new` produces). Never edit a pushed migration; add a new one.
- **Grants:** every new table or view needs explicit grants and an entry in `supabase/tests/database/03_privileges.test.sql`, or the tests fail. New `public` functions need explicit `revoke ... from public, anon, authenticated` (functions default to `EXECUTE` for `PUBLIC` unless revoked). Never grant `TRUNCATE`, `REFERENCES`, `TRIGGER` or `MAINTAIN` to API roles.
- **Per-user data in the Flutter apps:** a provider that holds data the server filtered for the signed-in person (files, attempts, results) must watch the signed-in user, so a sign-out drops it and the next sign-in reloads it. Found 26 Sep in the console: after a content admin signed out, a reviewer on the same tab saw the admin's cached list, reference-only files included (the database itself filtered correctly). Fixed and tested.
- **Answer keys:** `question_options.is_correct` is unreadable by `anon`/`authenticated`, including staff. Client writes to options must not request the row back (PostgREST `Prefer: return=minimal`). The review console needs a server-side function (API or `security definer` with a staff check) to show the answer key. Practice feedback also needs a server-side check.
- **`exam_reserved` questions** are never public; the SEO build must read only `public.seo_questions` (service role).
- **Categories:** keep `profiles.category` for central (MCC) categories (`general`, `ews`, `obc_ncl`, `sc`, `st`); optional at signup, required only when using the college predictor. Before the predictor, add `state_category` (KEA categories) and a `pwd` flag.
- **Audit log:** `audit_log` exists (date-of-birth corrections). Decide in the review-console slice whether publishing/answer-key edits use it or a separate `content_audit` table (as `DATA_MODEL.md` sketches); one table is simpler.
- **Takedowns (decided 26 Sep):** moving a file to `reference_only` retires its published questions in the same transaction, one `question.retired` audit entry each (in `set_source_file_rights`). Slice 3 must also stop items or questions of `reference_only` files from being published again.
- **SHA-256 is computed in the browser** and trusted for duplicate detection; the slice 2 worker re-checks it against the stored file.
- **Deferred schema:** `questions.embedding` + HNSW index (slice 4), FK `questions.source_file_id → source_files` (slice 1), sub-topics and difficulty (before slice 2, `DATA_MODEL.md` section 10), `answer_checks` and `generation_jobs` (generator), `trap_type`, `neet_weightage` values.
- **iOS flavors** (dev/prod bundle IDs) are not set up; needs a Mac. iOS is Phase 3.
- **Git author** is fixed (`mVruksha`). The first commit on `main` (`bd933fc`) keeps the old placeholder author; that is fine and should not be rewritten.
- **GitHub CLI (`gh`)** is installed and logged in; PRs are opened with `gh pr create`.
- Local Supabase keys printed by `supabase status` are well-known defaults; still keep them out of commits (`config/local.json` and `services/api/.env` are ignored).
