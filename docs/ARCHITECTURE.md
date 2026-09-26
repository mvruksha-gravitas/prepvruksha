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
- Starting an attempt: returns the paper (question IDs, content, pattern config) once, with a signed session token.
- Accepting batched answer syncs and the final submission; scoring against the stored answer key.
- Analytics: result summaries, percentile, chapter heatmap, negative-marking and time analysis.
- Live mocks: scheduling, shift assignment, normalisation.
- AI tutor endpoint (grounded; question content only).
- Institution endpoints and the Vidhyavruksha ERP integration API.

Authentication: verifies the Supabase JWT on each request. Uses a service role connection for writes that must bypass RLS (e.g. scoring), with checks in code.

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
- Under-18 signup requires recorded parental consent (`consents` table).
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
| 2026-09-26 | App config via `--dart-define-from-file` (`config/*.json`, git-ignored); Android `dev`/`prod` flavors (`com.mvruksha.prepvruksha[.dev]`) | No keys in the repo; dev and prod builds install side by side |
| 2026-09-26 | Local Supabase enables Twilio with placeholder values | Supabase Auth refuses phone sign-in without a provider, even for test numbers; replaced by the DLT-registered provider |
