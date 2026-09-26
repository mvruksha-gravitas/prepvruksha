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

## Format rules (read by the loader)

- `# Botany` / `# Zoology` / `# Physics` / `# Chemistry` start a subject.
- `## [ ] Chapter name (`chapter-slug`, NCERT ref)`: the slug must match the seed
  (`supabase/seed/01_neet_syllabus.sql`). `[x]` = the expert approved the chapter; its
  sub-topics load with `expert_reviewed = true` (questions on them can be published).
- `- **Topic**` and `  - Sub-topic` (two spaces). No deeper levels.
- Add ` (removed)` at the end of a topic or sub-topic that left the syllabus; everything
  in a removed chapter (`is_removed` in the seed) is removed too. Removed parts stay so
  older PYQs can be tagged.
- ` — Check: …` notes are for the reviewer and are not loaded.
- To rename a topic or sub-topic after it has been loaded, keep its slug by ending the line with
  `{old-slug}`; otherwise the new name becomes a new row and the old one is kept (the seed file
  prints a notice listing rows the markdown no longer has).
- A topic with no sub-topics gets one sub-topic with the topic's own name.

## Loading

The loader writes a **new seed file** (not a migration: on a fresh database, migrations run
before the seed that creates the chapters):

```powershell
cd services/pipeline
uv run prepvruksha-pipeline syllabus-sql ../../docs/syllabus/biology.md --out ../../supabase/seed/04_syllabus_biology.sql
```

Seed files run once per project and are never re-run when edited, so a loaded file is never
edited: the teacher's corrections and approvals (`[x]`) go in a new, higher-numbered seed
file generated from the updated markdown. It updates existing rows (names, removed flags,
approvals, order), adds new ones, and never deletes any. Slugs are only frozen once a question on them is published.
