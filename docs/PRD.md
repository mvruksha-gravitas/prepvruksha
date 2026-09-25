# Product Requirements — PrepVruksha

Version 0.1 · 25 September 2026 · Owner: mVruksha Softwares

## 1. Summary

A NEET-UG preparation platform built on a large, human-verified question bank. Students
practise, take realistic computer-based (CBT) mock exams, see exactly why they lose marks,
and plan their way to a medical seat. PU colleges, tutorials, teachers and parents use the
same data through their own views.

## 2. Why now

- NEET-UG moves from pen-and-paper OMR to **CBT mode from the 2027 exam** (expected around May 2027). Most students have only practised on paper.
- The exam is expected to run in **multiple shifts with normalised percentiles**, and multi-stage testing has been recommended. The exam engine must handle pattern changes through configuration.
- Target: CBT mock engine and weekly live mocks running by **January 2027**.

## 3. Users and goals

| User | Main goal |
|---|---|
| Student (first attempt or repeater) | Know what to study next, stop losing marks, get comfortable with CBT, reach a target seat |
| PU college / school | Run regular tests with little effort, see class weaknesses, show results to parents and prospects |
| Tutorial / coaching centre | Offer a professional, branded test series without building content or tech |
| Teacher | Build tests quickly, see where each student struggles, answer doubts faster |
| Parent | Know simply whether their child is on track; get counselling and cost guidance |
| Content reviewer (internal) | Import, check, correct and publish questions quickly |

## 4. Principles

1. Students own their account; their profile follows them across institutions.
2. Free core (question dumps, previous-year papers, some mocks, public question pages, college predictor). Premium for depth.
3. Every published answer is human-verified. AI assists but never decides answers or scores.
4. Kannada and English from the start.
5. Works on cheap Android phones and slow networks; full mocks encouraged on desktop.

## 5. Modules and features

Priority: **P0** = needed for the January 2027 launch · **P1** = soon after launch · **P2** = later.

### 5.1 Question bank

| Feature | Priority |
|---|---|
| Questions with options, answer, explanation, images | P0 |
| Tags: subject, chapter, topic, concept, question format, source (PYQ year / original) | P0 |
| Question formats: single-correct MCQ, assertion–reason, match-the-following, multi-statement | P0 |
| Status workflow: draft → review → published → retired | P0 |
| Link each question to NCERT lines | P1 |
| Flag questions on topics removed by NCERT rationalisation | P1 |
| Difficulty calibrated from real attempt data (IRT) | P1 |
| Trap type on each wrong option | P1 |
| Kannada versions linked to the English original | P1 |
| Numerical-answer question type (in case NTA adds it) | P2 |

### 5.2 Content import pipeline

| Feature | Priority |
|---|---|
| Bulk upload of PDF, Word and ZIP files with per-file status | P0 |
| Extraction: Pandoc (Word), PyMuPDF (text PDF), Mathpix (scanned PDF, formulas) | P0 |
| AI parsing into structured questions with a confidence score | P0 |
| Matching answer keys printed separately from questions | P0 |
| Automatic tagging | P0 |
| Near-duplicate detection (embeddings) | P0 |
| Review screen: original page beside parsed question; approve / edit / reject | P0 |
| Excel/CSV and marked-up Word templates for new content | P1 |
| AI-drafted explanations and Kannada translations (always reviewed) | P1 |

### 5.3 CBT exam engine

| Feature | Priority |
|---|---|
| Interface close to NTA's CBT: subject tabs, question palette with status colours, Save & Next, Clear Response, Mark for Review, timer, language switch | P0 |
| Exam-day sequence: roll-number login, instructions screen, declaration | P0 |
| Test types: full mock, part syllabus, chapter test, previous-year paper, custom test | P0 |
| Local answer saving with periodic sync; resume after disconnection | P0 |
| Exam patterns stored as configuration | P0 |
| Scheduled live all-India mocks | P0 |
| Multiple shifts with different papers and normalised percentile | P1 |
| Confidence marking per answer (Sure / 50-50 / Guess) | P1 |
| Computer-skills warm-up module for first-time computer users | P1 |
| Accessibility: extra time, magnification, high contrast | P1 |
| Exam-lab mode: locked full-screen Windows app, offline local server with later sync | P2 |

Update the interface to match NTA's official NEET CBT demo as soon as it is released.

### 5.4 Results and analytics

| Feature | Priority |
|---|---|
| Score, subject breakdown, correct / wrong / skipped | P0 |
| Rank and percentile among platform users | P0 |
| Time per question and subject; questions where time was wasted | P0 |
| Chapter heatmap weighted by NEET frequency | P0 |
| Negative-marking analysis | P1 |
| Personal guessing rule from confidence data | P1 |
| Answer-change analysis | P1 |
| Test replay (navigation timeline) | P1 |
| Navigation analytics (revisits, marked-but-unanswered) | P1 |
| Trap profile | P2 |
| Comparison with top scorers | P2 |

### 5.5 Learning engine

