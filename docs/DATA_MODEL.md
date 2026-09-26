# Data Model — PrepVruksha

Version 0.3 · 26 September 2026 (sub-topics, difficulty, rights status, similarity, generated questions: planned, not migrated yet)

Core tables for Phase 1, plus the ones Phase 2–3 will need so the schema doesn't have to be
reshaped later. All tables use `uuid` primary keys and `created_at` / `updated_at`.
Columns listed are the important ones, not exhaustive. Migrations are the source of truth.

## 1. People and access

| Table | Key columns | Notes |
|---|---|---|
| `profiles` | `id` (= `auth.users.id`), `full_name`, `phone`, `preferred_language` (`en`/`kn`), `date_of_birth`, `target_exam_year`, `category`, `home_state` | One per user, created by a trigger on `auth.users`. `phone` is digits without `+` (as Supabase Auth stores it, e.g. `919999900001`). `category` holds central (MCC) categories (`general`, `ews`, `obc_ncl`, `sc`, `st`); `state_category` (KEA) and `pwd` are added before the college predictor. Minor status is derived with `private.is_minor(user_id)` (null when the date of birth is unknown), never stored. `phone` and `date_of_birth` are not client-editable; `date_of_birth` is set once at signup (ages 13–30) and only staff can correct it (`public.correct_date_of_birth`, audited). Category is optional at signup; category/state feed the predictor later. |
| `consents` | `user_id`, `type` (`parental`, `terms`, `marketing`), `policy_version`, `scope`, `granted_by_name`, `granted_by_phone`, `granted_at`, `method` (`parent_otp`, `in_app`, `offline_form`), `request_id`, `withdrawn_at` | DPDP consent. Parental rows must name the parent and their phone; `parent_otp` rows reference the verified request. One active consent per user/type/version. Withdrawal is recorded, not deleted. Written only by the signup functions. |
| `policy_versions` | `type` (`terms`, `parental`), `version`, `scope`, `document_url`, `is_current` | One current version per type. A new terms version makes students accept again. |
| `parental_consent_requests` | `user_id`, `parent_name`, `parent_phone`, `policy_version`, `scope`, `code_hash`, `status` (`pending`, `verified`, `expired`, `locked`, `superseded`, `cancelled`), `attempts`, `max_attempts`, `expires_at`, `verified_at` | One row per code sent to a parent. Only a keyed hash of the code, cleared once closed. Kept as evidence and for daily limits. Service role only. |
| `audit_log` | `actor_id`, `action`, `target_table`, `target_id`, `details` (jsonb) | Append-only record of sensitive changes (date-of-birth corrections; later publishing and role changes). |
| `institutions` | `name`, `type` (`pu_college`, `school`, `tutorial`), `city`, `erp_source` (`vidhyavruksha`/null), `erp_external_id`, `branding` (jsonb) | |
| `memberships` | `user_id`, `institution_id`, `role` (`student`, `teacher`, `admin`), `status` | A student can belong to several institutions over time. |
| `batches` | `institution_id`, `name`, `academic_year` | |
| `batch_members` | `batch_id`, `user_id` | |
| `parent_links` | `parent_user_id`, `student_user_id`, `visibility` (`summary`, `detailed`), `approved_by_student` | Student controls visibility. |
| `staff_roles` | `user_id`, `role` (`reviewer`, `content_admin`, `super_admin`), `granted_by` | Internal content team. Policies check it with `private.is_staff(...)`; `super_admin` satisfies every check. |

## 2. Syllabus

| Table | Key columns | Notes |
|---|---|---|
| `exams` | `code` (`NEET_UG`, later `KCET`, `PU_BOARD`), `slug`, `name_en`, `name_kn`, `name_kn_reviewed` | Supports adding exams later. |
| `exam_cycles` | `exam_id`, `exam_year`, `exam_date`, `date_confirmed` | One row per sitting. `public.target_exam_years(exam_code)` = the first sitting whose date has not passed (India time) and the two years after it; used by the profile step and enforced on `profiles.target_exam_year`. Content admins keep the next sitting on record. |
| `subjects` | `exam_id`, `code`, `slug`, `name_en`, `name_kn`, `name_kn_reviewed`, `sort_order` | Physics, Chemistry, Botany, Zoology. NCERT Biology chapters are split into Botany and Zoology following common NEET practice. |
| `chapters` | `subject_id`, `slug`, `name_en`, `name_kn`, `name_kn_reviewed`, `class_level` (11/12, null for units like experimental skills), `ncert_ref`, `neet_weightage`, `is_removed`, `sort_order` | `is_removed` = no longer in the exam syllabus; kept for tagging older PYQs. |
| `topics` | `chapter_id`, `slug`, `name_en`, `name_kn`, `name_kn_reviewed`, `sort_order` | |
| `sub_topics` (planned) | `topic_id`, `slug`, `name_en`, `name_kn`, `name_kn_reviewed`, `ncert_ref`, `is_removed`, `expert_reviewed`, `sort_order` | The level questions are tagged at. Drafted from the official NEET syllabus and NCERT; `expert_reviewed` stays false until the subject expert approves it. |

