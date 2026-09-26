-- Current terms/privacy and parental-consent policy versions.
-- PLACEHOLDER TEXT: the final terms, privacy policy and parental consent text
-- come from a lawyer before launch (launch blocker in docs/STATUS.md). A new
-- version is a new row with is_current = true (unset the old one first).

insert into public.policy_versions (type, version, scope, is_current) values
  ('terms', '2026-10-draft',
   'Running a PrepVruksha account: phone sign-in, exam practice and mock tests, and results and analytics shown to the student.',
   true),
  ('parental', '2026-10-draft',
   'A parent or guardian allows their child (under 18) to use PrepVruksha: phone sign-in, exam practice and mock tests, and results and analytics shown to the student. No behavioural tracking or targeted advertising. Parent reports only as the student chooses.',
   true)
on conflict (type, version) do nothing;
