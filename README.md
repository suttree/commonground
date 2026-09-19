# Common Ground

A small Rails pilot for introductions around what needs doing and why it matters. See [PLAN.md](PLAN.md) and [TECHNOLOGY.md](TECHNOLOGY.md).

## Run locally

Use Ruby 3.4.1 and Bundler.

```sh
bundle install
bin/rails db:prepare
bin/rails server
```

Open http://localhost:3000. The public site needs no account. It contains the landing page, person and organisation forms, a confirmation page and a privacy notice.

## Review applications

Set `ADMIN_USERNAME` and `ADMIN_PASSWORD` in the server environment to enable `/admin`. If either is absent, admin access is disabled. The browser asks for HTTP Basic credentials; there are no user accounts, registration or password-reset flows.

The admin area lists people and organisations, filters by type and status, and shows their full answers. Reviewers can update status and add private notes. All introductions and follow-up emails are handled manually. The app sends no email.

Production credentials are kept in Fly secrets. The initial deployment also has a local, ignored `.env.production` file with restrictive file permissions. Do not commit or share that file. It contains the admin credentials and Rails session secret.

## Deploy to Fly.io

The app is `commonground-pilot`, in the London region. `fly.toml` configures one shared CPU, 512 MB RAM and the `data` volume mounted at `/data`. SQLite uses `/data/production.sqlite3`.

The first deployment provisioned a 1 GB encrypted volume with scheduled snapshots and seven-day retention. Keep exactly one application machine: independent SQLite volumes do not replicate. Idle machines stop and start again on a request, so the first visit after idle time can take longer.

For subsequent deployments:

```sh
fly deploy --remote-only --ha=false
```

The container prepares the database on startup, where it can access the mounted volume. Do not move SQLite migrations into a Fly release command, which runs without that volume. The entrypoint fixes the volume directory's ownership and drops to the unprivileged Rails user before running migrations and the server.

Use `fly volumes list` and `fly volumes snapshots list VOLUME_ID` to inspect storage and snapshots. Before destructive data or schema changes, take and verify a backup. This pilot has one machine and one volume, so it is not highly available. A database restore drill has not yet been performed.

References: [Rails on Fly.io](https://fly.io/rails/) and [Fly volume storage](https://fly.io/docs/volumes/overview/).

## Checks

```sh
bin/rails test
bin/rails zeitwerk:check
bundle exec brakeman --no-pager
bin/rubocop
```

The integration suite covers both forms, validation, consent, session cookies and CSRF, honeypot filtering, admin authentication, filtering, review updates and unsafe input. Production has no JavaScript and a content security policy that disallows scripts.

JSON is pinned below version 3 because Rails 8.1.3.1's session decoder passes a positional options argument that JSON 3 rejects. The browser-session test covers this failure.

## Deployment verification

Verified on 13 September 2026 at https://commonground-pilot.fly.dev:

- Both public forms saved test applications and showed the confirmation page.
- Unauthenticated admin requests returned 401. Authenticated review and status updates worked.
- Requests without a CSRF token were rejected.
- Both applications and review notes survived a Fly machine restart.
- The two deployment test applications were removed afterward.
- Desktop and mobile layouts, visible keyboard focus, native required-field validation and accessibility labels were checked in the browser. No full screen-reader audit has been performed.
- All 12 integration tests passed, with 121 assertions. Brakeman reported no warnings.

## Structured profiles

New submissions use profile version 2. Personal profiles include SDG target choices, sectors, verified skills, education, and optional satisfaction and portfolio sections. Company profiles include purpose, beneficiaries, offerings, metrics, products, and challenges or goals. Repeated entries use server-rendered “add another” buttons; JavaScript is not required. Each group supports up to ten entries. Empty optional entries are discarded; started entries must be complete.

The 169 SDG targets are a local snapshot of the [Human Rights Guide to the SDGs](https://sdg.humanrights.dk/list-goals-targets), retrieved on 18 September 2026, in `config/data/sdg_targets.json`. Original target wording, dates and thresholds are retained. Sectors are a pilot-specific list in `ProfileOptions`, rather than an official classification.

The migration adds a JSON profile column and a version column. Existing applications retain their original answers and admin display. The public forms never accept review notes, status, kind or profile version from submitted parameters.

## Public profiles

Profiles are private by default. With the applicant's permission, an admin can enable "Publish profile" on their submission. The page is available at `/profiles/name-uniqueid` with a random 12-character suffix. Its URL stays the same after name changes or republication. Disabling publication makes the URL return 404.

The page shows profile answers and the website, but excludes contact email, pay expectations, consent records, review status and private notes. Public form submissions cannot set publication fields. Selected SDG targets retain their original wording inside expandable goal sections.

## Priorities and portfolio

People can choose up to three current SDG priorities or mark themselves as still exploring. Existing selections are preserved. Profiles with more than three targets omit that section publicly until the team narrows the selection in the admin review form. Saving unrelated review changes remains possible for older profiles.

New project entries require a title and role alongside problem, context, approach and results. Organisation, dates, project URL and image caption are optional. Older projects without titles or roles still render and remain reviewable.

Each project accepts one JPEG, PNG or WebP image, up to 2 MB, with at most ten projects per profile. The pilot stores image bytes in SQLite alongside the submission, so the existing mounted volume and database backups cover images too. Draft images use signed tokens restricted to the uploading browser session and expire after 24 hours. They survive validation errors and server-rendered add-another requests. Public image endpoints check that the associated profile is currently published; admin image endpoints require authentication. Unpublishing a profile also removes public access to its images.

Expired unattached drafts are removed on subsequent image uploads. To clean them up without a new upload, run `bin/rails portfolio:prune_drafts`. Image uploads are included in the form's request rate limit. No PDF export or questionnaire is included.

Skills on public profiles use horizontally scrollable preview cards with native scroll snapping and previous/next links. Each card links to `/profiles/:slug/skills/:position` for its full evidence. Detail pages follow the profile's publication status and return 404 for missing skills. A single skill has no carousel controls. No JavaScript or new profile fields are required.

Portfolio projects use the same carousel pattern, with image previews linking to `/profiles/:slug/projects/:position`. The case-study page contains the full image and caption, role, dates, problem, context, approach, results and external project link. These pages are available only while the parent profile is published.

The SDG quiz at `/quiz` asks eight short scenario questions, one per screen, with back, skip and restart controls. Answer mappings in `config/data/quiz_questions.json` cover all 17 goals. The three targets connected to the most answers become suggestions, each with an explanation. Ties follow question order; skipped answers add no matches. Answers stay in the browser session and are not attached to profiles.

The full selector at `/quiz/explore` includes all 169 targets. Short editorial labels live in `config/data/quiz_labels.json`; expandable details retain the original target wording. `SdgQuiz::EXAMPLES` provides explicitly labelled demonstration answers for Nika's published profile without changing her submitted answers.
