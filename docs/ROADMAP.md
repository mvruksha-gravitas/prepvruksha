# Roadmap — PrepVruksha

Version 0.1 · 25 September 2026

Target: CBT mock engine and weekly live mocks running by **January 2027**, ahead of the first
CBT-mode NEET (expected around May 2027). Dates below assume one developer plus
part-time content reviewers.

## 1. Start in this order

1. **Documents** (this folder) — agree the scope. ✔
2. **Long-lead items** (start this week; they take time outside your control):
   - Product name and domain: PrepVruksha, prepvruksha.com ✔ (also register the .in and the "vriksha" spelling)
   - Choose a DLT-registered SMS/WhatsApp OTP provider and start DLT sender and template registration.
   - Contract 1–2 subject-expert reviewers (Physics, Chemistry, Biology) and a Kannada translator.
   - Confirm content rights for the existing question files.
   - Google Play developer account (Apple developer account can wait until after launch).
3. **Minimum infrastructure** (one day — see section 2). Only dev at first; prod when the first slice works.
4. **Build in vertical slices** with Claude Code (section 3).

Don't set up every service in advance. Add each one when the slice that needs it starts.

## 2. Infrastructure setup checklist

### Day 1 — dev environment

- [ ] GitHub repository `prepvruksha` (private); add this folder; branch protection on `main`.
- [ ] Supabase organisation; project `prepvruksha-dev` in the **Mumbai** region; enable the `vector` extension.
- [ ] Supabase CLI locally (WSL2 + Docker) — `supabase init`, `supabase start` for a local database.
- [ ] Google Cloud project `prepvruksha-dev` (this is also the Firebase project): enable Cloud Run, Artifact Registry, Secret Manager, Cloud Scheduler; default region `asia-south1`.
- [ ] Firebase: add the project, enable Hosting and Cloud Messaging only.
- [ ] **Budget alerts** on GCP and a spend cap on Supabase.
- [ ] API accounts: Anthropic (Claude API), Mathpix. Keys into Secret Manager and a local `.env`.
- [ ] Flutter: create `apps/app`, `apps/console`, `packages/core`, `packages/ui_kit` (melos or pub workspaces).

### Before public launch — production

- [ ] Supabase `prepvruksha-prod` (Mumbai, Pro plan) and GCP `prepvruksha-prod`.
- [ ] Domain DNS in Route 53: site → Firebase Hosting; `api.` → Cloud Run custom domain.
- [ ] Google Search Console and Bing Webmaster Tools; submit the sitemap index.
- [ ] Backups: Supabase point-in-time recovery (or daily dumps to Cloud Storage).
- [ ] Monitoring: Crashlytics for apps, Cloud Logging alerts for API errors, uptime check on the API.
- [ ] Privacy policy and terms (DPDP-compliant consent flow).

## 3. Phase 1 — Launch (October 2026 → January 2027)

| Weeks | Slice | Done when |
|---|---|---|
| 1 | **Foundations** | Repo, CI (lint + tests), local Supabase, first migrations (profiles, syllabus, questions, options), seed subjects/chapters/topics, phone OTP login working in the app |
| 2–4 | **Import pipeline + review console** | Upload files in the console → extracted, parsed, tagged, de-duplicated → review screen with source page beside parsed question → approve publishes. Test on 10 of the messiest files first and measure accuracy |
| 3–12 (ongoing) | **Content** | Reviewers publishing continuously; target a few thousand reviewed questions by launch, covering every chapter |
| 5–8 | **CBT exam engine** | NTA-style interface, exam-day sequence, pattern from `exam_patterns`, local saving + batched sync, resume after disconnect, server-side scoring. Load-tested at 5,000 simulated students |
| 8–9 | **Results v1 + error notebook** | Score, subject breakdown, platform rank/percentile, time analysis, chapter heatmap; wrong answers collected with mistake reasons |
| 9–10 | **Practice + search** | Chapter tests, PYQ papers, custom tests; keyword search over published questions |
| 10–11 | **Public SEO pages** | Static question pages, hub pages, sitemaps deployed nightly; Search Console live |
| 11–12 | **Live mocks + pilot** | Scheduled all-India mock with scale-up routine; 2–3 pilot PU colleges onboarded manually; bug-fix buffer |
| Jan 2027 | **Launch** | Weekly live mocks begin; Android app on Play Store; web app live |

Publish the first reviewed question pages as early as week 6 — search ranking takes months.

## 4. Phase 2 — Retention (February → May 2027)

- Confidence marking, personal guessing rule, answer-change analysis, test replay
- Multiple shifts with normalised percentile
- Spaced repetition, diagnostic test, priority engine, daily adaptive practice, study planner
- Grounded AI tutor on explanations; meaning-based search and similar questions
- Kannada question versions and Kannada SEO pages
- Computer-skills warm-up module
- **Rank and college predictor (MCC + KEA) — live before NEET 2027 results**
- Counselling guides; streaks; WhatsApp daily quiz bot
- Update the exam interface once NTA publishes its official NEET CBT demo

## 5. Phase 3 — Growth (June → October 2027)

- Institution portal: batches, CSV import, test assignment, class analytics
- Vidhyavruksha ERP integration (student sync, single sign-on, results back)
- Parent dashboard and weekly WhatsApp summary
- iOS app
- Exam-lab Windows app with offline mode
- NCERT linking and the highlighted NCERT reader

## 6. Phase 4 — Advanced (late 2027 onwards)

Photo search, handwritten step checker, viva mode, likely-next questions, OMR scanning,
batch result forecast, white-label, leagues and duels, marks-to-seat and cost-to-seat planners.

## 7. Working with Claude Code

1. Put this folder at the root of the repository. Claude Code reads `CLAUDE.md` automatically.
2. Start each slice with a prompt like:
   > "Read docs/PRD.md sections 5.1–5.2, docs/ARCHITECTURE.md section 2.4 and docs/DATA_MODEL.md sections 3–4. Plan the import pipeline slice. Don't write code until I approve the plan."
3. Use plan mode for anything touching the schema, RLS or scoring.
4. Ask for tests with every slice: RLS policy tests, scoring tests with known answer keys, and sync/resume tests for the exam engine.
5. Keep the docs current: when a decision changes, update the relevant file and the decisions log in `docs/ARCHITECTURE.md`.
6. Fill in the **Commands** section of `CLAUDE.md` once the project runs.

## 8. Risks

| Risk | Mitigation |
|---|---|
| Not enough reviewed content by January | Start reviewers early; prioritise PYQs and high-weightage chapters; publish continuously |
| NTA changes the pattern or interface | Pattern in configuration; interface isolated in one module; update on NTA demo release |
| Live mock overload | Paper delivered once, batched sync, pre-scaling, load test before first live mock |
| AI parsing errors | Confidence scores, flags, human review of every item |
| Content rights disputes | Record source and rights note per file; remove on request |
| Solo developer bandwidth | Strict P0 scope for launch; vertical slices; defer everything P1+ |
