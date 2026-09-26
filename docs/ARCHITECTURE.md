# Architecture — PrepVruksha

Version 0.1 · 25 September 2026

## 1. Overview

```
                    ┌──────────────────────────────────────────┐
  Students,         │  Flutter apps                             │
  teachers,   ───►  │  apps/app (Android, iOS, web)             │
  parents           │  apps/console (web, content team)         │
                    │  exam-lab Windows app (later)             │
                    └───────┬───────────────────────┬──────────┘
                            │ Supabase SDK (RLS)    │ HTTPS (JWT)
                            ▼                       ▼
        ┌─────────────────────────────┐   ┌──────────────────────────┐
        │ Supabase (Mumbai)           │◄──│ services/api (FastAPI)   │
        │ Postgres + pgvector         │   │ Cloud Run, asia-south1   │
        │ Auth · Storage · Realtime   │   │ scoring, analytics,      │
        └──────┬──────────────────────┘   │ tests, AI tutor, ERP API │
               │ jobs table                └──────────────────────────┘
               ▼
        ┌─────────────────────────────┐   ┌──────────────────────────┐
        │ services/pipeline (worker)  │──►│ Mathpix · Claude API      │
        │ Cloud Run Jobs              │   │ (question content only)  │
        └─────────────────────────────┘   └──────────────────────────┘
               │
        ┌─────────────────────────────┐   ┌──────────────────────────┐
        │ services/seo (nightly)      │──►│ Firebase Hosting         │
        │ static pages + sitemaps     │   │ public question pages    │
        └─────────────────────────────┘   └──────────────────────────┘

  Push: Firebase Cloud Messaging · DNS: AWS Route 53 · CI/CD: GitHub Actions
```

## 2. Components

### 2.1 Flutter apps

- **`apps/app`** — one app with role-based navigation (student, teacher, institute admin, parent). Builds for Android, iOS and web.
- **`apps/console`** — Flutter web for the content team: imports, review queue, publishing, test authoring, analytics admin.
- **Exam-lab app (P2)** — Windows build of the exam module, full-screen locked, with a local store that syncs later.
- Shared code in `packages/core` (models, API client, exam state machine) and `packages/ui_kit` (theme, widgets).
- Talks to Supabase directly for simple reads and writes protected by RLS (profile, bookmarks, published questions), and to `services/api` for anything that computes official results.

### 2.2 Supabase

- **Postgres** is the single source of truth. Schema managed by migrations in `supabase/migrations/`.
- **Auth:** phone OTP (DLT-registered Indian SMS or WhatsApp provider) and Google sign-in. Roles are stored in our own tables, not only in JWT claims.
- **Storage buckets:** `imports` (private, uploaded source files), `question-assets` (public-read images for published questions), `exports` (private reports).
- **Realtime:** live-mock status and leaderboards only.
- **pgvector:** embeddings for duplicate detection, similar questions and meaning-based search.

### 2.3 services/api (FastAPI on Cloud Run)

Responsibilities:
- Signup: profile completion, terms and parental consent (parent OTP), consent withdrawal (`/me/*`). The rules are Postgres functions called with the secret key.
- Starting an attempt: returns the paper (question IDs, content, pattern config) once, with a signed session token.
- Accepting batched answer syncs and the final submission; scoring against the stored answer key.
- Analytics: result summaries, percentile, chapter heatmap, negative-marking and time analysis.
- Live mocks: scheduling, shift assignment, normalisation.
- AI tutor endpoint (grounded; question content only).
- Institution endpoints and the Vidhyavruksha ERP integration API.

