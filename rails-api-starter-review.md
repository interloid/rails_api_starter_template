# Rails 8 API-Only Starter Template — Architecture & Production-Readiness Review

**Stack:** Rails 8.1 · Ruby 4.0.2 · PostgreSQL  
**Scope:** Full codebase, API-only  
**Date:** 22 July 2026  
**Status:** Review only — no project files were modified.

---

## 1. Project Understanding

| Aspect | Finding |
|---|---|
| **Ruby** | 4.0.2 (`.ruby-version`, pinned in `Dockerfile` ARG) |
| **Rails** | 8.1.3 (`Gemfile`), `config.load_defaults 8.1` |
| **Database / adapter** | PostgreSQL via `pg ~> 1.1`; single-DB topology (Solid Queue/Cache/Cable all in primary) |
| **API versioning** | URL-based `namespace :api { namespace :v1 }`; controllers under `Api::V1` |
| **Authentication** | Custom JWT (HS256, 15-min access) + opaque DB refresh tokens with rotation + reuse detection + family revocation (`JwtService`, `RefreshToken`) |
| **Authorization** | Pundit policies bridged to a `permissions` table (`resource:action` RBAC) |
| **Serialization** | Hand-rolled PORO serializers (`ApplicationSerializer.one/.many`) — no gem |
| **Background jobs** | Solid Queue (Postgres-backed), recurring via `config/recurring.yml` |
| **Caching** | Solid Cache (Postgres-backed); also backs rate-limit counters |
| **Testing** | RSpec + FactoryBot + shoulda-matchers + SimpleCov (80% gate); Minitest dirs kept but empty |
| **API docs** | Rswag → OpenAPI 3.0.3 generated from request specs; Swagger UI mounted **dev-only**; CI fails on stale spec |
| **Linting / quality** | RuboCop (omakase + rspec/perf/minitest), Brakeman, bundler-audit, Bullet (raises on N+1), Traceroute, RubyCritic, Lefthook |
| **Error monitoring** | New Relic (`newrelic_rpm`), inert unless `NEW_RELIC_LICENSE_KEY` set |
| **Logging** | Lograge JSON to stdout, correlation IDs, per-request enrichment |
| **Containerization** | Multi-stage `Dockerfile`, non-root user, jemalloc, `HEALTHCHECK`, opt-in migrations via `bin/docker-entrypoint` |
| **CI/CD** | GitHub Actions: lint, security, RSpec+coverage, OpenAPI drift check, Docker build; Dependabot |
| **Secrets** | Rails encrypted credentials (separate `production.yml.enc`) + `anyway_config` + `dotenv` (dev/test) |

**Purpose:** A production-oriented starting point for **stateless, token-authenticated JSON REST APIs** serving web/mobile/SPA clients, with RBAC, file uploads, transactional mail, and ops wiring already solved.

**Supports well today:** first-party auth for SPA/mobile apps needing users, roles, profiles, avatars, and email flows.

**Built-in assumptions:** single Postgres database; single logical tenant (no organizations); TLS terminated upstream by a reverse proxy/LB; header-based bearer auth (no cookies/CSRF); short-lived non-revocable access tokens are acceptable.

**Already available:** auth + refresh rotation, RBAC, soft delete, rate limiting, health/readiness probes, graceful shutdown, structured logs, OpenAPI, CI, container image.

**Major gaps:** no multi-tenancy, no collection filtering/sorting/search, no service/use-case layer (acceptable — see §6), no API-key or service-to-service auth, no access-token revocation, no mailer view tests, rate-limit path untested, host-authorization defaults open.

---

## A. Executive Summary

**Overall quality: High.** One of the more carefully engineered Rails API starters reviewed. Idiomatic code, comments explaining *why* (not *what*), correct use of Rails 8 primitives (`rate_limit`, `generates_token_for`, `normalizes`, Solid stack), and a coherent, tested security model. Clearly built by someone who has run Rails in production.

