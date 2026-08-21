# Deliverables requirements — the acceptance contract for Phase 0 and Phase 1

SKILL.md tells you *what* Phase 0 and Phase 1 produce: a source audit whose defects become
requirements, and a PRD with "functional requirements in numbered groups with priorities, each one
testable as written" and "NFRs with numbers, not adjectives". That is intent. This file is the
specification — the field schemas, the numeric axes, and the pass/fail bar an entry must clear
before `PRD.md` or the audit output is allowed to leave the phase.

**Scale to the tier.** Sketch tier: the FR list, the decisions table, and §1.3's testability bar,
folded into `BUILD.md` — personas collapse to one sentence, launch metrics to one, and only the
NFR axes carrying a number that would change the design survive. Standard: everything except the
Phase-0 defect register when there is no predecessor. Full: all of it, including the parity
inventory. Four things never drop at any tier, because they are the mechanisms the rest rests on:
§1.3's testability bar, the mandatory `Fails if:` line on every FR, the open decisions table, and
the rule that a defect register entry's `Becomes` field cannot be empty. Dropping anything else is
correct and must be stated in the PRD ("greenfield — no defect register"); dropping it silently is
how a tier gate turns into an excuse.


The reason this file exists: a build agent reading `FR-AUTH-3: users can manage their account` has
no way to know whether it built the right thing, and no way to know when it is finished. It will
build *something*, declare done, and the defect surfaces at Phase 8 or later — at which point the
design, the screens, and the tests downstream of that FR are all wrong together. A requirement that
cannot fail is not a requirement; it is a wish with an ID number.

**Rule of the file: nothing here is satisfied by prose that sounds right.** Every schema below has
fields that are either filled with a specific value or explicitly marked unresolved. "TBD" scattered
through a PRD is fine when it is an entry in the open-decisions table with an owner and a deadline;
it is a defect when it sits silently in an acceptance criterion.

A note on scope: many users arrive with no PRD, no repo, and no product — just an idea. Every
schema in this file works from a standing start. Phase 0 has a documented greenfield substitute
(§6.5) and no section below requires a predecessor artifact to exist.

---

## 1. The functional-requirement (FR) entry schema

### 1.1 Required fields

Every FR carries all of these. A field that does not apply is written `n/a` with a half-line
reason, never omitted — an omitted field is indistinguishable from a forgotten one, and the
pre-flight audit cannot tell them apart either.

| Field | Required | What it holds | Why it is required |
|---|---|---|---|
| **ID** | yes | `FR-<GROUP>-<n>` per `document-set.md` §Numbering. Stable forever; never renumbered, never reused after deletion. | Every downstream document points at this string. Renumbering silently breaks screens, tests, and goals at once, and the breakage is invisible until `id-sweep.sh` runs. |
| **Group** | yes | The `<GROUP>` token, an uppercase noun for a coherent subsystem (`AUTH`, `BILLING`, `SEARCH`, `EXPORT`). | Groups are the unit of build scheduling and the unit of test-suite naming. A group that cannot be named is usually two features glued together. |
| **Statement** | yes | One sentence, active voice, naming the actor, the action, and the observable result. Present tense, not "should". | "Should" invites a builder to treat it as advisory. The statement is the contract clause. |
| **Priority** | yes | One of `P0` / `P1` / `P2` / `P3` (§1.2). | Without tiers, a build agent implements in file order and the launch-blocking work lands last. |
| **Acceptance criteria** | yes | One or more Given/When/Then triples, each with concrete values, not classes of values (§1.3). | This is the thing that makes the FR testable as written. Everything else is bookkeeping. |
| **Verified by** | yes | Named test IDs or suite names that exist in `TESTS_TDD.md`. | An FR with no test is an FR nobody can prove was built. Traceability (§8) fails on it. |
| **Screens** | yes | Screen IDs from `SCREENS.md` / `WIREFRAMES.md` where this requirement is visible, or `n/a — background job` etc. | An FR with no surface is either a hidden behavior (say so) or a requirement nobody can reach. |
| **Depends on** | yes | Other FR IDs that must exist first, or `none`. | The build's dependency graph in `LOOP_GOALS.md` is derived from this field. Missing edges cause an agent to start work it cannot finish and thrash. |
| **Data touched** | yes | Entities/tables read and written, plus which are user-owned or tenant-scoped. | The security phase reads this field to place authorization rules; the scale phase reads it for query shape. |
| **Out of scope** | yes | Explicit exclusions the statement could plausibly be read to include. | This is the single highest-yield field. An autonomous builder with an ambiguous statement expands scope, because expansion looks like diligence. |
| **Error behavior** | yes | What the user and the system see when this fails: message, status, retry semantics, whether the failure is silent. | Omitting this is how "no data" and "request failed" end up rendering identically. |
| **Source** | yes | Where the requirement came from: `Phase 0 defect DR-12`, `persona P2 goal`, `regulation X §Y`, `user decision D3`. | A requirement with no origin cannot be evaluated when scope needs cutting, and cannot be defended when someone asks why it exists. |
| **Open questions** | no | Unresolved sub-decisions, each cross-referenced to a `D<n>` row. | Keeps assumptions visible instead of settled by whoever implements first. |

### 1.2 Priority tiers — what each tier actually means

Tiers are commitments about *the launch*, not about enthusiasm. State the definitions verbatim in
the PRD so the build agent applies the same meaning you did.

| Tier | Meaning | Test consequence | Cut consequence |
|---|---|---|---|
| **P0** | Launch-blocking. The product is not shippable, safe, or legal without it. Includes auth, data integrity, payment correctness, and anything a regulation requires. | Must have a passing test before the build is called done. Failure is a red build. | Cannot be cut. If it must be cut, the launch scope changes and the PRD is amended. |
| **P1** | Launch-expected. Ship without it only with a named, dated follow-up and a stated user impact. | Must have a test; test may be marked `@p1` and excluded from the blocking gate only with an ADR. | Cut requires recording who accepted the gap and what the user sees instead. |
| **P2** | Post-launch. Designed now so the architecture accommodates it; built later. | Test may be written and skipped, or deferred entirely, but the data model must not preclude it. | Cut freely; record so it is not silently rediscovered as new work. |
| **P3** | Speculative. Recorded so a future reader knows it was considered and deliberately deferred. | No test. | No cost to cut. |

Two anti-patterns to name in the PRD itself: **everything is P0** (which means nothing is
prioritized, and the agent will still pick an order — just not yours), and **priority assigned by
effort** (priority is user/business consequence; effort belongs in the build plan).

### 1.3 What "testable as written" means

An acceptance criterion passes this bar when **two independent readers would build the same check**
and the check can go red. Concretely, each Given/When/Then must satisfy all four:

1. **Observable.** The Then names something a test can read: a rendered string, an HTTP status, a
   row in a table, an emitted event, a file on disk. Not "the user understands", not "the state is
   consistent" without saying which invariant.
2. **Bounded.** Every quantity is a number with a unit. "Quickly" is not bounded; "within 300 ms at
   p95" is. If the number belongs to an NFR, cite the NFR ID rather than restating it.
