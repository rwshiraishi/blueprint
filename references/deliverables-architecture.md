# Deliverables — architecture (Phases 2 and 5)

The acceptance contract for `docs/DESIGN_SPEC.md` (Phase 2) and `docs/EXTENSIBILITY.md` plus the
scaling designs (Phase 5). DESIGN_SPEC is the normative "how": on any conflict about mechanism it
beats every document except the PRD's intent. That authority is why its thinness is expensive — a
build agent that reads a plausible, underspecified spec will invent the missing half, and the
inventions will not agree with each other across files.

Everything here assumes **nothing exists yet**: no repo, no schema, no running service, no prior
architecture doc. If a predecessor exists, Phase 0's audit feeds this document as evidence; if it
does not, every section below is still required, sourced from the PRD and from verification you
perform now.

Scale to the tier. Sketch tier collapses this into a decisions list and a schema. Standard tier
runs every section at one worked example each. Full tier runs every section exhaustively, per
service and per table.

**The test for every section: could a competent agent implement this without asking a question?**
If a reader must choose something you left open, you have written a description, not a spec.

---

## 1. Architecture decisions (the AD table)

Architecture decisions are the load-bearing prose of the spec. They are also the section most
often reduced to a two-column table of "decision / reason", which records a preference and calls
it a decision.

**The rule: an AD with no rejected alternative is not a decision.** If nothing was seriously
considered and set aside, you have documented a default. Either find the alternative that was
genuinely in play and say why it lost, or demote the entry out of the AD table into a plain
statement of the stack.

### AD entry schema

Every AD carries all nine fields. Missing fields are the failure mode, not brevity.

| Field | What it must contain | Why it exists |
|---|---|---|
| `AD-<n>` | Stable ID, never renumbered, never reused after removal | Tests, goals, and the ID sweep reference it; renumbering silently breaks the traceability layer |
| **Decision** | One sentence, imperative, naming the concrete technology/pattern and its scope boundary | "Use Postgres" is not scoped; "Postgres 16 as the single system of record for all tenant data; no secondary write store" is |
| **Status** | `proposed` / `accepted` / `superseded by AD-<n>` | A superseded decision that is deleted takes its reasoning with it, and the same idea gets re-proposed in three months |
| **Forces** | The constraints that made this a real choice: NFR numbers, team size, budget ceiling, latency target, compliance obligation, deadline | Without forces, a later reader cannot tell whether the decision still holds when the forces change |
| **Alternatives considered** | Each candidate with a one-to-three-sentence rejection reason that is *specific and falsifiable* | "Too complex" is not a reason. "Requires a second operational datastore and a dual-write path we have no capacity to operate; the consistency bug class it introduces is the one NFR-DATA-2 forbids" is |
| **Consequences accepted** | The costs you are choosing to pay, stated as things that will actually hurt | Every architecture is a trade; a consequences list of only benefits means the trade was not examined |
| **Revisit trigger** | The observable condition that should reopen this — a metric crossing a threshold, a vendor change, a scale tier reached | Decisions rot silently. A trigger converts rot into an alert |
| **Serves** | The FR/NFR IDs this decision exists to satisfy | An AD serving no requirement is either scope creep or an undocumented requirement; both need surfacing |
| **Affects** | Sections/tables/services downstream that assume this | Makes the blast radius of a reversal visible before someone reverses it |

### Worked example (illustrative)

> **AD-004 — Background work runs on a durable queue, not in-request**
>
> **Status:** accepted
>
> **Decision:** All work that can exceed 2s wall-clock — document ingestion, export generation,
> LLM calls, outbound email — is enqueued to a durable queue with at-least-once delivery and
> processed by a separate worker pool. HTTP handlers never call an LLM provider directly.
>
> **Forces:**
> - NFR-PERF-2 sets p95 API latency at 400ms; a single LLM completion averages 3-20s.
> - NFR-AVAIL-1 requires that a provider outage degrade one feature, not the whole API.
> - The chosen host caps synchronous function execution at 10s (verified: platform limits page,
>   fetched 2026-08-19), which is below the p50 of the work in question.
> - One-person operations budget: the queue must be managed, not self-hosted.
>
> **Alternatives considered:**
> 1. *Synchronous in-request processing.* Rejected: the host's 10s execution cap is a hard ceiling
>    below the p50 of the LLM path, so this does not merely violate NFR-PERF-2, it fails outright
>    on the median request. This is the specific failure that Phase 0 recorded in the predecessor.
> 2. *Long-lived request with streaming response.* Rejected: keeps a connection per in-flight job,
>    which collapses the concurrency arithmetic in §6 (instances x concurrency vs. DB connections),
>    and gives no retry path — a dropped client connection loses the work with no record.
> 3. *Cron-polled jobs table in Postgres.* Rejected on latency and contention, not on principle:
>    a 60s poll interval breaks the FR-ING-3 "visible within 30s" requirement, and `FOR UPDATE
>    SKIP LOCKED` polling on the hot table adds write amplification to the table already flagged as
>    the highest-churn one in §2. Reconsider if queue cost becomes a top-three line item.
> 4. *Self-hosted broker (Redis/RabbitMQ).* Rejected: adds an operational component with its own
>    durability configuration to a one-person operations budget. Not rejected on capability.
>
> **Consequences accepted:**
> - Every enqueued operation must be idempotent, because at-least-once delivery will redeliver.
>   This is a real cost paid in every worker (§3 idempotency keys).
> - The UI must express in-flight state; "submit and see the result" is no longer available as an
>   interaction, and SCREENS.md owes a pending state for every affected screen.
> - Debugging spans a boundary: a request trace must carry into the worker (§7 trace boundaries).
> - Queue depth becomes a thing that can grow without bound, and therefore needs a §6 saturation
>   number and a §7 alert.
>
> **Revisit trigger:** queue cost exceeds 15% of infrastructure spend, OR p95 job latency exceeds
> 60s at steady state (meaning the worker pool, not the queue, is the constraint), OR the platform
> raises the synchronous execution cap above 60s.
>
> **Serves:** NFR-PERF-2, NFR-AVAIL-1, FR-ING-3, FR-EXP-1
>
> **Affects:** §3 (worker service boundary, DLQ), §4 (all async endpoints return 202 + job id),
> §5 (queue and worker line items), §6 (worker concurrency vs. connection ceiling), §7 (queue-depth
> SLI), TESTS_TDD (idempotency property tests)

### How many, and what belongs here

Aim for the decisions a new engineer would otherwise ask about in week one: datastore, tenancy
model, sync-vs-async boundary, auth mechanism, deployment target, framework choice where it
constrains everything downstream, and any decision that is expensive to reverse. A Standard-tier
package usually lands 8-15. Fifty ADs means the table has absorbed implementation details that
belong in the sections below; three means the table is a stack list.