**Maturity level:** Late-stage / near-production. Most "day-2 ops" concerns (health, shutdown, logging, CI, container hardening) are already addressed — the parts most starters skip.

**Suitable as a reusable starter?** **Yes** — strongly.

**Suitable for production?** **Yes, after a short list of minor hardening fixes.** There are **no confirmed Critical (auth-bypass / data-loss / cross-tenant) defects.**

**Five most important findings:**
1. **Host authorization fails *open* in production by default** — `ALLOWED_HOSTS` empty ⇒ all hosts allowed (`config/environments/production.rb:131-134`).
2. **Access tokens cannot be revoked before their 15-min TTL** — logout/password-reset revoke refresh tokens only. Must be documented and mitigated for high-security use.
3. **Login leaks account state / timing** — the `locked?` check returns `account_locked` before credential verification, and non-existent users skip bcrypt (`AuthController#login`).
4. **Rate limiting is effectively untested** (`spec/requests/security/rate_limit_spec.rb` is `skip`ped).
5. **No collection filtering/sorting/search + no query allowlist scaffolding** — a scalability/DX gap the moment a second resource is added.

---

## B. Current Architecture & Request Flow

```
Client request
→ Rack middleware: Rack::Cors → SecureHeaders → Host authorization → param_depth_limit(32)
→ Router (config/routes.rb)  [/up, /health* bypass SSL redirect + host auth]
→ ApplicationController (ActionController::API)
     · set_correlation_id (X-Correlation-ID echo)
     · rate_limit per-IP (global scope, Solid Cache)
     · Renderable + ExceptionHandler mixed in
→ Api::V1::BaseController
     · Paginatable + Authenticatable(before_action :authenticate_user!) + Pundit
     · after_action verify_authorized / verify_policy_scoped
→ Concrete controller action
     · authenticate_user!  → JwtService.decode → User.kept.find_by(id: sub)
     · authorize/policy_scope → Pundit → UserPolicy → user.permission?("users:read")
     · strong params (params.permit)
     · ActiveRecord (.kept scope, includes for eager load)
→ UserSerializer.one/.many (PORO allowlist)
→ Renderable#render_success/#render_error (envelope) → JSON
   (any exception → ExceptionHandler → same envelope + correlation-id)
```

There is **no service/domain layer**, and for the current CRUD surface that is the correct call.

---

## C. Project Hierarchy Review

| Area | Current Approach | Assessment | Recommendation |
|---|---|---|---|
| `app/controllers/api/v1` | Versioned namespace, thin actions, shared `BaseController` | **Good** | Keep |
| `app/controllers/concerns` | `Authenticatable`, `ExceptionHandler`, `Renderable`, `Paginatable` | **Good** — clean SRP split | Keep; add `Filterable` when filtering lands |
| `app/models` | 6 domain + 2 join models, RBAC graph | **Good** — thin, well-associated | Add `has_many :refresh_tokens` to `User` |
| `app/services` | Only `JwtService` (stateless helper) | **Correct** — not over-abstracted | Add `services/<Domain>/` only for real workflows |
| `app/serializers` | PORO `ApplicationSerializer` + 2 concrete | **Good** — no gem lock-in | Version under `Api::V1` if v2 diverges |
| `app/policies` | Pundit, default-deny base, permission-bridged | **Excellent** | Keep |
| `app/validators` / `forms` / `queries` | **Absent** | Correct for current scope | Add `queries/` when filtering/sorting lands |
| `app/jobs` | `ApplicationJob` + purge job | **Good** | Set explicit `retry_on`/`discard_on` |
| `app/mailers` + views | `UserMailer` + text templates | **Good** | Add mailer specs |
| `app/errors` / `app/middleware` | **Absent** | Fine — `ExceptionHandler` centralizes | Add only if domain exceptions proliferate |
| `app/configs` | `AppConfig < Anyway::Config` | Intentional (anyway_config convention) | Keep |
| `config` | Well-organized, heavily commented | **Excellent** | — |
| `db` | UUID PKs, citext, proper FKs/indexes, Solid schemas | **Good** | Minor index/constraint refinements |
| `spec` | RSpec, security suite, factories, support helpers | **Strong** | Fill gaps (§G) |
| `test/` | Empty Minitest scaffolding kept alongside RSpec | **Minor smell** | Remove `test/` |

