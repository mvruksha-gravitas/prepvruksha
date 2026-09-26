-- NEET-UG syllabus reference data: exam, subjects, chapters.
--
-- Safe to re-run (upserts on natural keys). Applied locally by
-- `supabase db reset` and to remote projects by `supabase db push --include-seed`.
--
-- Chapters follow the NCERT textbooks (Class 11 and 12), filtered to the NMC
-- NEET-UG syllabus. Chapters no longer in the NEET syllabus are kept with
-- is_removed = true so older previous-year questions can still be tagged.
-- Biology is split into Botany and Zoology following common NEET practice.
-- ncert_ref: "<class> <book> Ch <n>" in the current (2023 rationalised)
-- books; "(pre-2023)" marks chapters only in the older editions.
--
-- Kannada names (name_kn) are AI-DRAFTED and need translator review. They are
-- inserted with name_kn_reviewed = false. Re-running this file never
-- overwrites a Kannada name that has been marked reviewed.
--
-- neet_weightage is left null until there is a verified source.
-- Topics are added in a later seed.

insert into public.exams (code, slug, name_en, name_kn)
values ('NEET_UG', 'neet', 'NEET-UG', 'ನೀಟ್-ಯುಜಿ')
on conflict (code) do update set
  slug = excluded.slug,
  name_en = excluded.name_en,
  name_kn = case when exams.name_kn_reviewed then exams.name_kn else excluded.name_kn end;

insert into public.subjects (exam_id, code, slug, name_en, name_kn, sort_order)
select e.id, v.code, v.slug, v.name_en, v.name_kn, v.sort_order
from public.exams e
cross join (values
  ('PHY', 'physics',   'Physics',   'ಭೌತಶಾಸ್ತ್ರ',     1),
  ('CHE', 'chemistry', 'Chemistry', 'ರಸಾಯನಶಾಸ್ತ್ರ',   2),
  ('BOT', 'botany',    'Botany',    'ಸಸ್ಯಶಾಸ್ತ್ರ',     3),
  ('ZOO', 'zoology',   'Zoology',   'ಪ್ರಾಣಿಶಾಸ್ತ್ರ',    4)
) as v (code, slug, name_en, name_kn, sort_order)
where e.code = 'NEET_UG'
on conflict (exam_id, code) do update set
  slug = excluded.slug,
  name_en = excluded.name_en,
  name_kn = case when subjects.name_kn_reviewed then subjects.name_kn else excluded.name_kn end,
  sort_order = excluded.sort_order;

insert into public.chapters
  (subject_id, slug, name_en, name_kn, class_level, ncert_ref, is_removed, sort_order)
