# NEET sub-topic tree (draft for expert review)

The syllabus has four levels: **subject → chapter → topic → sub-topic**. Questions are tagged
at sub-topic level (with difficulty easy / moderate / difficult). Chapters already exist in
`supabase/seed/01_neet_syllabus.sql`; this folder drafts the two levels below them.

| File | Subject | Status |
|---|---|---|
| `biology.md` | Botany + Zoology | AI-drafted 26 Sep 2026, **awaiting subject-expert review** |
| `chemistry.md` | Chemistry | Not started |
| `physics.md` | Physics | Not started |

## How the draft was made

- Chapter list and order: the seed (current NEET-UG syllabus, NCERT rationalised 2023 books).
  Chapters removed from the syllabus (`is_removed = true`) are not broken down.
- Topics follow the NCERT chapter headings; sub-topics are the smallest units a question is
  usually about, so one question fits one sub-topic.
- AI-drafted. **Not yet checked line by line against the official NEET-UG syllabus PDF**
  (NMC); the reviewer should do that check.

## For the reviewer

For each chapter, please:

1. Tick the chapter's box when it is reviewed.
2. Strike through (`~~text~~`) anything outside the NEET syllabus, and add anything missing.
3. Merge sub-topics too small to tag separately; split ones that mix different ideas.
4. Mark lines with **Check** notes: those are points where the draft is unsure.

Rules the tree has to follow:

- Every sub-topic belongs to exactly one topic, every topic to exactly one chapter.
- Names are short (they appear in the app and on public pages). English only here; Kannada
  names are added later by the translator.
- Once questions are tagged, names can be corrected but a sub-topic is not deleted or moved
  without re-tagging its questions, so it is worth getting the structure right now.

After review the tree is loaded by a migration (`sub_topics`, `DATA_MODEL.md` section 10),
with `expert_reviewed = true` for approved chapters.