No fat controllers, fat models, god classes, circular deps, or premature abstractions found. The one genuine dead-weight is the empty `test/` tree coexisting with RSpec.

---

## D. Findings by Priority

### 🔴 Critical
**None confirmed.** No authentication bypass, SQL injection, mass-assignment, cross-tenant leak, or data-loss defect was found.

### 🟠 High

**H1 — Host authorization fails open in production**
- **Issue:** `config.hosts.concat(allowed) if allowed.any?` — if `ALLOWED_HOSTS` is unset, no host restriction is added, so any `Host` header is accepted.
- **Why it matters:** DNS-rebinding / Host-header injection (cache poisoning, poisoned password-reset links via absolute URLs) is exactly what `config.hosts` defends against.
- **File:** `config/environments/production.rb:131-134`
- **Fix:** Fail loud — raise on boot if `ALLOWED_HOSTS` is blank in production, or at minimum log a prominent warning.
  ```ruby
  if allowed.any?
    config.hosts.concat(allowed)
  else
    warn "[SECURITY] ALLOWED_HOSTS is empty — host authorization disabled in production"
  end
  ```

**H2 — Access tokens are not revocable within their TTL**
- **Issue:** Logout and password reset revoke **refresh** tokens; an already-issued 15-min access JWT stays valid. There is a `jti` claim but no denylist.
- **Why it matters:** "Log out everywhere" / "account compromised" does not immediately cut off active access tokens.
- **File:** `app/services/jwt_service.rb`, `Authenticatable#authenticate_user!`
- **Fix:** Document the ≤15-min revocation window as a tradeoff; offer an opt-in `jti`-denylist (store revoked `jti`s in Solid Cache with TTL = access TTL; check in `decode`). Keep it off by default.

**H3 — Login enables account enumeration (state + timing)**
- **Issue:** (a) `if user&.locked?` returns `account_locked` (403) **before** the password check. (b) For a non-existent email, `user&.authenticate` short-circuits, skipping bcrypt → faster response.
- **Why it matters:** Two enumeration oracles that undermine the generic `invalid_credentials` message.
- **File:** `app/controllers/api/v1/auth_controller.rb:29-42`
- **Fix:** Move the lock check to after a successful credential check; run a dummy `BCrypt::Password.create` when the user is nil so both paths do equal work.

### 🟡 Medium

**M1 — No filtering / sorting / search on collections, and no allowlist scaffolding**
- **Issue:** `UsersController#index` only supports pagination + fixed `order(created_at: :desc)`.
- **Why it matters:** Real APIs need these, and the unsafe way (interpolating `params[:sort]` into `order`) invites SQL injection. A starter should ship the safe pattern.
- **File:** `app/controllers/api/v1/users_controller.rb:4-16`, `Paginatable`
- **Fix:** Add a `Filterable` concern or `queries/users_query.rb` with an allowlist mapping request fields → columns.

**M2 — Account lockout is a self-service DoS vector**
- **Issue:** Any known email can be locked for 15 min with 5 bad attempts; no IP/device dimension.
- **File:** `app/models/user.rb:56-59`
- **Fix:** Acceptable default, but document it; pair lockout with per-IP throttling (present via the `auth` scope) and/or exponential backoff.

**M3 — Jobs have no explicit retry/discard policy**
- **Issue:** `ApplicationJob` relies on Solid Queue defaults; no `retry_on`/`discard_on`, no error reporting hook.
- **File:** `app/jobs/application_job.rb`
- **Fix:** Set defaults in `ApplicationJob` (`retry_on ActiveRecord::Deadlocked`, `discard_on ActiveJob::DeserializationError`) and report failures to New Relic.

