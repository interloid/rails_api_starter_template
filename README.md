# Rails 8 API-only Starter Template

A production-ready foundation for JSON APIs: token auth with refresh rotation, RBAC,
structured logging, health probes, background jobs, an 80%-gated test suite, and CI —
wired together and ready to build on. **Stack:** Rails 8.1, Ruby 4.0.2, PostgreSQL. No
Redis (Solid Queue/Cache are Postgres-backed).

## What's included

| Capability | Implementation |
|---|---|
| Code quality | RuboCop (omakase + rspec/perf), Lefthook git hooks, Bullet (N+1 raises), Brakeman, bundler-audit |
| Config | `anyway_config` (typed, boot-time validated) + Rails encrypted credentials |
| Logging | `lograge` structured JSON to stdout, per-request correlation IDs (`X-Correlation-ID`) |
| Observability | New Relic (inert unless `NEW_RELIC_LICENSE_KEY` is set) |
| Health | `/up` liveness, `/health/ready` readiness, `/health` diagnostics |
| Security | `secure_headers`, `rack-cors`, per-IP rate limiting, Host-header authorization |
| API standards | URL versioning (`/api/v1`), consistent response envelope, global exception handling, `pagy`, OpenAPI |
| Database | UUID primary keys, soft delete (`discard`), RBAC schema (roles/permissions) |
| Authentication | JWT access tokens + opaque refresh tokens with rotation & reuse detection; lockable, trackable, confirmable, recoverable |
| Authorization | Pundit policies over a permissions table |
| Performance | Solid Queue + Solid Cache (Postgres), recurring jobs |
| Resilience | Graceful shutdown (request + job draining, readiness drain sentinel) |
| File upload | Active Storage + S3 (proxied upload + presigned direct upload) |
| Mail | SMTP (inert unless credentials present) |
| Testing | RSpec, FactoryBot, SimpleCov with an enforced 80% coverage gate |
| Delivery | Portable Docker image, GitHub Actions CI (lint, security, test, docker build) |

## Quick start

```bash
git clone <your-fork-url> rails_api_starter_template
cd rails_api_starter_template

bin/setup                        # installs gems AND git hooks (lefthook)

# Add app secrets. jwt.secret is required — generate a value with `bin/rails secret`
# and add it under a `jwt:` key:
bin/rails credentials:edit

bin/rails db:create db:migrate db:seed
bin/rails server
```

The credentials file must contain at least:

```yaml
jwt:
  secret: <paste output of `bin/rails secret`>
```

Then authenticate with the seeded admin and call a protected endpoint:

```bash
# 1. Log in — returns access_token + refresh_token
TOKEN=$(curl -s -X POST localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"Password123!"}' \
  | ruby -rjson -e 'puts JSON.parse(STDIN.read).dig("data","access_token")')

# 2. Use the token
curl -s localhost:3000/api/v1/users -H "Authorization: Bearer $TOKEN"
```

**Seeded accounts (DEVELOPMENT ONLY):** `admin@example.com` and `member@example.com`,
password `Password123!`. They are created only in development and never exist in production.

## API conventions

All responses use one envelope. Keys are **snake_case**. Success responses have **no
`errors` key**; error responses have **no `data` key**.

**Success** (`GET /api/v1/users`):

```json
{
  "success": true,
  "status_code": 200,
  "message": "Users retrieved successfully",
  "data": [ { "id": "…", "email": "…", "roles": ["member"], "confirmed": false, "avatar_url": null } ],
  "pagination_meta": { "total": 4, "page": 1, "records_per_page": 20, "total_pages": 1 },
  "timestamp": "2026-07-19T09:13:15Z",
  "path": "/api/v1/users"
}
```

**Error** (`POST /api/v1/auth/login` with a bad password):

```json
{
  "success": false,
  "status_code": 401,
  "error_code": "invalid_credentials",
  "message": "Invalid email or password",
  "errors": [],
  "timestamp": "2026-07-19T09:13:15Z",
  "path": "/api/v1/auth/login"
}
```

`error_code` values:

| | | | |
|---|---|---|---|
| `validation_failed` | `not_found` | `unauthorized` | `forbidden` |
| `rate_limited` | `account_locked` | `invalid_credentials` | `token_reuse_detected` |
| `malformed_json` | `parameter_missing` | `authorization_missing` | `invalid_token` |
| `invalid_refresh_token` | `email_unconfirmed` | `no_file` | `internal_server_error` |

## Authentication

Register → log in → receive an **access token** (JWT, 15 min) and a **refresh token**
(opaque, 7 days, stored only as a SHA-256 digest). Refreshing **rotates** the pair and
revokes the old refresh token. Replaying an already-revoked refresh token is treated as
theft: the entire token **family is revoked** and the user must log in again.

Send the access token as: `Authorization: Bearer <access_token>`

| Method & path | Purpose |
|---|---|
| `POST /api/v1/auth/register` | Create an account (auto-assigned the default role) |
| `POST /api/v1/auth/login` | Get an access + refresh token pair |
| `POST /api/v1/auth/refresh` | Rotate the pair using a valid refresh token |
| `POST /api/v1/auth/logout` | Revoke tokens (optional `refresh_token` body ⇒ this device only) |
| `GET /api/v1/auth/me` | Current user |
| `POST /api/v1/account/forgot_password` | Request a reset email |
| `POST /api/v1/account/reset_password` | Reset with a token (revokes all sessions) |
| `POST /api/v1/account/confirm_email` | Confirm an email with a token |
| `POST /api/v1/account/resend_confirmation` | Resend the confirmation email |

## Authorization (RBAC)

Two layers:

1. **Permissions table** — coarse capabilities named `resource:action` (e.g. `users:write`).
   Roles have permissions; users have roles. Adding a permission is a **data change**, not
   a schema change.
2. **Pundit policies** — record-level rules on top of the capability.

```ruby
class UserPolicy < ApplicationPolicy
  def update? = permission?("users:write") && (record.id == user.id || admin?)
  def destroy? = permission?("users:delete") && admin?
end
```

`BaseController` runs Pundit's `verify_authorized` / `verify_policy_scoped` guards, so a
forgotten `authorize` call **fails loudly** (`authorization_missing`, 403) instead of
silently returning data.

## Configuration

Three sources, each with a distinct job:

| Source | Holds | Examples |
|---|---|---|
| Rails encrypted credentials | App secrets (committed, encrypted) | `jwt.secret`, `smtp.*`, `aws.*` |
| ENV | Infra / per-deploy config | `DATABASE_URL`, `RAILS_MASTER_KEY`, `NEW_RELIC_LICENSE_KEY` |
| `anyway_config` | Typed validation | App **fails to boot** on missing/invalid values |

[`.env.example`](.env.example) is the documented list of environment variables. It is
**not auto-loaded** — `dotenv` reads `.env.development.local` in development/test only.

## Development

```bash
bin/rails server          # http://localhost:3000
bin/rails console
bundle exec rspec         # coverage report written to coverage/
bundle exec rubocop
```

- **Git hooks (Lefthook):** pre-commit runs RuboCop on staged files; pre-push runs
  Brakeman + bundler-audit.
- **Dev-only surfaces:** `/api-docs` (Swagger UI) and `/jobs` (Mission Control) —
  their gems are in the `:development` bundle group and are **not** in the production image.
- **Local New Relic testing:** put the key in `.env.development.local` (gitignored).

## Testing

RSpec + FactoryBot. SimpleCov enforces an **80% minimum** — it exits non-zero below the
threshold, which fails the CI test job (a passing suite with low coverage still fails).

rswag request specs do double duty: they **test the endpoints** and **generate the OpenAPI
document**, so the docs can't drift from behavior:

```bash
bundle exec rake rswag:specs:swaggerize   # regenerates swagger/v1/swagger.yaml
```

CI regenerates this file and **fails if the committed copy is stale**, so after changing
any rswag request spec, run `bundle exec rake rswag:specs:swaggerize` and commit the result.

Minitest is retained alongside RSpec (`bin/rails test`).

## Background jobs