3. **Single-outcome.** One Then per triple. Compound criteria hide the half that was never built,
   because the test author picks the easy half.
4. **Negative-tested.** You can state, in one sentence, an input that makes the criterion fail. If
   you cannot, the criterion is vacuous — it will pass on an empty implementation, which is exactly
   how a build agent produces a green suite over a hollow product.

Point 4 is the one people skip. Write the failing input down next to the criterion while drafting;
it takes seconds and it kills roughly every vacuous criterion at the source.

### 1.4 Worked example — GOOD

```
FR-EXPORT-3
Group:        EXPORT
Priority:     P1
Statement:    A signed-in account owner exports their own records as a CSV file
              containing every record they own and no record they do not.
Depends on:   FR-AUTH-1 (session established), FR-RECORDS-2 (record list query)
Screens:      SCR-SETTINGS-DATA (button "Export CSV"), SCR-EXPORT-STATUS
Data touched: records (read, owner-scoped), export_jobs (write, owner-scoped)
Source:       Phase 0 defect DR-07 (legacy export silently truncated at 1,000 rows)

Acceptance criteria
  AC-1  Given an owner with 3 records and another account with 2 records,
        When the owner requests an export,
        Then the produced file contains exactly 3 data rows plus one header row.
        Fails if: the query is not owner-scoped (would yield 5).
  AC-2  Given an owner with 25,000 records,
        When the owner requests an export,
        Then the produced file contains exactly 25,000 data rows and the job
        completes without truncation (this is the DR-07 regression).
        Fails if: any pagination limit leaks into the export path.
  AC-3  Given a request from a session that is not signed in,
        When the export endpoint is called directly,
        Then the response is HTTP 401 and no export_jobs row is created.
        Fails if: authorization is enforced in the UI only.
  AC-4  Given the storage backend returns an error mid-write,
        When the export job runs,
        Then the job row is marked "failed" with the error code, the user sees
        "Export failed — nothing was downloaded. Try again.", and no partial
        file is served.
        Fails if: a truncated file is delivered as success.

Verified by:  tests/export/test_csv_scope.py::test_owner_scope_only  (AC-1, AC-3)
              tests/export/test_csv_large.py::test_25k_no_truncation (AC-2, DR-07)
              tests/export/test_csv_failure.py::test_partial_write   (AC-4)
Error behavior: see AC-4. No silent success. No partial file is ever downloadable.
Out of scope: XLSX and JSON formats (FR-EXPORT-5, P2); scheduled/recurring exports
              (P3); exporting another account's records under an admin role — there
              is no admin role at launch (D4).
Open questions: none.
```

Note what makes this work: every AC names values (3, 25,000, 401), each has a stated failing input,
the P0-ish security case is separated from the happy path so it cannot be half-built, and
`Out of scope` pre-empts the three expansions a builder would otherwise make on their own.

### 1.5 Worked example — BAD #1, the adjective requirement

```
FR-PERF-1
Statement: The system should be fast.
Priority:  P0
```

**Why it fails.** No actor, no operation, no number, no observable. There is no input that makes it
fail, so any implementation passes — it is vacuous by construction (§1.3 point 4). It is also
mis-filed: speed across the whole system is a non-functional axis, not a functional requirement, so
even a numeric version of it belongs in §2 and gets an `NFR-` ID. Left as-is, a build agent will
either ignore it (best case) or spend unbounded time optimizing an arbitrary path (worse case,
because the time comes out of P0 work).

**Rewrite.** Split into an NFR that carries the number and, where a specific user-visible behavior
is at stake, an FR that carries the behavior.

```
NFR-LATENCY-2
Axis:      Latency
Operation: Record list query, first page, 50 items, warm cache
Target:    p95 <= 400 ms, p99 <= 900 ms, measured server-side from request
           received to response flushed, excluding client render
Load:      at 200 concurrent sessions (see NFR-CONCURRENCY-1)
Verified:  load test load/list_query.js gates CI at the p95 threshold;
           dashboard panel "list p95" alerts above target for 5 min
Degrade:   above target, the list falls back to 20 items per page and logs
           a "degraded_page_size" event — it never returns a partial page silently

FR-RECORDS-6
Statement: The record list shows a loading state within 100 ms of the request and
           never renders a blank region while a query is in flight.
Priority:  P1
AC-1  Given a query artificially delayed by 2 s,
      When the list screen is opened,
      Then a skeleton state is visible from 100 ms until data arrives, and the
      empty-state copy ("No records yet") is never shown during the delay.
      Fails if: empty state and loading state share a render path.
```

The rewrite is longer, and that length is the point: it is the part that was missing, not padding.

### 1.6 Worked example — BAD #2, the container requirement

```
FR-ACCT-2
Statement: Users can manage their account.
Priority:  P0
AC: The account page works.
```

**Why it fails.** "Manage" is a container word hiding an unknown number of distinct behaviors —
change email, change password, change display name, change plan, add a payment method, close the
account, download data. Each has different security consequences (email change needs
re-verification; account closure needs data-retention handling; plan change touches billing) and
different tests. A build agent will implement the two easiest, and the reviewer has no way to say
it did not satisfy the statement, because the statement is true of that partial build. The AC
compounds it: "works" names no observable, so it can never go red.

The tell for this class: **if you cannot write the test names without asking a follow-up question,
the FR is a container.** Split it.

**Rewrite.** One FR per behavior, grouped, with the destructive ones separated and priced:

```
FR-ACCT-2  Change display name.        P2
FR-ACCT-3  Change email address.       P0
FR-ACCT-4  Change password.            P0
FR-ACCT-5  Close account and delete data. P1
(FR-ACCT-6 change plan → belongs to group BILLING, see FR-BILLING-4.)

FR-ACCT-3
Statement: A signed-in user changes the email address on their account, and the
           new address becomes the sign-in identity only after it is verified.
Priority:  P0
Depends on: FR-AUTH-1, FR-MAIL-1 (transactional send)
Screens:   SCR-SETTINGS-ACCOUNT, SCR-VERIFY-EMAIL
Data touched: accounts (write, self only), email_verifications (write)
AC-1  Given a signed-in user submits a new, unused address,
      When the change is submitted,
      Then a verification message is sent to the NEW address, the account's
      sign-in address remains the OLD one, and the UI shows "Pending
      verification".
      Fails if: the record is updated before verification (account-takeover path).
AC-2  Given a valid, unexpired verification token,
      When it is opened,
      Then the sign-in address becomes the new address, all other sessions are
      invalidated, and a notice is sent to the OLD address.
      Fails if: the old address is never told (silent takeover).
AC-3  Given a token older than 24 h,
      When it is opened,
      Then the response is "This link expired" and the address is unchanged.
AC-4  Given the new address already belongs to another account,
      When the change is submitted,
      Then the user sees "That address can't be used" and no enumeration of
      whether the address exists is possible from response timing or wording.
Out of scope: changing email for another user (no admin role at launch, D4);
      merging two accounts (P3).
```