**M4 — Rate limiting: untested, fixed-window, DB-backed**
- **Issue:** `rate_limit_spec.rb` is `skip`ped (`:null_store` binds at class load). Fixed-window (boundary bursts); every throttled check writes to Solid Cache (Postgres).
- **File:** `app/controllers/application_controller.rb:14`, `spec/requests/security/rate_limit_spec.rb`
- **Fix:** Test with a real memory store injected in that example group; document that heavy abuse control belongs at the edge (Rack::Attack + Redis, or LB/API-gateway).

**M5 — Single-record endpoints serialize without eager loading**
- **Issue:** `me`, `login`, `register`, `update` serialize a single user without includes → `UserSerializer` fires `roles` + `avatar` queries. Bounded (single record) so **Low** impact, but inconsistent with `index`/`show`.
- **File:** `app/serializers/user_serializer.rb:9-11` + call sites
- **Fix:** Reload with `.includes(:roles, avatar_attachment: :blob)` in `me`, or accept as negligible and note it.

### 🟢 Low
- **L1** — `User` lacks `has_many :refresh_tokens`; add with `dependent: :delete_all` (the FK has no `on_delete: :cascade`). `app/models/user.rb`.
- **L2** — Password policy is length-only (≥8). `has_secure_password` already caps at 72 bytes (no truncation bug); consider an opt-in breach/complexity check. `app/models/user.rb:16`.
- **L3** — Empty `test/` tree alongside RSpec — remove.
- **L4** — JWT has no `iss`/`aud` claims and no verification leeway. Add when tokens cross services. `app/services/jwt_service.rb`.
- **L5** — `.env.example` sets `RATE_LIMIT_REQUESTS=10` while code defaults to `300` — reconcile.
- **L6** — `refresh_tokens.expires_at` is unindexed; the purge job filters on it. Add an index if the table grows. `db/schema.rb:58`.

---

## E. API Endpoint Review

| Endpoint | Authentication | Authorization | Validation | Response | Status |
|---|---|---|---|---|---|
| `POST /api/v1/auth/register` | N/A (public, throttled) | Skipped (self) — Good | strong params + model | Envelope + user | `201` ✔ |
| `POST /api/v1/auth/login` | N/A (public, throttled) | N/A | Needs improvement (enum, H3) | Envelope + tokens | `200/401/403` |
| `POST /api/v1/auth/refresh` | N/A (public) | N/A | Good (rotation/reuse) | Envelope + tokens | `200/401` ✔ |
| `POST /api/v1/auth/logout` | Good | N/A (self) | Good | Envelope | `200` ✔ |
| `GET /api/v1/auth/me` | Good | N/A (self) | N/A | Envelope + user | `200` ✔ |
| `GET /api/v1/users` | Good | Good (policy_scope) | pagination clamp | Envelope + meta | `200` ✔ |
| `GET /api/v1/users/:id` | Good | Good | N/A | Envelope | `200/404` ✔ |
| `PATCH/PUT /api/v1/users/:id` | Good | Good (record-level) | strong params | Envelope | `200/403/422` ✔ |
| `DELETE /api/v1/users/:id` | Good | Good (admin) | N/A | Envelope | `200` (soft delete) |
| `PUT/DELETE/POST users/:id/avatar*` | Good | Good (`:update?`) | AS validations | Envelope | `200/400/422` ✔ |
| `POST /api/v1/account/*` | N/A (public, throttled) | Skipped (token/email-scoped) | token/model | Envelope | `200/422` ✔ |
| `GET /api/v1/status`, `/health*`, `/up` | Public | N/A | N/A | JSON | `200/503` ✔ |

Status-code usage is accurate throughout. `DELETE users/:id` returns `200` with a body (correct, since it returns a message). No use of `409`/`202` yet (no conflict/idempotency surface).

---

## F. Security Review