Authentication: verifies the Supabase JWT on each request (asymmetric signing keys from the project's JWKS endpoint, cached). Uses a service role connection for writes that must bypass RLS (e.g. scoring), with checks in code.

### 2.4 services/pipeline (import worker)

Runs as Cloud Run Jobs, triggered by rows in the `import_jobs` table (Postgres `SELECT … FOR UPDATE SKIP LOCKED` queue — no separate queue service).

Steps per file:
1. **Extract** — Word: Pandoc → HTML with LaTeX math + images. Text PDF: PyMuPDF text + images per page. Scanned PDF: Mathpix PDF API.
2. **Parse** — Claude API with a JSON schema: question, options, correct option (only if printed in the source), explanation, format, suggested tags, confidence, source page. Answer keys printed separately are matched in a second pass over the whole document.
3. **Validate** — four options, one answer, no broken LaTeX, images resolved.
4. **Deduplicate** — embedding similarity against existing questions; above threshold → flagged as possible duplicate.
5. **Store** — rows in `import_items` with status `needs_review`, linked to the source file and page.

The AI never fills in a missing answer. If the source has no answer, the item is marked `answer_missing` for a human.

Bulk AI work uses batch processing to lower cost.

### 2.5 services/seo (static site generator)

- Python + Jinja2. Reads `published` questions, renders one HTML page per question, hub pages (subject → chapter → topic, previous-year papers), `sitemap-*.xml` files and a sitemap index.
- Deploys to Firebase Hosting with the Firebase CLI from GitHub Actions (nightly, and on demand after review batches).
- Each page: question text in `<title>` and `<h1>`, options, answer and explanation as text, plain-text formula fallback, image alt text, canonical URL, schema.org Quiz/Question JSON-LD, link into the app to practise the topic.
- URL pattern: `/neet/{subject}/{chapter}/{slug}-{short_id}`. Slugs never change once published.

## 3. Key flows

### 3.1 Taking a mock exam

1. Student opens a test → app calls `POST /attempts` → API creates an attempt and returns the full paper + pattern config.
2. The app runs the exam entirely on the device: timer, palette, navigation. Every action is recorded in a local event log.
3. Every 30–60 s and on submit, the app sends the batch of answers and events to `POST /attempts/{id}/sync`. Syncs are idempotent (sequence numbers).
4. If the connection drops, the exam continues locally; on reconnect, pending batches are sent. Timer authority is the server start time plus pattern duration.
5. On submit or time-out, `POST /attempts/{id}/submit` → API scores from the answer key and stores results. Heavy analytics (percentile across all attempts) run as a follow-up job.

### 3.2 Live mock day

- Papers and shifts prepared in advance.
- One hour before: scale Supabase compute up and set Cloud Run minimum instances. Scale back down afterwards.
- Paper content served once per student at start; no per-question requests.
- Leaderboard updates published via Realtime after submissions are scored, not continuously.

### 3.3 Content publishing

`import_items (needs_review)` → reviewer approves or edits in the console → a `questions` row is created with `status = 'published'` and a `content_audit` entry → nightly SEO build picks it up.

### 3.4 Vidhyavruksha ERP integration (P1)

- ERP calls `services/api` with an institution API key to sync students, batches and parent contacts.
- Single sign-on: short-lived signed link from ERP → our app, exchanged for a session.
- Results pushed back to the ERP by webhook or pulled by the ERP.
- Separate databases; no shared tables.

## 4. Environments

| Environment | Supabase project | GCP project | Hosting |
|---|---|---|---|
| dev | `prepvruksha-dev` (Mumbai) | `prepvruksha-dev` | preview channels |
| prod | `prepvruksha-prod` (Mumbai) | `prepvruksha-prod` | live site |

Local development uses the Supabase CLI (local Postgres in Docker) and runs services with Docker Compose.

## 5. Security and privacy

- RLS on every table with user or institution data; policy tests in CI.
- Service role key used only inside `services/*`, never in apps.
- Secrets: GCP Secret Manager for services; `.env` (git-ignored) locally.
- AI calls send question content and anonymous answer data only.
- Under-18 signup requires recorded parental consent (`consents` table), given by the parent telling the student a code sent to the parent's phone. Signup status is derived at the time of checking, so the requirement ends on the 18th birthday.
- No behavioural tracking or targeted advertising for users under 18.
- Date of birth is set once; corrections are staff-only and written to `audit_log`.
- Audit log for publishing, editing answer keys and role changes.

## 6. Portability notes

- Postgres is standard; migrations run on any Postgres 15+ with pgvector.
- Services are plain Docker images; can move from Cloud Run to AWS ECS or a VM.
- Static site is plain files; any host works.
- Supabase Auth users are in Postgres (`auth.users`) and can be exported.
- Deliberately not used: Firebase Extensions, Firebase Dynamic Links, Firestore, Supabase Edge Functions for core logic.

## 7. Decisions log

| Date | Decision | Reason |
|---|---|---|
| 2026-09-25 | Supabase as core platform | Postgres-first needs (analytics, pgvector), low ops for a solo developer, open source for a clean exit |
| 2026-09-25 | Cloud Run for services | Simplest container hosting, scales to zero, Mumbai region |
| 2026-09-25 | Static HTML for SEO pages | Flutter web is not reliably indexable; static pages are fast and portable |
| 2026-09-25 | Separate product from Vidhyavruksha ERP | Different customers, student-owned accounts, isolate exam-day load |
| 2026-09-25 | Postgres jobs table instead of a queue service | Fewer moving parts at current scale |
| 2026-09-26 | `question_options.is_correct` not readable by app clients | Students could otherwise look up answers during a mock; correctness comes only from server-side code |
| 2026-09-26 | `questions.exam_reserved` pool for live mocks; SEO reads only `seo_questions` | Published questions appear on public pages, so live-mock papers need questions that are never public |
| 2026-09-26 | Store `date_of_birth`; derive minor status with `private.is_minor()` | A stored flag goes stale when a student turns 18 |
| 2026-09-26 | RLS helpers in a `private` schema | Not exposed through the Data API as RPC endpoints |
| 2026-09-26 | Allowed values as `text` + `CHECK`, not Postgres enums | Easier to extend in later migrations |
| 2026-09-26 | Dart pub workspaces instead of Melos | Built into Dart; one fewer tool |
| 2026-09-26 | App config via `--dart-define-from-file` (`config/*.json`, git-ignored); Android `dev`/`prod` flavors (`com.mvruksha.prepvruksha[.dev]`) | No keys in the repo; dev and prod builds install side by side. App ID is permanent once on the Play Store |
| 2026-09-26 | Apps use Supabase's publishable key (`SUPABASE_PUBLISHABLE_KEY`), never the legacy anon JWT or the secret key | The anon key name is deprecated in `supabase_flutter`; the secret key belongs only in `services/*` |
| 2026-09-26 | Python services are separate uv projects pinned to Python 3.12 | One lockfile and Docker image per service; matches the 3.12 target even where newer Python is installed |
| 2026-09-26 | Android debug builds allow cleartext HTTP (debug manifest only) | Needed to reach local Supabase from the emulator (`http://10.0.2.2:54321`); release builds stay HTTPS-only |
| 2026-09-26 | Wrong and expired OTP codes show one message | Supabase returns `otp_expired` for both |
| 2026-09-26 | App and syllabus Kannada text is AI-drafted and marked unreviewed until the translator approves it | Follows the rule that nothing AI-drafted is final without human review |
| 2026-09-27 | `profiles.category` holds central (MCC) categories only; `state_category` (KEA) and a `pwd` flag are added before the college predictor | MCC and KEA use different category lists |
| 2026-09-27 | Explicit grants per table; default privileges grant API roles nothing (all environments) | `prepvruksha-dev` has "Automatically expose new tables" off, local grants everything: relying on defaults broke dev and granted `TRUNCATE` (bypasses RLS) to app roles |
| 2026-09-26 | Signup rules as Postgres functions (`public.*`, service role only), called by `services/api` through the Data API (PostgREST RPC); no direct database connection from the API | Atomic checks (limits, attempts, set-once DOB) in one transaction; no database password in Cloud Run; clients cannot call them |
| 2026-09-26 | Signup status derived by `private.signup_status(user, as_of)`, never stored | Turning 18, new terms versions and withdrawals take effect without jobs or stale flags |
| 2026-09-26 | Parental consent by parent OTP: the API generates the code and stores only an HMAC-SHA256 (keyed, bound to the user) in `parental_consent_requests`; limits 60 s / 5 per user per day / 5 per parent number per day / 10 min expiry / 5 attempts | Evidence of the parent's involvement without storing codes; limits cap SMS cost and brute force. `offline_form` stays for paper forms recorded by staff |
| 2026-09-26 | Parent codes sent through an `OtpSender` interface; `LogOtpSender` (dev) and fixed-code test parent numbers; `APP_ENV=prod` refuses to start with either | The DLT-registered provider isn't chosen yet; development must not block on it, and prod must not ship without it |
| 2026-09-26 | Date of birth set once (trigger), ages 13–30 at signup; staff correction via `public.correct_date_of_birth` with an `audit_log` entry | Otherwise a minor could change their age to skip parental consent |
| 2026-09-26 | `audit_log`: one append-only table for sensitive changes (service role inserts, super admins read) | One place for DOB corrections now and publishing/role changes later |
| 2026-09-26 | Every signup call returns the full signup state; the app router maps the status to a screen | One source of truth for routing; screens never compute eligibility |
| 2026-09-26 | Date of birth typed as DD/MM/YYYY instead of the Material date picker | The picker's text entry follows US MM/DD order for English; scrolling back 16+ years is slow on phones |
| 2026-09-26 | No behavioural tracking or targeted advertising for users under 18 (`CLAUDE.md` rule 12) | DPDP Act obligations for children's data |
| 2026-09-26 | Local Supabase enables Twilio with placeholder values | Supabase Auth refuses phone sign-in without a provider, even for test numbers; replaced by the DLT-registered provider |