Slugs feed the SEO URLs and never change once used. `name_kn_reviewed` is false for AI-drafted Kannada names until the translator approves them; seeds never overwrite a reviewed name.
| `ncert_passages` (P1) | `chapter_id`, `book`, `page`, `para_no`, `text`, `embedding` (vector) | For NCERT linking and highlighted NCERT. |

## 3. Question bank

| Table | Key columns | Notes |
|---|---|---|
| `questions` | `exam_id`, `subject_id`, `chapter_id`, `format` (`single_mcq`, `assertion_reason`, `match_following`, `multi_statement`, `numerical`), `stem` (rich text / HTML with LaTeX), `stem_plain`, `language`, `translation_of` (fk → questions), `status` (`draft`, `review`, `published`, `retired`), `source_type` (`pyq`, `original`, `imported`, planned `ai_generated`), `pyq_year`, `source_file_id`, `source_page`, `slug`, `short_id`, `sub_topic_id` (planned), `difficulty` (planned: `easy`/`moderate`/`difficult`), `difficulty_ai` (planned), `difficulty_source` (planned: `reviewer`, `calibrated`), `difficulty_b` (IRT, nullable), `discrimination_a`, `canonical_id` (for duplicates), `exam_reserved`, `embedding` (vector, added in the import slice), `published_at`, `published_by` | `stem_plain` for search and SEO. `exam_reserved` holds a question back for live mocks: never public (app or SEO), even when published. The public URL is `{slug}-{short_id}`, so `slug` alone is not unique. The subject must belong to the exam and the chapter to the subject (composite foreign keys). Planned: a published question needs a `sub_topic_id` inside its chapter and a reviewer-confirmed `difficulty`; the AI's suggestion stays in `difficulty_ai`; recalibration from attempts sets `difficulty_source = 'calibrated'`. |
| `question_options` | `question_id`, `label` (A–D), `content`, `content_plain`, `is_correct`, `trap_type` (P1) | Correctness lives only here, and `is_correct` is not readable by app clients (column privilege). A published option question must have A–D with exactly one correct (checked at commit). Client writes must not ask for the row back (PostgREST `Prefer: return=minimal`); staff see the answer key through a server-side function. |
| `question_answers_numeric` (P2) | `question_id`, `value`, `tolerance` | Only for numerical questions. |
| `question_topics` | `question_id`, `topic_id` | Many-to-many. Planned: dropped (empty) and replaced by `questions.sub_topic_id`; secondary sub-topic tags only if reviewers need them. |
| `answer_checks` (planned, generator) | `question_id`, `kind` (`ai_proposed`, `ai_independent`, `expert_confirmed`), `answer` (option label or value), `model`, `actor_id`, `agrees` | For `ai_generated` questions. Publishing requires the two AI answers to agree (or the disagreement resolved by the expert) and an `expert_confirmed` row matching the current answer key; an answer-key edit voids the confirmation. |
| `similarity_flags` (planned, slice 4) | `subject_type` (`import_item`, `question`), `subject_id`, `match_type` (`question`, `reference_item`), `match_id`, `score`, `status` (`open`, `accepted`, `dismissed`), `resolved_by` | One row per match above the threshold. Open flags block publishing until a reviewer resolves them. |
| `question_ncert_links` (P1) | `question_id`, `ncert_passage_id`, `confidence`, `verified` | |
| `explanations` | `question_id`, `language`, `content`, `status`, `ai_drafted` (bool), `reviewed_by` | |
| `question_assets` | `question_id`, `storage_path`, `alt_text`, `position` | Images and diagrams. |
| `question_reports` | `question_id`, `user_id`, `reason`, `details`, `status` | "Report an error". |
| `content_audit` | `entity_type`, `entity_id`, `action`, `actor_id`, `before` (jsonb), `after` (jsonb) | Every publish / answer-key edit. |