Splitting also fixed the priority: the original single P0 would have pulled display-name editing
into launch-blocking work, and would have let account deletion — which has a legal retention
dimension — ride in as an afterthought.

---

## 2. Non-functional requirements — the axes and their numbers

An NFR carries a number, a unit, a measurement condition, and a verification mechanism. "Highly
available", "scalable", "secure" are not requirements; they are categories that a requirement lives
inside. Use `NFR-<AXIS>-<n>`.

Every NFR entry carries: **ID, axis, the operation or scope it applies to, the target with unit,
the load/condition it is measured under, how it is verified (the actual command, query, or dashboard),
and the degradation behavior when the target is missed.** That last field matters more than it
looks: an unstated degradation path becomes an outage, because the system's only two behaviors are
"fine" and "down".

### 2.1 The axes

| Axis | Unit it is stated in | What a defensible target looks like | How it is verified |
|---|---|---|---|
| **Latency** | ms at named percentiles, per named operation | Percentiles, never averages — an average hides the tail that users actually feel. State p50 for the typical experience, p95 for the promise, p99 for the pathology. Separate read from write, cached from cold, and interactive from batch. Include the measurement boundary (server-side vs. end-to-end). | Load test in CI asserting the percentile; a production histogram panel with an alert at the target. |
| **Throughput** | requests/sec, jobs/min, rows/sec — sustained, not peak | Sustained rate at a stated concurrency and payload size, plus the burst the system absorbs and for how long. A throughput number without a payload size is unfalsifiable. | Load generator at the stated shape, run to steady state (not a 30-second spike). |
| **Availability** | % over a stated window, plus the derived error budget in minutes | 99.9% monthly = 43.2 min/month of budget. State what counts as "down" (which endpoints, which status classes) — the definition does more work than the nines. Do not claim more nines than your dependencies: your ceiling is the product of theirs. | Synthetic probe from outside the network; budget burn tracked per month; the SLO doc names the burn-rate alert. |
| **Durability / RPO / RTO** | RPO in minutes of tolerable data loss; RTO in minutes to restore service; durability as the provider's stated figure | RPO must be smaller than your backup interval, or the interval is wrong. RTO is only real if a restore has been *rehearsed* and timed. | A dated restore drill with the measured wall-clock time recorded. Untested backups are an assumption, not a control. |
| **Retention** | days/months per data class, with the deletion mechanism | Per class: user content, logs, analytics events, backups, audit records. Each has a retention period, a deletion trigger, and a statement of whether backups are in scope for deletion requests (they usually are, legally, and usually are not, technically — resolve it in a `D<n>`). | A scheduled job with a test proving records past the window are gone; a query that returns zero rows older than the window. |
| **Concurrency** | simultaneous sessions, connections, or in-flight jobs | The number the latency and throughput targets are measured *at*. Also state the per-resource ceiling (database connections, worker slots) and what happens at the ceiling: queue, shed, or fail. | Load test at the stated concurrency; a saturation test that drives past it to confirm the ceiling behavior is the designed one. |
| **Payload and size limits** | bytes/rows/items, per input | Every user-supplied input has a maximum: upload size, request body, field length, array length, page size, batch size, export row count. An unstated limit becomes a denial-of-service surface and an unbounded query. | A test posting limit+1 and asserting a clean rejection (correct status, no partial write, no stack trace). |
| **Cold start / startup** | ms or s to first successful response after idle | Only meaningful on serverless or scale-to-zero platforms. State the measured cold path and whether a warm path is guaranteed. If cold start would breach the latency NFR, the mitigation (min instances, warmers) is part of the entry and shows up in the cost model. | Timed invocation after a forced idle; a p99 that separates cold from warm invocations. |
| **Accessibility** | A named conformance level and version | "WCAG 2.2 Level AA" — the level and version, not "accessible". Name the exempted areas explicitly if any, with reasons; silent exemptions are how audits fail. | Automated axe/Lighthouse pass in CI (catches perhaps a third of issues), plus a keyboard-only traversal and a screen-reader pass on each P0 flow. Automated-only is not conformance. |
| **Browser / device support** | An explicit matrix with versions | Name browsers with minimum versions and the rule that generates them ("current and current-1"), plus minimum viewport width, OS versions for native, and minimum device class. State what unsupported clients see — a blocking message beats a silently broken layout. | The matrix drives the E2E target list; anything not in the matrix is not tested and not claimed. |
| **i18n / l10n** | Locales, and which layers are localized | Which locales at launch; whether it is UI strings only or also dates, numbers, currency, sorting, and pluralization; RTL yes/no; whether user content is translated. Even an English-only launch states it, because "we'll add it later" without externalized strings is a rewrite later. | A pseudo-locale build that surfaces hardcoded strings; a lint rule failing on literal user-facing strings in components. |
| **Privacy / compliance** | The named regime(s) and the specific obligations that follow | Name them (GDPR, CCPA/CPRA, HIPAA, SOC 2, PCI DSS, COPPA, an accessibility statute) and enumerate the concrete obligations each creates: lawful basis, DSAR response window, breach notification window, data-residency, sub-processor list, consent records. A regime named without obligations enumerated is decoration. | Each obligation maps to an FR or a control with an owner. Compliance you cannot point at a mechanism for is not compliance. |
| **Cost ceiling** | Currency per unit (per user/month, per 1k requests, per job) | Optional but high-yield when LLM or media calls are in the path, where a single unbounded loop is a four-figure surprise. State the per-unit ceiling and the alert threshold. | A budget alert wired to the real account, plus a test asserting the per-request token or call ceiling. |

### 2.2 Filled example table

Generic placeholders throughout. Substitute the product's real operations.

