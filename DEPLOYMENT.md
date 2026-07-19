# Deployment

The production image is portable — it runs Puma directly and works on any container
platform (ECS, Kubernetes, Fly.io, Render, Cloud Run, plain Docker). This document is the
deploy contract: read the **Credentials** section first — it is the most common cause of a
failed first deploy.

---

## a) Credentials (read this first)

Rails uses **two different encrypted credential files with two different keys**:

| Environment | File | Decryption key |
|-------------|------|----------------|
| **Production** | `config/credentials/production.yml.enc` | `config/credentials/production.key` |
| Test / Development | `config/credentials.yml.enc` | `config/master.key` |

- In production, set **`RAILS_MASTER_KEY`** to the **contents of `config/credentials/production.key`** — *not* `config/master.key`. Using the wrong key produces `ActiveSupport::MessageEncryptor::InvalidMessage` (AEAD authentication tag verification failed) at boot.
- **Production credentials MUST contain:**
  - `secret_key_base`
  - `jwt.secret` (the JWT signing key — auth breaks without it)
- **Optional** (feature-gated — the app boots fine without them):
  - `smtp.user_name`, `smtp.password` (SMTP delivery; inert unless present)
  - `aws.access_key_id`, `aws.secret_access_key`, `aws.region`, `aws.bucket` (S3 file uploads; also resolvable from `AWS_*` env vars)
- **CI** runs specs in the **test** environment, so it decrypts `config/credentials.yml.enc` with `master.key`. Set the `RAILS_MASTER_KEY` GitHub Actions secret to the contents of `config/master.key`.

Edit production credentials with:
```bash
bin/rails credentials:edit --environment production
```

---

## b) Required production environment

**Required:**

| Variable | Purpose |
|----------|---------|
| `RAILS_MASTER_KEY` | Contents of `config/credentials/production.key` (see above) |
| `DATABASE_URL` | `postgres://user:pass@host:5432/dbname` |
| `SERVICE_NAME` | Log/APM service identifier (`rails_starter_template`) |
| `APP_HOST` | Public host used to build absolute URLs in emails |
| `ALLOWED_HOSTS` | Comma-separated Host allowlist (DNS-rebinding protection) |
| `CORS_ORIGINS` | Comma-separated allowed CORS origins |
| `SOLID_QUEUE_IN_PUMA` | `true` to run background jobs inside Puma |
| `ACTIVE_STORAGE_SERVICE` | Storage backend (`amazon` for S3) |

**Optional:**

`NEW_RELIC_LICENSE_KEY`, `SMTP_ADDRESS`, `SMTP_PORT`, `HEALTH_CHECK_TOKEN`,
`REQUIRE_EMAIL_CONFIRMATION`, `DEFAULT_USER_ROLE`, `FORCE_SSL`, `RUN_DB_PREPARE`,
`RATE_LIMIT_REQUESTS`, `RATE_LIMIT_WITHIN_SECONDS`, `SHUTDOWN_SENTINEL_PATH`.

See `.env.example` for descriptions and defaults.

---

## c) Build & run

```bash
docker build --build-arg GIT_SHA=$(git rev-parse HEAD) -t app .
docker run -d -p 3000:3000 -e RAILS_MASTER_KEY=<production.key contents> app
```

`GIT_SHA` populates the `commit` field in `/health`.

**Migrations are OPT-IN** via `RUN_DB_PREPARE=true`. Prefer running them as a **separate
release/deploy step** — multiple replicas each running `db:prepare` on boot will race.
Only set `RUN_DB_PREPARE=true` where a single container is responsible for migrations
(e.g. a Fly `release_command`, or a one-off migrate task).

---

## d) Health probes

| Endpoint | Use | Behavior |
|----------|-----|----------|
| `GET /up` | **Liveness** | Never checks dependencies — a DB blip must not trigger a restart. |
| `GET /health/ready` | **Readiness** | Checks DB connectivity + pending migrations. Returns `503` to pull the instance from the load balancer **without restarting it**. |
| `GET /health` | **Diagnostics** | The `info` block (commit, versions, uptime) is **token-gated in production** via the `X-Health-Token` header (`HEALTH_CHECK_TOKEN`). |

Both `/up` and `/health` are **excluded from the `force_ssl` redirect**, so plain-HTTP
internal probes (load balancers hitting the pod IP) work without a 301.

---

## e) Graceful shutdown budget

The timing values must satisfy:

```
terminationGracePeriodSeconds (60)
  >  preStop sleep (10)
   + Puma worker_shutdown_timeout (25)
   + Solid Queue shutdown_timeout (15)
```

Kubernetes snippet (**documentation only — do not commit manifests**):

```yaml
lifecycle:
  preStop:
    exec:
      command: ["/bin/sh", "-c", "touch /rails/tmp/shutdown && sleep 10"]
terminationGracePeriodSeconds: 60
env:
  - name: SHUTDOWN_SENTINEL_PATH
    value: /rails/tmp/shutdown
```

**Sequence:**

1. `preStop` touches the sentinel file (`/rails/tmp/shutdown`).
2. `/health/ready` immediately starts returning `503 "draining"`.
3. The load balancer sees the failing readiness check and **stops routing** new traffic to this instance (during the 10s `sleep`).
4. **Then** `SIGTERM` arrives: Puma drains in-flight HTTP requests (up to `worker_shutdown_timeout`) and Solid Queue drains in-flight jobs (up to `shutdown_timeout`).
5. Clean exit — no dropped requests, no `SIGKILL`, no orphaned jobs.

The container's `tmp/` is owned by the non-root `rails` user so the `preStop` hook can
write the sentinel.

---

## f) Notes

- **Seeds:** `db:seed` creates roles/permissions in **all** environments, but demo users only in development. **Run `db:seed` on first deploy** so the `DEFAULT_USER_ROLE` (`member`) exists — without it, registration succeeds but the new user gets **no role** and is denied on their own resources.
- **Dev-only surfaces:** `/jobs` (Mission Control) and `/api-docs` (Swagger UI) are development-only and are **not installed in the production image** (their gems are in the `:development` bundle group, excluded by `BUNDLE_WITHOUT="development"`).
- **SMTP:** Gmail SMTP is unsuitable for production (~500/day cap, SPF/DKIM alignment issues). Point `SMTP_ADDRESS`/`SMTP_PORT` at a transactional provider (SES / Postmark / Resend) and set `MAILER_FROM` to an address on a domain you control.
- **Background jobs:** run in-Puma by default (`SOLID_QUEUE_IN_PUMA=true`). For higher volume, unset it and run `bin/jobs` as a separate process/container.
- **Puma phased restarts:** do **not** use them while Solid Queue runs in-Puma — the worker fork does not survive a phased restart cleanly (rails/solid_queue#563). Use a rolling deploy (new containers) instead.
