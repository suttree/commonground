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

Set `ADMIN_USERNAME` and `ADMIN_PASSWORD` in the server environment to enable `/admin`. If either is absent, admin access is disabled. Every admin route requires both HTTP Basic credentials and a signed-in account with `admin: true`. Accounts use the email-code login flow and default to non-admin. Admin flags must be granted or revoked through the Rails console; public forms cannot change them.

The admin area lists people and organisations, filters by type and status, and shows their full answers. Reviewers can update status and add private notes. All introductions and follow-up emails are handled manually. The app sends transactional login codes.

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

The SDG quiz at `/quiz` asks eight short scenario questions, one per screen, with back, skip and restart controls. Answer mappings in `config/data/quiz_questions.json` cover all 17 goals. The three targets connected to the most answers become suggestions, each with an explanation. Ties follow question order; skipped answers add no matches. Guest answers stay in the browser session. For logged-in users, completing the quiz saves all eight answers and up to three suggested targets to the active profile.

The full selector at `/quiz/explore` includes all 169 targets. Short editorial labels live in `config/data/quiz_labels.json`; expandable details retain the original target wording. `SdgQuiz::EXAMPLES` provides explicitly labelled demonstration answers for Nika's published profile without changing her submitted answers.

The reference directory at `/sustainable-development-goals` has goal pages at `/sustainable-development-goals/:id` and shareable target pages such as `/sustainable-development-goals/targets/12.6`. Search combines the target identifier, short label, source wording and goal name, supports a goal filter, and paginates at 18 results. `config/data/sdg_guides.json` supplies short goal introductions and colour accents. The directory retains the source wording and retrieval date, and distinguishes editorial labels from that source. Quiz suggestions and example profile answers link to target references; the main navigation links to the directory.

Quiz results offer three next steps for Nika: pitch a problem, suggest a Zoom coffee chat or request services. Each opens `/profiles/:slug/contact` with the intent selected. Requests require contact consent, accept optional quiz suggestions from the current session, and appear privately at `/admin/contact_requests`. They do not send email or book meetings automatically.


## Accounts and directories

Signup now leads to `/create-account`. `/login` sends a six-digit email code. Each account owns one personal or company profile, enforced by a unique database index. Verification claims the pending signup profile with the same normalized email, or the earliest unclaimed profile for an existing applicant. It never replaces an account’s existing profile. Signed-in owners who open another signup form go to their profile editor. The dashboard highlights the quiz beside the directories and links the profile name to its page, where owners can edit it. Owners can preview a private profile and its portfolio without publishing it.

Codes expire in ten minutes, allow five attempts, and work once. They are stored as keyed hashes. Database-backed request limits allow three codes per email and twenty per IP in ten minutes. Sessions rotate at login, expire after thirty days, and clear at logout. Profile editing is scoped to the signed-in account. Email addresses, ownership, review status and admin notes cannot be changed through profile editing.

`/people` and `/companies` list published profiles only, with combined name, location, sector and SDG goal filters and 24 results per page. Owners can publish or unpublish from the edit form. Company profiles now include location, sectors and SDG priorities. Published profiles show the SDG priorities suggested by the quiz, without displaying individual quiz answers. Quiz answers are saved to the account’s single profile.

### Email setup

Production uses SMTP. Set `SMTP_ADDRESS`, `SMTP_PORT` (defaults to 587), `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_DOMAIN`, and `MAIL_FROM` to a sender verified with your email provider. `APP_HOST` defaults to `commonground-pilot.fly.dev`. Keep credentials in deployment secrets. STARTTLS is enabled, and delivery errors display a retry message without granting access.

Development writes messages to `tmp/mail` without sending them. Tests use Action Mailer's test delivery. Restart the development server after changing mail settings. Live delivery must be checked with the configured provider before opening account signup to users.

Login-code rows retain request timestamps and IPs for throttling. Run `bin/rails accounts:prune_codes` regularly to remove rows older than one day.


### Amazon SES

The Fly configuration targets SES in London, `eu-west-2`, at `email-smtp.eu-west-2.amazonaws.com:587`. SMTP requires STARTTLS and verifies the server certificate. The sender identity and SMTP credentials must belong to the same SES region.

