# Security deliverables — the acceptance contract

Phase 4 of `app-blueprint` produces `docs/SECURITY.md`. This file says what "done" means for that
document, exhaustively enough that a build agent working alone cannot satisfy the letter of the
spec while producing something thin.

The failure this file exists to prevent: SKILL.md says "a threat model by actor × surface" and
"enforced rules where every rule names its machine enforcement". Those are statements of intent.
An agent reading them writes eleven paragraphs of policy prose — "all input shall be validated",
"secrets shall be stored securely", "the application shall follow the principle of least
privilege" — ships it, and nothing in the build ever changes as a result. Policy prose is
unfalsifiable. It cannot fail CI. It cannot be violated by a pull request in any detectable way.
It is a document that describes a product nobody built.

The core rule, from SKILL.md, restated because everything below is a consequence of it:

> **Every rule names its machine enforcement — a CI grep, a lint rule, a test suite, a database
> privilege — or it is not a rule, it is a wish.**

And its corollary, which is where most security documents actually die:

> **An enforcement that has never gone red is passing vacuously.** Before the enforcement counts,
> show it FAILING on a known-bad input, and record that demonstration. A check that has never
> caught anything converts an unexamined codebase into a confident green, which is strictly worse
> than no check — no check leaves you alert.

`SECURITY.md` is not a policy. It is the security half of the acceptance oracle: threats enumerated
against real surfaces, controls that exist as code, and enforcements that are themselves tested.

**Scope note.** This is defensive specification for a product the user is building. Everything here
describes controls, tests, and enforcement for the user's own system. Nothing in `SECURITY.md`
should be usable as attack tooling against a third party — a test corpus of injection payloads
aimed at your own endpoints in your own CI is a regression suite; the same corpus pointed outward
is not this skill's business.

## §0 — How this file relates to the other security skills

This file specifies output. The craft lives elsewhere, and duplicating it here would guarantee two
drifting copies.

| Need | Skill that owns it | What this file adds |
|---|---|---|
| Reviewing written code for vulnerabilities | `security-review` skill / `security-reviewer` agent | The spec the review is run *against*; review happens during the build, this happens before it |
| LLM/agent-specific attack surface, prompt injection depth | `ai-security` | The required artifacts (§5) — corpus, gates, spend caps — that must exist in the package |
| Apple-platform crypto, Keychain, biometrics, App Transport Security | `swift-security-expert` | The mobile acceptance checklist (§4) that the Swift work must satisfy |
| IAM, network boundaries, cloud posture | `cloud-security` | The egress/allowlist and secrets-manager requirements that land in `SECURITY.md` |
| SOC 2 control mapping and evidence | `soc2-compliance` | The compliance artifact inventory (§7) that must exist before an audit is even schedulable |
| GDPR/DSGVO obligations, DPAs, lawful basis | `gdpr-dsgvo-expert` | The data inventory, deletion path, and subprocessor list as *required package artifacts* |
| Incident classification and response runbooks | `incident-response` | The requirement that a breach notification path exists as a named runbook, not a good intention |
| Live testing of a deployed system | `web-quality-gate` / `app-quality-gate` | Nothing; those run at the end of a build. This runs before one. |
| Offensive testing | `offensive-security` | Out of scope here and deliberately so; this skill produces defensive specification only |

**Dispatch, don't reimplement.** When Phase 4 needs an LLM threat taxonomy, say "expand with the
`ai-security` skill" and check the result against §5. If you find yourself writing an exploit
technique into a `docs/` file, you have crossed a line the package does not need you to cross —
the build agent needs the control and its test, not the attack.

## §1 — The threat model: actor × surface

### 1.1 Why a matrix and not a list

A threat list is written from imagination and stops when the author runs out of ideas. A matrix is
written from enumeration and stops when the cells are filled, which means its blank cells are
*visible*. The blank cell is the product: "another tenant × the background job queue" left empty is
a question nobody asked, and it will get asked in production by someone who is not on your side.

