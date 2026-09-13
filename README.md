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
