# Status — PrepVruksha

Last updated: 27 September 2026 (end of Week 1, Foundations slice)

Read this at the start of every conversation. Update it at the end of every slice.
Decisions and their reasons go in the decisions log in `docs/ARCHITECTURE.md`.

## 1. Done

### Week 1 — Foundations (PR #1, merged to `main`)

- **Repo:** monorepo per `CLAUDE.md`; `.gitattributes` (LF, CRLF for Windows scripts); `.gitignore` covers `config/*.json`, `.env` files and signing keys.
- **Flutter:** Dart pub workspace (`apps/app`, `apps/console`, `packages/core`, `packages/ui_kit`).
  - `apps/app`: phone OTP login (phone screen → OTP screen → placeholder home with sign-out), go_router guard on auth state, Riverpod, English + Kannada ARB strings, language button.
  - Android flavors `dev` (`com.mvruksha.prepvruksha.dev`, "PrepVruksha Dev") and `prod` (`com.mvruksha.prepvruksha`). Dev debug APK builds.
  - `apps/console`: placeholder screen only.
- **Config:** `--dart-define-from-file=config/<env>.json` (git-ignored); templates `config/local.example.json`, `config/dev.example.json`. Only the publishable key goes in app config.
- **Supabase:** migrations
  - `20260926000100` extensions + helpers (`private` schema, `set_updated_at`, `generate_short_id`)
  - `20260926000200` `staff_roles` + `private.is_staff()`
  - `20260926000300` `profiles` (with `date_of_birth`; `private.is_minor()`), `consents`
  - `20260926000400` `exams`, `subjects`, `chapters`, `topics` (with `name_kn_reviewed`)
  - `20260926000500` `questions` (with `exam_reserved`), `question_options`, `question_topics`, `seo_questions` view
  - `20260927000100` explicit Data API grants for every table/view; default privileges grant API roles nothing
- **Seed:** NEET-UG, Physics/Chemistry/Botany/Zoology, 100 chapters (81 current, 19 removed from the syllabus but kept for PYQ tagging). Kannada names AI-drafted, `name_kn_reviewed = false`. No topics yet.
- **Tests:** 144 pgTAP tests (RLS per role, schema rules, seed, privilege matrix); Flutter (core 18, app 8, console 1, ui_kit 1); Python services (ruff, mypy, pytest).
- **Services:** `services/api` (FastAPI `/health`), `services/pipeline`, `services/seo` scaffolds on Python 3.12 via uv. No business logic yet.
- **CI:** `.github/workflows/ci.yml` — Flutter (l10n up to date, format, analyze, tests), Python matrix, database (migrations, lint, pgTAP).

## 2. Environments

| | Local | `prepvruksha-dev` |
|---|---|---|
| Supabase | `supabase start` (Docker Desktop). Test numbers in `config.toml` | Ref `hzpuxfgfheizghpipmew`, Mumbai. Linked from this repo |
| Migrations | All 6 (via `supabase db reset`) | All 6 applied, up to `20260927000100` |
| Seed | Applied on reset | Applied (100 chapters) |
| Users / staff | Test numbers only | 0 users, 0 staff roles, 0 questions (as of 27 Sep) |
| Phone auth | Works with test numbers (placeholder Twilio in `config.toml`) | **Test numbers not configured yet** (see to-do) |
| GCP / Firebase | — | Project `prepvruksha-dev`, `asia-south1`. Nothing deployed yet |