| Feature | Priority |
|---|---|
| Error notebook (automatic) with mistake-reason tagging | P0 |
| Spaced repetition of wrong questions | P1 |
| Diagnostic test at signup | P1 |
| Priority engine (chapter weightage × weakness) | P1 |
| Daily adaptive practice set | P1 |
| Countdown study planner | P1 |
| Marks-to-seat planner | P2 |

### 5.6 Search and doubts

| Feature | Priority |
|---|---|
| Keyword search over published questions (Postgres full-text) | P0 |
| Meaning-based search and "similar questions" (pgvector) | P1 |
| AI tutor on each question, grounded in the verified explanation and NCERT | P1 |
| Photo search | P2 |
| Handwritten step checker for numericals | P2 |

### 5.7 Revision tools

Flashcards (P1), highlighted NCERT reader (P2), diagram labelling (P2), audio revision (P2), viva mode (P2), notes-to-flashcards (P2).

### 5.8 Counselling

| Feature | Priority |
|---|---|
| Rank and college predictor (MCC + KEA, category and quota) | P1 — must be live before NEET 2027 results |
| Counselling guides and document checklists | P1 |
| Cost-to-seat planner | P2 |
| Choice-filling simulator | P2 |

### 5.9 Institution portal

| Feature | Priority |
|---|---|
| Institution and batch setup; student import from CSV | P1 (pilot colleges set up manually for launch) |
| Assign tests and practice sets to batches | P1 |
| Class analytics, at-risk students | P1 |
| Vidhyavruksha ERP connection (student sync, single sign-on, results back) | P1 |
| OMR scanning for internal paper tests | P2 |
| Batch result forecast | P2 |
| Branding / white-label | P2 |
| Suspicious answer-pattern detection | P2 |

### 5.10 Parents

Weekly WhatsApp summary (P1), target tracking and engagement alerts (P1), student-controlled detail level (P1), counselling access (P1).

### 5.11 Engagement

Streaks (P1), WhatsApp daily quiz bot (P1), weekly leagues (P2), peer duels (P2), study twin (P2).

### 5.12 Public site and SEO

| Feature | Priority |
|---|---|
| One static page per published question (question, options, answer, explanation) | P0 |
| Subject → chapter → topic hub pages; previous-year paper pages | P0 |
| XML sitemaps (nightly), Search Console + Bing Webmaster | P0 |
| Structured data (schema.org Quiz/Question), canonical tags | P0 |
| Kannada pages with hreflang | P1 |
| NEET 2027 CBT, pattern and counselling guide pages | P1 |

## 6. AI use

- **Allowed:** import parsing, tagging, NCERT linking, duplicate detection, draft explanations and translations, question variants, grounded tutoring, summaries, parent reports, test assembly from the verified bank.
- **Statistics, not AI:** difficulty (IRT), rank / percentile / normalisation, college predictor, spaced repetition, priority engine, copying detection.
- **Never AI:** answer keys, scoring, publishing without review, cheating verdicts, emotional counselling (point to people and helplines instead).
- **Cost control:** generate once and store; batch processing for bulk jobs; smaller models for simple tasks; AI tutor limits on the free plan.

## 7. Non-functional requirements

| Area | Requirement |
|---|---|
| Performance | Question page load under 2 s on a mid-range Android phone over 4G |
| Live mocks | Designed for at least 5,000 concurrent students per shift at launch; database scaled up before each scheduled mock |
| Reliability | No answer lost on disconnection; exam resumes where it stopped |
| Data residency | All data in Indian regions |
| Privacy | Parental consent for under-18 users (DPDP Act); no personal data to AI services |
| Security | RLS on all user data; secrets in secret managers; audit log for content publishing |
| Localisation | English and Kannada at launch; structure ready for Hindi |
| Accessibility | Scalable text, contrast options, screen-reader labels on exam controls |

## 8. Business model

- **Free:** question dumps, previous-year papers, limited mocks, public question pages, college predictor.
- **Student premium:** deep analytics, unlimited AI tutor, live test series, adaptive plan.
- **Institutions:** annual per-student licence; white-label and ERP integration as add-ons.
- **Go-to-market:** pilot with 2–3 PU colleges already on Vidhyavruksha ERP.

## 9. Success measures (first 6 months)

- Published, reviewed questions in the bank
- Weekly active students and mocks completed per student
- Share of students taking a second mock within 14 days
- Pilot institutions converted to paid
- Question pages indexed and organic search visits

## 10. Open decisions

| Decision | Default until decided |
|---|---|
| Product name, brand, domain | **Decided:** PrepVruksha, prepvruksha.com |
| KCET and PU board coverage at launch | NEET only; data model supports other exams |
| Mobile app at launch vs web first | Android app + web app together (same Flutter code); iOS after launch |
| Phone OTP provider (DLT-registered) | To choose; start DLT registration early |
| Subject-expert reviewers and Kannada translators | To hire / contract |
| Content rights for existing question files | Verify before import |
| Pricing figures, AI and OCR budget | To set |
