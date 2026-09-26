# Data Model — PrepVruksha

Version 0.2 · 26 September 2026

Core tables for Phase 1, plus the ones Phase 2–3 will need so the schema doesn't have to be
reshaped later. All tables use `uuid` primary keys and `created_at` / `updated_at`.
Columns listed are the important ones, not exhaustive. Migrations are the source of truth.

## 1. People and access

| Table | Key columns | Notes |
|---|---|---|
| `profiles` | `id` (= `auth.users.id`), `full_name`, `phone`, `preferred_language` (`en`/`kn`), `date_of_birth`, `target_exam_year`, `category`, `home_state` | One per user, created by a trigger on `auth.users`. `phone` is digits without `+` (as Supabase Auth stores it, e.g. `919999900001`). `category` holds central (MCC) categories (`general`, `ews`, `obc_ncl`, `sc`, `st`); `state_category` (KEA) and `pwd` are added before the college predictor. Minor status is derived with `private.is_minor(user_id)` (null when the date of birth is unknown), never stored. `phone` and `date_of_birth` are not client-editable. Category/state feed the predictor later. |
| `consents` | `user_id`, `type` (`parental`, `terms`, `marketing`), `policy_version`, `granted_by_name`, `granted_by_phone`, `granted_at`, `method` (`parent_otp`, `in_app`, `offline_form`), `withdrawn_at` | DPDP parental consent for under-18s. Parental rows must name the parent and their phone. Withdrawal is recorded, not deleted. |
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
| `subjects` | `exam_id`, `code`, `slug`, `name_en`, `name_kn`, `name_kn_reviewed`, `sort_order` | Physics, Chemistry, Botany, Zoology. NCERT Biology chapters are split into Botany and Zoology following common NEET practice. |
| `chapters` | `subject_id`, `slug`, `name_en`, `name_kn`, `name_kn_reviewed`, `class_level` (11/12, null for units like experimental skills), `ncert_ref`, `neet_weightage`, `is_removed`, `sort_order` | `is_removed` = no longer in the exam syllabus; kept for tagging older PYQs. |
| `topics` | `chapter_id`, `slug`, `name_en`, `name_kn`, `name_kn_reviewed`, `sort_order` | |

Slugs feed the SEO URLs and never change once used. `name_kn_reviewed` is false for AI-drafted Kannada names until the translator approves them; seeds never overwrite a reviewed name.
| `ncert_passages` (P1) | `chapter_id`, `book`, `page`, `para_no`, `text`, `embedding` (vector) | For NCERT linking and highlighted NCERT. |

## 3. Question bank

| Table | Key columns | Notes |
|---|---|---|
| `questions` | `exam_id`, `subject_id`, `chapter_id`, `format` (`single_mcq`, `assertion_reason`, `match_following`, `multi_statement`, `numerical`), `stem` (rich text / HTML with LaTeX), `stem_plain`, `language`, `translation_of` (fk → questions), `status` (`draft`, `review`, `published`, `retired`), `source_type` (`pyq`, `original`, `imported`), `pyq_year`, `source_file_id`, `source_page`, `slug`, `short_id`, `difficulty_b` (IRT, nullable), `discrimination_a`, `canonical_id` (for duplicates), `exam_reserved`, `embedding` (vector, added in the import slice), `published_at`, `published_by` | `stem_plain` for search and SEO. `exam_reserved` holds a question back for live mocks: never public (app or SEO), even when published. The public URL is `{slug}-{short_id}`, so `slug` alone is not unique. The subject must belong to the exam and the chapter to the subject (composite foreign keys). |
| `question_options` | `question_id`, `label` (A–D), `content`, `content_plain`, `is_correct`, `trap_type` (P1) | Correctness lives only here, and `is_correct` is not readable by app clients (column privilege). A published option question must have A–D with exactly one correct (checked at commit). Client writes must not ask for the row back (PostgREST `Prefer: return=minimal`); staff see the answer key through a server-side function. |
| `question_answers_numeric` (P2) | `question_id`, `value`, `tolerance` | Only for numerical questions. |
| `question_topics` | `question_id`, `topic_id` | Many-to-many. |
| `question_ncert_links` (P1) | `question_id`, `ncert_passage_id`, `confidence`, `verified` | |
| `explanations` | `question_id`, `language`, `content`, `status`, `ai_drafted` (bool), `reviewed_by` | |
| `question_assets` | `question_id`, `storage_path`, `alt_text`, `position` | Images and diagrams. |
| `question_reports` | `question_id`, `user_id`, `reason`, `details`, `status` | "Report an error". |
| `content_audit` | `entity_type`, `entity_id`, `action`, `actor_id`, `before` (jsonb), `after` (jsonb) | Every publish / answer-key edit. |

## 4. Import pipeline

| Table | Key columns | Notes |
|---|---|---|
| `source_files` | `storage_path`, `original_name`, `file_type`, `uploaded_by`, `rights_note`, `status` (`queued`, `extracting`, `parsing`, `needs_review`, `done`, `failed`), `error` | |
| `import_jobs` | `source_file_id`, `step`, `status`, `attempts`, `locked_at`, `locked_by` | Queue polled with `FOR UPDATE SKIP LOCKED`. |
| `import_items` | `source_file_id`, `page`, `raw_extract`, `parsed` (jsonb), `confidence`, `flags` (text[]: `answer_missing`, `possible_duplicate`, `broken_math`…), `duplicate_of`, `status` (`needs_review`, `approved`, `rejected`), `question_id` (after approval), `reviewed_by` | One row per parsed candidate question. |

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
| Draft / review content, import tables | Reviewers, content admins | Reviewers, content admins, pipeline service |
| Syllabus (`exams` … `topics`) | Everyone | Content admins |
| `staff_roles` | The user (own roles); super admins | Super admins |
| `profiles` | The user; institution staff for their members (limited columns); linked parents per `visibility` | The user |
| `attempts`, `attempt_answers`, analytics | The user; teachers/admins of an institution the user belongs to (only for that institution's tests); parents per `visibility` | API service only (scores); app only through the API |
| `memberships`, `batches` | Institution admins; the member | Institution admins |
| `consents` | The user; super admins | Signup flow via API (service role) only |

## 9. Indexes to create early

- `questions (status, subject_id, chapter_id)`
- `questions` GIN index on `to_tsvector('simple', stem_plain)` for full-text search
- `questions` HNSW index on `embedding` (with the embedding column, import slice)
- `questions (short_id)` unique
- `attempts (user_id, test_id)`, `attempts (test_id, submitted_at)`
- `attempt_answers (attempt_id)`, `attempt_answers (question_id)`
- `import_jobs (status, created_at)`
