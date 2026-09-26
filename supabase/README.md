# supabase

Schema (migrations), seed data and database tests. Migrations are the source of
truth for the schema; never edit a remote schema by hand.

| Path | Contents |
|---|---|
| `migrations/` | SQL migrations, applied in filename order |
| `seed/` | Reference data (NEET syllabus). Idempotent; also pushed to remote projects |
| `tests/database/` | pgTAP tests: RLS per role, schema rules, seed checks |
| `config.toml` | Local stack settings (auth, test phone numbers, seed paths) |

## Local development

Needs Docker Desktop running.

```
supabase start          # start the local stack (prints URL and publishable key)
supabase db reset       # re-create the local DB from migrations + seed
supabase test db        # run the pgTAP tests
supabase db lint        # check the schema for common problems
supabase stop
```

Studio: http://127.0.0.1:54323

## Test phone numbers

No SMS is sent for these; the code is always `123456`.

| Phone | Use |
|---|---|
| +91 99999 00001 – 00005 | Local (`config.toml`) and `prepvruksha-dev` (dashboard) |

The local config enables Twilio with placeholder values because Supabase Auth
refuses phone sign-in without a provider. Real numbers fail with
`sms_send_failed` until the DLT-registered provider is set up.

On `prepvruksha-dev`, add the same numbers under
**Authentication > Sign In / Providers > Phone > Test phone numbers**; the
dashboard also needs an SMS provider enabled (placeholder values are fine for
test numbers).

### Test parent numbers (parental consent)

Parent consent codes are sent by `services/api`, not Supabase Auth. Numbers
listed in the API's `PARENT_OTP_TEST_CODES` get a fixed code and no SMS
(`.env.example` sets +91 99999 00006 and 00007 with `123456`). Codes for other
numbers are written to the API log in local/dev (`LogOtpSender`) until the
DLT-registered provider is set up.

## Remote project (`prepvruksha-dev`)

```
supabase login                                        # once, opens the browser
supabase link --project-ref hzpuxfgfheizghpipmew      # prompts for the DB password
supabase db push --include-seed                       # apply migrations + seed
supabase db query --linked "select ..."               # ad-hoc checks via the Management API
```

Never put the database password or the secret key in any file in this repo.

`supabase test db --linked` does not work with the CLI's temporary login role
(no access to the `extensions` schema where pgTAP is installed). Run the tests
locally, where the privileges now match the remote projects.

## First super admin

Staff roles can only be granted by a super admin, so the first one is inserted
by hand in the SQL editor (runs as `postgres`), after that person has signed in once:

```sql
insert into public.staff_roles (user_id, role)
select id, 'super_admin' from auth.users where phone = '91XXXXXXXXXX';
```

## Access rules in brief

- Nothing is granted by default, locally or on remote projects (migration
  `20260927000100`). Each migration that adds a table or view must grant
  exactly what `anon`, `authenticated` and `service_role` need, and add it to
  the matrix in `tests/database/03_privileges.test.sql`.

- `anon` / `authenticated` can never read `question_options.is_correct`. Answer
  correctness comes only from server-side code using the service role.
- Questions with `exam_reserved = true` are hidden from the public even when
  published. The SEO build reads only `public.seo_questions`.
- RLS helper functions live in the `private` schema, which the Data API does not expose.
- Signup functions (`public.get_signup_state`, `complete_profile`, `accept_terms`,
  `start_parental_consent`, `verify_parental_consent`, `withdraw_consent`,
  `correct_date_of_birth`) are executable only by `service_role`; `services/api`
  calls them after verifying the user's JWT. They raise `P0001` with a
  machine-readable message such as `dob_already_set`.
- `profiles.date_of_birth` is set once; re-setting it raises `dob_already_set`
  even for the service role, except through `correct_date_of_birth`.
