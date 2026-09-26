-- Upcoming exam sittings. Content admins maintain these rows; the seed only
-- adds missing ones and never overwrites an edited date.
--
-- NEET-UG 2027: "May 2027" for now, not yet notified. Stored as the first
-- Sunday of May (NEET-UG's usual pattern) with date_confirmed = false; update
-- it to the official date when NTA announces it.

insert into public.exam_cycles (exam_id, exam_year, exam_date, date_confirmed)
select e.id, 2027, date '2027-05-02', false
from public.exams e
where e.code = 'NEET_UG'
on conflict (exam_id, exam_year) do nothing;