| Security Area | Current State | Risk | Recommendation |
|---|---|---|---|
| SQL injection | Parameterized everywhere; purge job uses named binds | Low | Keep; allowlist future `order`/`where` from params |
| Mass assignment | `params.permit` allowlists; roles never mass-assignable | Low | Keep |
| Broken access control | Pundit default-deny + `verify_authorized`/`verify_policy_scoped` | Low (strong) | Keep |
| Cross-tenant access | Single-tenant; N/A today | N/A | Add tenant scoping before adding orgs (§14) |
| Sensitive data exposure | Serializer allowlist; `password_digest` never emitted | Low | Keep |
| Auth strength | bcrypt, short JWT, refresh rotation + reuse detection | Low | Address H2/H3 |
| Token handling | Refresh stored as SHA-256 digest, raw shown once | Low (excellent) | Keep |
| CORS | Fails closed in prod; `credentials:false`; exposes `Authorization` | Low | Keep |
| CSRF | Intentionally absent (stateless, header auth) — documented | Low | Correct |
| Rate limiting | Global + auth + account scopes; untested | Medium | M4 |
| Brute force | Lockable + throttle | Low/Med | H3/M2 |
| Request size | `param_depth_limit=32`; body size deferred to proxy | Medium | Document required LB body-size cap |
| File upload | `active_storage_validations` (type+size pre-commit) | Low (excellent) | Keep |
| Command injection / SSRF / deserialization | No shell-out, no user-driven URLs, no `Marshal`/`YAML.load` | Low | Keep |
| Open redirects | Reset/confirm URLs built from `FRONTEND_URL` env, not user input | Low | Keep (relates to H1) |
| Dependency CVEs | bundler-audit + Dependabot in CI | Low | Keep |
| Secrets in VCS | Encrypted credentials, split prod key; `.env*` gitignored | Low | Keep |
| Insecure logging / PII | `filter_parameters` includes email/tokens/secrets | Low | Keep |
| Host header | **Fails open by default** | **High** | H1 |
| Webhook verification / replay | No inbound webhooks yet | N/A | Add HMAC + timestamp when integrations land |
| Docs exposure | Swagger UI + Mission Control dev-only | Low | Keep |

---

## G. Test Coverage Review

**Strengths (confirmed):**
- Security suite is the standout — refresh-token rotation *and reuse → family-revocation*, per-device vs global logout, lockable auto-unlock (`travel_to`), password-reset session kill + single-use token, confirmation gate, envelope consistency, malformed-JSON handling, default-role regression.
- Authorization tested at **both** policy and request level, including non-owner-cannot-update and default-deny for a role-less user.
- JWT service fully tested (expired, tampered, wrong `type`).
- Real N+1 guard: `QueryCounter` + `Bullet.raise`; memoization of `permission_names` asserted at 1 query.
- Realistic factories with traits; SimpleCov 80% gate enforced; OpenAPI drift blocks the build.

**Missing / highest-risk untested workflows:**
1. **Rate limiting** (`rate_limit_spec.rb` skipped) — top gap.
2. **Mailer rendering** — no `spec/mailers/`; only enqueue is asserted.
3. **Discarded-user login refusal** — uses `User.kept` but unverified end-to-end.
4. **`avatar_presign` negatives** — only happy path.
5. **`confirm_email`/`resend_confirmation` effects** — assert envelope only, not that `confirmed_at` is set.

**Recommended additions:** `spec/mailers/`, un-skip and fix `rate_limit_spec`, presign negatives, a discarded-login request spec, and one end-to-end admin-updates-another-user spec.

---

## H. Recommended Project Hierarchy

The current hierarchy is already close to ideal. Additions are **demand-driven**, not upfront:

```
app/
├── controllers/api/v1/        # ✔ exists — versioned, thin
│   └── concerns/              # ✔ + Filterable  ← ADD with §17
├── models/                    # ✔
├── policies/                  # ✔ default-deny
├── serializers/               # ✔ PORO
├── services/                  # ✔ JwtService; add <Domain>/ ONLY for real workflows
├── queries/                   # ← ADD with filtering/sorting (allowlisted param → scope)
├── jobs/                      # ✔
├── mailers/                   # ✔
└── errors/                    # ← ADD only if custom domain exceptions multiply
```