The sender is `Commonbound <noreply@commonbound.work>`, configured in `fly.toml`. Store `SMTP_USERNAME` and `SMTP_PASSWORD` as Fly secrets. Use SES SMTP credentials rather than the AWS console password or an unconverted AWS secret access key. Keep the SMTP user limited to sending email for the verified sender identity. Do not put credentials in `fly.toml` or Git.

Before enabling public signup, verify the sender identity, configure the domain's DKIM records when using a domain identity, and confirm SES production access in London. Sandbox accounts can send only to verified recipients or the SES mailbox simulator. Verify a real login-code delivery after configuring the secrets and deploying.

References: [SES SMTP credentials](https://docs.aws.amazon.com/ses/latest/dg/smtp-credentials.html), [SES endpoints](https://docs.aws.amazon.com/general/latest/gr/ses.html), and [production access](https://docs.aws.amazon.com/ses/latest/dg/request-production-access.html).

The dedicated SMTP user is `commonbound-smtp`. Its sending policy is in `config/aws/commonbound-ses-smtp-policy.json` and permits only `ses:SendRawEmail` for `duncan@suttree.com` and `noreply@commonbound.work` in London. The policy is applied in IAM, and its SMTP credentials are stored in Fly secrets. The policy file alone does not grant access.

On 12 October 2026, SES verified `commonbound.work` and reported DKIM successful after its three Easy DKIM CNAME records were saved in GoDaddy. The domain uses 2048-bit signing keys. Both login codes and collaborator invitations use the `MAIL_FROM` sender.

| Name (relative to commonbound.work) | Target |
| --- | --- |
| `exzcym3fmomusrchab4rpl4ji4ffrbsv._domainkey` | `exzcym3fmomusrchab4rpl4ji4ffrbsv.dkim.amazonses.com` |
| `fuebnd4lpvz6w5n6e5a5ez2dfjfcbxvc._domainkey` | `fuebnd4lpvz6w5n6e5a5ez2dfjfcbxvc.dkim.amazonses.com` |
| `ydjkvws4djgzx5ieuxk3ltxvgydhv67w._domainkey` | `ydjkvws4djgzx5ieuxk3ltxvgydhv67w.dkim.amazonses.com` |

The `suttree.com` domain identity uses Easy DKIM with 2048-bit signing keys. These CNAME records are configured in Joker's DNS settings:

| Name (relative to suttree.com) | Target |
| --- | --- |
| `xukofuryxhxs5eix27kulbjyrsvzgioy._domainkey` | `xukofuryxhxs5eix27kulbjyrsvzgioy.dkim.amazonses.com` |
| `7liqle2ifftqgsodhmmhyvuuvvi3qeqg._domainkey` | `7liqle2ifftqgsodhmmhyvuuvvi3qeqg.dkim.amazonses.com` |
| `n6r2u3hrib4mid5msinuumjecf74zvn6._domainkey` | `n6r2u3hrib4mid5msinuumjecf74zvn6.dkim.amazonses.com` |

As of 20 September 2026, the app is deployed, the sender and domain are verified, and all three DKIM records resolve publicly. A live login code was delivered to `duncan@suttree.com` and used successfully to reach the dashboard. SES remains in the London sandbox until AWS approves production access; other recipients must be verified while that restriction applies.

### Private profile provocations

Personal profile owners see one unanswered question at a time, with four answer choices and a skip link. Each `ProvocationAnswer` belongs to a `Submission` and a `Provocation`; the provocation's `goal_id` resolves through the existing SDG directory. Other visitors cannot see or submit answers. Skipping rotates through unanswered questions without recording a belief. Previous answers remain editable on the private Your answers page, with 10 answers per page. Editing an answer returns to the same page. Answers are ordered by when they were first submitted, newest first.

The migration adds three initial questions. `bin/rails db:seed` also installs them after a fresh schema load and can be rerun safely. Create a new versioned provocation record for changes to wording or goal; existing records reject those edits so answers keep their original meaning.