| ID | Axis | Applies to | Target | Measured under | Verified by | On breach |
|---|---|---|---|---|---|---|
| NFR-LATENCY-1 | Latency | `GET /records` first page (50 items), server-side | p50 ≤ 120 ms, p95 ≤ 400 ms, p99 ≤ 900 ms | 200 concurrent sessions, warm cache | `load/list_query.js` gates CI at p95; Grafana panel `list_p95`, alert 5 min over | Page size drops to 20, `degraded_page_size` event emitted, no silent partial page |
| NFR-LATENCY-2 | Latency | Record write (create) | p95 ≤ 700 ms | 50 writes/sec | `load/write.js`; alert at p95 | Write queued, user sees "Saving…" then confirmation or explicit failure — never optimistic success |
| NFR-THROUGHPUT-1 | Throughput | Export job worker | ≥ 5,000 rows/sec sustained, 10 min | 4 workers, 2 KB avg row | `load/export_sustained.js` | Queue depth alert; jobs remain queued, never dropped |
| NFR-AVAIL-1 | Availability | Public API, 5xx and timeouts count as down | 99.9%/calendar month (43.2 min budget) | External synthetic probe, 60 s interval, 3 regions | Probe dashboard; monthly budget report | Burn-rate alert at 2% budget/hour; feature freeze at 50% burn |
| NFR-DURABILITY-1 | Durability / RPO / RTO | Primary datastore | RPO ≤ 5 min, RTO ≤ 60 min | Full-region loss | Quarterly restore drill, wall-clock recorded in `docs/AUDIT_LOG.md` | Drill overrun re-opens the design; an untested backup is treated as no backup |
| NFR-RETENTION-1 | Retention | Application logs | 30 days, then hard delete | — | Query returns 0 rows older than 30 d; deletion job test | Alert on job failure; log growth alert as backstop |
| NFR-RETENTION-2 | Retention | Deleted user content | Purged within 30 d of deletion request, backups included within 90 d | — | Test asserts purge; backup rotation documented | Manual purge runbook; the gap between 30 d and 90 d is disclosed in the privacy policy |
| NFR-CONCURRENCY-1 | Concurrency | API layer | 200 concurrent sessions; DB pool 40 connections | — | Saturation test to 400 | Above pool: queue up to 2 s, then 503 with `Retry-After` — never an unbounded wait |
| NFR-LIMITS-1 | Payload | Upload endpoint | ≤ 10 MB/file, ≤ 5 files/request | — | Test posts 10 MB + 1 byte, asserts 413, no partial object stored | Rejected at the edge before the body is buffered |
| NFR-LIMITS-2 | Payload | List endpoint page size | default 50, max 200 | — | Test asserts `?limit=1000` returns 400, not 1,000 rows | — |
| NFR-COLDSTART-1 | Cold start | Serverless API handlers | ≤ 1.5 s p99 cold, ≤ 1% of requests cold | Production traffic | Cold/warm split in the latency histogram | 2 min instances; the cost appears as a line in the cost model |
| NFR-A11Y-1 | Accessibility | All P0 flows | WCAG 2.2 Level AA | — | axe in CI (blocking), plus manual keyboard and screen-reader pass per release | Any AA failure on a P0 flow blocks release |
| NFR-BROWSER-1 | Browser/device | Web client | Chrome/Edge/Firefox/Safari current and current-1; iOS 17+, Android 12+; ≥ 360 px viewport | — | E2E matrix mirrors this list exactly | Unsupported client sees a blocking notice, not a broken layout |
| NFR-I18N-1 | i18n | Launch scope | English (US) only; all user-facing strings externalized; dates/numbers locale-formatted from day one | — | Pseudo-locale build shows zero hardcoded strings; lint rule blocks literals | — |
| NFR-PRIVACY-1 | Privacy | EU/UK users | GDPR: lawful basis recorded per purpose; DSAR answered ≤ 30 d; breach notice ≤ 72 h; sub-processor list published | — | Each obligation maps to an FR or a runbook with a named owner | Missing mapping is a P0 blocker, not a documentation task |
| NFR-COST-1 | Cost | LLM calls per user/month | ≤ USD 0.40 median, ≤ USD 2.00 p99 | — | Per-request token ceiling test; billing alert at 80% of monthly budget | Above p99 ceiling, the request is refused with an explicit message, never silently truncated |

Two rules that keep this table honest. **Do not state a number you have not decided how to
measure** — an unmeasurable target is a slogan and will be quietly dropped. And **do not state
availability above your dependencies'**: if your database's published SLA is 99.95%, your 99.99% is
arithmetic fiction, and writing it down commits you to a promise you cannot keep.

---

## 3. Persona schema

Personas exist to settle arguments, not to decorate the PRD. The test of a persona: **when two
design options conflict, does the persona pick one?** If not, it is a demographic sketch and should
be cut. Names, ages, and stock photos do no work here; the fields below do.

| Field | What it holds | Why a build agent needs it |
|---|---|---|
| **ID + label** | `P1 — Solo operator` | Referenced by FRs, screens, and metrics. |
| **Goal** | The outcome they want from the product, in their words, not the product's features. | Distinguishes "wants a report" from "wants to stop being asked for the report". Different products. |
| **Context of use** | Where and under what conditions: at a desk, on a phone in the field, mid-call, with an auditor watching, on hotel wifi. | Drives network assumptions, offline behavior, screen density, and how much reading a screen may demand. |
| **Frequency** | How often: many times daily, weekly, once a quarter, once ever. | Daily use rewards density and keyboard paths; quarterly use requires the interface to re-teach itself every time. This single field decides more UI arguments than any other. |
| **Device / environment** | Primary device class, viewport, OS, assistive tech, connectivity. | Feeds the support matrix (NFR-BROWSER) and the accessibility scope directly. |
| **Expertise** | Domain expertise and tool expertise, stated separately. | A domain expert new to the tool needs orientation but not concepts explained; a novice in both needs the opposite. Conflating them produces interfaces that patronize and confuse at once. |
| **Cost of failure** | What it costs *them* when the product is wrong, slow, or unavailable. | Sets how loud errors are, whether optimistic UI is acceptable, how much confirmation friction is warranted, and how hard the availability target must be. |
| **FR groups exercised** | The groups this persona touches, and the ones they never touch. | Lets the build sequence deliver one persona end-to-end instead of every group half-built. Also exposes groups no persona exercises — always worth interrogating. |
| **Success signal** | The observable event meaning this persona got what they came for. | Becomes the north-star input for §4 metrics; a metric with no persona behind it usually measures the product's convenience, not the user's. |

### Worked example

```
P2 — Reviewing manager (generic placeholder persona)

Goal:           Confirm that the week's submissions are complete and correct,
                and get to the two that need attention without reading the rest.
Context of use: Late in the day, often on a phone between meetings; sometimes
                on a laptop with a second person watching the screen.
Frequency:      2-3 times per week, in bursts of under five minutes.
Device:         Phone (iOS, ~390 px) 70% of sessions; laptop 30%. Occasional
                screen-reader use by a subset of this role.
Expertise:      High domain expertise (has done the underlying work for years);
                low tool expertise (uses it briefly, forgets navigation between
                sessions).
Cost of failure: A missed exception is caught downstream days later and is
                expensive to unwind; a false alarm costs a colleague an hour.
                So: precision matters more than recall, and any "all clear"
                state must be trustworthy enough to act on.
FR groups exercised: REVIEW (all), NOTIFY (all), RECORDS (read only),
                EXPORT (rarely). Never touches BILLING, SETTINGS-ADMIN.
Success signal: opens the review queue, resolves every flagged item, and leaves
                with zero unreviewed flags — event `review_queue_cleared`.

Design consequences this persona forces:
  - Low frequency + low tool expertise → the review queue must be reachable in
    one tap from launch and must re-explain itself; no learned shortcuts.
  - Phone-first + observers → no dense tables as the default view; P0 of the
    design system (one message per screen) applies hard here.
  - Precision over recall → flag thresholds tuned conservatively, and every
    flag shows its reason inline (drives FR-REVIEW-4).
  - "All clear" must never be indistinguishable from "failed to load"
    (drives FR-REVIEW-7 error behavior and NFR-AVAIL-1).
```

Those four consequence lines are the persona's real output. A persona that generates no
consequences did not need to be written.