Do **not** add `forms/`, `middleware/`, or a service layer for CRUD now. Remove the empty `test/` tree.

---

## I. Recommended Request Flow

The existing flow is correct. The single recommended insertion is an **allowlisted query/filter step** before Active Record:

```
Request
→ CORS → SecureHeaders → HostAuthorization(fail-closed) → depth-limit
→ Router (versioned)
→ ApplicationController: correlation-id, rate-limit
→ Api::V1::BaseController: authenticate → authorize/policy_scope
→ Strong params
→ [Filterable/Query object: allowlist sort+filter → scope]   ← the one addition
→ Active Record (.kept, includes)
→ Serializer (eager-loaded, allowlist)
→ Renderable envelope → JSON
   (any exception → ExceptionHandler → same envelope + correlation-id)
```

Also include the `correlation_id` **inside** the error envelope body (`Renderable#render_error`), not just the header.

---

## J. Refactoring Roadmap

### Phase 1 — Production blockers (security / data integrity)
| Task | Priority | Complexity | Depends on | Benefit |
|---|---|---|---|---|
| H1: Host auth fail-closed/loud | High | Small | — | Closes Host-injection hole |
| H3: Fix login enumeration (lock order + dummy bcrypt) | High | Small | — | Removes enumeration oracle |
| H2: Document token-revocation window; opt-in `jti` denylist | High | Small (doc) / Medium (denylist) | Solid Cache | Honest security posture |
| M4: Un-skip + fix rate-limit test | Medium | Small | — | Verifies a security control |

### Phase 2 — Architecture & consistency
| Task | Priority | Complexity | Depends on | Benefit |
|---|---|---|---|---|
| Add correlation_id to error body | Medium | Small | — | Better client debugging |
| M5: Consistent eager loading on single-record serialize | Low | Small | — | Query consistency |
| Remove empty `test/`; add `has_many :refresh_tokens` (L1) | Low | Small | — | Clarity/correctness |

### Phase 3 — Performance & reliability
| Task | Priority | Complexity | Depends on | Benefit |
|---|---|---|---|---|
| M1/§17: Allowlisted filtering/sorting via query object | Medium | Medium | — | Scales to real resources safely |
| M3: Job retry/discard + error reporting defaults | Medium | Small | New Relic | No silent job loss |
| L6: Index `refresh_tokens.expires_at` | Low | Small | — | Purge at scale |

### Phase 4 — Developer experience
| Task | Priority | Complexity | Depends on | Benefit |
|---|---|---|---|---|
| Mailer specs + presign/confirm negatives + discarded-login spec | Medium | Medium | — | Closes top test gaps |
| Multi-tenancy guide/hook | Low | Medium | product need | Ready when orgs arrive |
| README: token window, lockout DoS, LB body-size cap | Medium | Small | — | Operator clarity |

---

## K. Final Verdict

| Dimension | Rating |
|---|---|
| Architecture | **9/10** |
| Code quality | **9/10** |
| Security | **8/10** |
| API consistency | **9/10** |
| Testability | **8/10** |
| Performance readiness | **8/10** |
| Scalability | **7/10** (single-tenant, no filtering layer) |
| Deployment readiness | **9/10** |
| Developer experience | **9/10** |
| **Overall starter-template quality** | **8.5/10** |

### Recommendation: **Ready to use — after minor improvements.**

A high-quality, thoughtfully engineered starter that already solves the operational problems most templates ignore, with **no critical defects**. Ship it as the foundation, and complete the short Phase-1 list (host-auth fail-closed, login-enumeration fix, document the access-token revocation window, un-skip the rate-limit test) before putting anything security-sensitive in front of real users. Resist adding service/form/query layers until a concrete workflow demands them.

---

*Prepared as a full-codebase engineering review. No project files were modified during the review.*
