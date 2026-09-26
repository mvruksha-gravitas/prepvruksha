# Status — PrepVruksha

Last updated: exam cycles slice (branch `feat/exam-cycles`)

Read this at the start of every conversation. Update it at the end of every slice.
Decisions and their reasons go in the decisions log in `docs/ARCHITECTURE.md`.

## 0. Launch blockers

**No real user signs up until all of these are done.** Until then only the test phone numbers are used.

- [ ] **Real SMS sending (DLT-registered)** for both sign-in OTP (Supabase Auth) and parent consent codes (`services/api`, replacing `LogOtpSender`). The API refuses to start with `APP_ENV=prod` while the log sender or test parent numbers are configured.
- [ ] **Final legal text from a lawyer:** terms of use, privacy policy and parental consent text. Publish it as a new `policy_versions` row (terms + parental) and replace the placeholder in `PolicyScreen` / the `policyPlaceholderBody` strings. A new terms version makes every student accept again.
- [x] Signup and parental-consent flow (PR #3).

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
- **Tests:** 244 pgTAP (new `04_signup.test.sql`), API 39 pytest, core 26, app 30, console 1, ui_kit 1. Verified end to end against local Supabase + local API over HTTP (sign in → profile → terms → parent code → verify → withdraw; app clients get 403 on the RPC functions and on writing `date_of_birth`). The Flutter web build compiles; **the new screens have not been clicked through in Chrome yet** (see to-do).

### Modular structure — PRs #4 and #5, merged to `main`

Feature-first layout per "Modularity" in `CLAUDE.md`. No behaviour change.

- **API** (`services/api/src/prepvruksha_api/`): `auth/` (JWT verification), `profile/` (`GET /me/signup`, `PUT /me/profile`), `consent/` (terms, parent codes, withdrawal), `shared/` (settings, Supabase RPC, phone numbers, signup state + rule-error mapping). Each feature's `__init__.py` is its public entry. Tests mirror it (`tests/<feature>/`, fakes in `tests/conftest.py`).
- **App** (`apps/app/lib/src/`): `auth/`, `profile/` (profile step, language), `consent/` (signup state, gate, terms, policy, parent consent), `home/`, each with an entry file `<feature>.dart`; `app/` (app, router, config error) and `shared/` (routes, `appConfigProvider`). Tests: `test/<feature>/` and cross-feature `test/flows/`.
- **Boundary checks:** `import-linter` contracts in `services/api/pyproject.toml` (`uv run lint-imports`); `tool/check_import_boundaries.dart` for Dart (`dart run tool/check_import_boundaries.dart`). Both run in CI.
- **CI:** jobs run only when their folders change (`dorny/paths-filter`); **"CI result"** always runs and is the single required check.
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

### Exam cycles — branch `feat/exam-cycles`

The target exam years at signup come from data, not from a hard-coded month.

- **Database** (migration `20260929000100_exam_cycles.sql`, seed `03_exam_cycles.sql`):
  - `exam_cycles` (exam, year, date, `date_confirmed`): everyone reads, content admins write.
  - `public.target_exam_years(exam_code, as_of)` returns the first sitting whose date is today or later (India time) plus the two years after it, or empty when none is recorded.
  - `complete_profile` and a new `profiles` trigger (`private.guard_target_exam_year`) both use the rule, so direct client updates of `target_exam_year` are checked too. Only changes are checked, so a year chosen earlier stays valid after its exam.
  - Seed: NEET-UG 2027 on **2 May 2027** (first Sunday of May, NEET's usual pattern), `date_confirmed = false`.
- **App:** the profile step lists the years from the rule. It shows a retry when they fail to load, and a "signup paused" message when no upcoming date is recorded.
- **Tests:** pgTAP 265 (new `05_exam_cycles.test.sql`; `04_signup` uses its own cycles, independent of the date), app 33.

## 2. Environments

| | Local | `prepvruksha-dev` |
|---|---|---|
| Supabase | `supabase start` (Docker Desktop). Test numbers in `config.toml` | Ref `hzpuxfgfheizghpipmew`, Mumbai. Linked from this repo |
| Migrations | All 10 (via `supabase db reset`) | All 10 applied, up to `20260928000400` (checked 26 Sep with `supabase migration list --linked`) |
| Seed | Applied on reset | Syllabus (100 chapters) and the two `2026-10-draft` policy versions |
| Users / staff | Test numbers only | 1 test user (+91 99999 00001, "Test Student", minor, signup complete), 0 staff roles, 0 questions (26 Sep) |
| Phone auth | Works with test numbers (placeholder Twilio in `config.toml`) | Test numbers +91 99999 00001–00005 / `123456` (valid until 31 Dec 2027); placeholder Twilio values; OTP expiry 300 s. The test numbers are public: **no real student or personal data on dev** |
| `services/api` | `uv run uvicorn prepvruksha_api.main:app --reload` with `services/api/.env` (see `.env.example`: secret key, `OTP_HMAC_KEY`, `PARENT_OTP_TEST_CODES`) | Cloud Run `prepvruksha-api`: `https://prepvruksha-api-765197352192.asia-south1.run.app` (deployed from `main` by Deploy dev) |
| GCP / Firebase | — | Project `prepvruksha-dev`, `asia-south1`. Web app: `https://prepvruksha-dev.web.app`. See `infra/README.md` |

Privileges are identical locally and on dev, so local tests reflect dev.
`supabase test db --linked` does not work (the CLI's temporary role cannot see pgTAP in `extensions`); verify dev with the Data API or `supabase db query --linked`.

Test parent numbers (fixed code `123456`, nothing sent): +91 99999 00006 and 00007, configured in the API's `PARENT_OTP_TEST_CODES` (not in Supabase Auth).

## 3. Open to-do

- [ ] **Click through the signup flow in Chrome** against local Supabase + local API: add `"API_URL": "http://127.0.0.1:8000"` to `config/local.json` (now required, or the app shows the config error screen), start the API, sign in with +91 99999 00001, complete the profile as a minor, parent number +91 99999 00006, code `123456`.
- [ ] **Branch protection:** make "CI result" the only required status check on `main` (after this slice merges).
- [ ] **import-linter for `services/pipeline` and `services/seo`:** add contracts once they have feature folders (CI skips the step until then).
- [ ] Set `API_URL` in your local `config/dev.json` to the Cloud Run URL (Android dev builds).
- [ ] **First super admin** on dev: after the first login, run the SQL in `supabase/README.md`.
- [ ] **Push the exam-cycles migration to dev before merging `feat/exam-cycles`:** `supabase db push --include-seed`, then check `select public.target_exam_years('NEET_UG')` returns `{2027,2028,2029}`. Otherwise the deployed web app can't load the exam years.
- [ ] **Keep the next exam date on record:** when NTA announces NEET-UG 2027, a content admin sets the official `exam_date` and `date_confirmed = true`. Add the 2028 sitting **before 2 May 2027**, or signup pauses (no years offered). A console screen for exam cycles comes with the review console; until then, use SQL.
- [ ] **GitHub Actions on Node 20** (deprecated): bump `actions/checkout`, `google-github-actions/auth` and `setup-gcloud` to their Node 24 versions.
- [ ] **Staff date-of-birth correction** in the console: API endpoint + screen calling `public.correct_date_of_birth` (the function and its audit entry exist; no UI yet). Also offline (paper) parental consent: staff records `method = 'offline_form'` consents collected by pilot colleges.
- [ ] **Account deletion and data erasure requests** (DPDP), a later slice: delete/anonymise user data on request, keep what the law requires (consent records), and decide how long withdrawn accounts are kept.
- [ ] **Content review:**
  - Subject expert: chapter list, removed chapters, Botany/Zoology split (`supabase/seed/01_neet_syllabus.sql`).
  - Kannada translator: syllabus names (`name_kn`) and app strings (`apps/app/lib/l10n/app_kn.arb`, tracked in `apps/app/lib/l10n/README.md`), now including the signup and consent screens.
- [ ] Log in through the running app on the Android emulator. Emulator + local Supabase needs `http://10.0.2.2:54321`.
- [ ] Build the `prod` flavor once, and a release build (needs a signing key; never commit it).
- [ ] Choose the DLT-registered SMS/WhatsApp OTP provider (launch blocker above; long-lead item in `ROADMAP.md`).

## 4. Next slice: import pipeline + review console (Weeks 2–4 in `ROADMAP.md`)

Upload files in the console → extracted, parsed, tagged, de-duplicated → review screen with the source page beside the parsed question → approve publishes. Test on 10 of the messiest files first and measure accuracy. Includes the `content_audit`/`audit_log` entries for publishing and answer-key edits, and the server-side function that shows reviewers the answer key. Propose a plan first, per `CLAUDE.md`.

## 5. Carry-over notes

- **Children's data:** no behavioural tracking or targeted advertising for users under 18 (rule 12 in `CLAUDE.md`). Any analytics added later (Firebase Analytics, Crashlytics custom keys, marketing SDKs) must respect this; check minor status server-side, and default to off when it is unknown.
- **Blocking access:** today only the app router enforces "signup complete". When student data tables arrive (attempts, practice, bookmarks), their RLS policies and API endpoints must also require `private.signup_status(user) = 'complete'`, so a withdrawn consent blocks data access, not just screens.
- **Policy versions:** a new terms version sends every student back to the terms step. Parental consent is not re-asked on a new parental version (any active parental consent counts); decide when the lawyer's text arrives whether a new parental version needs fresh consent.
- **`.env` in images:** the API image never contains a `.env` (`.dockerignore`); settings come only from the Cloud Run environment and Secret Manager.
- **Deployer permissions:** `github-deployer` cannot change IAM. New public Cloud Run services, or new secrets, are added with the setup script (run by a person), not from GitHub Actions.
- **Parent consent evidence:** `consents` row (parent name, phone, method, policy version, scope, timestamp, `request_id`) + the `parental_consent_requests` row (sent time, attempts, verified time). Raw codes are never stored or logged outside the dev `LogOtpSender`.
- **Withdrawing parental consent** is possible from the student's own account for now. Parent accounts (`parent_links`) come later; the parent should be able to withdraw from their side too.
- **Migration timestamps:** the latest migration is `20260929000100`. New migrations must use later timestamps (the machine clock has been behind the migration dates; check what `supabase migration new` produces). Never edit a pushed migration; add a new one.
- **Grants:** every new table or view needs explicit grants and an entry in `supabase/tests/database/03_privileges.test.sql`, or the tests fail. New `public` functions need explicit `revoke ... from public, anon, authenticated` (functions default to `EXECUTE` for `PUBLIC` unless revoked). Never grant `TRUNCATE`, `REFERENCES`, `TRIGGER` or `MAINTAIN` to API roles.
- **Answer keys:** `question_options.is_correct` is unreadable by `anon`/`authenticated`, including staff. Client writes to options must not request the row back (PostgREST `Prefer: return=minimal`). The review console needs a server-side function (API or `security definer` with a staff check) to show the answer key. Practice feedback also needs a server-side check.
- **`exam_reserved` questions** are never public; the SEO build must read only `public.seo_questions` (service role).
- **Categories:** keep `profiles.category` for central (MCC) categories (`general`, `ews`, `obc_ncl`, `sc`, `st`); optional at signup, required only when using the college predictor. Before the predictor, add `state_category` (KEA categories) and a `pwd` flag.
- **Audit log:** `audit_log` exists (date-of-birth corrections). Decide in the review-console slice whether publishing/answer-key edits use it or a separate `content_audit` table (as `DATA_MODEL.md` sketches); one table is simpler.
- **Deferred schema:** `questions.embedding` + HNSW index (once the embedding model is chosen), FK `questions.source_file_id → source_files`, `trap_type`, topics seed, `neet_weightage` values.
- **iOS flavors** (dev/prod bundle IDs) are not set up; needs a Mac. iOS is Phase 3.
- **Git author** is fixed (`mVruksha`). The first commit on `main` (`bd933fc`) keeps the old placeholder author; that is fine and should not be rewritten.
- **GitHub CLI (`gh`)** is installed and logged in; PRs are opened with `gh pr create`.
- Local Supabase keys printed by `supabase status` are well-known defaults; still keep them out of commits (`config/local.json` and `services/api/.env` are ignored).
