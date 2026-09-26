# Status — PrepVruksha

Last updated: end of the signup and parental-consent slice (branch `feat/profile-consent`, not merged yet)

Read this at the start of every conversation. Update it at the end of every slice.
Decisions and their reasons go in the decisions log in `docs/ARCHITECTURE.md`.

## 0. Launch blockers

**No real user signs up until all of these are done.** Until then only the test phone numbers are used.

- [ ] **Real SMS sending (DLT-registered)** for both sign-in OTP (Supabase Auth) and parent consent codes (`services/api`, replacing `LogOtpSender`). The API refuses to start with `APP_ENV=prod` while the log sender or test parent numbers are configured.
- [ ] **Final legal text from a lawyer:** terms of use, privacy policy and parental consent text. Publish it as a new `policy_versions` row (terms + parental) and replace the placeholder in `PolicyScreen` / the `policyPlaceholderBody` strings. A new terms version makes every student accept again.
- [x] Signup and parental-consent flow (this slice).

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

### Signup and parental consent (DPDP) — branch `feat/profile-consent`

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

## 2. Environments

| | Local | `prepvruksha-dev` |
|---|---|---|
| Supabase | `supabase start` (Docker Desktop). Test numbers in `config.toml` | Ref `hzpuxfgfheizghpipmew`, Mumbai. Linked from this repo |
| Migrations | All 10 (via `supabase db reset`) | 6 applied, up to `20260927000100`. **This slice's 4 migrations + seed `02_policy_versions.sql` not pushed yet** |
| Seed | Applied on reset | Syllabus applied (100 chapters); policy versions not yet |
| Users / staff | Test numbers only | 0 users, 0 staff roles, 0 questions (as of 27 Sep) |
| Phone auth | Works with test numbers (placeholder Twilio in `config.toml`) | **Test numbers not configured yet** (see to-do) |
| `services/api` | `uv run uvicorn prepvruksha_api.main:app --reload` with `services/api/.env` (see `.env.example`: secret key, `OTP_HMAC_KEY`, `PARENT_OTP_TEST_CODES`) | Not deployed |
| GCP / Firebase | — | Project `prepvruksha-dev`, `asia-south1`. Nothing deployed yet |

