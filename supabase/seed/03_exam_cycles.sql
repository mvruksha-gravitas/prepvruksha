-- Upcoming exam sittings. Content admins maintain these rows; the seed only
-- adds missing ones and never overwrites an edited date.
--
-- NEET-UG 2027-2029: tentative, not yet notified by NTA. Each is stored as the
-- first Sunday of May (NEET-UG's usual pattern) with date_confirmed = false;
-- set the official date and date_confirmed = true when NTA announces it.
-- Later sittings keep signup open after an exam passes (see
-- public.target_exam_years).

insert into public.exam_cycles (exam_id, exam_year, exam_date, date_confirmed)
select e.id, v.exam_year, v.exam_date, false
from public.exams e
cross join (values
  (2027::smallint, date '2027-05-02'),
  (2028::smallint, date '2028-05-07'),
  (2029::smallint, date '2029-05-06')
) as v (exam_year, exam_date)
where e.code = 'NEET_UG'
on conflict (exam_id, exam_year) do nothing;