---

## 4. Launch metric schema

**A metric with no instrumentation point is not a metric.** It is an intention, and it will be
discovered to be uninstrumented on the day someone first asks for the number — which is always
after launch, when adding the event means shipping a release and waiting for data you no longer
have time to collect. The instrumentation point is a required field precisely because it is the
field that turns a metric into something that exists.

| Field | What it holds |
|---|---|
| **ID + name** | `M3 — Activation rate`. |
| **Definition (formula)** | A computable expression over named events or tables, with the denominator, the window, and the deduplication rule spelled out. If two analysts could compute different numbers from your definition, it is not finished. |
| **Instrumentation point** | The exact event name and where it fires (file, endpoint, job) — or the table and query if derived. Plus whether it exists today or must be built, and the FR that builds it. |
| **Segment** | Which persona or cohort it is computed over, and the cohorting rule (signup week, plan, locale). Aggregate-only metrics hide the segment that is failing. |
| **Baseline** | The current value, with its source and date. If there is no predecessor, write `no baseline — greenfield`, state the comparable you are reasoning from and where it came from, and treat the first fortnight of data as the baseline. Never invent a plausible-looking starting number. |
| **Target** | The value and the date by which it is expected, with the reasoning for that number. |
| **Decision it drives** | What you will actually do at, above, and below target. |
| **Guardrail** | The metric that must not degrade while this one improves. Without it, every activation metric is gameable by making the product more insistent. |

Worked rows (generic placeholders):

| ID | Metric | Definition | Instrumentation | Baseline | Target | Decision it drives | Guardrail |
|---|---|---|---|---|---|---|---|
| M1 | Activation | Distinct accounts firing `first_record_saved` within 7 d of `signup_completed`, ÷ accounts with `signup_completed` in the same week cohort | `first_record_saved` emitted server-side on first successful record insert (FR-RECORDS-2 builds it); `signup_completed` on session creation (FR-AUTH-1) | none — greenfield; first 2 weeks post-launch set it | ≥ 40% by week 8, on the reasoning that below this the onboarding flow, not the product, is the constraint | < 30% → onboarding rework becomes the next build phase, ahead of P2 features | Support contacts per new account must not rise |
| M2 | Review latency | Median hours from `item_flagged` to `item_resolved`, per reviewing-manager cohort | Both events server-side in the review service (FR-REVIEW-4, FR-REVIEW-6) | none — greenfield | ≤ 8 h median by week 6 | > 24 h → notification design is failing P2 and gets a dedicated phase | False-flag rate must not fall below the precision floor in NFR-QUALITY-1 |
| M3 | Export reliability | `export_completed` ÷ (`export_completed` + `export_failed`), 7-day rolling | Emitted by the export worker (FR-EXPORT-3 AC-4) | Predecessor: 91.2% (source: predecessor job log, 90 days, fetched YYYY-MM-DD) | ≥ 99.5% at launch | < 99% → export is treated as a P0 defect, not a P1 improvement | p95 export duration must not rise above NFR-THROUGHPUT-1 |

Note M3's baseline: it carries a source and a fetch date because it came from somewhere. A baseline
without provenance is indistinguishable from a guess, and gets treated as one.

---

## 5. The open-decisions table (D1…Dn)

**A silently assumed decision is the exact failure this table prevents.** When a builder — human or
agent — hits an unresolved fork, they pick one. Not maliciously: picking is the only way to keep
moving. The choice then hardens through the schema, the screens, and the tests, and by the time
anyone notices it was a choice, reversing it costs a rewrite. The table's whole job is to catch the
fork while it is still a sentence.

The discipline: **an assumption that is expensive to reverse is a blocking question, not a
default.** Cheap-to-reverse assumptions can be defaulted and recorded. The test is not how likely
you are to be right; it is what being wrong costs. Single-tenant vs. multi-tenant, chosen wrongly,
is a rewrite. Button placement, chosen wrongly, is an afternoon.

| Field | What it holds | Why |
|---|---|---|
| **ID** | `D<n>`, stable, never reused. | Cited from FRs, ADs, and goals. |
| **Decision** | The fork as a question with a definite answer set. | "How should we handle tenancy?" is a research task. "Do accounts belong to organizations at launch: yes or no?" is a decision. |
| **Why it is a human call** | What makes this not yours to assume: cost, legal exposure, brand, business model, taste with real consequences, or information only the user holds. | Prevents the table filling with things you could have determined by reading the docs. If a search or a spike settles it, do the search — do not bill it to the user's attention. |
| **Options** | Each with real tradeoffs: what it costs to build, what it costs to reverse later, what it forecloses. | Options without costs are not options; the reader picks the one that sounds nicest. |
| **Recommendation + reasoning** | Your pick and why, in one or two sentences. | A table of unweighted options transfers the whole analytical burden back to the user, which is the work they delegated. |
| **Blocks** | The exact documents, FRs, ADs, or goals that cannot be finalized until this resolves. | Makes the cost of deferral visible and lets work be sequenced around it. |
| **Resolve by** | The phase after which the cost of changing the answer jumps. | A deadline expressed in phases, not dates, because phases are what the build actually moves through. |
| **Status** | `open` / `resolved (answer, date)` / `deferred (until, why)`. | Resolved rows stay in the table. Deleting them destroys the record of why the product is shaped this way. |

Worked rows (generic placeholders):

| ID | Decision | Why human | Options (cost to build / cost to reverse) | Recommendation | Blocks | Resolve by |
|---|---|---|---|---|---|---|
| D1 | Do accounts belong to organizations at launch — yes or no? | Business model and pricing; only the user knows whether the first customers buy as teams. | (a) Personal accounts only: fastest, but retrofitting org scoping later touches every table, every query, and every authorization rule — effectively a rewrite. (b) Org-scoped from day one, with orgs of size 1: modest extra work up front, near-zero later. | (b). The asymmetry is extreme: a few days now against a rewrite later, and the day-one cost is mostly a column and a policy. | Full schema, every authorization rule, FR-AUTH-*, FR-BILLING-*, AD-2 | Before Phase 2 |
| D2 | Which payment processor, and does the product store card data? | Contractual and compliance exposure; the user's existing banking relationships. | (a) Hosted checkout, no card data touches the product: PCI scope stays minimal. (b) Direct card handling: full PCI DSS obligations, an audit, and ongoing cost. | (a). PCI scope is the single most expensive thing to acquire accidentally, and nothing in the product needs raw card data. | FR-BILLING-*, NFR-PRIVACY-*, the security threat model | Before Phase 4 |
| D3 | Are EU/UK users in scope at launch? | Legal obligation, and it is the user's risk to accept. | (a) In scope: GDPR obligations become P0 FRs (lawful basis, DSAR path, sub-processors, possibly residency). (b) Out of scope with geo-restriction: less work, but restriction must be enforced and honest. | (a) if any EU traffic is expected at all — retrofitting DSAR and residency after launch is harder than building them, and (b) is only credible if actually enforced. | NFR-PRIVACY-1, NFR-RETENTION-2, legal artifacts, FR-ACCT-5 | Before Phase 2 |
| D4 | Is there an admin role at launch that can act on another account's data? | Trust and support-model call, with a real abuse surface. | (a) No admin role: simplest, but every support request needs the user present. (b) Scoped admin with mandatory audit logging and user-visible notice: more work, materially better support, new insider-threat surface. | (a) at launch, (b) designed but not built, so the audit-log table exists from the start and the retrofit is additive. | FR-ACCT-3 out-of-scope note, FR-EXPORT-3 out-of-scope note, threat model | Before Phase 4 |