Solid Queue (Postgres-backed — no Redis). Runs **in-Puma** by default
(`SOLID_QUEUE_IN_PUMA=true`); for higher volume, unset it and run `bin/jobs` as a separate
process. Recurring tasks live in `config/recurring.yml` (ships with a daily expired
refresh-token purge). Dashboard at `/jobs` in development.

## Deployment

See **[DEPLOYMENT.md](DEPLOYMENT.md)** for the full contract (credentials, env, shutdown
budget, Kubernetes probes). In short:

```bash
docker build --build-arg GIT_SHA=$(git rev-parse HEAD) -t app .
docker compose up -d --build    # local production-mode testing
```

Probe endpoints: `/up` (liveness), `/health/ready` (readiness), `/health` (diagnostics).

## Architecture decisions

| Decision | Rationale |
|---|---|
| No Redis | Solid Queue/Cache are Postgres-backed and the Rails 8 default — one less service. Swap to Sidekiq+Redis if volume demands it. |
| Native auth over Devise | Devise is session/cookie-oriented; a token API needs JWT + refresh rotation, which `has_secure_password` + `jwt` + `generates_token_for` handle cleanly. |
| Opaque refresh tokens (not JWTs) | Self-contained buys nothing here; DB-backed tokens are instantly revocable. |
| UUID primary keys | Non-enumerable IDs on a public API. (v4 is random and fragments index inserts at scale — switch the column default to `uuidv7()` on PostgreSQL 18+.) |
| Soft delete on users | Preserves audit history. |
| Credentials for secrets, ENV for infra | Credentials are committed (encrypted), so machine/deploy-specific values belong in ENV. |
| No CSRF | `ActionController::API` has none, and CSRF is a cookie-session attack — irrelevant to a stateless token API. |
| Observability / S3 / SMTP inert by default | The app runs with zero external dependencies until you configure them. |

## Gotchas

- **Credentials keys differ by environment.** Production decrypts
  `config/credentials/production.yml.enc` with `config/credentials/production.key`;
  test/dev/CI use `config/credentials.yml.enc` with `config/master.key`. Set
  `RAILS_MASTER_KEY` to the **right** key for the environment, and mirror shared secrets
  (especially `jwt.secret`) into **both** files.
- **Run `db:seed` on first deploy.** Roles/permissions seed in every environment (demo
  *users* only in development). Without it, `DEFAULT_USER_ROLE` won't exist and registered
  users get no role.
- **Bullet raises on N+1** in development and test. A raised Bullet error is a real bug —
  fix the eager-loading, don't disable Bullet.
- **Rate limiting is backed by `Rails.cache`** and no-ops under `:null_store` (test), so
  its spec is `pending`; it's verified working against Solid Cache.
- **`rubocop -A` has deleted rswag spec bodies** before (`RSpec/EmptyExampleGroup` doesn't
  recognize `run_test!`). Exclusions are in `.rubocop.yml` — check the request specs after
  running `-A`.
- **No Puma phased restarts** while Solid Queue runs in-Puma
  ([rails/solid_queue#563](https://github.com/rails/solid_queue/issues/563)).
- **Gmail SMTP is development-only** (~500/day, SPF/DKIM alignment). Use SES/Postmark/Resend
  in production and set `MAILER_FROM` to a domain you control.
- **Restart the server fully after editing `config/`.** Rails hot-reloads app code but not
  initializers or middleware.

## Project structure

Non-obvious directories:

```
app/serializers/            # response shaping (ApplicationSerializer.one/.many)
app/policies/               # Pundit authorization policies
app/services/               # plain service objects (e.g. JwtService)
app/controllers/concerns/   # Renderable, ExceptionHandler, Authenticatable, Paginatable
spec/requests/api/v1/       # rswag request specs — test endpoints AND emit OpenAPI
spec/requests/security/     # plain request specs for security behaviors (rotation, lockout, envelope)
swagger/                    # generated OpenAPI (swagger/v1/swagger.yaml) — do not hand-edit
```

## License

MIT — add a `LICENSE` file with your details before publishing.