Privileges are identical locally and on dev (migration `20260927000100`), so local tests reflect dev.
`supabase test db --linked` does not work (the CLI's temporary role cannot see pgTAP in `extensions`); verify dev with the Data API or `supabase db query --linked`.

## 3. Open to-do

- [ ] **Test phone numbers on `prepvruksha-dev`:** add +91 99999 00001–00005, code `123456`, under Auth > Providers > Phone, with a placeholder SMS provider (see `supabase/README.md`). Then log in from the app with `config/dev.json`.
- [ ] **First super admin** on dev: after the first login, run the SQL in `supabase/README.md`.
- [ ] **Content review:**
  - Subject expert: chapter list, removed chapters, Botany/Zoology split (`supabase/seed/01_neet_syllabus.sql`).
  - Kannada translator: syllabus names (`name_kn`) and app strings (`apps/app/lib/l10n/app_kn.arb`, tracked in `apps/app/lib/l10n/README.md`).
- [ ] **Deploy dev web app to Firebase Hosting automatically on merge to `main`** (GitHub Actions; needs a Firebase service account in GitHub secrets and a hosting target/preview channel).
- [ ] **Move the language button:** in debug builds the debug banner partly hides it (top-right app bar action).
- [x] Log in through the running app on web (Chrome, local Supabase) — verified.
- [ ] Log in through the running app on the Android emulator. Emulator + local Supabase needs `http://10.0.2.2:54321`.
- [ ] Build the `prod` flavor once, and a release build (needs a signing key; never commit it).
- [ ] Choose the DLT-registered SMS/WhatsApp OTP provider (long-lead item in `ROADMAP.md`).

## 4. Next slice: profile completion, signup and parental consent (DPDP)

Scope to plan (propose a plan first, per `CLAUDE.md`):
- Profile completion after first login: name, date of birth, target exam year, language, category.
- If under 18 (`private.is_minor()`; null = ask for date of birth): parental consent with the parent's name and phone (`consents`, `type = 'parental'`, `method` e.g. `parent_otp`). Consent and `date_of_birth` are written by the API (service role), not the client.
- Terms consent with `policy_version`; consent withdrawal (`withdrawn_at`).
- Route guard: incomplete profile or missing consent → completion flow.
- Persist the language choice to `profiles.preferred_language`.
- **No real user signs up until this slice is complete** (`ROADMAP.md`).

## 5. Carry-over notes

- **Migration timestamps:** `20260927000100_explicit_api_grants.sql` is dated 2026-09-27. New migrations must use later timestamps (`supabase migration new <name>` does this if the clock is right; check). Never edit a pushed migration; add a new one.
- **Grants:** every new table or view needs explicit grants and an entry in `supabase/tests/database/03_privileges.test.sql`, or the tests fail. Never grant `TRUNCATE`, `REFERENCES`, `TRIGGER` or `MAINTAIN` to API roles.
- **Answer keys:** `question_options.is_correct` is unreadable by `anon`/`authenticated`, including staff. Client writes to options must not request the row back (PostgREST `Prefer: return=minimal`). The review console needs a server-side function (API or `security definer` with a staff check) to show the answer key. Practice feedback also needs a server-side check.
- **`exam_reserved` questions** are never public; the SEO build must read only `public.seo_questions` (service role).
- **Categories:** keep `profiles.category` for central (MCC) categories (`general`, `ews`, `obc_ncl`, `sc`, `st`). Before the college predictor, add `state_category` (KEA categories) and a `pwd` flag.
- **Consent `method` values** are `parent_otp`, `in_app`, `offline_form` — confirm or change in the consent slice.
- **Audit log** (`content_audit`) for publishing, answer-key edits and staff role changes is not built yet; add it with the review console (Week 2).
- **Deferred schema:** `questions.embedding` + HNSW index (once the embedding model is chosen), FK `questions.source_file_id → source_files`, `trap_type`, topics seed, `neet_weightage` values.
- **Language choice** is in memory only (Riverpod); persisted in the next slice.
- **iOS flavors** (dev/prod bundle IDs) are not set up; needs a Mac. iOS is Phase 3.
- **Git author** is fixed (`mVruksha`). The first commit on `main` (`bd933fc`) keeps the old placeholder author; that is fine and should not be rewritten.
- **GitHub CLI (`gh`) is not installed** on the dev machine; PRs are opened in the browser unless it is installed.
- Local Supabase keys printed by `supabase status` are well-known defaults; still keep them out of commits (`config/local.json` is ignored).