Privileges are identical locally and on dev, so local tests reflect dev.
`supabase test db --linked` does not work (the CLI's temporary role cannot see pgTAP in `extensions`); verify dev with the Data API or `supabase db query --linked`.

Test parent numbers (fixed code `123456`, nothing sent): +91 99999 00006 and 00007, configured in the API's `PARENT_OTP_TEST_CODES` (not in Supabase Auth).

## 3. Open to-do

- [ ] **Click through the signup flow in Chrome** against local Supabase + local API: add `"API_URL": "http://127.0.0.1:8000"` to `config/local.json` (now required, or the app shows the config error screen), start the API, sign in with +91 99999 00001, complete the profile as a minor, parent number +91 99999 00006, code `123456`.
- [ ] **Push this slice to `prepvruksha-dev`** after merge: `supabase db push --include-seed`, then check `policy_versions` has the two draft rows.
- [ ] **Deploy `services/api` to Cloud Run (dev)** with secrets in Secret Manager (`SUPABASE_SECRET_KEY`, `OTP_HMAC_KEY`); set `API_URL` in `config/dev.json`. Until then the dev app can't get past signup (use `http://10.0.2.2:8000` for a local API from the emulator).
- [ ] **Test phone numbers on `prepvruksha-dev`:** add +91 99999 00001–00005, code `123456`, under Auth > Providers > Phone, with a placeholder SMS provider (see `supabase/README.md`). Then log in from the app with `config/dev.json`.
- [ ] **First super admin** on dev: after the first login, run the SQL in `supabase/README.md`.
- [ ] **Staff date-of-birth correction** in the console: API endpoint + screen calling `public.correct_date_of_birth` (the function and its audit entry exist; no UI yet). Also offline (paper) parental consent: staff records `method = 'offline_form'` consents collected by pilot colleges.
- [ ] **Account deletion and data erasure requests** (DPDP), a later slice: delete/anonymise user data on request, keep what the law requires (consent records), and decide how long withdrawn accounts are kept.
- [ ] **Content review:**
  - Subject expert: chapter list, removed chapters, Botany/Zoology split (`supabase/seed/01_neet_syllabus.sql`).
  - Kannada translator: syllabus names (`name_kn`) and app strings (`apps/app/lib/l10n/app_kn.arb`, tracked in `apps/app/lib/l10n/README.md`), now including the signup and consent screens.
- [ ] **Deploy dev web app to Firebase Hosting automatically on merge to `main`** (GitHub Actions; needs a Firebase service account in GitHub secrets and a hosting target/preview channel).
- [ ] **Move the language button:** in debug builds the debug banner partly hides it (top-right app bar action).
- [ ] Log in through the running app on the Android emulator. Emulator + local Supabase needs `http://10.0.2.2:54321`.
- [ ] Build the `prod` flavor once, and a release build (needs a signing key; never commit it).
- [ ] Choose the DLT-registered SMS/WhatsApp OTP provider (launch blocker above; long-lead item in `ROADMAP.md`).

## 4. Next slice: import pipeline + review console (Weeks 2–4 in `ROADMAP.md`)

Upload files in the console → extracted, parsed, tagged, de-duplicated → review screen with the source page beside the parsed question → approve publishes. Test on 10 of the messiest files first and measure accuracy. Includes the `content_audit`/`audit_log` entries for publishing and answer-key edits, and the server-side function that shows reviewers the answer key. Propose a plan first, per `CLAUDE.md`.

## 5. Carry-over notes

- **Children's data:** no behavioural tracking or targeted advertising for users under 18 (rule 12 in `CLAUDE.md`). Any analytics added later (Firebase Analytics, Crashlytics custom keys, marketing SDKs) must respect this; check minor status server-side, and default to off when it is unknown.
- **Blocking access:** today only the app router enforces "signup complete". When student data tables arrive (attempts, practice, bookmarks), their RLS policies and API endpoints must also require `private.signup_status(user) = 'complete'`, so a withdrawn consent blocks data access, not just screens.
- **Policy versions:** a new terms version sends every student back to the terms step. Parental consent is not re-asked on a new parental version (any active parental consent counts); decide when the lawyer's text arrives whether a new parental version needs fresh consent.
- **Parent consent evidence:** `consents` row (parent name, phone, method, policy version, scope, timestamp, `request_id`) + the `parental_consent_requests` row (sent time, attempts, verified time). Raw codes are never stored or logged outside the dev `LogOtpSender`.
- **Withdrawing parental consent** is possible from the student's own account for now. Parent accounts (`parent_links`) come later; the parent should be able to withdraw from their side too.
- **Migration timestamps:** the latest migration is `20260928000400`. New migrations must use later timestamps (the machine clock has been behind the migration dates; check what `supabase migration new` produces). Never edit a pushed migration; add a new one.
- **Grants:** every new table or view needs explicit grants and an entry in `supabase/tests/database/03_privileges.test.sql`, or the tests fail. New `public` functions need explicit `revoke ... from public, anon, authenticated` (functions default to `EXECUTE` for `PUBLIC` unless revoked). Never grant `TRUNCATE`, `REFERENCES`, `TRIGGER` or `MAINTAIN` to API roles.
- **Answer keys:** `question_options.is_correct` is unreadable by `anon`/`authenticated`, including staff. Client writes to options must not request the row back (PostgREST `Prefer: return=minimal`). The review console needs a server-side function (API or `security definer` with a staff check) to show the answer key. Practice feedback also needs a server-side check.
- **`exam_reserved` questions** are never public; the SEO build must read only `public.seo_questions` (service role).
- **Categories:** keep `profiles.category` for central (MCC) categories (`general`, `ews`, `obc_ncl`, `sc`, `st`); optional at signup, required only when using the college predictor. Before the predictor, add `state_category` (KEA categories) and a `pwd` flag.
- **Audit log:** `audit_log` exists (date-of-birth corrections). Decide in the review-console slice whether publishing/answer-key edits use it or a separate `content_audit` table (as `DATA_MODEL.md` sketches); one table is simpler.
- **Deferred schema:** `questions.embedding` + HNSW index (once the embedding model is chosen), FK `questions.source_file_id → source_files`, `trap_type`, topics seed, `neet_weightage` values.
- **iOS flavors** (dev/prod bundle IDs) are not set up; needs a Mac. iOS is Phase 3.
- **Git author** is fixed (`mVruksha`). The first commit on `main` (`bd933fc`) keeps the old placeholder author; that is fine and should not be rewritten.
- **GitHub CLI (`gh`) is not installed** on the dev machine; PRs are opened in the browser unless it is installed.
- Local Supabase keys printed by `supabase status` are well-known defaults; still keep them out of commits (`config/local.json` and `services/api/.env` are ignored).