**Decisions that outlive the build get promoted out of this table.** When a decision will keep
being revisited by people who never read this package — the tenancy model, the consistency
guarantee, the versioning policy — capture it with the `architecture-decision-records` skill as a
standalone ADR in the repo, and have the AD entry point at it. DESIGN_SPEC is a build contract and
gets read least once the build succeeds; ADRs are the durable record.

---

## 2. Data model

### The bar: full DDL, not an ER sketch

Ship executable `CREATE TABLE` statements with every constraint, index, and comment. An ER diagram
communicates shape; it does not communicate the twelve decisions per table that determine whether
the system is correct under concurrency. An agent handed a diagram invents those twelve, and
invents them differently in the migration than in the query layer.

For document databases (Firestore, DynamoDB, Mongo) the equivalent bar is: every collection path,
every document shape as a typed schema, every composite index as its deployable index definition
file, and every denormalization written out with the write path that maintains it. "Denormalized
for read performance" without the maintaining write path is the single most common way document
models go inconsistent.

### Per-table requirements

Every table answers all of these, in prose beside the DDL where the DDL cannot express it:

**Primary key strategy.** Which kind and why. Sequential integers leak volume and make cross-tenant
enumeration trivial. Random UUIDv4 fragments B-tree inserts and inflates index size. Time-sortable
IDs (UUIDv7, ULID) keep insert locality without leaking counts. Composite natural keys are correct
when the natural key is genuinely immutable, which it usually is not. Say which and say why — this
choice is unreversible once foreign keys point at it.

**Every foreign key and its index.** State plainly, in the document: **the database does not
automatically index the referencing side of a foreign key.** Postgres, MySQL/InnoDB, and SQLite
all create an index for the *referenced* key (it is the primary key) and none for the referencing
column. The consequences are not subtle: every `DELETE` or `UPDATE` on the parent does a sequential
scan of the child to enforce the constraint, and it takes a lock while doing so. This is the single
most reliable schema defect in generated specs, which is why the database scale audit checks it
explicitly. Every FK column gets a declared index unless you state the reason it does not need one
(the FK is the leading column of an existing composite index, and you name that index).

**Uniqueness constraints.** Every one, including partial uniqueness — `UNIQUE (tenant_id, slug)
WHERE deleted_at IS NULL` is a different system than `UNIQUE (tenant_id, slug)`, because the second
one means a deleted record blocks reuse of its slug forever. Decide, and write the decision down.

**Check constraints encoding domain invariants.** If the PRD says a score is 0-100, a discount
cannot exceed the subtotal, or an end date must follow a start date, that belongs in the schema as
a `CHECK`, not only in application validation. Application validation is enforced by whichever code
path someone remembered; a check constraint is enforced by the database against every writer
including the migration you run at 2am. Prefer the constraint that makes the illegal state
*unrepresentable* over the test that detects it.

**Nullability with reasoning.** For every nullable column, one clause on what NULL means. If NULL
means "not yet set" and NULL also means "explicitly cleared", the column is carrying two states in
one representation and every query that touches it will get one of them wrong. If you cannot state
what NULL means, the column should be `NOT NULL` with a default, or split.