## 4. Import pipeline

| Table | Key columns | Notes |
|---|---|---|
| `source_files` | `storage_path`, `original_name`, `file_type`, `size_bytes`, `sha256` (unique), `uploaded_by`, `rights_status` (`owned_licensed`, `official_pyq`, `reference_only`), `rights_note`, `pyq_exam_id` + `pyq_year` (required for `official_pyq`, else null), `status` (`awaiting_upload`, `queued`, `extracting`, `parsing`, `needs_review`, `done`, `failed`), `error` | Rights status and note are required at upload (slice 1). Items from a `reference_only` file can never become published questions (checked in the database); they are embedded into the reference corpus. |
| `import_jobs` | `source_file_id`, `step` (`extract_parse`), `status` (`queued`, `running`, `done`, `failed`), `attempts`, `locked_at`, `locked_by`, `last_error` | Queue polled with `FOR UPDATE SKIP LOCKED`. Content admins read. |
| `import_items` | `source_file_id`, `page`, `raw_extract`, `parsed` (jsonb), `confidence`, `flags` (text[]: `answer_missing`, `possible_duplicate`, `broken_math`…), `duplicate_of`, `status` (`needs_review`, `approved`, `rejected`), `question_id` (after approval), `reviewed_by` | One row per parsed candidate question. Planned: sub-topic and difficulty suggestions in `parsed`; `embedding` (slice 4). Items of `reference_only` files get status `reference` and are never approved. |
| `generation_jobs` (planned, generator) | `sub_topic_id`, `difficulty`, `format`, `count`, `model`, `status`, `requested_by` | One request to the question generator; results are `questions` in `review` with `source_type = 'ai_generated'`. |

## 5. Tests and attempts

| Table | Key columns | Notes |
|---|---|---|
| `exam_patterns` | `code` (e.g. `NEET_UG_2027_CBT`), `duration_min`, `sections` (jsonb: subject, question count, optional count), `marking` (jsonb: correct, wrong, unattempted per format), `question_types` (text[]), `ui_variant` | Pattern is data, not code. Verify values against the NTA bulletin. |
| `tests` | `title`, `type` (`full_mock`, `part`, `chapter`, `pyq`, `custom`, `practice`), `pattern_id`, `owner_institution_id` (null = platform), `visibility`, `is_live`, `is_free` | |
| `test_questions` | `test_id`, `question_id`, `section`, `position` | |
| `test_schedules` | `test_id`, `shift_no`, `starts_at`, `ends_at`, `paper_variant` | Live mocks and shifts. |
| `test_assignments` | `test_id`, `batch_id`, `due_at` | Institution use. |
| `attempts` | `user_id`, `test_id`, `schedule_id`, `started_at`, `submitted_at`, `status` (`in_progress`, `submitted`, `expired`), `client` (`android`, `web`, `lab`), `last_sync_seq`, `raw_score`, `correct`, `wrong`, `skipped`, `percentile`, `normalised_percentile`, `rank` | |
| `attempt_answers` | `attempt_id`, `question_id`, `selected_option_id`, `numeric_value`, `confidence` (`sure`, `half`, `guess`), `time_spent_ms`, `visits`, `answer_changes` (jsonb), `is_correct`, `marks` | `is_correct` / `marks` written only by the API. |
| `attempt_events` | `attempt_id`, `events` (jsonb array of {t, type, question_id, …}), `seq` | Compressed navigation log for test replay; one row per sync batch. |
| `attempt_analytics` | `attempt_id`, `summary` (jsonb: subject, chapter, time, negative-marking breakdowns) | Computed after submit. |

## 6. Learning

| Table | Key columns | Notes |
|---|---|---|
| `error_notebook` | `user_id`, `question_id`, `first_wrong_at`, `mistake_reason` (`concept`, `calculation`, `misread`, `guess`), `times_wrong`, `resolved` | |
| `srs_cards` (P1) | `user_id`, `question_id` or `flashcard_id`, `due_at`, `interval_days`, `ease`, `reps` | Spaced repetition. |
| `user_chapter_stats` | `user_id`, `chapter_id`, `attempted`, `correct`, `avg_time_ms`, `mastery` | Updated after each attempt; feeds heatmap and priority engine. |
| `study_plans` (P1) | `user_id`, `exam_date`, `plan` (jsonb), `generated_at` | |
| `bookmarks` | `user_id`, `question_id` | |

## 7. Counselling (P1)