The matrix is also the only structure that reliably surfaces the two threat classes teams skip:
the insider/operator (because it feels rude) and the compromised dependency (because it feels like
someone else's problem). Both are rows. Both get filled.

### 1.2 Actor classes (rows) — all of these, every time

| Actor | Definition | Why it is a separate row |
|---|---|---|
| **Anonymous** | No credentials. Reaches whatever is publicly routable. | Every public route is its surface; the public-route allowlist (§3.5) exists to bound this row |
| **Authenticated user** | Valid credentials, lowest privilege in their tenant | The IDOR row. Most real breaches live here: a valid session reading an object it does not own |
| **Tenant admin** | Elevated within one tenant | Can they escalate to platform? Can they read another tenant's data through an integration, invite, or export? |
| **Another tenant** | Fully valid user of a different tenant | The isolation row. Its cells are proven by the isolation test (§6.4), never by inspection |
| **Insider / operator** | Your own engineer, support agent, or CI runner with production access | Support impersonation, prod DB console, log access. The control here is *audit* and *scoping*, not trust |
| **Compromised dependency** | A package, container base image, or CI action that turns hostile | Postinstall scripts, build-time exfiltration, a transitive bump. Controls are lockfiles, pinned digests, egress limits |
| **Lost / rooted device** (mobile) | The device is in someone else's hands, or the OS integrity is gone | Local store, keychain, cached tokens, deep links. Everything on the device is readable in this row |
| **The model itself** (LLM features) | The model emits text that flows into a sink, or decides to call a tool | Not malice — a model is a *stochastic untrusted producer*. Treated as an actor because its output reaches sinks |

Add product-specific actors when the domain has them (a webhook sender, a marketplace app, a
partner API consumer, a scheduled report recipient). Do not remove rows because "we don't have
that yet" — a row with cells reading "N/A: no multi-tenancy in v1, revisit at D7" is a record of a
decision; a deleted row is an omission nobody can see.

### 1.3 Surface classes (columns) — enumerated from the architecture, not from memory

Every column is derived from `DESIGN_SPEC.md`, which means the matrix cannot be written before
Phase 2 is done. If you can write the matrix without reading the spec, the matrix is fiction.

| Surface class | How to enumerate it | Common misses |
|---|---|---|
| **Ingress** | Every route in the API surface, every form action, every webhook receiver, every websocket/SSE channel, every file-upload endpoint | Webhook receivers (unauthenticated by design), health/debug endpoints, the framework's own dev routes shipped to prod |
| **Data stores** | Every table, bucket, cache, queue, and search index in the schema | Caches and queues — they hold the same data with none of the row-level policy |
| **Outbound calls** | Every external API, every user-supplied URL fetch, every email/SMS/push send, every LLM call | User-supplied URL fetch is the SSRF surface and is almost never listed as a "surface" by an unprompted agent |
| **Background jobs** | Every scheduled task, queue consumer, cron, retry worker, batch import/export | Jobs usually run with elevated privilege and no session context; the authz code path is often entirely different from the request path |
| **Admin paths** | Internal tooling, support impersonation, feature-flag toggles, the DB console, migration runners | Impersonation is a full authentication bypass with a friendly name |
| **Local store** (mobile) | Files, UserDefaults/SharedPreferences, SQLite/Realm/Core Data, cached images and API responses, keychain/keystore | Cached API responses containing PII; screenshots in the app switcher |
| **IPC / deep links** (mobile) | Custom URL schemes, universal/app links, share extensions, app-to-app intents, pasteboard, notification payloads | Deep links are unauthenticated ingress that arrives with the user's session already attached |
| **Build & supply chain** | Package manifests, CI workflows, container base images, third-party scripts on web pages | Postinstall scripts; a CI action pinned to a mutable tag |

Products without mobile drop those two columns. Products with mobile do not drop the others.

### 1.4 What every filled cell must contain

Four fields. A cell missing any of them is not filled.

| Field | Requirement |
|---|---|
| **Threat** | A specific, concrete action — "user A reads user B's invoice by changing the ID in the URL", not "unauthorized access" |
| **Impact** | What it costs: data classes exposed, integrity lost, availability lost, money spent, regulatory trigger. Name the data class from §7.1's inventory |
| **Control** | The mechanism that stops it, at the layer it operates. Prefer a *construction* that makes the threat inexpressible over a *check* that detects it |
| **Enforcement** | The exact CI grep, lint rule, test path, or DB grant that proves the control is present and stays present. This is the same field as §2's schema — cells and rules share one enforcement vocabulary |

**Prefer constructions to checks.** A check can be forgotten at the one call site that matters. A
construction cannot be. A repository layer where every query is scoped by tenant because tenant is
a constructor argument and there is no unscoped client to import beats a code-review rule that says
"remember to filter by tenant". Where a construction exists, use it and say in the cell that the
threat is inexpressible rather than detected.

### 1.5 Worked cell — one, complete

Copy this shape. Every cell in `SECURITY.md` gets this level of specificity, in a table row rather
than prose.

> **Actor:** Authenticated user (lowest privilege, tenant T1)
> **Surface:** Ingress — `GET /api/v1/documents/:id`
>
> **Threat.** A signed-in user of tenant T1 substitutes a document ID belonging to tenant T2 (IDs
> are sequential integers in the current schema) and reads the response. Same threat via the
> sibling routes `PATCH /documents/:id`, `DELETE /documents/:id`, and `GET
> /documents/:id/export` — the export route is the highest-value variant because it returns the
> full document body plus attachment URLs, and its handler predates the shared authorization
> helper.
>
> **Impact.** Cross-tenant read of `class:confidential` customer content (see data inventory
> §7.1, row DC-3). Full-tenant enumeration is possible because IDs are sequential: one authenticated
> account walks the whole corpus. Triggers breach notification under the obligations recorded in
> §7.5. Loss class: confidentiality, complete.
>
> **Control.** Two layers, both required.
> 1. *Construction:* the request-scoped repository is the only exported database accessor, and it
>    is constructed with the caller's `tenant_id` from the verified session; there is no exported
>    unscoped client. Cross-tenant reads are not expressible in application code.
> 2. *Defense in depth:* Postgres row-level security on `documents` with
>    `USING (tenant_id = current_setting('app.tenant_id')::uuid)`, and the application role
>    (`app_runtime`) holds no `BYPASSRLS`. A bug in layer 1 returns zero rows rather than another
>    tenant's rows.
>
> Additionally, external document IDs are UUIDv7 rather than sequential integers, so enumeration is
> not a practical attack even if a route is missed. This is a construction, not a control — it
> reduces blast radius, it does not authorize anything.
>
> **Enforcement.**
> - `tests/security/tenant_isolation_test.ts` — for every table carrying `tenant_id`, seeds two
>   tenants and asserts that a T1-scoped connection reads zero T2 rows on select, update, and
>   delete. Table list is derived from `information_schema` at test time, so a new tenant-scoped
>   table is covered the day it is added rather than the day someone remembers.
> - `tests/security/authz_matrix_test.ts` — asserts the `(route × role)` cell
>   `(GET /documents/:id, cross-tenant-user) → 404`. All four document routes are cells; the matrix
>   is generated from the route table so an unlisted route fails the completeness assertion (§6.3).
> - CI grep: `rg -n "createUnscopedClient|BYPASSRLS" src/ --glob '!src/db/bootstrap.ts'` must return
>   zero matches. Job `security-greps`, exit nonzero on any hit.
> - DB grant: migration `0007_rls_documents.sql` enables RLS and revokes `BYPASSRLS`;
>   `tests/security/rls_enabled_test.ts` asserts `relrowsecurity = true` for every table in the
>   tenant-scoped list, so RLS cannot be silently dropped by a later migration.
>
> **Negative test (the enforcement's own proof).** `tests/security/negative/` contains a fixture
> branch that removes the tenant predicate from the documents repository; CI job
> `enforcement-negative-check` applies it, runs the isolation and matrix suites, and **fails the
> build if they pass**. Recorded demonstration date and result live in `AUDIT_LOG.md`.

Note what this cell does *not* do: it does not say "implement proper access control". Every noun in
it is a file, a role, a command, or a migration.

### 1.6 Domain-specific threats

The matrix covers structural threats. It will not, on its own, surface threats that come from what
the product *is*. Add a short section enumerating them, derived from the PRD's domain: a scheduling
product has double-booking-as-denial-of-service and calendar-invite phishing; a marketplace has
payout redirection and seller-account takeover; a health product has re-identification through
combined non-identifying fields; a document collaboration product has share-link leakage through
referrers and forwarded email.

Each domain threat gets the same four fields. If Phase 0 audited a predecessor system, every
security defect the audit found is automatically a row here with a named regression test in
`TESTS_TDD.md` — that traceability is the point of Phase 0.

## §2 — The enforced-rule schema

### 2.1 The five fields

Every rule in `SECURITY.md` is a table row or a short block carrying exactly these:

| Field | Requirement | Failure mode when omitted |
|---|---|---|
| **Rule** | What must always or never happen, stated so a reviewer can decide compliance without judgment | "Be careful with SQL" — nothing to check against |
| **Reason** | Why it exists, concretely enough to survive an argument. The reason is what lets a future engineer distinguish a real exception from an inconvenience | Rules without reasons get deleted by the first person they block, correctly, because there is nothing to weigh |
| **Enforcement** | The exact mechanism: the grep pattern verbatim, the lint rule ID, the test file path, the DB grant statement, the CI job name | "Enforced in code review" is not enforcement. Humans miss things at a rate you can measure |
| **Proof** | The test that proves the *enforcement itself* works — the negative test (§2.3) | Without it the enforcement may have been broken since the day it was written |
| **Exception path** | How to get an exemption: the annotation, the file it is recorded in, who must approve, and how the exemption list is audited | Without a path, the first legitimate exception is handled by deleting the rule |

The **Exception path** field is the one agents skip, and skipping it is what makes security rules
brittle. There is always eventually a legitimate reason to concatenate a SQL fragment (a dynamic
`ORDER BY` column, validated against an allowlist). If the only way to do it is to delete the grep,
the grep gets deleted. Give exceptions a named annotation (`-- blueprint:sql-dynamic-ok`), require
them to be enumerated in a single reviewed file, and make CI fail when the count grows without a
matching entry — the exception becomes a *visible* decision instead of an invisible one.

### 2.2 Enforcement mechanism types, ranked

Prefer the highest tier that can express the rule. Every tier down is a wider window between
introduction and detection.

| Tier | Mechanism | Detection latency | Use when |
|---|---|---|---|
| 1 | **Construction** — the unsafe thing is not expressible (no unscoped client exported; a `Sanitized<T>` type is the only thing the render sink accepts) | Compile time; never introduced | Always, if the language allows it |
| 2 | **Type system / compiler** | Compile time | Tainted-string wrappers, branded types, exhaustive role unions |
| 3 | **Lint rule with a named ID** | Editor + CI, seconds | Pattern-level rules the type system cannot see |
| 4 | **Test suite** | CI, minutes | Behavioral rules — authz cells, isolation, injection corpora |
| 5 | **CI grep / static scan** | CI, seconds | Textual anti-patterns; cheap, blunt, and honest about being blunt |
| 6 | **Database privilege / RLS policy** | Runtime, at the last line | Defense in depth beneath every application-layer control |
| 7 | **Runtime assertion that fails closed** | Runtime | When earlier tiers cannot cover it; must fail closed, never log-and-continue |
| — | *Code review, documentation, training* | — | **Not enforcement.** May accompany a mechanism, never substitute for one |

A rule enforced only at tier 7 should say so and explain why tiers 1–6 do not apply. That sentence
is usually where someone notices tier 1 was available.

### 2.3 The meta-rule: negative-test every enforcement

This is the rule that makes the rest of the file mean anything.

**An enforcement counts only after it has been shown to FAIL on a known-bad input.** Write the
violation, run the check, watch it go red, record the date and the observed failure output in
`AUDIT_LOG.md`, then revert the violation. Until that has happened, the check's green is
uninformative: it is equally consistent with "the codebase is clean" and "the pattern never
matched anything, ever."

The failure modes this catches are mundane and universal:

- A grep whose pattern never matched because the regex was wrong (an unescaped `.`, a `+` that
  needed `-E`, a `--glob` that excluded the whole `src/` tree).
- A test suite that exits 0 because its runner found no test files — a path typo turns a suite into
  a no-op that reports success.
- A lint rule configured at `warn` in a config where CI only fails on `error`.
- An RLS policy created on a table but never enabled (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY`
  omitted), so the policy exists in `pg_policies` and does nothing.
- A CI job that runs on `pull_request` but the branch protection requires a job name that was
  renamed, so it is not a required check.

Make it structural rather than ceremonial: keep the known-bad inputs as committed fixtures under
`tests/security/negative/`, and run a CI job (`enforcement-negative-check`) that applies each one,
runs the corresponding check, and **fails the build if the check passes**. Now the negative tests
are themselves maintained, and an enforcement that rots gets caught by the same machinery that
catches everything else.

This mirrors SKILL.md's Phase 8 rule — show the gate failing before you trust it — applied to every
security control rather than only to the package's own audit scripts.

### 2.4 Worked example — SQL parameterization

> **Rule.** SQL reaches the database only through the parameterized query builder or a prepared
> statement. String concatenation, template interpolation, and f-string composition of SQL are
> forbidden, including in migrations, seed scripts, admin tooling, and analytics jobs.
>
> **Reason.** Concatenation is the entire mechanism of SQL injection, and it does not stay in the
> web tier — the reporting job that builds a `WHERE` clause from a saved-filter row is the same
> vulnerability with a longer fuse. Scoping the rule to "user-facing endpoints" is how injection
> ends up in the batch exporter.
>
> **Enforcement.**
> - Lint: `eslint` rule `security/detect-sql-injection` at `error` for `src/**`, plus the project
>   rule `local/no-raw-sql` which bans importing the driver's raw-query export outside
>   `src/db/builder.ts`.
> - CI grep, job `security-greps`, verbatim:
>   `rg -n --pcre2 "(?i)\b(select|insert|update|delete|from|where)\b[^\n]*\$\{" src/ migrations/ scripts/`
>   and `rg -n --pcre2 "sql\.raw\(|db\.query\(\s*[^,)]*(\$\{|\+)" src/ --glob '!src/db/builder.ts'`.
>   Any match exits nonzero.
> - Test: `tests/security/injection_sql_test.ts` drives the shared corpus
>   (`tests/security/corpora/sql.txt`, ~120 payloads) through every endpoint that accepts a string
>   parameter, asserting 4xx-or-empty and never a 500 or a leaked driver error. Endpoint list is
>   generated from the route table, so a new endpoint is covered on the day it is added.
>
> **Proof.** `tests/security/negative/sql_concat_fixture.ts` contains a handler that concatenates a
> query parameter. `enforcement-negative-check` applies it and requires both the grep and the
> corpus suite to fail. Last demonstrated red: recorded in `AUDIT_LOG.md`.
>
> **Exception path.** Dynamic identifiers (a sortable column name, a table name in a migration
> helper) cannot be parameterized by the driver. The exception is an allowlist lookup — the user
> value indexes into a hardcoded map of permitted identifiers and never reaches SQL directly —
> annotated `// blueprint:sql-dynamic-ok:<reason>` and enumerated in
> `docs/security/exceptions.md`. CI asserts the annotation count equals the entry count in that
> file; a new annotation without an entry fails the build.

### 2.5 Worked example — secrets

> **Rule.** No credential, API key, token, private key, connection string with a password, or
> signing secret appears in the repository, in a build artifact, in a container image layer, in a
> client bundle, in a log line, or in an error message. Secrets are read at runtime from the
> platform secret manager (or, in local development, from an untracked `.env` that is git-ignored
> and never populated with production values).
>
> **Reason.** A committed secret is public from the moment of the commit, not the moment of the
> push, and rotating it is strictly more expensive than never committing it. Git history keeps it
> after deletion. Client bundles and mobile binaries are the same problem with no rotation
> ceremony at all: anything shipped to a device is published (§4.8).
>
> **Enforcement.**
> - Pre-commit: `gitleaks protect --staged --redact` via the repo's hook config. Local, fast, and
>   the only tier that prevents rather than detects.
> - CI job `secret-scan`: `gitleaks detect --no-git --redact --exit-code 1` over the working tree,
>   plus a full-history scan on a schedule (history scans are slow; running one per PR trains
>   people to skip CI).
> - CI grep for the shapes scanners miss, job `security-greps`: high-entropy assignment patterns to
>   names matching `(?i)(secret|token|api_?key|password|private_?key)\s*[:=]\s*["'][A-Za-z0-9/+_-]{16,}`
>   across the tree excluding `tests/fixtures/`.
> - Startup assertion: the config loader enumerates required secret names and exits nonzero at boot
>   if any is absent or empty. Fails closed — a missing secret must never resolve to a default,
>   an empty string, or a permissive mode.
> - Log redaction: the logger is constructed with a deny-list of field names and a regex for
>   token-shaped values; `tests/security/log_redaction_test.ts` asserts that a request carrying an
>   `Authorization` header and a body field named `password` produces log output containing
>   neither value.
>
> **Proof.** `tests/security/negative/planted_secret/` holds a fixture file with a synthetic
> AWS-shaped key. `enforcement-negative-check` stages it and requires both the pre-commit hook and
> the CI scanner to reject; if either passes, the build fails. Also assert that the startup check
> exits nonzero with the secret env var unset — a config loader with a `|| ''` fallback is the
> single most common way this rule quietly stops existing.
>
> **Exception path.** Test fixtures need credential-shaped strings. They live under
> `tests/fixtures/` (scanner-excluded), are structurally invalid (wrong length or a reserved
> prefix), and are never valid against any real service. No other exception exists; a real
> credential in the repo is a rotation event, not a review comment.

### 2.6 Worked example — authentication by default

> **Rule.** Every route requires an authenticated session unless it appears in an explicit,
> reviewed public-route allowlist. The default for an unlisted route is deny.
>
> **Reason.** Opt-in authentication fails silently and asymmetrically: the developer who forgets
> `requireAuth` on a new endpoint sees it work perfectly in every test they run, because they are
> signed in. The bug is invisible from the inside and obvious from the outside. Deny-by-default
> inverts the failure — forgetting to list a genuinely public route breaks it loudly, in
> development, in the first minute.
>
> **Enforcement.**
> - Construction: authentication is applied by the router at mount, not by per-handler middleware.
>   A handler cannot opt out; it can only be registered under the public mount, which reads its
>   member list from `src/auth/public-routes.ts`.
> - Test: `tests/security/auth_default_test.ts` enumerates the framework's registered route table
>   at runtime, subtracts the allowlist, and asserts every remaining route returns 401 for an
>   unauthenticated request. Because it reads the live route table rather than a maintained list,
>   a new route is covered automatically and cannot be forgotten.
> - Allowlist review: `src/auth/public-routes.ts` is in `CODEOWNERS` with a required reviewer, and
>   a CI check fails when the file changes without an entry appended to `docs/security/exceptions.md`
>   giving the route, the reason it is public, and the date.
> - Rate limiting: every public route additionally carries an unauthenticated rate limit (§3.9),
>   since the anonymous actor row of the matrix has this list as its entire surface.
>
> **Proof.** `tests/security/negative/unlisted_public_route.ts` registers a route on the public
> mount without adding it to the allowlist; `enforcement-negative-check` requires
> `auth_default_test` to fail. Separately assert the test's own coverage is non-vacuous: it must
> report a nonzero count of routes checked, and CI fails if that count is zero or drops between
> runs without a corresponding route deletion. A route-enumeration test that silently enumerates
> nothing is the exact vacuous-green failure §2.3 exists to catch.
>
> **Exception path.** Health checks, the login and signup endpoints, OAuth callbacks, webhook
> receivers, and public marketing pages. Webhook receivers are public to the network but are *not*
> unauthenticated: each verifies a provider signature over the raw body before parsing, and that
> verification is its own row in the matrix.

## §3 — Per-domain required content

Each subsection below is a required artifact set, not advice. `SECURITY.md` contains a section per
domain; absent domains are marked "N/A" with the reason. Every rule in every domain carries the
§2.1 five fields — the text below states what must be specified, not the prose to copy.

### 3.1 Input validation at boundaries

**Required:** a named schema per boundary (HTTP body, query, path params, headers you read,
webhook payloads, queue messages, file metadata, environment config, LLM structured output), each
defined once in a shared module and imported by both the runtime validator and the type
definitions. Validation happens at the boundary, before any business logic, and rejection is the
default for unknown fields (strict/strip mode, stated explicitly — pass-through of unknown keys is
how mass-assignment happens).

**Required:** a statement of what "valid" means beyond type — length caps on every string
(unbounded strings are a memory and a storage attack), range bounds on every number, enum
membership for every constrained value, and a maximum request body size enforced by the server, not
by the parser.

**Enforcement:** a lint or CI grep asserting no handler reads the raw request object directly
(`rg -n "req\.(body|query|params)" src/routes/` returns zero outside the validation middleware); a
test that posts an unknown field to every endpoint and asserts rejection or strip; a test that
posts an over-length string and asserts 400 rather than 500.

**Note the corollary that gets missed:** queue messages and background job payloads cross a trust
boundary too. A job whose payload was written by a previous version of the code, or by a poisoned
producer, is untrusted input. Validate on consume, not only on produce.

### 3.2 SQL injection

Covered as the worked example in §2.4. `SECURITY.md` carries that rule verbatim, plus: the ORM or
builder in use and its escape hatches by name, the migration and seed scripts explicitly in scope,
and the analytics/reporting path explicitly in scope. If the product uses a document store or
Firestore rather than SQL, this section becomes the equivalent — query construction from
user-controlled field paths, and the rule that security rules files are tested, not assumed.

### 3.3 Output encoding, CSP, and the single sanitized surface

**Required:** a statement of the rendering model and where auto-escaping applies, plus an explicit
inventory of every escape hatch the framework offers (`dangerouslySetInnerHTML`, `v-html`,
`{@html}`, `innerHTML`, `AttributedString` from HTML) with a CI grep banning each outside a named
allowlist of files.

**Required:** exactly **one** rich-text surface, if the product needs one at all. Not one per
feature. It runs a maintained sanitizer (named, versioned, pinned) with an explicit allowlist of
tags and attributes, on the **server**, on write and again on read if stored HTML predates the
current sanitizer version. Client-side-only sanitization is not a control; the client is the
attacker in this row.

**Required:** the Content-Security-Policy header as a literal string in the doc, with a one-line
justification per directive, and the rule that `unsafe-inline` and `unsafe-eval` in `script-src`
are forbidden. If a nonce or hash strategy is needed, name it. Also required as literals: the other
response headers and their values (`Strict-Transport-Security` with `max-age` and `includeSubDomains`,
`X-Content-Type-Options: nosniff`, `Referrer-Policy`, `Permissions-Policy`, frame-ancestors handled
in CSP rather than the legacy header).

**Required:** the cookie attribute set as literals — `HttpOnly`, `Secure`, `SameSite` with the
chosen value and why, `Path`, and the domain scope, plus whether the session cookie is host-only.

**Enforcement:** a test that fetches a representative response and asserts every header is present
with the exact expected value (header drift through a proxy or platform config change is silent
otherwise); a test that feeds the XSS corpus through every field that renders in the UI and asserts
the stored and rendered forms are inert; a CI grep for the escape hatches.

### 3.4 SSRF containment

Required for any component that fetches a URL the user influenced — link previews, webhook
registration, avatar-by-URL, importers, RSS/feed readers, PDF renderers that follow references,
LLM tools that browse, and OAuth/OIDC discovery endpoints if the issuer is user-supplied.

**Required, all four:**

1. **Post-DNS-resolution denial.** Resolve the hostname, then check the *resolved addresses*
   against a deny list: RFC1918 space, loopback, link-local `169.254.0.0/16` (which is where cloud
   metadata lives), `::1`, IPv6 unique-local `fc00::/7`, IPv4-mapped IPv6, `0.0.0.0/8`, and the
   carrier-grade NAT range. Checking the hostname before resolution is defeated by DNS that
   resolves to a private address, which is not exotic — it is a one-line DNS record.
2. **Re-validation on every redirect hop.** The first response is a 302 to `169.254.169.254`
   unless you re-check. Cap the hop count, and re-run the full resolution check at each hop, not
   only on the initial URL.
3. **Scheme and port allowlist.** `https` only in production (state the exception if `http` is
   needed and why), and a port allowlist. Deny `file:`, `gopher:`, `ftp:`, `data:`, and anything
   the HTTP client library helpfully supports.
4. **Network-level egress restriction.** The fetching component runs where it cannot reach the
   metadata endpoint or internal services at all — an egress allowlist, a dedicated subnet, or a
   forward proxy that enforces the destination policy. Application-layer checks are layer one;
   this is the layer that survives a bug in layer one. Name the mechanism concretely.

**Also required:** response size cap and timeout (a fetch of an infinite stream is a denial of
service), content-type allowlist where the consumer expects a specific type, and the rule that
fetched content is never rendered as HTML in the product's origin.

**Enforcement:** `tests/security/ssrf_test.ts` as unit tests over the resolver-and-policy function
with a fixture table covering each denied range, the redirect-to-private case, the
DNS-resolves-to-private case, the scheme cases, and the oversize/timeout cases. Plus a CI grep
asserting no direct use of the HTTP client outside the guarded fetch wrapper
(`rg -n "fetch\(|axios\.|requests\.get" src/ --glob '!src/net/safe-fetch.ts'`). The wrapper is the
construction; the grep is what keeps it the only door.

### 3.5 Authentication defaults and the public-route allowlist

Covered as the worked example in §2.6. `SECURITY.md` additionally specifies: the authentication
mechanism and provider; password storage (algorithm and parameters as literals, if you store
passwords at all — delegating to an identity provider is a legitimate and usually better answer,
recorded as an AD); MFA support and whether it is required for admin roles; the account-recovery
flow, which is an authentication bypass wearing a helpful costume and needs its own matrix cells;
brute-force and credential-stuffing defenses with the specific thresholds; and the rule that
authentication failure messages do not distinguish "no such user" from "wrong password".

### 3.6 Authorization in one server-side place, plus the route × role matrix

**Required:** a single server-side authorization module. Not a decorator on some handlers and an
`if` in others. One function, one place, and a stated policy shape (RBAC roles enumerated as a
closed union, or ABAC with the attribute list, or relationship-based with the relation set). The
client's role claim is display state, never a decision input — the server re-derives authority from
the session on every request.

**Required:** the **route × role matrix, as a test, not as a table in prose**. Every route is a
row, every role (including anonymous, cross-tenant, and expired-session) is a column, and every
cell asserts the expected status. A prose matrix in a document is a wish; the same matrix as
parameterized test cases is the control. The matrix must be *complete*: generate the route list
from the live route table and fail if any route lacks a cell, so adding a route without adding its
authz cells breaks the build.

**Required:** the object-level check, distinct from the route-level check. Route-level answers "may
this role call this endpoint"; object-level answers "may this principal act on this specific
record". IDOR lives entirely in the gap between them, and a route matrix that passes while object
checks are missing is the most common false sense of security in this whole file.

**Enforcement:** `tests/security/authz_matrix_test.ts` (completeness assertion included);
`tests/security/idor_test.ts` which, for every resource type, creates a record as principal A and
attempts every mutating and reading operation as principal B; a CI grep asserting no route file
imports the data layer directly, bypassing the authorization module.

### 3.7 Session and token handling

**Required as literals:** session lifetime, idle timeout, absolute timeout, refresh-token rotation
policy and reuse-detection behavior, where tokens are stored on each client type, the signing
algorithm and key rotation cadence, and the revocation mechanism. "Revocation: none, JWTs expire in
15 minutes" is an acceptable answer *stated*; the failure is not stating it and discovering at
incident time that there is no way to log anyone out.

**Required:** the session-invalidation triggers — password change, email change, MFA enrollment
change, role or tenant-membership change, explicit sign-out, and sign-out-everywhere. A role
downgrade that leaves the old session valid until expiry is a privilege-escalation window with a
clock on it.

**Required:** CSRF posture stated explicitly. Either the API is token-authenticated with no
ambient credentials (say so, and enforce that no endpoint accepts cookie auth), or cookies are used
and there is a CSRF token or a strict `SameSite` posture with the exceptions enumerated. "We use
JWTs so CSRF doesn't apply" is true only if the JWT never rides in a cookie; verify rather than
assume.

**Enforcement:** tests asserting each invalidation trigger actually invalidates; a test asserting an
expired and a tampered token are both rejected; a test asserting refresh-token reuse triggers the
documented response.

### 3.8 Multi-tenant isolation and the isolation proof

Required whenever more than one customer's data shares infrastructure.

**Required:** the isolation model named — separate databases, separate schemas, shared tables with
a tenant column, or a hybrid — with the AD that chose it. Then defense in depth: the application
construction (§1.5 layer 1), the database policy (RLS or equivalent, layer 2), and the rule that
the runtime role cannot bypass the policy.

**Required:** the tenant-scoping inventory. Every table, bucket prefix, cache key namespace, queue
name or message field, search index, and log field that must carry the tenant identifier, listed.
Caches and search indexes are the ones that get missed: an authorization-correct application that
serves a cached response keyed only by resource ID is a cross-tenant leak with a very short
reproduction.

**Required:** the **isolation proof test**, which is different in kind from the authz matrix. The
matrix asserts specific known routes. The proof enumerates the schema at test time, and for every
tenant-scoped store, asserts a T1-scoped principal observes zero T2 rows. It is a completeness test
over the data model rather than the route surface, which is why it catches the table someone added
last Tuesday.

**Also required:** what is deliberately shared (a global feature-flag table, a plan catalog) and
why each shared thing cannot carry tenant data.

### 3.9 Rate limits, quotas, and instance caps as cost-DoS defense

**Required:** limits as a table with real numbers, keyed correctly. Per-IP for anonymous surfaces,
per-user for authenticated ones, per-tenant for anything billed, and per-endpoint for the expensive
ones. A single global limit protects nothing: one abusive tenant consumes it and everyone else is
denied, which converts an attack on you into an outage for your customers.

**Required:** the cost-DoS analysis specifically, because it is the one that gets skipped. For every
operation the product performs that costs money per invocation — LLM calls, image generation,
third-party API calls with per-request pricing, email sends, SMS, PDF rendering, video transcoding
— state the per-invocation cost, the per-user and per-tenant cap, what happens at the cap
(degrade, queue, or refuse — and refuse is a legitimate answer), and the alert threshold before the
cap. An unbounded expensive operation behind authentication is a credit-card attack that requires
only a free-tier signup.

**Required:** **maximum instance counts** on every autoscaling component. Autoscaling without a
ceiling converts a traffic spike into an unbounded bill and, worse, into a metastable collapse when
the scaled-out fleet exhausts a shared connection pool. The cap is a security control, not a
finance preference.

**Required:** the durability rule for counters. A quota counter in an evictable cache must fail
*toward* the durable ledger when it is missing, never toward zero. Failing toward zero means cache
eviction resets everyone's spend, which is an attack primitive as soon as anyone notices.

**Enforcement:** tests asserting the limiter returns 429 with the documented `Retry-After` at the
documented threshold; a test asserting the counter's behavior on cache miss is fail-closed; an
infrastructure assertion (a config test or a policy check) that every service has `maxInstances`
set. Plus a billing alert wired to a real destination, since the last line of cost-DoS defense is
noticing.

### 3.10 Secrets management and CI scanning

Covered as the worked example in §2.5. `SECURITY.md` additionally specifies: the secret manager by
name, the rotation cadence per secret class, who and what can read each secret (CI runners are
principals — a workflow that can print the production database password on a fork's pull request is
the compromised-dependency row of the matrix), and the rotation runbook, which must exist as a
runbook because rotation under incident pressure is not the time to design it.

### 3.11 Supply chain

**Required:** a committed lockfile for every package manager in the repo, and CI installing with the
frozen flag (`npm ci`, `pnpm install --frozen-lockfile`, `uv sync --frozen`, `bundle install
--deployment`) so a resolver never silently upgrades in a build. Enforcement is a CI grep asserting
no workflow calls a non-frozen install.

**Required:** an audit gate — `npm audit --audit-level=high`, `pip-audit`, `cargo audit`, or the
platform equivalent — as a CI job with a stated failure threshold, plus a documented process for
the unavoidable case where a high-severity advisory has no fix. That process must produce a dated
entry with an owner, not an indefinitely suppressed warning.

**Required:** pinned digests, not tags, for container base images (`FROM image@sha256:...`) and for
third-party CI actions (a commit SHA, not `@v4`). A mutable tag is an arbitrary-code-execution
primitive granted to whoever controls the tag, and CI runners typically hold the deployment
credentials.

**Required:** a postinstall/lifecycle-script posture. Either scripts are disabled by default with
an allowlist of packages that genuinely need them (`ignore-scripts=true` plus the allowlist), or the
document states why that is impractical here and what compensates. Postinstall scripts run with
developer and CI privileges at install time, before any code review has looked at the diff.

**Required:** dependency-addition policy — who reviews a new direct dependency, and the minimum bar
(maintained, non-trivial download volume, license compatible, no unexplained postinstall). Also
required: a generated SBOM if the product's customers will ask for one, which enterprise customers
do.

### 3.12 File upload handling

Required whenever the product accepts a file.

**Required:** size cap enforced at the edge before the body is buffered; content-type determined by
inspecting file content, never by trusting the client's declared `Content-Type` or the filename
extension; an extension and type allowlist rather than a deny list; a generated storage filename
that discards the user's (path traversal, null bytes, unicode direction overrides, and
case-collision on case-insensitive filesystems all enter through the original name); storage
outside the web root and served through an authorizing handler or signed time-limited URLs, never
by static path; and images re-encoded rather than passed through, which strips both metadata and
polyglot payloads.

**Required:** a decision on malware scanning with its reason, and if scanning exists, the state
machine — a file is `pending`, `clean`, or `rejected`, and `pending` files are not downloadable.
The UI needs the pending state (`deliverables-design.md` §3.3 lists it as a required FileUpload
state) which is a good check that the two documents agree.

**Required:** the serving rule — user-uploaded content is served from a separate origin, or with
`Content-Disposition: attachment` and `X-Content-Type-Options: nosniff`, so that an uploaded HTML
or SVG file cannot execute in the application's origin. SVG is the one that surprises people: it is
an executable document format.

**Enforcement:** tests uploading a polyglot file, an oversize file, a traversal filename, an SVG
with a script element, and a mismatched content type — each asserting the documented rejection or
neutralization.

### 3.13 Logging and PII

**Required:** an explicit never-log list — passwords, tokens, session identifiers, API keys, full
payment instrument numbers, government identifiers, full request bodies on authentication routes,
and the product's own sensitive data classes from §7.1. Redaction is implemented in the logger
construction so that it is on by default, not applied by each call site.

**Required:** what *must* be logged, because under-logging is also a security failure. Every
authentication attempt with its outcome, every authorization denial, every privilege or
role change, every admin and impersonation action with the acting operator's identity, every
secret access, every data export, and every destructive operation. These are the audit trail; if an
incident cannot be reconstructed, the response is guesswork.

**Required:** retention and access — how long logs live, who can read them, and whether the log
store is in scope for the deletion path (§7.2). Logs are the most commonly forgotten copy of
personal data, and "we deleted the user" is false while the logs still name them.

**Required:** the correlation identifier that ties a request through every service and job, since an
audit trail you cannot join is an audit trail you cannot use.

**Enforcement:** `tests/security/log_redaction_test.ts` (§2.5); a test asserting each required audit
event is emitted with its required fields; a CI grep for direct console/print calls outside the
logging module, since the redaction lives in the module and a bare `console.log(user)` bypasses it.

## §4 — Mobile-specific requirements

Required whenever the product ships an iOS or Android app. The premise of every rule here: **the
device belongs to the attacker in at least one row of the matrix**, and that row is not exotic — a
lost phone and a rooted phone are both ordinary.

### 4.1 Local data at rest

**Required:** an inventory of everything the app persists — files, `UserDefaults`/`SharedPreferences`,
the local database, cached API responses, cached images, analytics queues, crash-report breadcrumbs
— classified against §7.1, with the storage decision per item.

**Required, as a hard rule:** credentials, tokens, refresh tokens, encryption keys, and anything
classified confidential go in the **platform keychain/keystore** (iOS Keychain with an explicit
accessibility class; Android Keystore, hardware-backed where available), never in
`UserDefaults`/`SharedPreferences`, never in a plist or a JSON file, never in the local database
unencrypted. `UserDefaults` and `SharedPreferences` are plain files. They are readable in a device
backup and on a rooted device with no exploit involved, and this is the single most common mobile
finding in real audits.

**Required:** the iOS Keychain accessibility class stated explicitly, with its reason.
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly` versus `...AfterFirstUnlock` is the difference
between an item that survives into a backup and one that does not, and background work that needs a
token after reboot forces the weaker choice. State which constraint you accepted.

**Required:** file protection class for stored files, whether the local database is encrypted and
where its key lives (a key stored beside the database is not a control), and the app-switcher
snapshot posture for screens showing sensitive content — the OS screenshots your app on background,
and that image is on disk.

**Required:** what is excluded from cloud backup, and the mechanism.

### 4.2 Biometric gating — and what it does not prove

**Required:** a statement of what biometric gating is being used for, because there are two
completely different uses and they are frequently confused.

Biometric gating is a **local presence check**. It proves the person holding the device passed a
local check. It does **not** authenticate to your server, it does not prove identity to any remote
party, and its result is a boolean returned by the client, which the client controls. A server that
accepts "biometrics passed" as an authentication assertion has accepted a client-supplied claim.

**Required, if biometrics gate access to a stored secret:** the secret is bound to the biometric in
the keychain/keystore itself, so that the OS releases it only on a successful biometric evaluation.
That is a real control because the enforcement is in the secure element, not in an `if` statement
in your code. Say which mechanism (an access control flag on the keychain item; a keystore key
requiring user authentication).

**Required:** the enrollment-change policy. If a new fingerprint or face is enrolled on the device,
does the stored secret invalidate? The permissive answer means anyone who can add a biometric to an
unlocked device inherits the app's stored credential.

**Required:** the fallback path (device passcode, or your own credential) and its security
equivalence, plus the no-biometrics-available path.

### 4.3 Certificate pinning and its operational cost

**Required:** a decision, with reasoning, on whether to pin. This is a genuine tradeoff and the doc
must show the work rather than reflexively say yes.

Pinning defends against a compromised or coerced certificate authority and against casual
traffic interception on a device the user controls. It costs: a pinned app whose certificate rotates
without a shipped update **bricks itself in the field**, and the fix travels at app-review speed,
which is days. That is a self-inflicted outage with no server-side remedy.

**Required if pinning:** pin to the intermediate or to a public-key hash rather than a leaf
certificate; ship at least one backup pin for the next key; document the rotation runbook including
the lead time between shipping the new pin and switching the server; and provide a remote kill
switch delivered over a channel that is not itself pinned, or accept that a mistake is a store
release.

**Required if not pinning:** say so and name what carries the load instead (platform ATS/network
security config, HSTS preloading, short-lived tokens, server-side anomaly detection).

### 4.4 Deep links, URL schemes, and IPC

**Required:** an inventory of every inbound entry point — custom URL schemes, universal/app links,
share extensions, intents, notification payload actions, and pasteboard reads — with a validation
rule for each.

**Required rules:** custom URL schemes are claimable by any other app on the device, so a custom
scheme is an *unauthenticated, unauthenticated-source* input channel; prefer universal/app links,
which are domain-verified. Every deep link parameter is untrusted input validated by the same shared
schema discipline as §3.1. A deep link may navigate; it may not perform a state-changing action
without the user confirming in the app, because the link's sender is unknown. Never accept an
authentication token, a session identifier, or a redirect target through a deep link without
validating the target against an allowlist — open-redirect and token-injection both arrive this way.

**Required:** the pasteboard posture (what the app writes, whether it is marked local-only or
expiring, and whether it reads the pasteboard on launch — reading it is a privacy event on iOS with
a visible banner).

**Required:** exported components on Android enumerated with their intent filters and permission
requirements; anything exported without a reason is an entry point you did not intend.

### 4.5 Jailbreak and root posture

**Required:** a stated posture, and honesty about what it buys. Detection is a *speed bump*: it
raises the effort for casual tampering and it is defeated by anyone determined, because the code
doing the detecting runs on the machine being detected. Treat it as telemetry and friction, never as
a control that anything else depends on.

**Required:** the response behavior — refuse to run, run with a reduced feature set, or log and
continue — and its reason. Refusing to run has a real user cost (developers, security researchers,
and people with modified devices are also customers), so it needs a reason beyond reflex.

**Required, explicitly:** no server-side security decision depends on a client-reported integrity
signal. If a signal matters (a high-value transaction), use a platform attestation service
(App Attest / DeviceCheck, Play Integrity) verified server-side, and say which — attestation is
verified by the platform's servers, which is a different trust model from an `isJailbroken()`
boolean.

### 4.6 What the client must never be trusted to enforce

**Required, as a standalone rule with its own enforcement:** all authorization is server-side. A
hidden button is not a permission. A disabled field is not a validation. A client-side price is not
a price. A feature flag evaluated on the client is a UI hint, not an entitlement.

The mobile client is a *rendering and input* layer whose code, network traffic, and local storage
are all inspectable and modifiable by its user. Every rule in §3.6 applies unchanged; the mobile
section exists only to say that the mobile UI does not create an exception.

**Enforcement:** the authz matrix test (§6.3) exercises the API directly rather than through the
client, so that a server-side gap is visible even when the client hides the affordance. A matrix
driven through the UI would pass while the API remained wide open, which is precisely the bug.

### 4.7 App transport security

**Required:** TLS for all connections with no exceptions, or the exceptions enumerated with expiry
dates. On iOS, state the App Transport Security configuration and justify any exception domain — ATS
exceptions are also disclosed at review time, so an unjustified one is both a security and a
submission problem. On Android, state the network security config, including whether user-added CAs
are trusted (they should not be for production traffic) and whether cleartext is permitted for any
domain.

**Required:** the same rules for third-party SDKs, which make their own network calls. An analytics
SDK sending over cleartext is your cleartext.

### 4.8 Everything in the binary is public

**Required, as a rule with enforcement:** any key, token, endpoint, or secret compiled into the app
is published. Extracting strings from an app bundle is a one-command operation. This includes API
keys in source, keys in a plist or resource file, keys assembled at runtime from parts (obfuscation
raises the effort from one command to five minutes), and anything in the `Info.plist` or the
manifest.

**Required:** the design consequence, stated. If a third-party API requires a secret key, the app
calls *your* backend and your backend holds the key. If a third-party SDK requires a client key,
confirm the vendor treats it as public and that server-side restrictions (bundle ID allowlist,
referrer restriction, per-key scoping) are configured — and record where those restrictions are
configured, because they are the actual control.

**Enforcement:** a build-time scan of the compiled bundle (not just the source tree) for
credential-shaped strings, as a CI job on the release artifact. Scanning source misses keys injected
by the build system, which is where they usually are. Negative-test it by planting a synthetic key
in a build config and confirming the scan goes red.

## §5 — LLM-specific requirements

Required whenever the product includes a model call. The premise: **a model is a stochastic
untrusted producer whose input is frequently attacker-influenced**, and the security architecture
follows from that sentence rather than from anything about how the model works.

### 5.1 Channel separation

**Required:** an explicit statement of which channel carries instructions and which carries data,
and the mechanism that keeps them apart. Instructions come from the system prompt, which the product
controls. Everything else — user messages, retrieved documents, fetched web pages, tool results,
file contents, prior model output, database rows written by other users — is **data**, never
instructions, no matter what it says about itself.

**Required:** the mechanism. Untrusted content is delivered in a structurally distinct position
(separate message role, explicitly delimited and labeled block, or a dedicated content field), the
system prompt states that content in that position is data to be analyzed and never obeyed, and the
delimiters are escaped or stripped from the untrusted content so it cannot close its own block.

**Required, and this is the part that carries the actual security:** prompt-level separation is
mitigation, not enforcement. There is no known prompt construction that reliably resists injection.
Therefore the architecture assumes injection sometimes succeeds, and the controls that matter are
downstream: what the model can *do* (§5.4, §5.6) and what happens to what it *says* (§5.3). A
`SECURITY.md` whose LLM section is entirely about prompt wording has specified the weakest layer
and skipped the load-bearing ones.

### 5.2 Structured outputs only

**Required:** every model call that feeds a program returns a schema-constrained structure, via the
provider's structured-output or tool-call mechanism, validated against the same shared schema
discipline as §3.1. Free-text parsed with a regex is a parser you did not design being fed by an
adversary.

**Required:** the invalid-output behavior, which fails closed — retry with variation, then surface
an explicit error state. Never coerce a malformed response into a plausible default, and never let
a parse failure and a legitimate empty result render identically.

### 5.3 Model output is untrusted input before it reaches any sink

**Required:** an inventory of every sink model output can reach, with the validation applied at
each. Sinks and their rules:

| Sink | Rule |
|---|---|
| HTML rendering | Escape, or sanitize through the §3.3 single surface. Model-generated markdown containing a `javascript:` link or an image with an `onerror` handler is XSS with an unusual author |
| SQL / query construction | Never. A model does not compose queries; it selects parameters from a constrained enum, and the query is built by code |
| Shell / eval / deserialization | Never. If code execution is a product feature, it runs in a sandbox with no network, no credentials, a memory and time cap, and an ephemeral filesystem — see the `sandboxed-code-execution` skill |
| File paths | Allowlist or generated names only; never a model-supplied path |
| URLs to fetch | Through the §3.4 guarded fetcher, with no exception for "the model chose it" |
| Outbound messages (email, chat, webhook) | Recipient set is chosen by code from the authenticated context, never by the model. A model that picks the recipient is an exfiltration channel |
| Tool arguments | Validated against the tool's schema *and* re-authorized against the user's actual permissions (§5.4) |
| Logs | Redacted like any other content; model output can contain the secret it was shown |

**The exfiltration case that generalizes:** a model that can both read private context and emit a
URL (a link, an image source, a fetch) can encode the private context into that URL. This is why
markdown image rendering from model output and unrestricted outbound fetch are the two highest-value
things to lock down in any retrieval-augmented product.

### 5.4 Tool authorization — a model deciding to call a tool is not authorization

**Required, as a standalone rule:** every tool call is authorized server-side against the *user's*
permissions at execution time, through the same authorization module as §3.6. The model's decision
to call a tool is a request, identical in trust level to an HTTP request from the browser. An agent
loop that executes tool calls because the model emitted them has replaced the authorization layer
with a text generator.

**Required:** the tool inventory with, per tool: the permissions required, whether it is read-only
or mutating, its cost per invocation, its rate limit, and whether it requires human confirmation.

**Required:** human gating on expensive and destructive tools. Destructive is deletion, external
sends, payments, permission changes, and anything a user cannot undo. Expensive is anything with a
material per-call cost. The gate is a real confirmation in the UI showing the concrete action and
its arguments — not a blanket up-front "allow this agent to act" toggle, which is consent to an
unknown future action.

**Required:** the loop bound. Maximum iterations, maximum tool calls per turn, maximum wall-clock,
and the behavior at each limit. An unbounded agent loop is both a cost incident and a way to
convert one prompt injection into sustained action.

### 5.5 The prompt-injection test corpus, as a required artifact

**Required:** `tests/security/corpora/prompt_injection.txt` (or equivalent), committed, with cases
drawn from the product's own retrieval and input surfaces: instruction-override attempts in
retrieved documents, instructions hidden in HTML comments and alt text of fetched pages,
instructions in uploaded file content, instructions in a field written by a different user of the
same tenant, and attempts to elicit the system prompt or a tool credential.

**Required:** the corpus is exercised in CI against the real prompt assembly with the tool layer
mocked at the *authorization* boundary, and the assertion is behavioral: the unauthorized tool was
not invoked, the private context did not appear in output, the outbound-URL sink was not reached.
Asserting on the model's prose ("did it refuse politely") is a flaky test of the wrong property.

**Required:** the corpus grows. Every injection found in production or in review is added as a case
before the fix ships, which is the same discipline as a regression test for a bug — because it is
one.

**Note the model-drift property:** these tests are non-deterministic and a model version change can
regress them. Pin the model version, run the corpus as a gate on any model change, and treat a
regression as a blocking finding rather than noise.

### 5.6 Spend caps, per user and per tenant

**Required:** the numbers. Per-request token cap, per-user daily cap, per-tenant cap, and a global
kill switch, each with the behavior at the limit and an alert threshold below it. This is §3.9
applied to the most expensive operation most products have, and it is the control that stops one
compromised free-tier account from generating a five-figure invoice overnight.

**Required:** the counter durability rule from §3.9 applies here specifically — a spend counter in
an evictable cache must fail toward the ledger.

### 5.7 What is sent to the provider

**Required:** a statement of what data leaves for the model provider, classified against §7.1;
whether the provider is a subprocessor requiring disclosure (§7.6); the data-retention and
training-use terms as configured on the account; and the redaction applied before the call, if any.
This is both a security and a compliance artifact, and it is the one an enterprise customer asks
for first.

## §6 — Required security test suites

Each suite is a real directory with real files, mapped to a CI job with a stated exit condition.
`SECURITY.md` carries this table filled in with the product's actual paths and job names.

| Suite | Path | What it asserts | CI job | Exit condition |
|---|---|---|---|---|
| Injection corpora | `tests/security/injection_*_test.*` + `tests/security/corpora/` | SQL, XSS, command, path-traversal, and template payloads through every string-accepting boundary produce rejection or inert storage — never a 500, never a driver error, never execution | `security-tests` | Any payload producing execution, a 5xx, or a leaked internal error fails the build |
| SSRF units | `tests/security/ssrf_test.*` | Every denied network range, DNS-resolves-to-private, redirect-to-private, denied scheme, oversize response, timeout | `security-tests` | Any allowed fetch to a denied destination fails the build |
| Authz matrix | `tests/security/authz_matrix_test.*` | Every (route × role) cell asserted, including anonymous, cross-tenant, and expired session; completeness assertion over the live route table | `security-tests` | Any cell mismatch, or any route without cells, fails the build |
| IDOR / object-level | `tests/security/idor_test.*` | For every resource type, principal B cannot read or mutate principal A's record through any operation | `security-tests` | Any successful cross-principal operation fails the build |
| Tenant isolation proof | `tests/security/tenant_isolation_test.*` | Schema enumerated at test time; every tenant-scoped store returns zero foreign-tenant rows under a scoped principal; RLS enabled on every such table | `security-tests` | Any nonzero foreign-tenant read, or any tenant-scoped table without RLS, fails the build |
| Auth-by-default | `tests/security/auth_default_test.*` | Live route table minus allowlist returns 401 unauthenticated; nonzero route count asserted | `security-tests` | Any unlisted route reachable, or a zero route count, fails the build |
| Header & cookie assertions | `tests/security/headers_test.*` | CSP, HSTS, nosniff, referrer policy, permissions policy, cookie flags present with exact expected values | `security-tests` | Any missing or drifted header fails the build |
| Secret scanning | — (scanner, not a suite) | No credential-shaped strings in tree, history, or release artifact | `secret-scan` | Any finding fails the build; history scan on schedule, tree scan per PR |
| Dependency audit | — (scanner) | No advisories at or above the stated severity without a dated, owned exemption | `dependency-audit` | Any unexempted finding at threshold fails the build |
| Static greps | `scripts/security-greps.sh` | Every §2 grep pattern, run as one script with per-pattern output | `security-greps` | Any match fails the build; the script exits nonzero listing file:line |
| Log redaction | `tests/security/log_redaction_test.*` | Credentials and sensitive fields absent from emitted log output; required audit events present with required fields | `security-tests` | Any leak, or any missing audit event, fails the build |
| Prompt injection (LLM) | `tests/security/prompt_injection_test.*` + corpus | Unauthorized tool not invoked; private context not emitted; outbound sink not reached | `llm-security-tests` | Any successful injection fails the build; runs on every model-version change |
| Upload handling | `tests/security/upload_test.*` | Polyglot, oversize, traversal filename, script-bearing SVG, mismatched content type all rejected or neutralized | `security-tests` | Any accepted-and-served hostile file fails the build |
| **Enforcement negative checks** | `tests/security/negative/` | Each known-bad fixture applied; the corresponding check must go red | `enforcement-negative-check` | **Fails the build if any check passes on its known-bad fixture** |

Two rules about this table:

**The jobs are required checks.** A job that runs but is not a required status check on the
protected branch is advisory, and advisory checks are merged past. Name the branch protection
requirement explicitly, and verify it — a renamed job silently stops being required.

**The last row is the one that keeps the others honest.** Everything above it can pass vacuously.
`enforcement-negative-check` is the only job whose green means the other greens mean something.
Its own fixtures are committed, so its coverage is reviewable, and §8 requires the demonstration to
be recorded with a date.

## §7 — Compliance and legal artifacts

These are discovered missing at Phase 8's pre-flight audit — SKILL.md's blind-spot list names
"ToS/privacy artifacts" explicitly, and by Phase 8 the build plan is written and the schema is
frozen. That is too late, because two of these (the data inventory and the deletion path) are
*schema decisions*. Retrofitting a deletion path onto a schema with no ownership edges, denormalized
copies, and no soft-delete convention is a migration, not a feature.

Produce them in Phase 4. Every item is an artifact with a location, not an intention.

### 7.1 Data inventory and classification

**Required:** a table of every data element the product stores, with: the element, where it lives
(table.column, bucket, cache, log field, third-party system), its classification, its lawful basis
or business justification, its retention period, and whether it leaves the system (to which
subprocessor).

**Required:** a classification scheme with three or four named levels and a one-line definition
each — public, internal, confidential, restricted/regulated. Every element gets one. This table is
referenced by §1's impact field and §5.7, so it must exist before the threat model can be finished,
which is a useful forcing function.

**The rows that get missed:** log fields, analytics events, crash-report payloads, LLM prompt
content sent to a provider, email content in the transactional-mail provider, support-ticket
attachments, and backups. Backups especially: they are a copy of everything with an independent
retention period and their own access control.

### 7.2 Retention and deletion — the mechanism, not the policy

**Required:** for every element in §7.1, the retention period and the **actual deletion
mechanism**: the job that runs, its schedule, the query it executes, and the stores it touches.
"We delete data after 30 days" without a job is a sentence, not a control.

**Required:** the account-deletion path traced end to end. What happens to the user's rows, their
uploaded files, their cache entries, their search index documents, their analytics events, their
log lines, their entries in third-party systems, and their presence in backups. Backups are the
honest hard case: state the real answer (deleted-on-restore, or expired within the backup retention
window with the window named), because the alternative is claiming a deletion you do not perform.

**Required:** the distinction between soft delete, hard delete, and anonymization, per element, and
which one the user-facing promise refers to. Also required: what is *retained* after deletion and
why — financial records under a statutory retention period, fraud-prevention signals, a
suppression list so a deleted user is not re-marketed to — because that list needs to be in the
privacy policy and it is the detail that makes a deletion claim survive scrutiny.

**Enforcement:** a test that creates a user with data in every store, runs the deletion path, and
asserts zero remaining rows in each store enumerated from §7.1. This is the only way the path stays
correct as new tables appear, and it is exactly the isolation-proof pattern applied to deletion.

### 7.3 Subject access and export

**Required:** the mechanism by which a user obtains a copy of their data — self-serve export in the
product, or an operator runbook with a named owner and a response-time target. State the format,
the completeness scope (which of §7.1's elements are included, and which are excluded with reasons),
and the authentication required to request it. An export endpoint that returns another user's data
is a breach with a compliance label, so it gets its own matrix cells and its own IDOR test.

### 7.4 Consent and preferences, where applicable

**Required if the product uses cookies beyond strictly-necessary, sends marketing email, or
processes data on a consent basis:** where consent is recorded (a table with a timestamp, the
version of the notice consented to, and the mechanism), how it is withdrawn, and what the system
does differently when it is absent. A consent banner that sets no state and gates no behavior is a
liability rather than a control — it documents that you knew.

### 7.5 Breach notification path

**Required:** a named runbook — who declares an incident, the severity criteria, who assesses
whether notification is triggered, the notification deadlines applicable to the product's
jurisdictions and customer contracts, the contact list, the customer-communication template
location, and the evidence-preservation steps that must happen before remediation destroys the
logs. Dispatch the substance to `incident-response`; what Phase 4 must produce is the artifact's
existence and its location, because the failure mode is discovering at hour zero that nobody knows
who decides.

**Required:** log retention long enough to support an investigation, which is a §3.13 parameter that
this section constrains. A seven-day log retention makes a breach investigation impossible for any
incident discovered in week two.

### 7.6 Subprocessor list

**Required:** every third party that receives customer data — hosting, database, object storage,
email, SMS, analytics, error tracking, session replay, support desk, payment processor, LLM
provider, CDN — with what data each receives, its region, and its DPA status. Enterprise customers
ask for this list in the first security review, and session-replay and error-tracking tools are the
two that surprise teams, because both can capture far more than intended (form field contents,
tokens in URLs) unless configured not to. State the configuration.

### 7.7 Privacy policy and terms artifacts

**Required:** the location of each document and the specific facts it must assert, derived from
§7.1–§7.6 rather than from a template — the data collected, the purposes, the subprocessors, the
retention periods, the deletion mechanism, the international transfer basis, and the contact route.

**Never invent business specifics.** Company legal name, address, support email, DPO or privacy
contact, governing jurisdiction, and effective dates are supplied by the user or written as an
explicit `{{PLACEHOLDER}}`. A plausible-looking fabricated legal entity in a published privacy
policy is a worse outcome than a visible blank, because the blank gets filled and the fabrication
gets shipped. Record each placeholder as an open decision in the PRD's decisions table so it
surfaces rather than sits.

### 7.8 Platform privacy disclosures (app stores)

Required for any product shipping to the App Store or Google Play, and required *in Phase 4* rather
than at submission, because the disclosure must match what the code does and discovering the
mismatch during review costs a rejection cycle.

**Required:** the App Store privacy nutrition label content — per data type: collected or not,
linked to identity or not, used for tracking or not, and the purposes. Derived from §7.1 and from
the SDK inventory, since **third-party SDKs collect on your behalf and you disclose their
collection**. An analytics or attribution SDK is the usual source of a disclosure mismatch.

**Required:** the iOS privacy manifest content — declared API usage reasons for the required-reason
APIs the app calls, the tracking domains list, and the collected data types; plus confirmation that
every third-party SDK ships its own manifest and signature, which is a submission requirement, not
a nicety.

**Required:** App Tracking Transparency posture — whether the app tracks as the platform defines it,
and if so where the prompt appears and what happens on denial (which must be a working app, not a
degraded-to-useless one).

**Required for Play:** the Data Safety form content, the declared permissions with justifications,
and the data-deletion route the listing must expose — Play requires an in-app and a web-accessible
account-deletion path, which is §7.2 surfacing as a store requirement.

**Enforcement:** a review checklist item mapping each declared data type back to the §7.1 row and
the SDK that collects it, so the disclosure is derived from the inventory rather than composed
independently. Two independently written lists always diverge, and the divergence is found by the
store reviewer.

## §8 — Phase 4 definition of done

Every line is mechanically checkable. A line that cannot be checked without judgment does not belong
here, and a line that fails is a build blocker rather than a todo.

**Threat model**

- [ ] `docs/SECURITY.md` contains an actor × surface matrix with all eight actor rows present (or a
      row marked N/A with a stated reason and a decision ID).
- [ ] Surface columns are derived from `DESIGN_SPEC.md`; every ingress route, data store, outbound
      call, background job, and admin path in the spec appears as a column or in a column's
      enumeration.
- [ ] Mobile products additionally have local-store and IPC/deep-link columns.
- [ ] Every non-N/A cell contains all four fields: threat, impact, control, enforcement.
- [ ] Every cell's impact names a data class that exists in the §7.1 inventory.
- [ ] Domain-specific threats section exists and is non-empty.
- [ ] Every security defect found in Phase 0 appears as a cell and as a named regression test in
      `TESTS_TDD.md`.

**Enforced rules**

- [ ] Every rule carries all five fields: rule, reason, enforcement, proof, exception path.
- [ ] Zero rules whose enforcement is "code review", "training", or "documentation" alone.
- [ ] Every grep pattern appears verbatim and runs — `scripts/security-greps.sh` executes with no
      syntax error.
- [ ] Every named test path exists in `TESTS_TDD.md` as a specified suite.
- [ ] Every named lint rule ID appears in the lint configuration.
- [ ] Every named DB grant or policy appears in a migration file named in the doc.
- [ ] Every exception annotation has a matching entry in `docs/security/exceptions.md`, and the
      count check is itself a CI step.

**Negative testing**

- [ ] `tests/security/negative/` is specified with at least one fixture per enforcement mechanism.
- [ ] `enforcement-negative-check` is defined as a CI job that fails when a check passes on its
      known-bad fixture.
- [ ] Every enforcement's demonstrated-red date and observed output is recorded in
      `AUDIT_LOG.md`.
- [ ] Route-enumeration and schema-enumeration tests assert a nonzero item count, so a vacuous
      enumeration fails.

**Per-domain coverage**

- [ ] All thirteen §3 domains are present, each either specified or marked N/A with a reason.
- [ ] CSP, HSTS, cookie flags, and every other security header appear as literal values, not
      descriptions.
- [ ] SSRF section names all four required layers including the network-level egress mechanism.
- [ ] Rate limit table has real numbers keyed per-IP, per-user, and per-tenant.
- [ ] Every money-costing operation has a per-user and per-tenant cap with a number.
- [ ] Every autoscaling component has a stated maximum instance count.
- [ ] Never-log list and must-log audit-event list both present.

**Mobile** (or the whole block marked N/A: no mobile client)

- [ ] Local persistence inventory complete, with a storage decision per item.
- [ ] Keychain/keystore rule stated with the accessibility class and its reason.
- [ ] Biometric section states what it does not prove and whether the secret is OS-bound.
- [ ] Pinning decision recorded with reasoning; if pinning, backup pin and rotation runbook exist.
- [ ] Deep-link and URL-scheme inventory with a validation rule per entry point.
- [ ] Jailbreak/root posture stated, including the rule that no server decision depends on it.
- [ ] "All authorization is server-side" present as a rule with the API-level matrix test as its
      enforcement.
- [ ] Binary-secret scan specified as a CI job over the release artifact, not just source.

**LLM** (or marked N/A: no model calls)

- [ ] Channel separation mechanism stated, including the sentence that prompt-level separation is
      mitigation and not enforcement.
- [ ] Structured output required on every program-consuming call, with fail-closed behavior.
- [ ] Sink inventory complete with a rule per sink.
- [ ] Tool inventory with permissions, cost, rate limit, and human-gate flag per tool.
- [ ] "A model deciding to call a tool is not authorization" present as a rule with its enforcement.
- [ ] Loop bounds stated with numbers.
- [ ] `tests/security/corpora/prompt_injection.*` specified with behavioral assertions.
- [ ] Per-user and per-tenant spend caps stated with numbers and a kill switch.
- [ ] §5.7 provider-data statement present.

**Test suites and CI**

- [ ] The §6 table is filled in with real paths and real job names.
- [ ] Every job has a stated exit condition.
- [ ] Every job is named as a required status check on the protected branch.
- [ ] Every suite in §6 appears in `TESTS_TDD.md`; no suite exists in one document and not the
      other.
- [ ] Security suites appear in `LOOP_GOALS.md` as goals with literal exit commands.

**Compliance artifacts**

- [ ] Data inventory table exists with every element classified, including logs, analytics, crash
      reports, LLM payloads, and backups.
- [ ] Deletion mechanism specified per element — job, schedule, query, stores touched.
- [ ] Account-deletion path traced through every store, with a test asserting zero remaining rows.
- [ ] Subject access/export mechanism named, with its own IDOR test.
- [ ] Breach notification runbook location named with an owner.
- [ ] Subprocessor list complete, including analytics, error tracking, and any LLM provider.
- [ ] Privacy policy and terms locations named; every business specific is either user-supplied or
      an explicit `{{PLACEHOLDER}}` recorded as a PRD decision.
- [ ] App-store products: privacy label content, privacy manifest content, tracking posture, and
      Play Data Safety content all derived from the data inventory, with the SDK-to-data-type
      mapping shown.

**Cross-document consistency**

- [ ] Every FR the threat model references exists in `PRD.md` (caught by `scripts/id-sweep.sh`).
- [ ] Every table, route, and job the enforcement fields name exists in `DESIGN_SPEC.md`.
- [ ] No rule in `SECURITY.md` contradicts a decision in the AD table; conflicts are resolved in
      the spec, per the precedence chain, not by softening the security rule.
- [ ] `AUDIT_LOG.md` has a Phase 4 section: findings, fixes, what was deliberately not fixed and
      why, the verification pass verdict, and the negative-test demonstration record.

A package that satisfies every line above still needs Phase 8's pre-flight audit run against it by a
fresh agent. This checklist proves the document is complete; it does not prove the document is
right.