**Soft versus hard delete.** Decide per table, not globally. Soft delete costs: every query needs
the predicate, every unique constraint needs the partial form, and the row keeps consuming index
space and appearing in FK checks forever. Hard delete costs: audit trail loss, cascade behavior
that must be specified per FK (`RESTRICT` / `CASCADE` / `SET NULL` — pick each one deliberately;
`CASCADE` from a tenant row is a single statement that deletes a customer's world). State the
retention rule and the purge job that enforces it, or the soft-delete flag is just a leak.

**Tenancy discriminator and row-level isolation.** For any multi-tenant product: which column
carries the tenant, whether it is on *every* table (it should be, including leaf tables reachable
only through joins — a join-derived tenancy check is one buggy query away from a cross-tenant
read), and **how isolation is enforced at the storage layer, not the application layer**. Name the
mechanism: Postgres row-level security policies with the tenant from a session variable set by the
connection pool, a separate schema per tenant, a separate database per tenant, or Firestore
security rules with the path prefix. Then state what proves it: an isolation test that authenticates
as tenant A and asserts zero rows from tenant B on every table, run in CI against a real database.
Isolation enforced only by `WHERE tenant_id = ?` in application code is enforced by developer
memory, and the security document should say so.

**Audit columns.** `created_at`, `updated_at` with the mechanism that maintains them (trigger,
ORM hook, application — pick one and only one, or they will disagree), `created_by`/`updated_by`
where accountability matters, and a version/etag column wherever optimistic concurrency is needed.
Any table a user can edit concurrently needs the version column now; adding it later means
backfilling and rewriting every update path.

**Migration and backfill path.** Even greenfield. Say how migrations run (tool, ordering,
transactional or not), whether they run automatically on deploy or as a gated step, and — for any
table expected to be large — the pattern for adding a `NOT NULL` column without a table-rewrite
lock: add nullable, backfill in batches, add the constraint `NOT VALID`, validate. Writing this
once here means the build agent does not learn it during an outage.

### The query inventory — the part that is usually missing

**An index list not derived from a query list is a guess.** Indexes are not properties of tables;
they are answers to questions. Ship the questions.

For each table, a table of every query the application will actually run:

| Query ID | Trigger | Predicate + ORDER BY + LIMIT | Expected rows scanned/returned | Index that serves it | Frequency |
|---|---|---|---|---|---|

Rules the inventory enforces:

- **Leading-column rule.** An index serves a query only if the query's equality predicates match
  the index's leading columns. `INDEX (a, b)` serves `WHERE a = ? AND b = ?` and `WHERE a = ?`; it
  does not serve `WHERE b = ?`.
- **ORDER BY servability.** If the query sorts, the index must produce that order, or the database
  sorts the whole result set before applying `LIMIT` — which is the difference between reading 20
  rows and reading two million. Column order and direction both matter.
- **Partial-index predicate matching.** A partial index only applies when the planner can prove the
  query's predicate implies the index's. `WHERE deleted_at IS NULL` in the index requires the
  literal same predicate in the query.
- **Every index appears in at least one row.** An index no query uses is pure write cost, and it
  is invisible cost — nobody notices the 8% slower inserts.
- **Every query has a serving index, or an explicit "sequential scan is correct here" note** with
  the row bound that makes it correct (a tenant-settings table with one row per tenant does not
  need an index; say so).

### Worked example (illustrative)

```sql
-- Documents belong to exactly one tenant and one uploader.
-- Highest-churn table in the system: status transitions on every ingestion step.
CREATE TABLE documents (
    id              uuid        PRIMARY KEY DEFAULT uuidv7(),   -- time-sortable: insert locality
                                                                -- without leaking row counts
    tenant_id       uuid        NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    uploaded_by     uuid        NOT NULL REFERENCES users(id)   ON DELETE RESTRICT,
    title           text        NOT NULL CHECK (length(title) BETWEEN 1 AND 300),
    storage_key     text        NOT NULL,
    byte_size       bigint      NOT NULL CHECK (byte_size > 0 AND byte_size <= 104857600),
    status          text        NOT NULL DEFAULT 'pending'
                                CHECK (status IN ('pending','processing','ready','failed')),
    failure_reason  text        NULL,  -- NULL iff status <> 'failed'; the CHECK below enforces it
    page_count      integer     NULL   CHECK (page_count IS NULL OR page_count > 0),
                                       -- NULL means "not yet extracted", never "zero pages"
    version         integer     NOT NULL DEFAULT 1,  -- optimistic concurrency, FR-DOC-7 concurrent edit
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),  -- maintained by trigger set_updated_at()
    deleted_at      timestamptz NULL,   -- soft delete; purge job hard-deletes at +30d per NFR-DATA-4

    CONSTRAINT failure_reason_iff_failed
        CHECK ((status = 'failed') = (failure_reason IS NOT NULL))
);

-- FK indexes. The database creates NEITHER of these automatically; without them every
-- tenant or user deletion sequentially scans this table while holding a lock.
CREATE INDEX documents_tenant_id_idx   ON documents (tenant_id);
CREATE INDEX documents_uploaded_by_idx ON documents (uploaded_by);

-- Q1's serving index. Supersedes documents_tenant_id_idx for reads (tenant_id leads), but that
-- index is kept for the FK enforcement path, which does not use the sort columns.
CREATE INDEX documents_tenant_live_recent_idx
    ON documents (tenant_id, created_at DESC)
    WHERE deleted_at IS NULL;

-- Q2's serving index. Partial on the two non-terminal states: the worker never scans ready/failed.
CREATE INDEX documents_pending_work_idx
    ON documents (status, created_at)
    WHERE status IN ('pending','processing') AND deleted_at IS NULL;

-- Q3. Slug-free system; title uniqueness is per tenant and only among live rows, so a deleted
-- document does not permanently reserve its title.
CREATE UNIQUE INDEX documents_tenant_title_live_uniq
    ON documents (tenant_id, lower(title))
    WHERE deleted_at IS NULL;

ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY documents_tenant_isolation ON documents
    USING (tenant_id = current_setting('app.tenant_id')::uuid);
-- Enforced at the storage layer, not in application WHERE clauses. Proof: TESTS_TDD §isolation
-- authenticates as tenant A and asserts 0 rows returned for every tenant-B row on every table.
```

| Query ID | Trigger | Predicate + ORDER BY + LIMIT | Rows | Serving index | Frequency |
|---|---|---|---|---|---|
| Q1 | Document list screen (SCREENS §3) | `tenant_id = ? AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 50` + keyset cursor | 50 | `documents_tenant_live_recent_idx` | ~30/min at tier 2 |
| Q2 | Worker claims next job | `status IN ('pending','processing') AND deleted_at IS NULL ORDER BY created_at ASC LIMIT 10 FOR UPDATE SKIP LOCKED` | ≤10 | `documents_pending_work_idx` | 1/s per worker |
| Q3 | Upload dedupe check | `tenant_id = ? AND lower(title) = ? AND deleted_at IS NULL` | 0-1 | `documents_tenant_title_live_uniq` | per upload |
| Q4 | Tenant usage rollup (nightly) | `tenant_id = ? AND created_at >= ? — SUM(byte_size)` | up to 100k | `documents_tenant_live_recent_idx` (range scan on second column) | 1/day per tenant |
| Q5 | Admin cross-tenant search | `to_tsvector(title) @@ ?` | ≤100 | **none — sequential scan, accepted**: admin-only, run <10x/day, and the table is bounded at tier 3 by the §6 capacity plan. Revisit at 5M rows. | <10/day |

Note what the inventory forces into the open: Q4 reuses Q1's index as a range scan rather than
earning its own, and Q5's missing index is a recorded decision with a revisit threshold rather than
an oversight.

### Mobile: local persistence and sync are part of the data model

A mobile app has two data models, and specifying only the server one guarantees the client one gets
invented ad hoc. Additionally required:

- **The local schema** (SwiftData/Core Data/Room/SQLite), including which server entities are
  mirrored, which are cache-only, and what the eviction rule is.
- **The sync direction and trigger** per entity: server-authoritative pull, client-authoritative
  push, or bidirectional. Bidirectional needs the next item.
- **The conflict-resolution rule, stated explicitly and per entity.** Last-write-wins by server
  timestamp, last-write-wins by client timestamp (different, and worse — device clocks lie),
  field-level merge, CRDT, or "conflicts are impossible because writes are append-only". "We'll
  handle conflicts" is not a rule. Whichever you choose, state what the user sees when a conflict
  resolves against them, because silently discarding their edit is a bug report you will not be
  able to reproduce.
- **The offline write queue**: where queued mutations live, whether they survive app termination
  (they must), their ordering guarantee, and the retry/expiry policy for a mutation whose server
  precondition no longer holds.
- **Migration of the local store** across app versions, including the downgrade case when a user
  installs an older build from TestFlight.

---

## 3. Service and pipeline design

### The boundary list

Enumerate every deployable unit and every logical module inside it. For each: **what it owns** —
stated as the data it is the sole writer of. Two components writing the same table is not a service
boundary, it is a shared mutable global with network latency. If two components must write the same
data, say which one owns it and how the other one asks.

Per boundary: name, deployment shape (long-running service, serverless function, worker pool,
scheduled job, client), the data it exclusively writes, the data it reads from others, and its
scaling parameters (min/max instances, concurrency per instance).

### Edges: synchronous versus asynchronous, declared

Draw every edge between boundaries and label it `sync` or `async`. The label is a commitment: a
sync edge means the caller's latency includes the callee's latency and the caller's availability is
bounded by the callee's. Multiply the chain out and put the number in §6.

For each edge, the contract:

- **Interface**: the exact request and response shape (reference the §4 endpoint, or the queue
  message schema with its versioning field).
- **Timeout**: a number. Every sync call has a client-side timeout shorter than the caller's own
  deadline, or the caller inherits the callee's worst case.
- **Idempotency key**: what makes a retry safe. For queue messages, the key is derived from the
  work, not generated per delivery — a UUID minted at publish time is correct, a UUID minted at
  consume time is a bug that produces duplicates under redelivery. State where the dedupe record
  lives and how long it is retained (retention must exceed the maximum retry window, or a late
  redelivery duplicates).
- **Retry and backoff policy with bounds**: max attempts, base delay, multiplier, jitter (required
  — synchronized retries from many instances are a self-inflicted thundering herd), and the
  **short-circuit rule for deterministic failures**. Retrying a 400 five times with exponential
  backoff is five identical failures and a slower error message. Classify errors into retryable
  (5xx, timeout, 429, connection reset) and terminal (4xx other than 429, schema validation
  failure, business-rule rejection) and route terminal failures straight to the DLQ.
- **Dead-letter handling**: where failed messages land, what fields are recorded with them (original
  payload, attempt count, last error with stack, first-seen and last-attempt timestamps), the alert
  that fires on DLQ depth, and — the part usually missing — **the replay procedure**, including
  whether replay is safe given the idempotency key and who is allowed to trigger it.
- **Failure semantics: what the caller sees.** For every edge, the caller-visible outcome of each
  failure class. This is the section that makes error handling designable rather than improvised:

| Failure | Caller sees | Retryable by caller | User-visible copy |
|---|---|---|---|
| Callee timeout | 504, `Retry-After: 5` | yes | "Taking longer than expected. Retrying." |
| Callee 5xx | 502 | yes, with backoff | same |
| Callee rejects input | 422 with field errors, passed through | no | field-level validation message |
| Queue publish fails | 503, nothing enqueued | yes | "Couldn't start. Try again." |
| Worker exhausts retries | job row `status='failed'`, `failure_reason` set, DLQ entry | no (support replay) | "Processing failed: {reason}" + support path |

### Transactional boundaries — and what is explicitly not transactional

State, per operation, what is inside one database transaction and what is not. Then state the
consequence of the not.

The dominant case in any system with a queue or an external API: **the database write and the
external effect are not atomic**. Writing a row and publishing a message are two systems; a crash
between them leaves one done. Pick and document the resolution:

- **Transactional outbox** — write the message to an outbox table inside the same transaction as
  the row, and a relay publishes it. At-least-once, ordered, no lost messages, at the cost of a
  relay component and a polling interval.
- **Publish-then-write** with a reconciliation job that detects orphaned messages.
- **Accept the gap** with a stated, bounded consequence and a detection query.

Whichever you pick, write down: what a crash at each point leaves behind, and what cleans it up.
"We use transactions" is not an answer when half the operation is an HTTP call.

Also state explicitly, as its own list: **operations that span multiple services and are therefore
not atomic at all**, with the compensating action for each partial failure. A signup that creates a
tenant row, a Stripe customer, and a mailing-list subscriber has three failure points and needs
three answers, not one `try/catch`.

### Code-level sketches

For each non-obvious pipeline, a sketch in the target language: the function signature, the order
of operations, the error branches, and the logging calls. Not a full implementation — enough that
the ordering of the idempotency check, the transaction, and the publish is unambiguous, because
that ordering is where the bugs are. A prose description of a pipeline reliably loses the ordering.

---

## 4. API surface

### Per endpoint

| Field | Requirement |
|---|---|
| Method + path | Exact, including path params with their types and formats |
| Purpose | One line, and the FR ID it serves |
| Auth requirement | Which credential, and the **role matrix**: every role x this endpoint = allow/deny/allow-with-filter. Enumerate roles; do not write "admin or owner" and leave the other four roles unstated |
| Request schema | Full: field, type, required, constraints, default. As a schema artifact (OpenAPI/JSON Schema/zod) where possible, so the validator is generated rather than written twice |
| Response schema | Full, per status code. Including the shape of the success envelope and whether it differs by status |
| Error codes | **Every one**, with trigger and body shape (below) |
| Rate limit | The number, the window, the key it is counted against (per user? per tenant? per IP? — they behave very differently under a shared NAT), and the response when exceeded, including `Retry-After` |
| Idempotency | Whether the endpoint is idempotent by nature; if not, whether it accepts an `Idempotency-Key` header, how long keys are retained, and what a replay with the same key returns (the original response, replayed — not a 409, unless the body differs, which is a 422) |
| Pagination | The contract (below) |
| Versioning | How this endpoint changes without breaking clients (below) |

### Error responses are half the contract, and the half that gets skipped

A spec that lists happy-path responses and one generic error shape has specified about half of what
the client must handle, and it is the half that determines whether the product feels solid or
flaky. Mobile clients in particular cannot patch quickly; an unhandled error shape ships for weeks.

For every endpoint, an error table:

| Status | `code` | Trigger | Body | Client should |
|---|---|---|---|---|
| 400 | `malformed_request` | Body is not valid JSON | `{error:{code,message}}` | fix and do not retry |
| 401 | `unauthenticated` | Missing/expired token | same | refresh token once, then sign out |
| 403 | `forbidden` | Authenticated, role lacks permission | same | show permission message; do not retry |
| 404 | `not_found` | ID absent **or belongs to another tenant** | same | do not distinguish — see below |
| 409 | `version_conflict` | `If-Match`/version mismatch | `{error:{code,message,current_version}}` | refetch and re-present |
| 422 | `validation_failed` | Schema-valid, rule-invalid | `{error:{code,message,fields:[{path,code,message}]}}` | field-level display |
| 429 | `rate_limited` | Over limit | `{error:{code,message,retry_after_s}}` + `Retry-After` | back off per header |
| 503 | `dependency_unavailable` | Downstream out | same + `Retry-After` | retry with backoff |

Two rules that belong in the document text, not just the table:

- **404 and 403 must not be distinguishable across a tenancy boundary.** Returning 403 for a
  resource that exists in another tenant and 404 for one that does not exist is an enumeration
  oracle. Return 404 for both. State this once, apply everywhere, and put it in SECURITY.md too.
- **Error bodies never leak internals.** No stack traces, no SQL, no upstream provider messages
  passed through verbatim. The correlation ID goes in the response so support can find the detail
  in the logs; the detail does not go in the response.

### Pagination contract

Pick one and apply it everywhere; two pagination styles in one API is a permanent client tax.

Offset pagination is acceptable only for bounded admin lists — it drifts under concurrent inserts
(an item shifts across a page boundary and the client never sees it) and degrades as offset grows,
because the database still walks the skipped rows. Keyset/cursor pagination is the default for
anything user-facing and growing: state the sort key, that the sort key must be unique or
tie-broken by the primary key (a non-unique sort key silently skips rows at page boundaries),
whether cursors are opaque, and whether they expire.

Specify: default page size, max page size, the parameter names, the response envelope
(`{data:[...], next_cursor: "..."|null}`), and whether a total count is available — total counts on
large tables are expensive and are usually the reason a list endpoint is slow.

### Versioning policy

State the mechanism (URL path segment, header, or content negotiation), what counts as a breaking
change (removing a field, narrowing a type, adding a required request field, changing an error code
— all breaking; adding an optional response field is not, provided clients are specified to ignore
unknown fields, which must be stated), the deprecation window in real units, and how a deprecated
version is announced and measured (you cannot retire v1 without knowing who still calls it, so the
per-version request metric is part of the policy, not an afterthought).

### Offline and mobile considerations

A mobile client is not a browser with a smaller screen; it is a partially-connected replica. Specify:

- **What the client caches**, per resource, with the TTL and the eviction rule. Anything not listed
  is not cached, and the client shows a loading state instead of stale data.
- **What the client queues** when offline: which mutations are queueable, their local optimistic
  representation, and what the UI shows for a pending-but-unsynced item (it must be visually
  distinct from a synced one — a fake and a real state must not render identically).
- **How the server signals staleness**: `ETag`/`If-None-Match` for conditional GETs, a
  `updated_since` cursor for delta sync, and a version or minimum-supported-client field that lets
  the server tell an old build to upgrade rather than fail cryptically.
- **The forced-upgrade path**: the endpoint or field that carries a minimum client version, and the
  client behavior when it is below it. Without this, a breaking server change bricks old installs
  with a parse error.
- **Payload size and battery**: which endpoints are called on app foreground, and the budget for
  that burst. A cold start that fires nine parallel requests is a spec decision, made here or made
  accidentally.

---

## 5. Cost model

### The hard rule on prices

**Every price is fetched from a primary source today, and the source URL and fetch date are
recorded beside the figure.** A price that could not be fetched is recorded as **"could not
verify"** with what was attempted. It is never estimated silently, and it is never a remembered
number with today's date stamped beside it — that produces a document that looks verified and is
not, which is worse than an obvious gap because it survives review.

Cloud prices change, free tiers get restructured, and per-unit LLM pricing has moved by an order of
magnitude within single years. A remembered price is a guess wearing a citation.

### Per line item

| Field | Requirement |
|---|---|
| Line item | The specific SKU, not the product family: instance class and region, storage class, model name and context tier |
| Unit price | The number with its unit, exactly as the vendor states it |
| Source URL | Direct link to the pricing page or calculator |
| Fetch date | The date you actually loaded it |
| Assumed volume | The number |
| **Basis of the assumption** | Where the volume came from: an FR, a measured predecessor metric, a competitor benchmark, or "assumption — unvalidated", which is an honest and useful label |
| Resulting figure | Monthly cost, arithmetic shown |

The basis column is the one that gets dropped and the one that matters. A cost model is a chain of
assumptions with a dollar sign at the end; without the basis, a reader cannot tell which assumption
to attack when the number looks wrong.

### Per-scale-tier tables

Produce the full table at each tier from §6 (typically: launch, 10x, 100x). The purpose is not the
totals, it is the **shape change** — which line item overtakes which, and where. A model with one
tier cannot show that the LLM line passes the entire infrastructure line somewhere between tier 1
and tier 2, which is the most decision-relevant fact in most cost models.

Report per-tier: total, cost per tenant, cost per active user, and cost per unit of the product's
core action. Cost per unit is what tells you whether the pricing in the PRD survives.

### Floors that do not scale down

Name every cost that exists at zero usage: minimum instance counts, provisioned database and its
minimum size, reserved IPs, log retention, monitoring seats, domain and certificate costs, the paid
tier of anything used at all, and per-seat developer tooling. Sum them. That sum is the monthly
cost of the product existing with no customers, and it is the number that determines runway. It is
also routinely absent from cost models that report only marginal cost.

### Levers, ranked by savings per unit of architectural damage

A list of optimizations is not useful; a ranking by what it costs you to take them is.

| Lever | Monthly saving | Architectural damage | Reversible? | Take when |
|---|---|---|---|---|
| Cache LLM responses on exact-input hash | high | low — a pure addition, needs an invalidation rule | yes | immediately |
| Drop to a smaller model for classification steps | high | low, gated on eval scores holding | yes | eval gate passes |
| Batch API where latency permits | medium | medium — changes the UX contract for those flows | partly | tier 2 |
| Reserved/committed-use pricing | medium | none technically, but locks spend | no, for the term | volume is predictable |
| Self-host the queue | low | high — adds an operational component | no, practically | never at this team size |

The point of the "damage" column is to stop the model from recommending, in a flat list, both a
free cache and a rewrite.

### The two or three things that break the model

Not risks in general. The specific mechanisms by which this model becomes wrong, each with a
**monitored guard and threshold**:

1. **Price cliff** — a free tier or committed-use discount ends and the line steps rather than
   slopes. Guard: an alert on approaching the tier boundary (usage as a percentage of the included
   allowance), threshold at 80%.
2. **Per-unit feature that explodes at volume** — a feature priced per request that is called
   inside a loop somewhere. Guard: cost per core action tracked as a metric, alert on a percentage
   change week over week rather than an absolute value.
3. **Drifting assumption** — the volume basis was a guess and reality differs. Guard: the actual
   value of each assumed volume emitted as a metric with the assumed value as the comparison, so
   the model self-checks in production rather than in a quarterly review.

A "thing that breaks the model" without a guard is a paragraph nobody reads again.

---

## 6. Capacity plan

For each scale tier, arithmetic — not adjectives. "Scales horizontally" describes a hope; a
capacity plan describes a ceiling.

### Concurrency arithmetic against every downstream ceiling

The recurring failure: an autoscaling tier multiplied out against a fixed downstream limit,
discovered in production. Do the multiplication here.

```
API tier:    max_instances 20 x concurrency 80          =  1,600 concurrent requests
Worker tier: max_instances 10 x concurrency  4          =     40 concurrent jobs

DB connections needed:
  API:    20 instances x pool_size 5                    =    100 connections
  Worker: 10 instances x pool_size 2                    =     20 connections
  Migrations/admin/reserve                              =     10 connections
                                                   total = 130

DB connection ceiling (managed instance, verified against the vendor's
limits page — record URL and fetch date)                 =    120  <-- BREACH at max scale
```

That breach is the deliverable. Resolve it explicitly: add a connection pooler in transaction mode
(and then state, per §2, what breaks under transaction pooling — session-scoped state, `LISTEN`/
`NOTIFY`, advisory locks, prepared statements, `SET` per connection), or cap instances below the
arithmetic, or raise the instance class. Whichever, the number that constrains the system is now
written down instead of discovered.

Run the same multiplication against every downstream ceiling, not just the database: third-party
API rate limits (requests/min against your max concurrency), provider token-per-minute quotas,
file-descriptor and socket limits, storage IOPS, and any per-account service quota. Each one gets
its arithmetic and its verified limit with source and date.

### Saturation point of each stage

For every stage in the request and job paths: its service rate (units/sec at the configured size),
the arrival rate at each tier, and the utilization ratio. Note where utilization crosses ~70%,
because queueing delay rises non-linearly past there — a stage at 85% utilization has roughly
double the queue delay of one at 70%, and the graph looks fine right up until it does not.

### Where backpressure lives

For each stage boundary, what happens when the downstream stage cannot keep up. There are exactly
four honest answers: block the producer (bounded), shed load (reject with 429/503), buffer with a
**bounded** queue and a documented drop or reject policy at the bound, or degrade the operation to
a cheaper form. "Buffer" without a bound is not backpressure — it relocates the failure into memory
exhaustion or unbounded queue growth, and the unbounded queue is the classic path to metastable
collapse, where the system does not recover after load subsides because the backlog keeps it
saturated.

State it per boundary, with the bound.

### The first component to break, and at what number

Close the section with a ranked list:

| Rank | Component | Breaks at | Symptom | Mitigation | Lead time |
|---|---|---|---|---|---|
| 1 | DB connections | 1,400 concurrent req (~87% of API max) | `too many connections`, cascading 500s | pooler in transaction mode | ~1 day |
| 2 | LLM provider TPM quota | ~40 jobs/min sustained | 429s, queue depth climbs, jobs age | request quota increase; second provider | ~1 week vendor lead |
| 3 | Worker pool | 55 jobs/min arrival | queue depth grows unbounded, latency SLO breached | raise max instances (re-run §6 arithmetic — it moves ceiling 1) | minutes |
| 4 | Single-writer counter row | ~200 writes/sec to one tenant row | lock convoy, write latency spike | shard counters or move to append-and-aggregate | ~2 days |

The lead-time column is what makes this actionable: a mitigation with a one-week vendor lead time
must be started before the threshold, not at it. And note that raising ceiling 3 moves ceiling 1 —
capacity ceilings interact, and the plan should say so rather than treating them as independent.

---

## 7. Observability

Observability designed after an incident is designed by the incident. Specify it here.

### SLIs

Each SLI: the exact measurement, where it is measured, and the events it counts. "Availability" is
not an SLI. "The proportion of HTTP requests to `/api/*`, excluding 4xx-other-than-429, that return
a non-5xx status, measured at the load balancer, over a 28-day rolling window" is. Measurement
location matters: a success rate measured inside the application cannot see the requests that never
arrived.

### SLOs with error budgets

Per SLI: the target, the window, and the resulting error budget in units a human feels — "99.5%
over 28 days = 3h 36m of downtime, or 50,000 failed requests at current volume". Then the burn-rate
policy: what happens at 2x burn (page), at 10x burn (page and halt deploys), and what happens when
the budget is exhausted (feature work stops until it recovers). An SLO with no consequence attached
is a dashboard label.

### Required structured-log fields

Every log line, every service, non-negotiable, so that queries work across boundaries:

`timestamp` (RFC3339, UTC) · `level` · `service` · `version` (build SHA) · `trace_id` · `span_id` ·
`request_id` · `tenant_id` · `user_id` (nullable, and null on unauthenticated paths — not omitted)
· `route` · `status` · `duration_ms` · `event` (a stable machine-readable name, not a prose message)
· `error.type` / `error.message` / `error.stack` where applicable.

Plus the rules: **no secrets, tokens, passwords, full payloads, or PII beyond the ID fields** — with
the CI grep or redaction middleware that enforces it named here, because "don't log PII" without a
mechanism is enforced by memory. And the cascade rule from the operating principles: every step of a
multi-step pipeline logs its inputs' shape, its output, the branch taken, and every near-miss
(validation rejection, empty result, cache hit/miss, fallback trigger). If diagnosing a failure
requires adding logging afterward, the logging was underspecified here.

### Trace boundaries

Where a trace starts (edge, with the incoming header propagated if present), and — the part usually
missing — **how the trace crosses the async boundary**: the trace context is a field in the queue
message, and the worker continues the trace rather than starting a new one. Without this, every
async system's traces stop at the enqueue, which is exactly where the interesting latency begins.
List every propagation point.

### Alerts

Per alert: name, condition with threshold and duration, severity, **what it actually means in one
sentence**, and the runbook link. An alert whose meaning is not written down gets acknowledged and
ignored within a month.

| Alert | Condition | Sev | Means | Runbook |
|---|---|---|---|---|
| API error rate | 5xx > 1% for 5m | page | Users are seeing failures now | `runbooks/api-errors.md` |
| Queue depth | depth > 1,000 for 10m | page | Workers cannot keep up; §6 ceiling 3 | `runbooks/queue-backlog.md` |
| DLQ non-empty | any message > 15m | ticket | Work permanently failed; needs triage/replay | `runbooks/dlq.md` |
| DB connections | > 85% of ceiling for 5m | page | Approaching §6 ceiling 1 | `runbooks/db-connections.md` |
| Cost per action | +40% week-over-week | ticket | §5 model breaking | `runbooks/cost-drift.md` |
| Heartbeat missing | no beat for 3 intervals | page | **The monitoring is dead** | `runbooks/heartbeat.md` |

Alert on symptoms users feel and on leading indicators tied to a §6 ceiling. Alerting on CPU
produces pages nobody can act on.

### The heartbeat, measured independently

**A monitor that dies silently reports healthy.** If the alerting path depends on the system it
watches — the metrics pipeline emitting, the same host, the same region, the same credential — then
a total failure produces silence, and silence is indistinguishable from health.

Require a heartbeat emitted on a fixed schedule and checked by something outside the system: an
external uptime service, a separate provider's scheduled check, a dead-man's-switch service that
alerts on *absence*. State which component emits it, what independent thing checks it, and — this
is the part the pre-flight audit checks — **that it has been demonstrated failing at least once**.
A monitor never observed going red is passing vacuously.

### Client-side error tracking and crash reporting

Server observability sees zero of the failures that happen before the request: JS bundle errors,
render crashes, offline queue corruption, and every native crash. Required:

- Crash reporting for mobile with symbolication set up as part of the build pipeline (unsymbolicated
  crash reports are unreadable, and the dSYM upload step is the one that gets forgotten), plus the
  crash-free-session rate as a tracked SLI.
- Frontend error tracking with source maps uploaded per release and errors tagged with the release,
  so a regression is attributable to a deploy.
- **Release-version tagging on every client event**, because the first question about any client
  error is which build, and the second is what percentage of that build's sessions.
- The sampling and privacy rule: what is captured from a user's session, what is scrubbed before
  transmission, and the consent posture. This is a privacy surface and belongs in SECURITY.md too.

---

## 7.5 Integrations

`document-set.md` requires DESIGN_SPEC to carry integrations, and they are the most common source
of a build stalling on something nobody wrote down. One entry per external service the product
depends on — payment, auth provider, email, storage, model provider, analytics, anything with an
API key.

**Required per integration:** the vendor and the specific product tier; the auth mode (API key,
OAuth, service account) and where the credential lives per `SECURITY.md` §3.10; whether a sandbox
or test mode exists and how a local build reaches it; the rate limit and quota **as fetched
numbers with their source URL and fetch date**, per §5's price rule — a rate limit from memory is
the same defect as a price from memory; the failure semantics (what the product does when this
service is down, slow, or returns an error — degrade, queue, or fail the request, stated); and
**what breaks if this vendor disappears**, with the migration cost in one sentence.

**Required once:** the integration that is hardest to replace, named. Every product has one, and
knowing which it is before the build is the difference between a considered dependency and an
accident.

**Definition of done:** every integration has all six fields; every rate limit carries a source URL
and fetch date or is marked "could not verify"; every integration names a sandbox path or states
explicitly that local development cannot reach it, which is a `BLOCKERS.md` entry waiting to
happen and should be written now.

## 7.6 Verification backlog — the ⚠ list

Every claim the spec rests on that could not be verified against a primary source today. This is
the honest counterpart to the verify-never-assume rule: the rule cannot mean "delete anything
unverifiable", so it means "list it, mark it, and give it a fallback."

| ⚠ | Claim | Why unverified | Fallback in force | Re-check trigger |
|---|---|---|---|---|
| ⚠1 | {{"provider X supports Y"}} | {{docs ambiguous / needs an account}} | {{the design that works either way}} | {{before goal G-x.y}} |

**Required:** every ⚠ has a fallback that is *actually designed*, not "we'll figure it out" — the
architecture must work if the claim turns out false, or the claim is a blocker rather than a ⚠.
And every ⚠ has a re-check trigger naming a goal, so it is re-verified at the moment it starts to
matter rather than at the moment it breaks.

**Definition of done:** no ⚠ without a fallback; no ⚠ without a trigger; every ⚠ referenced from
the goal its trigger names, so a build agent reaching that goal sees it.

## 7.7 Build plan — the numbering `LOOP_GOALS.md` mirrors

The section Phase 7 converts into goals. `document-set.md` §Numbering states that goals are
`G-<phase>.<n>` **matching the build plan's deliverable numbering**, which means this section
defines that numbering. Get it wrong and every goal ID in the package is arbitrary.

**Required:** phases numbered `1..n`, each with deliverables numbered `<phase>.<n>`. Per
deliverable:

- **Scope** — one sentence: what exists when this is done that did not before.
- **Depends on** — other deliverable numbers only. This is the source of the dependency graph; a
  cycle here becomes a cycle in the goals and is caught by the pre-flight audit far too late.
- **Lands** — the `FR-`/`NFR-` IDs this deliverable satisfies. Every P0 FR appears in exactly one
  deliverable's Lands list. An FR in none is unbuilt; an FR in two is a scope collision.
- **Demo** — the thing you can show a human when it is done. Not a test result: a behavior. This
  is what stops a phase from being "the plumbing works" three times in a row.

**Ordering rules.** The kernel goes first — the tenant-context wrapper, the auth boundary, the
money path — because everything depends on it and retrofitting it touches every file. Anything
needing a human-provided prerequisite (`CLAUDE.md` §5) goes as late as its dependencies allow. Any
deliverable carrying a ⚠ from §7.6 is scheduled after the re-check that clears it, or carries its
fallback design explicitly.

**Definition of done:** every P0 FR appears in exactly one Lands list; every Depends-on resolves to
a deliverable that exists; the graph is acyclic (`scripts/goal-graph.sh --check`, which ships with this skill);
every deliverable has a Demo that is a behavior, not a passing test; the kernel is deliverable 1.x;
no phase-1 deliverable depends on a human prerequisite.

## 8. EXTENSIBILITY.md (Phase 5)

Short document, high leverage. It exists to answer one question before it is asked under deadline
pressure: *where does customer-specific work go?* Without an answer, it goes into the kernel as an
`if (tenant === 'acme')`, and every one of those is permanent.

**The governing rule, stated at the top of the document: custom work lands in a named surface, or
it does not land.** A request that fits no surface is either a new surface (designed, versioned,
documented) or a decline. Both are acceptable; "just this once in the core" is not.

### The fixed kernel, enumerated explicitly

List the components that are not extensible, by name. Typically: the data model and its migrations,
the authentication and authorization path, the tenancy isolation mechanism, billing and
entitlement enforcement, audit logging, and the core domain invariants.

State why each is fixed. The reason is nearly always the same and worth writing anyway: these are
the components where an extension could violate an invariant that other components trust, and a
violated invariant does not fail locally.

### Extension surfaces

For each surface:

| Field | Requirement |
|---|---|
| Name and ID | Stable |
| What it lets you change | Concrete, with the boundary of what it cannot reach |
| Interface contract | The actual signature/schema, versioned, with the compatibility policy |
| Lifecycle | Registration, initialization order, activation/deactivation, upgrade, removal — including what happens to data the extension created when it is removed |
| Invocation | When it runs, whether sync or async, ordering when several are registered, and whether ordering is deterministic (it must be — non-deterministic ordering makes behavior irreproducible) |
| Isolation guarantees | Timeout, memory/CPU bound, what it may access (its own config, the event payload) and what it may not (the database, other tenants' data, the network unless allowlisted, secrets) |
| Failure semantics | What happens when it throws, times out, or returns garbage. **Default: the extension fails, the core operation continues**, with the failure recorded and surfaced to the tenant. An extension that can fail a core write is not isolated |
| Observability | Extensions emit the standard log fields plus their extension ID; their latency counts separately in traces so a slow extension is attributable |
| Testing | The contract test every implementation must pass before registration |

### Tenant configuration governance

Every threshold and constant in the spec is tenant configuration with a recorded default —
hardcoded values are a named anti-pattern in this method. That creates a governance obligation:

- **The registry**: every configurable key, its type, its default, its valid range or enum, whether
  it is tenant-settable or operator-only, and the FR/AD it derives from.
- **Validation**: schema-validated at write time, not read time. A configuration that fails at read
  time fails inside a request, for one tenant, at an unpredictable moment.
- **Locked keys**: the settings tenants cannot change because they encode safety or correctness
  semantics — status colors and confidence encodings from the design system, retention minimums,
  isolation parameters. Locked is a property in the registry, enforced in code, and tested.
- **Change audit**: who changed which key, from what, to what, when. Configuration changes are the
  uncorrelated cause of half of all "nothing changed and it broke" incidents.
- **Defaults are versioned**: when a default changes, existing tenants keep the old value unless
  they never set one explicitly. State this rule, because the alternative — a default change
  silently altering live tenant behavior — is a category of incident that is very hard to diagnose.

### At least one worked module example

An end-to-end example of a real extension against a real surface: its manifest/registration, its
configuration schema, its implementation sketch, its contract test, and its failure behavior
demonstrated. One worked example prevents more misinterpretation than three pages of interface
description, because it fixes the things prose leaves ambiguous — where files live, how
registration is discovered, what the config looks like on disk.

### What is deliberately NOT extensible, and the escalation path

A list of the requests you expect and will decline, each with what to do instead:

| Request | Why not | Instead |
|---|---|---|
| Custom database tables per tenant | Breaks migrations, isolation proofs, and backup/restore | Structured JSONB in the extension's own namespaced column, schema-validated at write |
| Custom auth provider per tenant | Auth is kernel; a bug is cross-tenant | Standard SSO surface (OIDC/SAML) — if it does not fit, it is a roadmap item |
| Arbitrary code in the request path | No isolation story at this size | Async webhook surface, which is isolated by construction |
| Override a locked semantic token | Safety semantics; a themed status color is a misread status | Decline. Escalate to a design-system change if genuinely wrong for everyone |

Then the escalation path: who decides that a declined request becomes a new surface, what evidence
is required (how many tenants, what revenue, what the alternative costs), and the fact that a new
surface is a versioned interface with a support obligation, not a patch. The path matters because
without one, "no" is unstable under commercial pressure and the exception lands in the kernel
anyway.

### Scaling designs (the other Phase 5 deliverable)

Two axes, and specifying only one is the common miss:

- **Data volume**: table growth curves, partitioning or archival strategy with the trigger row
  count, index size against memory, backup and restore *duration* at each tier (a restore that
  takes 14 hours is an availability fact, not a storage fact), and every unbounded-growth table
  named with its retention rule.
- **Users and subscribers**: stateless auth so instances are interchangeable, the read-path ceiling
  and the read-replica step with its replication-lag consequence for read-after-write, realtime
  fan-out (subscriptions per view, which is usually the largest connection population in the
  system), tenant packing into cells with a provisioning path that never builds new infrastructure
  per tenant, entitlements as data so a plan change is a row update rather than a deploy, billing
  wiring, and concurrency correctness at high seat counts (optimistic versioning, alert digesting
  so 400 seats do not generate 400 notifications for one event).

---

## 9. Definition of done — Phases 2 and 5

Each line is mechanically checkable. Do not mark the phase complete on impression.

**Architecture decisions**
- [ ] Every AD has all nine fields populated; no field is "TBD".
- [ ] Every AD lists ≥1 rejected alternative with a specific, falsifiable reason. Zero ADs read
      "no alternative considered".
- [ ] Every AD's `Serves` cites at least one FR or NFR ID that exists in the PRD (verified by
      `scripts/id-sweep.sh docs`).
- [ ] Every AD has a revisit trigger that is an observable condition, not "when it becomes a
      problem".
- [ ] Decisions that outlive the build are captured as ADRs and referenced from the AD entry.

**Data model**
- [ ] DDL is executable: it runs against an empty database without error (run it).
- [ ] Every FK column has a declared index, or a written reason it does not need one.
- [ ] Every nullable column has a stated meaning for NULL.
- [ ] Every table declares soft-vs-hard delete, and every soft-delete table has a purge job and a
      retention number.
- [ ] Every table carries the tenancy discriminator, and the isolation mechanism is named at the
      storage layer with the test that proves it.
- [ ] The query inventory lists every query; every query maps to a serving index or a written
      "sequential scan is correct, bounded at N rows".
- [ ] Every declared index appears in at least one query row.
- [ ] Mobile: local schema, sync direction, conflict rule, offline queue durability, and local
      migration path are all specified per entity.

**Services and pipelines**
- [ ] Every service names the data it exclusively writes; no table has two writers.
- [ ] Every edge is labeled sync or async and carries timeout, idempotency key, retry bounds with
      jitter, terminal-error short-circuit, and DLQ destination.
- [ ] Every edge has a failure-semantics row stating what the caller sees.
- [ ] Every DLQ has a replay procedure and an alert.
- [ ] Transactional boundaries are stated, including an explicit list of what is not transactional
      with its compensating action.
- [ ] Every non-obvious pipeline has a code-level sketch showing operation ordering.

**API**
- [ ] Every endpoint has a complete role x endpoint matrix covering every declared role.
- [ ] Every endpoint lists every error code with trigger, body shape, and client action.
- [ ] 404-not-403 across tenancy boundaries is stated and applied.
- [ ] Pagination is one style, specified with sort key, tie-break, and max page size.
- [ ] Versioning policy states what is breaking, the deprecation window, and the per-version usage
      metric.
- [ ] Rate limits state the number, window, and counting key.
- [ ] Mobile/offline: cache list with TTLs, queueable mutations, staleness signal, forced-upgrade
      path.

**Cost**
- [ ] Every line item has unit price + source URL + fetch date; every unfetchable price reads
      "could not verify" with what was attempted. Zero prices from memory.
- [ ] Every assumed volume states its basis, including "assumption — unvalidated" where true.
- [ ] Tables exist for every §6 scale tier; per-tenant, per-user, and per-core-action costs are
      reported.
- [ ] Floors that do not scale down are enumerated and summed.
- [ ] Levers are ranked with an architectural-damage column and a reversibility column.
- [ ] Two or three model-breakers are named, each with a monitored guard and a numeric threshold.

**Capacity**
- [ ] Concurrency arithmetic is written out per tier against every downstream ceiling, with each
      ceiling's source and fetch date.
- [ ] Any breach found by that arithmetic has a stated resolution.
- [ ] Every stage has a saturation point and a utilization ratio per tier.
- [ ] Every stage boundary names its backpressure mechanism with a bound; no unbounded buffers.
- [ ] The first-to-break ranking exists with the load number, symptom, mitigation, and lead time,
      and notes where mitigating one ceiling moves another.

**Observability**
- [ ] Every SLI states its exact measurement and measurement location.
- [ ] Every SLO states its error budget in human units and its burn-rate consequences.
- [ ] The required log-field list is complete, with the mechanism enforcing PII exclusion named.
- [ ] Trace propagation across the async boundary is specified at every propagation point.
- [ ] Every alert has a meaning sentence and a runbook path that exists.
- [ ] A heartbeat is emitted and checked by something independent of the system, and it has been
      demonstrated failing once.
- [ ] Client-side error tracking and crash reporting are specified with symbolication/source-map
      upload in the build pipeline and release tagging.

**Extensibility (Phase 5)**
- [ ] The fixed kernel is enumerated by component name with a reason each.
- [ ] Every surface has interface contract, lifecycle, deterministic ordering, isolation bounds,
      failure semantics, observability, and a contract test.
- [ ] Extension failure defaults to "extension fails, core operation continues"; any exception is
      justified in writing.
- [ ] The configuration registry lists every key with type, default, range, settable-by, and
      locked flag; validation is at write time; changes are audited.
- [ ] At least one worked module example is complete end to end.
- [ ] The NOT-extensible list exists with an "instead" for each entry and a named escalation path.
- [ ] Both scaling axes — data volume and users/subscribers — have designs, not just the one that
      was more interesting to write.

**Audit trail**
- [ ] The database scale, system scale, and consistency audits from `references/audits.md` have run
      as fresh agents and written findings, fixes, deliberate non-fixes, the "gets right" list, and
      a verification-pass verdict to `docs/AUDIT_LOG.md`.
- [ ] The verification pass ran on the *fixed* document, not the original.
- [ ] §7.5 Integrations: every entry has all six fields; every rate limit carries a source URL and fetch date or is marked "could not verify".
- [ ] §7.6 Verification backlog: every ⚠ has a designed fallback and a re-check trigger naming a goal.
- [ ] §7.7 Build plan: every P0 FR appears in exactly one Lands list; the dependency graph is acyclic; the kernel is deliverable 1.x; every deliverable has a behavioral Demo.
- [ ] DESIGN_SPEC.md uses these section numbers verbatim (§1 Architecture decisions … §8 Extensibility), and every `§n` cross-reference in the package resolves to a section that exists.