| Table | Key columns | Notes |
|---|---|---|
| `colleges` | `name`, `state`, `type` (`govt`, `private`, `deemed`, `aiims`…), `fees` (jsonb) | |
| `cutoffs` | `college_id`, `year`, `authority` (`MCC`, `KEA`), `round`, `quota`, `category`, `closing_rank` | Loaded from published counselling data. |
| `score_rank_curves` | `year`, `score`, `estimated_rank` | For rank prediction. |

## 8. Row Level Security (summary)

| Data | Who can read | Who can write |
|---|---|---|
| Published questions, options, explanations | Everyone, except `exam_reserved` questions. `question_options.is_correct` is never readable by `anon`/`authenticated`: correctness comes only from server-side code (after submission for mocks, per question for practice, the SEO build, review-console functions) | Reviewers and content admins (only content admins delete) |
| `seo_questions` view | Service role only (the SEO build): published and not `exam_reserved` | — |
| Draft / review content, import tables, `answer_checks`, `similarity_flags`, `generation_jobs` | Reviewers, content admins | Service-role functions that check the staff role; pipeline / generator service |
| Reference-only files and their items | Content admins and super admins only (not reviewers) | Pipeline service only; never published, never in `seo_questions` |
| Syllabus (`exams`, `exam_cycles` … `topics`) | Everyone | Content admins |
| `staff_roles` | The user (own roles); super admins | Super admins |
| `profiles` | The user; institution staff for their members (limited columns); linked parents per `visibility` | The user |
| `attempts`, `attempt_answers`, analytics | The user; teachers/admins of an institution the user belongs to (only for that institution's tests); parents per `visibility` | API service only (scores); app only through the API |
| `memberships`, `batches` | Institution admins; the member | Institution admins |
| `consents` | The user; super admins | Signup flow via API (service role) only |
| `parental_consent_requests` | Service role only | Signup flow via API only |
| `policy_versions` | Everyone | Service role (migrations/seed; later the console via the API) |
| `audit_log` | Super admins | Service role (insert only; never updated or deleted) |

## 9. Indexes to create early

- `questions (status, subject_id, chapter_id)`
- `questions` GIN index on `to_tsvector('simple', stem_plain)` for full-text search
- `questions` and `import_items` HNSW indexes on `embedding` (pipeline slice 4, before launch)
- `questions (sub_topic_id, difficulty, status)` for coverage and test assembly
- `questions (short_id)` unique
- `attempts (user_id, test_id)`, `attempts (test_id, submitted_at)`
- `attempt_answers (attempt_id)`, `attempt_answers (question_id)`
- `import_jobs (status, created_at)`

## 10. Sub-topics and difficulty (migration `20261001000100`, 26 Sep 2026)

Decided 26 Sep: tagging against the draft tree is allowed, but **a question can be published only when its sub-topic has `expert_reviewed = true`** (commit-time trigger `questions_published_sub_topic`), plus a sub-topic and a reviewer-set difficulty (check). Removed chapters, topics and sub-topics stay in the tree with `is_removed = true`, so older PYQs still get a sub-topic under the strict rule; **practice and mocks exclude questions on removed sub-topics by default** (to enforce when those slices are built). `sub_topics.chapter_id` is stored and kept equal to the topic's chapter by a composite FK; `questions (sub_topic_id, chapter_id)` references it, so a question's sub-topic is always in its own chapter. `difficulty_source` is null exactly when `difficulty` is. The tree itself is loaded by numbered **seed files** generated from `docs/syllabus/*.md` (`docs/syllabus/README.md`), never edited once pushed.

Original plan:

One migration after slice 1, before the worker writes any `import_items`, so nothing has to be re-tagged (0 questions today):

1. `sub_topics` table (grants, RLS: everyone reads, content admins write; privileges matrix + pgTAP).
2. `questions.sub_topic_id` (FK, with a check that the sub-topic's topic belongs to `questions.chapter_id`), `difficulty`, `difficulty_ai`, `difficulty_source`; `source_type` gains `ai_generated`.
3. Publish check: a published question has a `sub_topic_id` and a reviewer-set `difficulty`.
4. Drop the empty `question_topics` table.
5. Data: topics and sub-topics from the expert-reviewed draft tree. Because seed files run once per project, dev and prod get this data through a migration, not a changed seed file.

The rights status comes with slice 1 (`source_files`). `answer_checks`, `similarity_flags`, embeddings and `generation_jobs` come with the slices that use them.