select s.id, v.slug, v.name_en, v.name_kn, v.class_level, v.ncert_ref, v.is_removed, v.sort_order
from (values
  -- Physics, Class 11
  ('PHY', 'units-and-measurements', 'Units and Measurements', 'ಏಕಮಾನಗಳು ಮತ್ತು ಅಳತೆಗಳು', 11, 'XI Physics Ch 1', false, 101),
  ('PHY', 'motion-in-a-straight-line', 'Motion in a Straight Line', 'ಸರಳ ರೇಖೆಯಲ್ಲಿ ಚಲನೆ', 11, 'XI Physics Ch 2', false, 102),
  ('PHY', 'motion-in-a-plane', 'Motion in a Plane', 'ಸಮತಲದಲ್ಲಿ ಚಲನೆ', 11, 'XI Physics Ch 3', false, 103),
  ('PHY', 'laws-of-motion', 'Laws of Motion', 'ಚಲನೆಯ ನಿಯಮಗಳು', 11, 'XI Physics Ch 4', false, 104),
  ('PHY', 'work-energy-and-power', 'Work, Energy and Power', 'ಕೆಲಸ, ಶಕ್ತಿ ಮತ್ತು ಸಾಮರ್ಥ್ಯ', 11, 'XI Physics Ch 5', false, 105),
  ('PHY', 'system-of-particles-and-rotational-motion', 'System of Particles and Rotational Motion', 'ಕಣಗಳ ವ್ಯವಸ್ಥೆ ಮತ್ತು ಆವರ್ತನ ಚಲನೆ', 11, 'XI Physics Ch 6', false, 106),
  ('PHY', 'gravitation', 'Gravitation', 'ಗುರುತ್ವಾಕರ್ಷಣೆ', 11, 'XI Physics Ch 7', false, 107),
  ('PHY', 'mechanical-properties-of-solids', 'Mechanical Properties of Solids', 'ಘನವಸ್ತುಗಳ ಯಾಂತ್ರಿಕ ಗುಣಗಳು', 11, 'XI Physics Ch 8', false, 108),
  ('PHY', 'mechanical-properties-of-fluids', 'Mechanical Properties of Fluids', 'ದ್ರವಗಳ ಯಾಂತ್ರಿಕ ಗುಣಗಳು', 11, 'XI Physics Ch 9', false, 109),
  ('PHY', 'thermal-properties-of-matter', 'Thermal Properties of Matter', 'ದ್ರವ್ಯದ ಉಷ್ಣೀಯ ಗುಣಗಳು', 11, 'XI Physics Ch 10', false, 110),
  ('PHY', 'thermodynamics', 'Thermodynamics', 'ಉಷ್ಣಗತಿಶಾಸ್ತ್ರ', 11, 'XI Physics Ch 11', false, 111),
  ('PHY', 'kinetic-theory', 'Kinetic Theory', 'ಚಲನ ಸಿದ್ಧಾಂತ', 11, 'XI Physics Ch 12', false, 112),
  ('PHY', 'oscillations', 'Oscillations', 'ಆಂದೋಲನಗಳು', 11, 'XI Physics Ch 13', false, 113),
  ('PHY', 'waves', 'Waves', 'ತರಂಗಗಳು', 11, 'XI Physics Ch 14', false, 114),
  ('PHY', 'physical-world', 'Physical World', 'ಭೌತಿಕ ಜಗತ್ತು', 11, 'XI Physics Ch 1 (pre-2023)', true, 190),
  -- Physics, Class 12
  ('PHY', 'electric-charges-and-fields', 'Electric Charges and Fields', 'ವಿದ್ಯುದಾವೇಶಗಳು ಮತ್ತು ಕ್ಷೇತ್ರಗಳು', 12, 'XII Physics Ch 1', false, 201),
  ('PHY', 'electrostatic-potential-and-capacitance', 'Electrostatic Potential and Capacitance', 'ಸ್ಥಿರವಿದ್ಯುತ್ ವಿಭವ ಮತ್ತು ಧಾರಕತೆ', 12, 'XII Physics Ch 2', false, 202),
  ('PHY', 'current-electricity', 'Current Electricity', 'ವಿದ್ಯುತ್ ಪ್ರವಾಹ', 12, 'XII Physics Ch 3', false, 203),
  ('PHY', 'moving-charges-and-magnetism', 'Moving Charges and Magnetism', 'ಚಲಿಸುವ ಆವೇಶಗಳು ಮತ್ತು ಕಾಂತೀಯತೆ', 12, 'XII Physics Ch 4', false, 204),
  ('PHY', 'magnetism-and-matter', 'Magnetism and Matter', 'ಕಾಂತೀಯತೆ ಮತ್ತು ದ್ರವ್ಯ', 12, 'XII Physics Ch 5', false, 205),
  ('PHY', 'electromagnetic-induction', 'Electromagnetic Induction', 'ವಿದ್ಯುತ್ಕಾಂತೀಯ ಪ್ರೇರಣೆ', 12, 'XII Physics Ch 6', false, 206),
  ('PHY', 'alternating-current', 'Alternating Current', 'ಪರ್ಯಾಯ ವಿದ್ಯುತ್ ಪ್ರವಾಹ', 12, 'XII Physics Ch 7', false, 207),
  ('PHY', 'electromagnetic-waves', 'Electromagnetic Waves', 'ವಿದ್ಯುತ್ಕಾಂತೀಯ ತರಂಗಗಳು', 12, 'XII Physics Ch 8', false, 208),
  ('PHY', 'ray-optics-and-optical-instruments', 'Ray Optics and Optical Instruments', 'ಕಿರಣ ದೃಗ್ವಿಜ್ಞಾನ ಮತ್ತು ದೃಕ್ ಉಪಕರಣಗಳು', 12, 'XII Physics Ch 9', false, 209),
  ('PHY', 'wave-optics', 'Wave Optics', 'ತರಂಗ ದೃಗ್ವಿಜ್ಞಾನ', 12, 'XII Physics Ch 10', false, 210),
  ('PHY', 'dual-nature-of-radiation-and-matter', 'Dual Nature of Radiation and Matter', 'ವಿಕಿರಣ ಮತ್ತು ದ್ರವ್ಯದ ದ್ವಿಸ್ವಭಾವ', 12, 'XII Physics Ch 11', false, 211),
  ('PHY', 'atoms', 'Atoms', 'ಪರಮಾಣುಗಳು', 12, 'XII Physics Ch 12', false, 212),
  ('PHY', 'nuclei', 'Nuclei', 'ನ್ಯೂಕ್ಲಿಯಸ್‌ಗಳು', 12, 'XII Physics Ch 13', false, 213),
  ('PHY', 'semiconductor-electronics', 'Semiconductor Electronics: Materials, Devices and Simple Circuits', 'ಅರೆವಾಹಕ ಎಲೆಕ್ಟ್ರಾನಿಕ್ಸ್: ವಸ್ತುಗಳು, ಸಾಧನಗಳು ಮತ್ತು ಸರಳ ಮಂಡಲಗಳು', 12, 'XII Physics Ch 14', false, 214),
  ('PHY', 'communication-systems', 'Communication Systems', 'ಸಂವಹನ ವ್ಯವಸ್ಥೆಗಳು', 12, 'XII Physics Ch 15 (pre-2023)', true, 290),
  ('PHY', 'experimental-skills', 'Experimental Skills', 'ಪ್ರಾಯೋಗಿಕ ಕೌಶಲಗಳು', null, null, false, 300),

  -- Chemistry, Class 11
  ('CHE', 'some-basic-concepts-of-chemistry', 'Some Basic Concepts of Chemistry', 'ರಸಾಯನಶಾಸ್ತ್ರದ ಕೆಲವು ಮೂಲ ಪರಿಕಲ್ಪನೆಗಳು', 11, 'XI Chemistry Ch 1', false, 101),
  ('CHE', 'structure-of-atom', 'Structure of Atom', 'ಪರಮಾಣುವಿನ ರಚನೆ', 11, 'XI Chemistry Ch 2', false, 102),
  ('CHE', 'classification-of-elements-and-periodicity', 'Classification of Elements and Periodicity in Properties', 'ಧಾತುಗಳ ವರ್ಗೀಕರಣ ಮತ್ತು ಗುಣಗಳಲ್ಲಿ ಆವರ್ತಿತತೆ', 11, 'XI Chemistry Ch 3', false, 103),
  ('CHE', 'chemical-bonding-and-molecular-structure', 'Chemical Bonding and Molecular Structure', 'ರಾಸಾಯನಿಕ ಬಂಧ ಮತ್ತು ಅಣು ರಚನೆ', 11, 'XI Chemistry Ch 4', false, 104),
  ('CHE', 'thermodynamics', 'Thermodynamics', 'ಉಷ್ಣಗತಿಶಾಸ್ತ್ರ', 11, 'XI Chemistry Ch 5', false, 105),
  ('CHE', 'equilibrium', 'Equilibrium', 'ಸಮತೋಲನ', 11, 'XI Chemistry Ch 6', false, 106),
  ('CHE', 'redox-reactions', 'Redox Reactions', 'ರೆಡಾಕ್ಸ್ ಕ್ರಿಯೆಗಳು', 11, 'XI Chemistry Ch 7', false, 107),
  ('CHE', 'organic-chemistry-basic-principles-and-techniques', 'Organic Chemistry: Some Basic Principles and Techniques', 'ಸಾವಯವ ರಸಾಯನಶಾಸ್ತ್ರ: ಕೆಲವು ಮೂಲ ತತ್ವಗಳು ಮತ್ತು ತಂತ್ರಗಳು', 11, 'XI Chemistry Ch 8', false, 108),
  ('CHE', 'hydrocarbons', 'Hydrocarbons', 'ಹೈಡ್ರೋಕಾರ್ಬನ್‌ಗಳು', 11, 'XI Chemistry Ch 9', false, 109),
  ('CHE', 'p-block-elements-groups-13-14', 'The p-Block Elements (Groups 13 and 14)', 'p-ಬ್ಲಾಕ್ ಧಾತುಗಳು (ಗುಂಪು 13 ಮತ್ತು 14)', 11, 'XI Chemistry Ch 11 (pre-2023)', false, 110),
  ('CHE', 'states-of-matter', 'States of Matter', 'ದ್ರವ್ಯದ ಸ್ಥಿತಿಗಳು', 11, 'XI Chemistry Ch 5 (pre-2023)', true, 190),
  ('CHE', 'hydrogen', 'Hydrogen', 'ಹೈಡ್ರೋಜನ್', 11, 'XI Chemistry Ch 9 (pre-2023)', true, 191),
  ('CHE', 's-block-elements', 'The s-Block Elements', 's-ಬ್ಲಾಕ್ ಧಾತುಗಳು', 11, 'XI Chemistry Ch 10 (pre-2023)', true, 192),
  ('CHE', 'environmental-chemistry', 'Environmental Chemistry', 'ಪರಿಸರ ರಸಾಯನಶಾಸ್ತ್ರ', 11, 'XI Chemistry Ch 14 (pre-2023)', true, 193),
  -- Chemistry, Class 12
  ('CHE', 'solutions', 'Solutions', 'ದ್ರಾವಣಗಳು', 12, 'XII Chemistry Ch 1', false, 201),
  ('CHE', 'electrochemistry', 'Electrochemistry', 'ವಿದ್ಯುದ್ರಸಾಯನಶಾಸ್ತ್ರ', 12, 'XII Chemistry Ch 2', false, 202),
  ('CHE', 'chemical-kinetics', 'Chemical Kinetics', 'ರಾಸಾಯನಿಕ ಚಲನಶಾಸ್ತ್ರ', 12, 'XII Chemistry Ch 3', false, 203),
  ('CHE', 'd-and-f-block-elements', 'The d- and f-Block Elements', 'd- ಮತ್ತು f-ಬ್ಲಾಕ್ ಧಾತುಗಳು', 12, 'XII Chemistry Ch 4', false, 204),
  ('CHE', 'coordination-compounds', 'Coordination Compounds', 'ಸಮನ್ವಯ ಸಂಯುಕ್ತಗಳು', 12, 'XII Chemistry Ch 5', false, 205),
  ('CHE', 'haloalkanes-and-haloarenes', 'Haloalkanes and Haloarenes', 'ಹ್ಯಾಲೋಆಲ್ಕೇನ್‌ಗಳು ಮತ್ತು ಹ್ಯಾಲೋಅರೀನ್‌ಗಳು', 12, 'XII Chemistry Ch 6', false, 206),
  ('CHE', 'alcohols-phenols-and-ethers', 'Alcohols, Phenols and Ethers', 'ಆಲ್ಕೋಹಾಲ್‌ಗಳು, ಫೀನಾಲ್‌ಗಳು ಮತ್ತು ಈಥರ್‌ಗಳು', 12, 'XII Chemistry Ch 7', false, 207),
  ('CHE', 'aldehydes-ketones-and-carboxylic-acids', 'Aldehydes, Ketones and Carboxylic Acids', 'ಆಲ್ಡಿಹೈಡ್‌ಗಳು, ಕೀಟೋನ್‌ಗಳು ಮತ್ತು ಕಾರ್ಬಾಕ್ಸಿಲಿಕ್ ಆಮ್ಲಗಳು', 12, 'XII Chemistry Ch 8', false, 208),
  ('CHE', 'amines', 'Amines', 'ಅಮೈನ್‌ಗಳು', 12, 'XII Chemistry Ch 9', false, 209),
  ('CHE', 'biomolecules', 'Biomolecules', 'ಜೈವಿಕ ಅಣುಗಳು', 12, 'XII Chemistry Ch 10', false, 210),
  ('CHE', 'p-block-elements-groups-15-18', 'The p-Block Elements (Groups 15 to 18)', 'p-ಬ್ಲಾಕ್ ಧಾತುಗಳು (ಗುಂಪು 15 ರಿಂದ 18)', 12, 'XII Chemistry Ch 7 (pre-2023)', false, 211),
  ('CHE', 'solid-state', 'The Solid State', 'ಘನ ಸ್ಥಿತಿ', 12, 'XII Chemistry Ch 1 (pre-2023)', true, 290),
  ('CHE', 'surface-chemistry', 'Surface Chemistry', 'ಮೇಲ್ಮೈ ರಸಾಯನಶಾಸ್ತ್ರ', 12, 'XII Chemistry Ch 5 (pre-2023)', true, 291),
  ('CHE', 'isolation-of-elements', 'General Principles and Processes of Isolation of Elements', 'ಧಾತುಗಳನ್ನು ಬೇರ್ಪಡಿಸುವ ಸಾಮಾನ್ಯ ತತ್ವಗಳು ಮತ್ತು ಪ್ರಕ್ರಿಯೆಗಳು', 12, 'XII Chemistry Ch 6 (pre-2023)', true, 292),
  ('CHE', 'polymers', 'Polymers', 'ಪಾಲಿಮರ್‌ಗಳು', 12, 'XII Chemistry Ch 15 (pre-2023)', true, 293),
  ('CHE', 'chemistry-in-everyday-life', 'Chemistry in Everyday Life', 'ದೈನಂದಿನ ಜೀವನದಲ್ಲಿ ರಸಾಯನಶಾಸ್ತ್ರ', 12, 'XII Chemistry Ch 16 (pre-2023)', true, 294),
  ('CHE', 'practical-chemistry', 'Principles Related to Practical Chemistry', 'ಪ್ರಾಯೋಗಿಕ ರಸಾಯನಶಾಸ್ತ್ರಕ್ಕೆ ಸಂಬಂಧಿಸಿದ ತತ್ವಗಳು', null, null, false, 300),

  -- Botany, Class 11
  ('BOT', 'the-living-world', 'The Living World', 'ಜೀವ ಜಗತ್ತು', 11, 'XI Biology Ch 1', false, 101),
  ('BOT', 'biological-classification', 'Biological Classification', 'ಜೈವಿಕ ವರ್ಗೀಕರಣ', 11, 'XI Biology Ch 2', false, 102),
  ('BOT', 'plant-kingdom', 'Plant Kingdom', 'ಸಸ್ಯ ಸಾಮ್ರಾಜ್ಯ', 11, 'XI Biology Ch 3', false, 103),
  ('BOT', 'morphology-of-flowering-plants', 'Morphology of Flowering Plants', 'ಹೂಬಿಡುವ ಸಸ್ಯಗಳ ರೂಪವಿಜ್ಞಾನ', 11, 'XI Biology Ch 5', false, 104),
  ('BOT', 'anatomy-of-flowering-plants', 'Anatomy of Flowering Plants', 'ಹೂಬಿಡುವ ಸಸ್ಯಗಳ ಅಂಗರಚನಾಶಾಸ್ತ್ರ', 11, 'XI Biology Ch 6', false, 105),
  ('BOT', 'cell-the-unit-of-life', 'Cell: The Unit of Life', 'ಜೀವಕೋಶ: ಜೀವದ ಘಟಕ', 11, 'XI Biology Ch 8', false, 106),
  ('BOT', 'cell-cycle-and-cell-division', 'Cell Cycle and Cell Division', 'ಜೀವಕೋಶ ಚಕ್ರ ಮತ್ತು ಜೀವಕೋಶ ವಿಭಜನೆ', 11, 'XI Biology Ch 10', false, 107),
  ('BOT', 'photosynthesis-in-higher-plants', 'Photosynthesis in Higher Plants', 'ಉನ್ನತ ಸಸ್ಯಗಳಲ್ಲಿ ದ್ಯುತಿಸಂಶ್ಲೇಷಣೆ', 11, 'XI Biology Ch 11', false, 108),
  ('BOT', 'respiration-in-plants', 'Respiration in Plants', 'ಸಸ್ಯಗಳಲ್ಲಿ ಉಸಿರಾಟ', 11, 'XI Biology Ch 12', false, 109),
  ('BOT', 'plant-growth-and-development', 'Plant Growth and Development', 'ಸಸ್ಯ ಬೆಳವಣಿಗೆ ಮತ್ತು ಅಭಿವೃದ್ಧಿ', 11, 'XI Biology Ch 13', false, 110),
  ('BOT', 'transport-in-plants', 'Transport in Plants', 'ಸಸ್ಯಗಳಲ್ಲಿ ಸಾಗಣೆ', 11, 'XI Biology Ch 11 (pre-2023)', true, 190),
  ('BOT', 'mineral-nutrition', 'Mineral Nutrition', 'ಖನಿಜ ಪೋಷಣೆ', 11, 'XI Biology Ch 12 (pre-2023)', true, 191),
  -- Botany, Class 12
  ('BOT', 'sexual-reproduction-in-flowering-plants', 'Sexual Reproduction in Flowering Plants', 'ಹೂಬಿಡುವ ಸಸ್ಯಗಳಲ್ಲಿ ಲೈಂಗಿಕ ಸಂತಾನೋತ್ಪತ್ತಿ', 12, 'XII Biology Ch 1', false, 201),
  ('BOT', 'principles-of-inheritance-and-variation', 'Principles of Inheritance and Variation', 'ಅನುವಂಶೀಯತೆ ಮತ್ತು ವ್ಯತ್ಯಯದ ತತ್ವಗಳು', 12, 'XII Biology Ch 4', false, 202),
  ('BOT', 'molecular-basis-of-inheritance', 'Molecular Basis of Inheritance', 'ಅನುವಂಶೀಯತೆಯ ಆಣ್ವಿಕ ಆಧಾರ', 12, 'XII Biology Ch 5', false, 203),
  ('BOT', 'microbes-in-human-welfare', 'Microbes in Human Welfare', 'ಮಾನವ ಕಲ್ಯಾಣದಲ್ಲಿ ಸೂಕ್ಷ್ಮಜೀವಿಗಳು', 12, 'XII Biology Ch 8', false, 204),
  ('BOT', 'organisms-and-populations', 'Organisms and Populations', 'ಜೀವಿಗಳು ಮತ್ತು ಸಮಷ್ಟಿಗಳು', 12, 'XII Biology Ch 11', false, 205),
  ('BOT', 'ecosystem', 'Ecosystem', 'ಪರಿಸರ ವ್ಯವಸ್ಥೆ', 12, 'XII Biology Ch 12', false, 206),
  ('BOT', 'biodiversity-and-conservation', 'Biodiversity and Conservation', 'ಜೀವವೈವಿಧ್ಯ ಮತ್ತು ಸಂರಕ್ಷಣೆ', 12, 'XII Biology Ch 13', false, 207),
  ('BOT', 'reproduction-in-organisms', 'Reproduction in Organisms', 'ಜೀವಿಗಳಲ್ಲಿ ಸಂತಾನೋತ್ಪತ್ತಿ', 12, 'XII Biology Ch 1 (pre-2023)', true, 290),
  ('BOT', 'strategies-for-enhancement-in-food-production', 'Strategies for Enhancement in Food Production', 'ಆಹಾರ ಉತ್ಪಾದನೆ ಹೆಚ್ಚಿಸುವ ಕಾರ್ಯತಂತ್ರಗಳು', 12, 'XII Biology Ch 9 (pre-2023)', true, 291),
  ('BOT', 'environmental-issues', 'Environmental Issues', 'ಪರಿಸರ ಸಮಸ್ಯೆಗಳು', 12, 'XII Biology Ch 16 (pre-2023)', true, 292),

  -- Zoology, Class 11
  ('ZOO', 'animal-kingdom', 'Animal Kingdom', 'ಪ್ರಾಣಿ ಸಾಮ್ರಾಜ್ಯ', 11, 'XI Biology Ch 4', false, 101),
  ('ZOO', 'structural-organisation-in-animals', 'Structural Organisation in Animals', 'ಪ್ರಾಣಿಗಳಲ್ಲಿ ರಚನಾತ್ಮಕ ಸಂಘಟನೆ', 11, 'XI Biology Ch 7', false, 102),
  ('ZOO', 'biomolecules', 'Biomolecules', 'ಜೈವಿಕ ಅಣುಗಳು', 11, 'XI Biology Ch 9', false, 103),
  ('ZOO', 'breathing-and-exchange-of-gases', 'Breathing and Exchange of Gases', 'ಉಸಿರಾಟ ಮತ್ತು ಅನಿಲಗಳ ವಿನಿಮಯ', 11, 'XI Biology Ch 14', false, 104),
  ('ZOO', 'body-fluids-and-circulation', 'Body Fluids and Circulation', 'ದೇಹದ ದ್ರವಗಳು ಮತ್ತು ಪರಿಚಲನೆ', 11, 'XI Biology Ch 15', false, 105),
  ('ZOO', 'excretory-products-and-their-elimination', 'Excretory Products and their Elimination', 'ವಿಸರ್ಜನಾ ಉತ್ಪನ್ನಗಳು ಮತ್ತು ಅವುಗಳ ನಿವಾರಣೆ', 11, 'XI Biology Ch 16', false, 106),
  ('ZOO', 'locomotion-and-movement', 'Locomotion and Movement', 'ಚಲನವಲನ ಮತ್ತು ಚಲನೆ', 11, 'XI Biology Ch 17', false, 107),
  ('ZOO', 'neural-control-and-coordination', 'Neural Control and Coordination', 'ನರ ನಿಯಂತ್ರಣ ಮತ್ತು ಸಮನ್ವಯ', 11, 'XI Biology Ch 18', false, 108),
  ('ZOO', 'chemical-coordination-and-integration', 'Chemical Coordination and Integration', 'ರಾಸಾಯನಿಕ ಸಮನ್ವಯ ಮತ್ತು ಏಕೀಕರಣ', 11, 'XI Biology Ch 19', false, 109),
  ('ZOO', 'digestion-and-absorption', 'Digestion and Absorption', 'ಜೀರ್ಣಕ್ರಿಯೆ ಮತ್ತು ಹೀರಿಕೆ', 11, 'XI Biology Ch 16 (pre-2023)', true, 190),
  -- Zoology, Class 12
  ('ZOO', 'human-reproduction', 'Human Reproduction', 'ಮಾನವ ಸಂತಾನೋತ್ಪತ್ತಿ', 12, 'XII Biology Ch 2', false, 201),
  ('ZOO', 'reproductive-health', 'Reproductive Health', 'ಸಂತಾನೋತ್ಪತ್ತಿ ಆರೋಗ್ಯ', 12, 'XII Biology Ch 3', false, 202),
  ('ZOO', 'evolution', 'Evolution', 'ವಿಕಾಸ', 12, 'XII Biology Ch 6', false, 203),
  ('ZOO', 'human-health-and-disease', 'Human Health and Disease', 'ಮಾನವ ಆರೋಗ್ಯ ಮತ್ತು ರೋಗ', 12, 'XII Biology Ch 7', false, 204),
  ('ZOO', 'biotechnology-principles-and-processes', 'Biotechnology: Principles and Processes', 'ಜೈವಿಕ ತಂತ್ರಜ್ಞಾನ: ತತ್ವಗಳು ಮತ್ತು ಪ್ರಕ್ರಿಯೆಗಳು', 12, 'XII Biology Ch 9', false, 205),
  ('ZOO', 'biotechnology-and-its-applications', 'Biotechnology and its Applications', 'ಜೈವಿಕ ತಂತ್ರಜ್ಞಾನ ಮತ್ತು ಅದರ ಅನ್ವಯಗಳು', 12, 'XII Biology Ch 10', false, 206)
) as v (subject_code, slug, name_en, name_kn, class_level, ncert_ref, is_removed, sort_order)
join public.subjects s on s.code = v.subject_code
join public.exams e on e.id = s.exam_id and e.code = 'NEET_UG'
on conflict (subject_id, slug) do update set
  name_en = excluded.name_en,
  name_kn = case when chapters.name_kn_reviewed then chapters.name_kn else excluded.name_kn end,
  class_level = excluded.class_level,
  ncert_ref = excluded.ncert_ref,
  is_removed = excluded.is_removed,
  sort_order = excluded.sort_order;
