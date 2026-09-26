# Roadmap — PrepVruksha

Version 0.3 · 26 September 2026 (progress marked; subject-teacher advice added: sub-topics, rights status, similarity before launch, question generator; details in `STATUS.md`)

Target: CBT mock engine and weekly live mocks running by **January 2027**, ahead of the first
CBT-mode NEET (expected around May 2027). Dates below assume one developer plus
part-time content reviewers.

## 1. Start in this order

1. **Documents** (this folder) — agree the scope. ✔
2. **Long-lead items** (start this week; they take time outside your control):
   - Product name and domain: PrepVruksha, prepvruksha.com ✔ (also register the .in and the "vriksha" spelling)
   - Choose a DLT-registered SMS/WhatsApp OTP provider and start DLT sender and template registration.
   - Contract 1–2 subject-expert reviewers (Physics, Chemistry, Biology) and a Kannada translator. **First expert task: review the draft NEET sub-topic tree** (needed before pipeline slice 2); later, confirming answers of AI-generated questions.
   - Confirm content rights for the existing question files; each file gets a rights status at upload (`owned_licensed`, `official_pyq`, `reference_only`).
   - Google Play developer account (Apple developer account can wait until after launch).
3. **Minimum infrastructure** (one day — see section 2). Only dev at first; prod when the first slice works.
4. **Build in vertical slices** with Claude Code (section 3).

Don't set up every service in advance. Add each one when the slice that needs it starts.

## 2. Infrastructure setup checklist

### Day 1 — dev environment

- [x] GitHub repository `prepvruksha`; branch protection on `main` ("CI result" required). Note: the repository is currently **public**, not private (decision open in `STATUS.md`).
- [x] Supabase organisation; project `prepvruksha-dev` in the **Mumbai** region; enable the `vector` extension.
- [x] Supabase CLI locally (Docker Desktop) — `supabase init`, `supabase start` for a local database.
- [x] Google Cloud project `prepvruksha-dev` (this is also the Firebase project): Cloud Run, Artifact Registry, Secret Manager enabled (`infra/gcp-dev-setup.sh`); region `asia-south1`. Cloud Scheduler is added with the first scheduled job (nightly SEO build).
- [x] Firebase: project added; Hosting (`prepvruksha-dev.web.app`) and Cloud Messaging only.
- [ ] **Budget alerts** on GCP and a spend cap on Supabase.
- [ ] API account: Anthropic (Claude API). Key into Secret Manager and a local `.env`. (Mathpix dropped after slice 0.)
- [x] Flutter: create `apps/app`, `apps/console`, `packages/core`, `packages/ui_kit` (pub workspaces).
- [x] CI/CD: per-area CI with one required check; Deploy dev after CI passes on `main` (database, then API on Cloud Run, then web app on Firebase Hosting); keyless sign-in to GCP.

### Before public launch — production

- [ ] Supabase `prepvruksha-prod` (Mumbai, Pro plan) and GCP `prepvruksha-prod`.
- [ ] Domain DNS in Route 53: site → Firebase Hosting; `api.` → Cloud Run custom domain.
- [ ] Google Search Console and Bing Webmaster Tools; submit the sitemap index.
- [ ] Backups: Supabase point-in-time recovery (or daily dumps to Cloud Storage).
- [ ] Monitoring: Crashlytics for apps, Cloud Logging alerts for API errors, uptime check on the API.
- [ ] Privacy policy and terms: final text from a lawyer (the DPDP consent flow is built; it uses placeholder text versioned in `policy_versions`).
- [ ] Login provider decision (Firebase Phone Auth vs Supabase Auth + a DLT-registered Indian OTP provider; notes in `STATUS.md`), then real SMS for sign-in OTP and parent consent codes.

## 3. Phase 1 — Launch (October 2026 → January 2027)

Revised 26 Sep 2026 after the subject-teacher advice. Week 2 starts 28 Sep 2026.