Rows the table should *not* contain: anything answerable by fetching a document (that is research,
§7), anything with no consequence either way (just pick), and anything phrased as a topic rather
than a question with an answer set.

---

## 6. Phase 0 — source-audit output schema

Phase 0 runs when a predecessor exists: an old codebase, a live system being rewritten, a
spreadsheet-and-scripts arrangement, a competitor product the user is cloning the good parts of.
Read the code, not the README. Cite `file:line` for every claim.

**The audit's product is not a report. It is a set of named requirements and regression tests.**
A defect register that ends at "here are 23 problems" has done half the work and the expensive
half is the half left undone: the next build reproduces the defects that were never converted. So
every register row terminates in an `FR-`/`NFR-` ID or a named regression test, and a row that
terminates in neither must say why in the row itself ("deliberately not carried forward — feature
removed, see D7").

### 6.1 Defect register

| Field | What it holds |
|---|---|
| **ID** | `DR-<n>`, stable; referenced by the FR or test it becomes. |
| **Citation** | `path/to/file.ext:LINE` (a range where the logic spans lines). Uncitable claims are recorded as suspicions, in a separate list, never in the register. |
| **Observed behavior** | What the code actually does, described mechanically. |
| **Documented/expected behavior** | What the README, the marketing copy, the UI, or the user believes it does — with its own citation. The gap between these two rows is where the highest-value findings live. |
| **Trigger** | The input or condition that produces it. Without this, nobody can write the regression test. |
| **Severity** | `critical` (data loss, silent wrong answers, security) / `high` (wrong output under common conditions) / `medium` (degraded, visible) / `low` (cosmetic, papercut). Severity here is about consequence, not frequency; a rare silent corruption outranks a common visible glitch. |
| **Class** | One of the Phase 0 hunt categories: documented-vs-implemented gap, silent failure, destructive default, missing identity/audit, hardcoded-should-be-config, marketing-only feature, unbounded query, or other (named). |
| **Becomes** | The `FR-`/`NFR-` ID and/or the named regression test. **This field cannot be empty.** |
| **Port decision** | `fix in new build` / `do not port (reason)` / `port as-is (reason)`. |

Worked row:

```
DR-07
Citation:   legacy/exporters/csv_export.py:142-159
Observed:   The export query is built with the same paginated helper the list view
            uses, and the caller never advances the cursor. Any account with more
            than PAGE_SIZE (1,000) records receives a file containing exactly
            1,000 rows. The job then writes status="complete" (line 171) and the
            UI shows a success toast.
Documented: The product page and the in-app help both state "export all of your
            records" (legacy/web/templates/help_export.html:23).
Trigger:    Any account with > 1,000 records. Reproduced on a seeded account with
            1,001 records: file contained 1,000 data rows, no warning anywhere.
Severity:   critical — silent data loss presented as success. Users have been
            reconciling against truncated files without knowing.
Class:      silent failure + documented-vs-implemented gap
Becomes:    FR-EXPORT-3 AC-2 (25,000-row export completes without truncation) and
            regression test tests/export/test_csv_large.py::test_25k_no_truncation,
            named for DR-07 in its docstring.
Port decision: fix in new build. The pagination helper is not reused on the export
            path at all; export streams a cursor to completion. Additionally
            FR-EXPORT-3 AC-4 forbids marking a job complete when the row count
            written does not match the row count counted.
```

That row does the audit's whole job: it is citable, reproducible, converted into an acceptance
criterion, converted into a named test, and it produced a second requirement (the count check) that
generalizes past the specific bug — which is the difference between fixing this defect and fixing
the class of defect.

### 6.2 Parity inventory — what the legacy system gets right

Derived from **code, not memory, and not the user's description**. People remember the features
they demo, not the ones that quietly carry the product; the small behavior nobody mentions is
routinely the one whose absence makes the rewrite feel worse than the original.

| Field | What it holds |
|---|---|
| **ID** | `PI-<n>`. |
| **Behavior** | What it does, as a user-visible statement. |
| **Citation** | `file:line` where it is implemented. |
| **Why it matters** | The failure it prevents or the work it saves. Behaviors whose value cannot be stated are candidates for the do-not-port list, not the parity list. |
| **Evidence of use** | Logs, analytics, support threads, or a screen where it is unavoidable. Prevents porting features that exist but nobody uses. |
| **Carried as** | The FR ID that preserves it — or an explicit `dropped (D<n>)`. |

Pay attention to the unglamorous ones: keyboard shortcuts, a default sort order, an idempotency
key, a retry with backoff, an off-by-one guard with a comment explaining a real incident. Those are
compressed bug-fix history. Dropping them silently re-opens every bug they closed.

### 6.3 Do-not-port list

Explicit, with reasons, because otherwise a diligent builder reads the legacy code and reproduces
it. Each entry: **what it is, its citation, why it is not carried forward, what replaces it (or
nothing), and who accepted the removal** (a `D<n>` row if the user must accept it).

Typical entries: features that exist only in marketing copy and have no code path; workarounds for
a dependency no longer in use; a permission model superseded by D1; a data denormalization that
solved a scale problem the new architecture does not have; anything whose only user was a person
who has left.

### 6.4 Deployed-vs-source divergence

The running system is frequently not the code you were given. Record, each with how you established
it: version/commit actually deployed vs. the branch you read; configuration and feature flags set
in production that change behavior; manual data fixes never reflected in code; schema drift (columns
in production absent from migrations, and vice versa); endpoints live in production with no source;
and behavior observed on the deployed instance that the source cannot produce.

Where the user can grant access to a deployed instance or send screenshots, take them — a divergence
you did not look for becomes a requirement you did not write. Where you could not check, record
`could not verify` (§7) rather than assuming the source is authoritative.

### 6.5 When there is no predecessor — the greenfield substitute

Phase 0 is not skipped when the product is new. It is **redirected**, because its function is to
enter Phase 1 with evidence instead of assumptions, and that function does not depend on a legacy
codebase existing. Replace the source audit with as many of these as apply, using the same output
discipline — cited findings, each converted into a requirement, a decision row, or a metric
baseline.

**(a) Competitive-set audit.** Pick 3-5 products the user's target actually uses today. Use them —
sign up, complete the core flow, hit the edges. Record per product: the core flow step by step with
screenshots, what it does well (a `PI-`-style parity entry, since it sets the floor for what your
product must not feel worse than), what it does badly and why (candidate FRs and differentiators),
its pricing with a fetch date, and its stated limits. Public reviews and support forums are the
cheapest source of the failure modes users actually feel; each claim gets a URL and a date, and
each is labeled as an opinion, not a measurement.

**(b) Current-manual-process audit.** If the user (or their customers) does this work today by
hand, that process *is* the predecessor. Walk it step by step and record: every step with its
inputs, outputs, and duration; where the data lives now, in what format, and how much of it exists
(this sets migration requirements and payload limits); the workarounds people have built, each of
which is an unstated requirement; the errors that happen and what they cost; and the steps that are
deliberately manual because judgment is required — those must not be automated away, and marking
them is how you avoid building a product that removes the human from the one step that needed one.

**(c) Adjacent-tools audit.** The spreadsheets, scripts, form builders, and chat channels the work
currently flows through. These generate the integration and import requirements that greenfield
PRDs most often miss, plus the honest answer to "what format is the existing data in".

**(d) Constraint and regulation audit.** For regulated or platform-hosted products: the actual rule
text and the actual platform policy, fetched and cited (§7). App-store rules, payment-network
rules, and sector regulations are all cheaper to read now than to be rejected by later.

Output shape is unchanged: a register of findings with citations (a URL and date, or a described
observation with its date, rather than `file:line`), each terminating in an FR, an NFR, a `D<n>`,
or a metric baseline. **A greenfield Phase 0 that produces zero findings was not run.** The
competitive set alone reliably produces requirements the user did not think to state, because they
have internalized them as how software simply works.

---

## 7. Research and verification requirements

Everything asserted about the world outside this document is either **verified against a primary
source, with a URL and the date it was fetched recorded beside the claim**, or marked
**`could not verify`**. There is no third state. A number with no provenance is a guess wearing a
number's clothes, and downstream readers cannot tell the difference — which is precisely why the
provenance goes next to the claim rather than in a bibliography nobody cross-checks.

**What requires a citation:** that an API or endpoint exists and is generally available (not
waitlisted, not deprecated); rate limits and quotas; prices and pricing tiers; free-tier boundaries;
platform capabilities and restrictions (OS APIs, store policies, browser support); library features
and their minimum versions; regulatory obligations and their thresholds; competitor features and
pricing; any statistic used to justify a decision.

**Primary means primary.** The vendor's own docs or pricing page, the standard's text, the
regulator's own publication, the repository's source or release notes. A blog post summarizing a
price is not a price; a tutorial claiming an API supports something is not the API's documentation.
Where only a secondary source exists, cite it and label it secondary.

**Recording format** — inline beside the claim, not in a footnote pile:

```
Storage list price: USD 0.023/GB-month, first 50 TB, region us-east-1.
  Source: <vendor pricing page URL>  Fetched: YYYY-MM-DD
Batch API concurrency ceiling: 8 concurrent jobs per project.
  Source: <vendor docs URL#section>  Fetched: YYYY-MM-DD
Webhook delivery retry schedule: could not verify — the docs page describes
  "automatic retries" without a schedule, and support was not contacted.
  Impact: the retry assumption in AD-6 is unverified; NFR-THROUGHPUT-2 carries
  a 2x margin because of it. Re-check before Phase 2 sign-off.
```

Note the third entry. A `could not verify` is not an apology; it names the impact and what was done
about it. Recorded that way, it is actionable. Silently rounded to a plausible number, it is a
latent defect with a confident face.

**Dates are not optional.** Prices change, free tiers shrink, APIs deprecate. A figure with a date
can be re-checked in seconds; the same figure without one has to be re-researched from scratch, so
it never is. This is why SKILL.md singles out "a date stamped on a remembered price" as the failure
mode: the date makes a remembered number look verified. Stamp the date you actually fetched, or
write `could not verify`.

**Nothing about the user's own business is ever invented.** Not the company or legal-entity name,
not a support/contact/legal email address, not a physical address, not a domain, not a privacy-policy
or terms URL, not a tax or registration number, not a founder title, not a support phone number,
not an app or bundle identifier. These are the details that flow straight into legal documents,
store listings, and transactional email, where a plausible invention is worse than an obvious gap
because it survives review.

Every such value is either supplied by the user and quoted exactly, or written as a visible
placeholder that cannot be mistaken for a real value:

```
{{LEGAL_ENTITY_NAME}}   {{SUPPORT_EMAIL}}   {{PRIVACY_POLICY_URL}}
{{COMPANY_ADDRESS}}     {{APP_BUNDLE_ID}}   {{PRIMARY_DOMAIN}}
```

Placeholders that block a phase are promoted to `D<n>` rows with a `Resolve by`. Before delivery,
grep the package for `{{` and list every remaining placeholder in the handoff message — a
placeholder nobody was told about becomes a literal `{{SUPPORT_EMAIL}}` in a production footer.
Examples in these documents use obviously generic placeholders for the same reason: an example
company name in a template gets copied into a real product with startling reliability.

---

## 8. Requirements traceability

Traceability is a graph, and **orphans in any direction are a pre-flight blocker** — not a
documentation nicety, because each orphan class names a specific way the build goes wrong:

| Direction | Orphan means | Consequence if shipped |
|---|---|---|
| FR → screen | A requirement with no surface and no `n/a — background` note | Either it is unreachable, or a screen exists that no requirement authorized. Both are real defects; the second is scope that arrived without a decision. |
| Screen element → FR | An element implementing no requirement | Unjustified UI. It has no test, no owner, and no reason to survive a redesign — but it will, because nobody can say why it is there. |
| FR → test | A requirement nothing verifies | Nobody can prove it was built. This is the orphan class that lets a build agent declare done on a hollow feature. |
| Test → FR | A test verifying nothing stated | Either an undocumented requirement (write it) or a test asserting incidental behavior, which will block a legitimate change later. |
| FR → build goal | A requirement in no goal's scope | It will not be built. The plan is silently smaller than the PRD. |
| Goal → FR | A goal implementing nothing required | Work with no user justification. First candidate to cut. |
| Phase-0 defect → FR or test | A defect converted into nothing | The rewrite reproduces it. This is the single most expensive orphan class, because the audit's entire cost was already paid. |
| NFR → verification | A number nobody measures | It will be missed, and missed silently. |
| `D<n>` → what it blocks | A decision citing nothing | Either it does not matter (delete it) or the dependency is unrecorded (find it). |

Maintain the graph as three tables — FR↔screen, FR↔test, FR↔goal — living in the documents that own
each side (screens in `WIREFRAMES.md`'s numbered annotations, tests in `TESTS_TDD.md`'s traceability
section, goals in `LOOP_GOALS.md`). Do not maintain a fourth master copy: a duplicated graph
diverges, and then neither copy can be trusted.

**Mechanical check.** `scripts/id-sweep.sh docs` verifies ID *resolution* — that every `FR-`,
`NFR-`, `AD-`, `D<n>`, and `G-` referenced anywhere has a defining entry somewhere. It exits
nonzero on dangling IDs and warns on weak (table-cell-only) definitions. Run it, append its output
to `docs/AUDIT_LOG.md`, and do this before every delivery, because successive edit passes drop defining
entries while leaving the prose that discusses them — a failure the eye does not catch across
fourteen documents.

Know its limit: the sweep proves an ID resolves, not that the mapping is *complete*. It cannot tell
you an FR has no test, only that a referenced test ID exists. Completeness is the by-hand half, and
the table above is its checklist. And per SKILL.md: before trusting the sweep on this package,
break an ID deliberately and watch it go red. A gate that has never failed is passing vacuously.

---

## 9. Definition of done — Phase 0 and Phase 1

Each line is mechanically checkable: a grep, a script, a count, or a yes/no with no interpretation.
Every line is checked before Phase 2 begins. A failing line is a blocker, not a note.

**Forward references are legal at Phase 1 and are closed at Phase 8.** Some lines below cite
`TESTS_TDD.md` (Phase 6) and screen IDs from `SCREENS.md` (Phase 3), which do not exist yet when
this checklist first runs. That is not a defect in the checklist and it is not permission to skip
the line — it is a two-stage gate, and conflating the stages is the "gate required before the goal
that creates it" protocol killer the pre-flight audit hunts:

- **At Phase 1 close**, the line passes if the FR names a *planned* ID conforming to the grammar
  (`TS-<GROUP>-<n>`, `SCR-<NAME>`) — a commitment that this FR will be proved by a named suite on
  a named screen, or the explicit token `n/a` with the reason. Naming nothing is the failure; the
  FR then has no acceptance path and nobody notices until the build.
- **At Phase 6 and Phase 8 close**, the same line passes only when every ID *resolves* —
  `scripts/id-sweep.sh docs` exits 0 and the by-hand check confirms the suite actually exercises
  the FR.

Run this checklist twice, and say in `docs/AUDIT_LOG.md` which stage each run was. A single run
that ticks the resolving version at Phase 1 has invented IDs to satisfy a checkbox, and those IDs
dangle for the rest of the package.

**Phase 0 — source audit (predecessor exists)**

- [ ] Every defect-register row has a `file:line` citation, and each cited file exists at that path.
- [ ] Every row has an `Observed` and a `Documented/expected` value; rows where nothing was documented say so explicitly.
- [ ] Every row has a reproduction trigger a test author could act on without asking a question.
- [ ] Every row has a severity from the fixed set and a class from the fixed set.
- [ ] **Every row's `Becomes` field is non-empty** — an FR/NFR ID, a named regression test, or an explicit not-carried-forward reason with a `D<n>`.
- [ ] Every named regression test names its `DR-<n>` in its docstring or title. *Phase 1*: the `TS-` ID is committed to. *Phase 6/8*: it appears in `TESTS_TDD.md`.
- [ ] Parity inventory entries each carry a citation and an evidence-of-use note; each is carried as an FR or marked dropped with a `D<n>`.
- [ ] Do-not-port list is non-empty or explicitly states that nothing was excluded, with a reason.
- [ ] Deployed-vs-source divergence section exists, naming the deployed version/commit checked — or `could not verify` with the reason and the impact.
- [ ] Suspicions that could not be line-verified are in a separate list, not in the register.

**Phase 0 — greenfield substitute (no predecessor)**

- [ ] The substitute actually run is named: competitive set, manual process, adjacent tools, constraints — or a stated reason each was not applicable.
- [ ] At least 3 competitors examined firsthand where a competitive set exists, each with URL and date.
- [ ] Every finding carries a source (URL + fetch date, or a dated described observation).
- [ ] Every finding terminates in an FR, an NFR, a `D<n>`, or a metric baseline.
- [ ] The finding count is greater than zero; a zero-finding audit is recorded as not-run, not as clean.
- [ ] Manual-process findings distinguish steps that are manual by necessity (judgment) from steps that are manual by accident.

**Phase 1 — PRD**

- [ ] Every FR has all required fields from §1.1; `n/a` entries carry a reason.
- [ ] Every FR ID matches `FR-<GROUP>-<n>`; no duplicates; no reused IDs from deleted requirements.
- [ ] Every FR has a priority from `{P0,P1,P2,P3}` and the tier definitions appear verbatim in the PRD.
- [ ] Not every FR is P0 (if it is, prioritization did not happen).
- [ ] Every FR has ≥ 1 acceptance criterion in Given/When/Then form.
- [ ] Every acceptance criterion names an observable outcome and, where a quantity appears, a number with a unit or a cited NFR ID.
- [ ] Every acceptance criterion has a stated failing input (the `Fails if` line) — no vacuous criteria.
- [ ] No FR statement contains an unquantified adjective (`fast`, `easy`, `intuitive`, `robust`, `seamless`, `secure`, `scalable`) — grep for them.
- [ ] No FR statement uses a container verb (`manage`, `handle`, `support`, `deal with`) without an enumerated scope, and none has an `Out of scope` field left empty.
- [ ] Every FR names a screen or explicitly states it has no surface.
- [ ] Every FR names ≥ 1 test. *Phase 1*: a planned `TS-<GROUP>-<n>` ID. *Phase 6/8*: that ID resolves in `TESTS_TDD.md`.
- [ ] Every FR's `Depends on` IDs resolve to defined FRs.
- [ ] Every FR names its `Source`.
- [ ] Every NFR axis in §2.1 is either addressed with a number or explicitly marked out of scope with a reason. No axis is silently absent.
- [ ] Every NFR carries a unit, a measurement condition, a verification mechanism, and a degradation behavior.
- [ ] The availability target does not exceed the product of the stated dependency SLAs.
- [ ] Every persona has all §3 fields and produces at least one stated design consequence.
- [ ] Every FR group is exercised by at least one persona, or is flagged for interrogation.
- [ ] **Every launch metric has an instrumentation point** naming the event and where it fires, and whether it exists or must be built (with the FR that builds it).
- [ ] Every metric has a computable formula with a denominator and a window; every baseline has a source and date, or says `no baseline — greenfield`.
- [ ] Every metric has a guardrail metric.
- [ ] The open-decisions table exists with ≥ 1 row, and every row has options with costs, a recommendation with reasoning, what it blocks, and a `Resolve by` phase.
- [ ] No decision expensive to reverse has been defaulted instead of asked — walk the `D<n>` candidates and confirm each defaulted assumption is cheap to reverse.
- [ ] Every external claim carries a source URL and fetch date, or is marked `could not verify` with its impact stated.
- [ ] No fetch date is stamped on a figure that was not actually fetched in this run.
- [ ] `grep -r '{{' docs/` returns only intentional placeholders, and every one is listed in the handoff message.
- [ ] No invented business specifics: grep the package for candidate email addresses, domains, and entity names, and confirm each was user-supplied or is a placeholder.
- [ ] `scripts/id-sweep.sh docs` exits 0, with its output appended to `docs/AUDIT_LOG.md`.
- [ ] The sweep has been shown failing on a deliberately broken ID in this package before its pass was trusted.