| Weeks | Slice | Done when |
|---|---|---|
| 1 ✔ | **Foundations** | Repo, CI (lint + tests), local Supabase, first migrations (profiles, syllabus, questions, options), seed subjects/chapters, phone OTP login working in the app |
| 2 | **Pipeline 1: staff console + uploads** | Secret scanning in CI; staff upload a PDF/Word file with a rights status and note; listed as `queued` with an import job |
| 3 | **Sub-topics + difficulty** | Migration (DATA_MODEL section 10); draft NEET sub-topic tree seeded as unreviewed; subject expert reviewing in parallel |
| 3–4 | **Pipeline 2: worker** | Files parsed into `import_items` on Cloud Run, incl. scanned pages and figures; AI suggests sub-topic and difficulty |
| 5 | **Pipeline 3: review + publishing** | Source page beside the parsed question; reviewer confirms sub-topic, difficulty and answer; approve publishes; `reference_only` items cannot be published |
| 6–7 | **Pipeline 4: similarity (before launch)** | Embeddings for the bank and the reference-only corpus; every new question compared and flagged above the threshold; harder answer-key layouts |
| 7–8 | **Question generator** | Questions per sub-topic, difficulty and format into review; independent second solve; expert answer confirmation; similarity check |
| 3–16 (ongoing) | **Content** | Reviewers publishing continuously from week 5; target a few thousand reviewed questions by launch, covering every chapter |
| 9–12 | **CBT exam engine** | NTA-style interface, exam-day sequence, pattern from `exam_patterns`, local saving + batched sync, resume after disconnect, server-side scoring. Load-tested at 5,000 simulated students |
| 12–13 | **Results v1 + error notebook** | Score, subject breakdown, platform rank/percentile, time analysis, chapter/sub-topic heatmap; wrong answers collected with mistake reasons |
| 13–14 | **Practice + search** | Chapter, sub-topic and difficulty-based tests, PYQ papers, custom tests; keyword search over published questions |
| 14–15 | **Public SEO pages** | Static question pages, hub pages, sitemaps deployed nightly; Search Console live |
| 15–16 | **Live mocks + pilot** | Scheduled all-India mock with scale-up routine; 2–3 pilot PU colleges onboarded manually; bug-fix buffer |
| Late Jan 2027 (week 17) | **Launch** | Weekly live mocks begin; Android app on Play Store; web app live |

**Timeline impact:** about **+4 weeks** of build (sub-topics ~1 week, similarity moved before launch ~1.5 weeks, generator ~2 weeks, minus overlap). The CBT engine moves from weeks 5–8 to 9–12 (ready around 20 Dec instead of mid-Nov), and launch from early January to **late January 2027**, leaving about 14 weekly mocks before a May 2027 exam instead of about 18. If early January must hold, the lever is to build the generator after the CBT engine (weeks 13–14), which brings the engine back to weeks 7–10 and launch to about week 15.

Done by 26 Sep 2026 (see `STATUS.md`): Foundations; signup and parental consent (DPDP); feature-first code layout with boundary checks; dev deploy pipeline; target exam years from `exam_cycles` data. Next: pipeline slice 1 (staff console and uploads, with rights status), starting with secret scanning.

Publish the first reviewed question pages as early as week 6 — search ranking takes months.

**No real user signs up until the signup and parental-consent flow is complete** (built in the slice after Foundations), **real DLT-registered SMS sending is live, and the final legal text is published** (launch blockers in `STATUS.md`). Until then only the test phone numbers are used.

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
| Wrong answers on AI-generated questions | Independent second AI solve must agree; subject expert confirms every answer; attempt data flags questions students get "wrong" unusually often |
| Sub-topic tree not reviewed in time | AI-drafted tree marked unreviewed; tagging can start on it; expert review runs in parallel with slice 2 |
| Content rights disputes | Rights status and note per file at upload; `reference_only` never published; similarity check against the reference corpus; remove on request |
| Solo developer bandwidth | Strict P0 scope for launch; vertical slices; defer everything P1+ |
