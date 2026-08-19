# Deliverables testing — the acceptance contract for Phase 6

SKILL.md calls `TESTS_TDD.md` "the acceptance oracle" and states the principles correctly:
failing tests first, a real-infrastructure substrate, property tests for algorithmic claims,
regression tests named for every Phase-0 defect, eval gates for ML/LLM components, and an ADR
requirement before any test is weakened. That is intent. This file is the specification — the
entry schema, the traceability rules, the substrate rules, and the pass/fail bar `TESTS_TDD.md`
must clear before Phase 7 is allowed to start.

The reason this file exists: a build agent handed "write tests first, use real infrastructure"
writes a testing-philosophy section, one example suite, and moves on. The document then reads
well and decides nothing. When the agent later has to answer "is `FR-EXPORT-3` done?", the
document has no answer, so the agent invents one — usually "the code exists and the suite is
green", which is exactly the state a hollow build produces.

**An oracle is a document that can say NO.** Every schema below exists to make a specific "no"
expressible: this FR has no suite; this suite proves nothing that was required; this test has
never been observed red; this eval has no numeric bar; this authorization check ran against a
mock and therefore tested the mock.

**Division of labor.** This file owns *what `TESTS_TDD.md` must contain*. It does not own
execution mechanics. The red-green-refactor loop as an operating discipline lives in the
`tdd-workflow` skill; proving a change actually works before calling it done lives in the
`verification-loop` skill. Cite those skills from `TESTS_TDD.md` and from `CLAUDE.md` rather
than restating them — a duplicated protocol drifts, and then the build agent obeys whichever
copy it read last.

**Scale to the tier.** Sketch tier: sections 1, 4, and 12, folded into `BUILD.md`. Standard:
everything except the parts naming components the product does not have (no LLM, no §7). Full:
all of it. Dropping a section because the product lacks that component is correct and must be
stated in `TESTS_TDD.md` ("no ML component — §7 not applicable"); dropping it because it is
work is the failure this file exists to prevent.

---

## 1. The test-suite entry schema

A suite is the unit of the oracle. It is the thing an FR points at, the thing CI runs, and the
thing that goes red. Suites are named and numbered because "the export tests" is not a
referent — it cannot be cited from a PRD, cannot be counted, and cannot be checked for
existence.

### 1.1 Suite IDs

`TS-<GROUP>-<n>`, where `<GROUP>` is the same uppercase token used by the FR group it serves
(`TS-EXPORT-1`, `TS-AUTH-4`). Stable forever; never renumbered, never reused after deletion,
for the same reason FR IDs are not: every downstream document points at the string.

A suite maps to one file or one clearly-bounded module of tests. When a suite grows past
roughly a screenful of test names, split it and give the halves new IDs rather than letting one
ID mean "everything about export" — a suite that means everything cannot be cited to prove
anything specific.

**Know the tooling limit.** `scripts/id-sweep.sh` checks `FR-`, `NFR-`, `AD-`, `D<n>`, and `G-`
IDs. It does **not** know the `TS-` grammar, so dangling suite IDs are not caught mechanically
by that script. Either extend the script's `ID` regex when you adopt `TS-` (one alternation
added to one line) or make the by-hand traceability check in §2.4 carry that weight and say in
`TESTS_TDD.md` which you chose. Do not leave it implicit; an unstated gap in a gate is
indistinguishable from a gate that does not exist.

### 1.2 Required fields

Every suite entry carries all of these. A field that does not apply is written `n/a` with a
half-line reason, never omitted — an omitted field is indistinguishable from a forgotten one,
and the pre-flight audit cannot tell them apart either.

| Field | Required | What it holds | Why it is required |
|---|---|---|---|
| **ID** | yes | `TS-<GROUP>-<n>`. | The citable referent. Without it, FR↔test traceability is prose and cannot be checked. |
| **Proves** | yes | One sentence naming the *claim*, not the mechanism. "Export contains exactly the requester's records and never truncates" — not "tests the export function". | A suite described by its mechanism cannot be evaluated for relevance. When the implementation is rewritten, a mechanism-described suite is deleted with it; a claim-described suite survives and catches the rewrite's bugs. |
| **Covers** | yes | The `FR-`/`NFR-` IDs and specific acceptance-criterion labels (`FR-EXPORT-3 AC-1, AC-3`), plus `DR-<n>` for regression suites. | This field *is* the traceability graph (§2). An entry with no covers field is a test with no stated purpose, which §2's Test→FR orphan class covers. |
| **Level** | yes | One of `unit` / `integration` / `e2e` / `property` / `eval` / `regression` (§1.3). | Level determines the substrate, the runtime budget, and which CI job runs it. Mislabeling is how a suite needing a real database ends up in the fast unit job with a mock. |
| **Substrate** | yes | What it runs against: real database with policies enabled, containerized service, simulator, real device, live third-party sandbox, in-process. Name the specific thing (§3). | "Integration test" says nothing about whether authorization was actually exercised. The substrate field is where a mocked security test becomes visible. |
| **Fixtures** | yes | The named fixtures/factories/seed data required, and their ownership scope (which tenant, which user, which role). | A test that shares mutable fixture state with another test is a flake generator (§11). Naming fixtures makes the sharing visible at review time rather than at 2am. |
| **Runtime budget** | yes | Wall-clock ceiling for the suite, with the machine class it assumes. | Suites without a budget grow until the feedback loop is too slow to run, at which point developers stop running it and CI becomes the only signal. Budgets also make the "is this the right level?" question answerable. |
| **CI job** | yes | The named job/workflow that runs it, and whether it is **blocking** or **reporting**. | A suite nothing runs is documentation. Blocking-vs-reporting must be explicit, because the difference between them is whether a failure can ship. |
| **Exit condition** | yes | What "this suite passes" means beyond the exit code: assertions that must exist, minimum case counts, thresholds for property/eval suites. | Exit code 0 is satisfiable by a suite that skipped everything. The exit condition is the thing that makes an empty green run detectable. |
| **Depends on** | no | Other `TS-` IDs that must pass first (schema migration suites before data suites), or `none`. | Ordering that exists only in a CI config file is invisible to the document readers who need it. |
| **Known limits** | no | What this suite does *not* prove, especially where a reader would assume it does. | Prevents a later engineer citing `TS-AUTH-2` as proof of something it never checked. This field is cheap and prevents an entire class of false confidence. |

### 1.3 Levels — what each one is for

Choosing the level is choosing what the test can be wrong about. State the definitions verbatim
in `TESTS_TDD.md` so the build agent applies the same meanings you did.

| Level | Runs against | Proves | Fails to prove |
|---|---|---|---|
| **unit** | In-process, no I/O. Pure functions, reducers, formatters, validators, state machines. | The logic is correct given inputs. Fast enough to run on every save. | Anything about wiring, persistence, permissions, or the network. A fully-unit-tested system can be entirely disconnected. |
| **integration** | Real database, real queue, real cache — containerized locally, provisioned in CI (§3). | The pieces talk to each other, the schema matches the queries, authorization policies apply, migrations run. | End-user experience; anything above the API boundary. |
| **e2e** | The assembled product, driven the way a user drives it: browser, simulator, or device. | The critical journeys work when everything is wired together. Catches config, build, routing, and integration-of-integrations failures nothing else sees. | Cheap coverage. E2E is the slowest and flakiest level; treat every e2e test as a purchase (§8.1). |
| **property** | Usually in-process, sometimes against the real store. Generated inputs, asserted invariants. | The claim holds across the input space, not just the three cases someone thought of (§5). | Anything about specific outputs. Property tests are for invariants; example tests still carry the "this exact input yields this exact output" contracts. |
| **eval** | The real model or pipeline against a golden set (§7). | A non-deterministic component meets a stated numeric bar, and has not drifted since the last run. | Correctness in the binary sense. An eval reports a score, and the bar is a policy decision. |
| **regression** | Whatever substrate reproduces the original defect. | A specific named defect (`DR-<n>` from Phase 0, or a production incident) does not return (§6). | Anything general. A regression test is a memorial to one bug; it is not a substitute for the property test that would have prevented the class. |

Two rules the level field enforces. **The substrate follows the level, not convenience**: if an
integration-level claim is being tested with mocks because the container is slow, the entry is
lying about what it proves. And **level inflation is real**: teams write e2e tests because they
feel thorough, then discover the suite takes forty minutes and flakes 3% of runs. Push each
claim to the cheapest level that can actually falsify it, and record in `Known limits` what the
cheaper level gave up.

### 1.4 Worked example

This is the full entry for the export requirement used throughout
`deliverables-requirements.md` §1.4. Note that every acceptance criterion in that FR is
accounted for by a specific test name here — that correspondence is the whole point.

```
TS-EXPORT-1
Proves:      A signed-in owner's CSV export contains exactly the records they own,
             at any row count, and never reports success when the file is short.
Covers:      FR-EXPORT-3 (AC-1, AC-2, AC-3, AC-4); NFR-LIMITS-2 (page-size limit
             does not leak into the export path); DR-07 (legacy silent truncation).
Level:       integration
Substrate:   Real Postgres 16 in a container, migrations applied from the same
             migration files production uses, row-level security ENABLED and the
             connection made as the application role — not as the owner/superuser
             role, which bypasses policies and would make AC-3 vacuous.
             Object storage: the local S3-compatible container, not a stub, because
             AC-4 is about a mid-write storage failure and a stub cannot produce one.
Fixtures:    factory `account(records=n)`; two accounts per test, never shared
             across tests (each test creates its own; no module-scoped account).
             Storage bucket namespaced per test run, torn down after.
Runtime:     <= 90 s on a 2-core CI runner, of which the 25k-row case is ~60 s.
CI job:      `integration` (blocking on main and on every PR).
Exit:        4 named tests present and passing; the 25k case asserts an exact row
             count read back from the produced file (not a >= assertion, which the
             truncation bug would have passed); the 401 case asserts zero rows in
             export_jobs afterwards.
Depends on:  TS-MIGRATE-1 (schema applies cleanly) — a schema failure must surface
             as a migration failure, not as forty confusing export failures.
Known limits: Does not prove the download link expires (that is TS-EXPORT-2), and
             does not prove browser-side download behavior (TS-E2E-3).
```

```python
# tests/export/test_csv_scope.py
# Suite TS-EXPORT-1. Covers FR-EXPORT-3 AC-1, AC-3.
# Substrate: real Postgres with RLS enabled, connected as the application role.

def test_owner_scope_only(app_db, storage):
    """AC-1: export contains exactly the requester's rows.

    Fails if the query is not owner-scoped: this test would see 5 data rows.
    """
    owner = make_account(records=3)
    make_account(records=2)                      # a second account, not the requester

    result = run_export(as_account=owner)
    rows = read_csv(storage, result.file_key)

    assert len(rows) == 3                        # exact, not >=; a leak must fail
    assert {r["account_id"] for r in rows} == {owner.id}


def test_export_endpoint_requires_session(app_client, app_db):
    """AC-3: unauthenticated call is rejected at the server, and creates nothing.

    Fails if authorization is enforced only in the UI. This is the assertion a
    mocked auth layer cannot make, which is why this suite's substrate is the
    real database with policies on.
    """
    response = app_client.post("/api/exports", session=None)

    assert response.status_code == 401
    assert count_rows(app_db, "export_jobs") == 0


# tests/export/test_csv_large.py
# Suite TS-EXPORT-1. Covers FR-EXPORT-3 AC-2. Regression for DR-07.

def test_25k_no_truncation(app_db, storage):
    """DR-07 regression: legacy export reused the paginated list helper and
    silently returned exactly PAGE_SIZE (1,000) rows, then wrote status
    'complete'. See docs/PRD.md Phase-0 register, DR-07.

    Fails if any pagination limit reaches the export path.
    """
    owner = make_account(records=25_000)

    result = run_export(as_account=owner)
    rows = read_csv(storage, result.file_key)

    assert len(rows) == 25_000
    assert result.status == "complete"
    assert result.rows_written == 25_000         # the count check FR-EXPORT-3 added
```

What makes the entry usable: the substrate names the *role* the connection uses, because
connecting as the owner role silently disables the policies and turns AC-3 into a test of
nothing; the exit condition forbids the `>=` assertion that the original bug would have passed;
`Known limits` stops a future reader citing this suite for link expiry; and the skeleton's
docstrings carry the AC labels and the `DR-` number, so the mapping survives even if the
document and the code drift.

---

## 2. FR-to-test traceability

`deliverables-requirements.md` §8 declares the orphan classes and states that orphans in any
direction are a pre-flight blocker. This section specifies the half of that graph
`TESTS_TDD.md` owns.

### 2.1 The two rules

**Every FR maps to at least one suite. Every suite maps to at least one FR.** Both directions
are blockers at Phase 8, for different reasons:

- An **FR with no suite** cannot be proven built. This is the orphan class that lets a build
  agent declare done on a hollow feature: the code exists, nothing checks it, and the suite is
  green because it never looked.
- A **suite with no FR** is asserting behavior nobody required. It is either an undocumented
  requirement (write the FR — the behavior is evidently wanted) or a test pinned to an
  implementation detail, which will block a legitimate refactor later and be deleted under
  pressure by whoever is least equipped to judge whether it mattered.

P3 requirements are the one exception, and it is stated rather than assumed: per
`deliverables-requirements.md` §1.2, P3 carries no test. P2 may have a written-and-skipped test.
Both cases appear in the table with the exception named, never as a blank cell — a blank cell is
how a P0 gap hides among legitimate P3 gaps.

### 2.2 The table format

Lives in `TESTS_TDD.md`. One row per FR, ordered by FR ID.

| FR | Priority | Suites | Criteria covered | Gaps |
|---|---|---|---|---|
| FR-EXPORT-3 | P1 | TS-EXPORT-1, TS-E2E-3 | AC-1, AC-2, AC-3, AC-4 | none |
| FR-AUTH-1 | P0 | TS-AUTH-1, TS-AUTH-2 | AC-1, AC-2 | AC-3 (session revocation across devices) — **no suite**, blocker |
| FR-SEARCH-4 | P2 | TS-SEARCH-2 (`@skip`, P2 deferral) | AC-1 | deferred per §1.2; test written, skipped, unskips when built |
| FR-REPORT-9 | P3 | none — P3, no test per §1.2 | — | none |

And the reverse table, one row per suite, ordered by suite ID:

| Suite | Level | Covers | Orphan? |
|---|---|---|---|
| TS-EXPORT-1 | integration | FR-EXPORT-3, NFR-LIMITS-2, DR-07 | no |
| TS-CACHE-1 | unit | — | **yes — asserts LRU eviction order, which no FR requires.** Either write the FR (eviction order is user-visible in the stale-data behavior) or delete the suite. |

The `Gaps` column is the one that does work. A traceability table with no gaps column gets
filled optimistically, because the author fills in the suite they intend to write. The gaps
column forces the missing criterion to be written down as missing, and a written gap is
something Phase 8 can count.

### 2.3 NFR and Phase-0 coverage

Two more mappings, same rules, kept in the same section:

- **Every NFR maps to its verification mechanism** — which is often not a test suite but a load
  script, a dashboard panel, or a scheduled drill. `deliverables-requirements.md` §2 requires
  the mechanism in the NFR entry; `TESTS_TDD.md` restates it as a row so the "who runs this and
  when" question has one home. An NFR whose mechanism is "monitoring" with no panel named is an
  orphan.
- **Every `DR-<n>` from Phase 0 maps to a named regression test or an explicit
  not-carried-forward reason** (§6). This is the most expensive orphan class in the whole
  package, because the audit's cost was already paid and the rewrite is about to reproduce the
  defect anyway.

### 2.4 The mechanical check, and what it cannot do

`scripts/id-sweep.sh docs` verifies **ID resolution**: every `FR-`, `NFR-`, `AD-`, `D<n>`, and
`G-` referenced anywhere in the package has a defining entry somewhere. Run it, append its
output to `AUDIT_LOG.md`, and do it before every delivery — successive edit passes drop defining
entries while leaving the prose that discusses them, and the eye does not catch that across
fourteen documents.

**The grading rule matters here specifically.** The sweep grades a definition STRONG (heading,
list item, bold lead-in, or the `ID: text` idiom), WEAK (the ID alone in a table cell), or NONE
(prose mentions only, treated as undefined and failing the run). A traceability table is
structurally identical to a definition table, so **the tables in §2.2 produce WEAK definitions
and nothing more**. If an FR's only appearance in the package is a cell in a traceability table,
the sweep passes with a warning and the FR has in fact been deleted from the PRD by an edit
pass. Treat every weak-only ID in the sweep output as a question to answer, not a note to skim:
find the real defining entry in `PRD.md`, or restore it.

The sweep also cannot tell you the mapping is *complete*. It proves a referenced test ID
resolves; it cannot know that `FR-AUTH-1 AC-3` has no suite. Completeness is the by-hand half,
and §2.2's gaps column plus the §12 checklist is its instrument.

And per SKILL.md: before trusting the sweep on this package, break an ID deliberately and watch
it go red. A gate that has never failed is passing vacuously, and a vacuous gate converts an
unexamined package into a confident GO.

---

## 3. The real-infrastructure substrate

SKILL.md states it flatly: *mocked authorization tests are worthless*. The reasoning is worth
writing into `TESTS_TDD.md` verbatim, because the build agent will otherwise reach for a mock
the first time a container is inconvenient.

**A mocked authorization test asserts that the mock returns what the test told it to return.**
The real question — does the database refuse this read when the policy is applied, does the
middleware run on this route, does the token's tenant claim actually scope the query — is
answered by the code that was replaced by the mock. Every authorization bug that has ever
shipped passed a mocked authorization test, because the bug lives precisely in the layer the
mock stood in for. The same argument applies to any claim about a *seam*: schema-query
agreement, migration correctness, transaction boundaries, cascade deletes, unique constraints,
serialization at the wire.

### 3.1 What must run against real infrastructure

| Claim class | Substrate required | What a mock would hide |
|---|---|---|
| Authorization and tenancy isolation | Real database, policies/RLS **enabled**, connection as the **application role** | The policy not being attached, the role bypassing it, a query path that skips the scoped view entirely. Connecting as owner/superuser silently disables RLS in Postgres — this single detail invalidates more security suites than any other. |
| Schema ↔ query agreement | Real database with production migrations applied | A column rename that the ORM mock happily accepts and production rejects. |
| Migrations | Real database, applied forward from an empty schema **and** from a snapshot of the previous release's schema | Forward-only testing hides the migration that works on empty but locks or fails on populated tables. |
| Constraints, cascades, defaults | Real database | Uniqueness enforced only in application code; a cascade that orphans rows; a default that differs from the ORM's. |
| Transactions and concurrency | Real database, real concurrent connections | Lost updates, deadlocks, and non-repeatable reads are all properties of the engine, not of the model layer. |
| Queue/job semantics | Real broker or its emulator | At-least-once redelivery, visibility timeouts, and dead-lettering are the reason the queue exists; a mock removes all three. |
| File/object storage | Real storage container | Partial writes, eventual consistency, and permission errors — the failure modes the error-behavior acceptance criteria are about. |
| Auth token issuance and verification | Real identity provider emulator where one exists | Signature verification, expiry, clock skew, and audience claims. |
| Search/index behavior | Real engine | Analyzer and tokenizer behavior is the feature; a mocked search proves the call was made. |

### 3.2 What may legitimately be faked, and how each fake stays honest

Faking is not forbidden — it is *constrained*. Each fake below is allowed because the real thing
is nondeterministic, costs money, or reaches a third party who did not consent to your test
suite. Each carries a constraint that keeps the seam testable, because an unconstrained fake
becomes an untested integration.

| May be faked | Why | Constraint that keeps the seam honest |
|---|---|---|
| **Third-party paid APIs** (LLM providers, payment processors, mapping, enrichment) | Cost and rate limits make per-run calls untenable. | Fake at the **HTTP boundary**, not by stubbing your own client class — stubbing your client leaves your request-building and response-parsing untested, which is where the bugs are. Record real responses (including the error shapes: 429, 402, 500, malformed body) into fixtures, date them, and re-record on a stated cadence. Keep **one** contract suite that runs against the vendor sandbox on a schedule (not on every PR) and fails loudly when the recorded shape stops matching reality. Payment specifically: use the vendor's official test mode, which is real infrastructure, not a fake. |
| **The clock** | Tests must be able to reach expiry, retention, and scheduling boundaries without waiting. | Inject a clock; never `sleep`. Every time-dependent test states the instant it pins. Assert at boundaries: exactly at expiry, one unit before, one unit after — and include at least one test crossing a DST transition and one at a UTC day boundary in a non-UTC display timezone, because those are the two production bugs this class actually produces. |
| **Randomness** | Reproducibility. | Seed it, and **record the seed in the failure output**. A random-input failure nobody can re-run is a defect report with the evidence removed (§5.4). |
| **Email delivery** | Sending real mail from CI is a deliverability and privacy problem. | Capture at the transport with a local sink (a mail-catcher container or the provider's sandbox mode) so the message is really rendered and really handed off. Assert on the rendered body, subject, recipient, and headers — not on "send was called". Deliverability itself (SPF/DKIM/DMARC alignment) is not a test; it is a launch checklist item with an owner. |
| **Push delivery** | Real push requires device tokens and reaches real devices. | Assert the payload built and the provider call made with the correct token, priority, and collapse key against the provider's sandbox endpoint where one exists. The device-side receipt is explicitly untestable in CI — declare it (§3.4). |
| **Outbound webhooks you send** | You are calling someone else. | Point at a local receiver; assert signature, retry schedule, and idempotency key. These three are the contract; the URL is not. |
| **Feature flags / remote config** | Remote state makes tests order-dependent. | Pin per-test with an explicit value. **Every flag that gates a P0 path gets both states tested**, or the off-state ships untested and is discovered by the first user who lands in it. |

Two rules to state in `TESTS_TDD.md` above this table. **A fake is a declaration that you are
not testing something** — write down what, in the suite's `Known limits`. And **fakes never
appear in the substrate for a security claim**: if a fake stands between the test and the
authorization decision, the suite proves nothing about authorization, regardless of what it
asserts.

### 3.3 Local parity — containers and emulators

The test substrate must be **runnable on a developer machine with one command**, and it must be
the same substrate CI uses. Specify in `TESTS_TDD.md`:

- The compose file (or equivalent) that brings up every backing service, with **pinned image
  versions matching production's major/minor**. `postgres:latest` is a test substrate that
  changes underneath you, and the day it breaks the failure looks like your bug.
- The one command that runs the suite from a clean checkout, and its expected wall-clock time.
- How the schema arrives: production migration files applied forward, never a hand-maintained
  test schema. A separate test schema drifts, and the drift is discovered in production.
- Seeding and teardown: per-test isolation (transaction rollback or truncate-between), never a
  shared mutable dataset. Shared fixtures are the single largest source of order-dependent
  flakes (§11).
- Where a managed service has an official emulator, name it and name the **fidelity gaps** —
  emulators routinely diverge on exactly the things you are testing (security rules evaluation,
  index requirements, quota and contention behavior, transaction semantics). Anything in the gap
  list needs a periodic suite against a real staging project, or an explicit undeclared risk.
- If CI provisions a real managed instance instead of a container, say so, and say how tenancy
  between concurrent CI runs is kept from colliding.

### 3.4 Mobile — simulator, device, and the things that cannot be tested

Mobile splits the substrate in a way web does not, and the split must be written down because
the untestable set is where false "passing" claims come from.

| Runs in simulator/emulator | Requires a real device | Genuinely cannot be tested automatically |
|---|---|---|
| UI layout, navigation, view state, most business logic, local persistence, network with a stubbed or local server, accessibility tree assertions, most snapshot tests | Biometric enrollment and prompts, real push receipt, camera and photo capture, background execution and OS-initiated termination, real StoreKit/billing purchase flows, Bluetooth/NFC, precise GPS behavior, performance and thermals, memory pressure kills | Store review behavior; genuine network conditions in the field; OS-version behavior on versions you do not have a device or image for; anything requiring another person's device |

The rule, stated plainly in `TESTS_TDD.md`: **an inability to test something is declared, never
quietly claimed as passing.** Each item in the middle and right columns that touches a P0
requirement gets an entry in an explicit table:

```
UNTESTABLE-1  Biometric unlock on cold launch  (FR-AUTH-6, P0)
  Why:       Simulator biometric enrollment does not exercise the real
             LocalAuthentication failure paths (lockout after N failures,
             biometry-changed invalidation).
  Substitute: Unit tests over the auth state machine with the platform call
             injected (TS-AUTH-5) + a manual device checklist run each release,
             recorded with device model and OS version in AUDIT_LOG.md.
  Residual risk: The real prompt's cancel/fallback path is verified by a human,
             not by CI. A regression there ships if the manual pass is skipped.
  Owner:     {{RELEASE_OWNER}}
```

The `Residual risk` line is the one that must never be dropped. Without it, the manual checklist
reads as coverage, and the next person to feel time pressure deletes it.

Also specify: the **device/OS matrix** the suite targets (from `NFR-BROWSER-1` or its mobile
equivalent, mirroring it exactly rather than restating it differently), and which tests run on
which. A matrix in the NFR that the suite does not mirror is a promise nobody keeps.

---

## 4. The failing-test-first protocol

`tdd-workflow` owns the red-green-refactor loop as a working discipline. What `TESTS_TDD.md`
owns is the **evidence rule** — what must exist afterwards to prove the loop actually ran, for a
build agent that no human watched.

### 4.1 The sequence

1. **Write the test** from the acceptance criterion, using the criterion's concrete values. Not
   the implementation's values — those do not exist yet, which is the point.
2. **Run it. Confirm it fails.**
3. **Confirm it fails on the intended assertion.** Read the failure message. It must be the
   assertion you wrote — `AssertionError: expected 3, got 5` — and not `ImportError`,
   `NameError`, `fixture 'app_db' not found`, a collection error, or a syntax error.
4. **Commit the failing test**, alone, with the FR/AC or `DR-` reference in the message.
5. **Implement until green.** The minimum that satisfies the assertion.
6. **Never edit the test to make it pass.** A failing test is information. Editing it destroys
   the information and keeps the bug (§10).

**Step 3 is the entire protocol, and step 3 is the step that gets skipped.** A test that fails
with `ImportError` will also "pass" the moment the import resolves, whether or not the behavior
was ever implemented. That is the exact mechanism by which an autonomous build produces a
green suite over a hollow product: every test went red, every test went green, and not one of
them ever evaluated its assertion. Red for the wrong reason is not red — it is a test that has
never run.

A related trap worth naming: a test that fails because a *fixture* is missing, then passes once
the fixture exists, has tested the fixture. Confirm the fixture is present and the assertion is
what fails.

### 4.2 The evidence rule

For any P0 requirement, and for every regression test, the red state is **recorded**, not
attested. Recording means: the assertion failure message, and the commit SHA of the
test-only commit that produced it.

```
FR-EXPORT-3 AC-2  /  DR-07  /  TS-EXPORT-1
  Red commit:  a1b2c3d  "test: 25k export must not truncate (FR-EXPORT-3 AC-2, DR-07)"
  Red output:  tests/export/test_csv_large.py::test_25k_no_truncation FAILED
               AssertionError: assert 1000 == 25000
  Green commit: e4f5g6h  "feat: stream export cursor to completion (FR-EXPORT-3)"
```

Two properties make this worth the keystrokes. The assertion text proves step 3 happened — an
`ImportError` in that slot is visible at a glance and is a Phase 8 finding. And the pair of SHAs
makes the sequence auditable after the fact by anyone, including a reviewer who was not present,
which is the normal case for an autonomous build.

Where this record lives: a short table in `TESTS_TDD.md` for the P0 and regression set, or
`AUDIT_LOG.md` appended as the build proceeds. Either is fine; **no** location is not, because
"we did TDD" is unfalsifiable and therefore worth nothing as a claim.

### 4.3 The three exemptions, stated so they are not invented

Test-first has real edges. Name them rather than leaving the agent to improvise a broader one:

- **Spikes and exploration.** Throwaway code written to learn something. The exemption holds
  only if the spike is deleted; if any of it survives, it arrives via a test written first
  against the surviving behavior.
- **Generated code and scaffolding.** Tests cover the behavior you configured, not the
  generator's output.
- **Pure refactors.** No new test, because no new behavior — but the existing suite must pass
  before and after **without modification**. A refactor that requires touching tests is not a
  refactor; it is a behavior change wearing a refactor's commit message, and it needs the
  test-first path.

---

## 5. Property-based tests

An example test proves the claim for the three inputs someone thought of. A property test states
the claim itself and lets a generator hunt for the counterexample. Where a requirement makes a
*general* claim, examples are the wrong instrument — they are a sample from an input space
nobody characterized.

### 5.1 Which claims demand one

Any FR or design claim that is **algorithmic, scoring, ordering, parsing, or arithmetic** gets a
property suite. Concretely:

| Claim shape | Property to assert |
|---|---|
| Scoring or ranking ("results are ordered by relevance") | Ordering is total and antisymmetric; the comparator is transitive; score is deterministic for identical input; a change that should not affect rank does not (metamorphic). |
| Serialization / parsing (CSV, JSON, dates, query strings, IDs) | Round-trip: `parse(render(x)) == x` for all generated `x`, including empties, embedded delimiters, quotes, newlines, unicode, and the maximum length from the payload NFR. |
| Money and arithmetic | Sums are associative under the rounding policy; totals equal the sum of parts to the stated precision; no operation produces a negative where the domain forbids it; currency never crosses without an explicit conversion. |
| Pagination and cursors | Concatenating all pages equals the full set, with no duplicates and no omissions, under insertions between page fetches (this is where cursor bugs actually live). |
| Deduplication, merging, set operations | Idempotence: applying twice equals applying once. Commutativity where claimed. |
| Retry and idempotency | Applying the same idempotency key twice produces one effect. Replaying a delivered message changes nothing. |
| Access control decisions | Monotonicity: adding a permission never removes access; removing one never grants it. Cheap to state, and it catches the boolean-logic inversion that reviews miss. |
| State machines | Every generated legal transition sequence leaves the entity in a legal state; no sequence reaches a state with no exit. |
| Caching | The cached answer equals the uncached answer for every generated input — the property that makes a cache safe to add. |

The rule of thumb, worth stating in the document: **if the requirement's statement contains
"every", "all", "any", "never", or "always", it is a property claim.** Those words are quantifiers,
and a quantifier tested with three examples is an assertion about three things.

### 5.2 Stating the invariant

An invariant is written as one sentence with an explicit quantifier and a stated domain, then
translated directly into the property function. Vague invariants generate vague tests.

```
Weak:   "Export handles large accounts correctly."
Strong: "For every account with 0 <= n <= 100,000 records, the exported file
         contains exactly n data rows and one header row."

Weak:   "The parser is robust."
Strong: "For every record r drawn from the record generator,
         parse_csv(render_csv([r])) == [r] — including records whose text fields
         contain commas, double quotes, CR, LF, CRLF, and the 4-byte-UTF-8 range."
```

The second is testable as written, and the domain statement (`0 <= n <= 100,000`) doubles as the
generator specification.

### 5.3 Generator design

The generator is where property tests silently lose their power. A generator that only produces
well-formed medium-sized values proves the code works on well-formed medium-sized values,
expensively.

- **Generate at the boundaries the requirement names**: zero, one, the NFR's stated maximum,
  and maximum+1 where rejection is the required behavior.
- **Generate the hostile shapes**: empty strings and empty collections, whitespace-only, the
  delimiter inside a field, embedded newlines, unicode beyond the BMP, combining characters,
  strings that look numeric, `null` where nullable, duplicate keys, deeply nested structures to
  the stated depth limit.
- **Generate structurally, not stringly.** Build a valid domain object and derive the string
  from it, so the generator cannot drift out of the space the code will ever see and waste every
  run on inputs that are not real.
- **Constrain to preconditions with a filter only when the rejection rate is low.** A filter
  discarding most candidates turns a 200-case run into a 12-case run silently. Prefer
  constructing valid values directly, and assert the generator's own yield where the library
  reports it.
- **State the case count** in the suite's exit condition. The default is often 100; for a P0
  algorithmic claim, say the number you chose and why, since the number is the strength of the
  test.

### 5.4 Shrinking and the seed rule

**Shrinking** — the library's reduction of a failing case to a minimal one — is the reason
property tests are debuggable. Two requirements follow: use a library that shrinks (name it in
the document), and write generators that shrink usefully, which means composing library
primitives rather than hand-rolling from a raw random source. A hand-rolled generator typically
does not shrink at all, and a 4KB random blob failure is a defect report you cannot act on.

**The seed rule: every property suite records its seed on failure, and the seed is sufficient to
reproduce the run.** State it in the suite's exit condition and make the CI output carry it. A
property test that fails once in CI, reports "falsified after 63 tests", and cannot be re-run is
strictly worse than no test — it consumes attention and produces nothing actionable.

Where the library supports a failure database, commit it, so a once-found counterexample is
re-tried on every subsequent run forever. That converts a lucky find into a permanent regression
test at no cost, which is the best value in this entire section.

Finally: **a shrunk counterexample becomes a named example test.** Property tests find the case;
an example test pins it. Property suites are re-randomized on every run and cannot be relied on
to re-find the same bug, so the counterexample gets its own permanent test with the property
suite's name and the date cited.

---

## 6. Regression tests for Phase-0 defects

Phase 0's product is not a report — it is a set of named requirements and regression tests
(`deliverables-requirements.md` §6). This section is where the second half of that lands, and
it is the highest-value, lowest-effort section in this file: the analysis was already paid for,
and skipping the conversion means the rewrite reproduces the defect the audit found.

### 6.1 The rule

**One named test per `DR-<n>`, named for the defect, citing the original defect in its
docstring or title, and asserting the specific behavior the defect violated.** A `DR-<n>` that
becomes no test must carry an explicit not-carried-forward reason with a `D<n>` — and that
reason lives in the defect register row, not only in someone's memory of the conversation.

The docstring citation is not ceremony. Five months later, someone will look at
`test_25k_no_truncation`, see that the export path obviously streams a cursor now, conclude the
test is redundant, and delete it. The docstring is the sentence that stops them: it says what
broke, what users experienced, and that this test is the only thing standing between the product
and a repeat.

```python
def test_25k_no_truncation(app_db, storage):
    """Regression for DR-07 (docs/PRD.md Phase-0 register).

    Legacy export reused the paginated list helper without advancing the cursor.
    Any account over PAGE_SIZE (1,000) received a file with exactly 1,000 rows,
    and the job was marked 'complete' with a success toast. Users reconciled
    against truncated data for an unknown period without any signal.

    Do not delete this test because the export path 'obviously' streams now.
    That is what makes the regression cheap to reintroduce.
    """
```

### 6.2 Generalize past the instance

The most valuable regression tests assert the **class**, not the instance. `DR-07` is
specifically a 1,000-row truncation; the class is "a job reports success while writing fewer
rows than it counted". The instance becomes the regression test; the class becomes an invariant
asserted everywhere it applies — in `DR-07`'s case, the `rows_written == rows_counted` check
that `FR-EXPORT-3 AC-4` added to every export job, plus a property test over row counts (§5).

State this as the standard in `TESTS_TDD.md`: **each `DR-<n>` produces one regression test, and
is examined once for the generalization.** When the class-level test exists, note it in the
register row alongside the instance test. When it does not, say why in one line — sometimes the
defect really is a one-off, and recording that judgment is more useful than pretending you
looked and found nothing.

### 6.3 Production incidents inherit the same rule

The `DR-` register does not close at Phase 0. Every post-launch incident and every user-reported
bug gets the same treatment: a failing test that reproduces it, committed before the fix, named
for the incident, citing the postmortem. Write that rule into `TESTS_TDD.md` now, because a rule
that arrives after the first incident arrives after the argument about whether it is worth it.

---

## 7. Eval gates for ML and LLM components

A test asserts a fact. An eval measures a distribution. Any component whose output is not a
deterministic function of its input — an LLM call, a classifier, a ranker, an embedding-based
retrieval, an OCR or speech pipeline — is measured, not asserted, and the measurement needs a
number attached to it or it decides nothing.

**An eval with no numeric pass bar is a demo.** It produces output that a human reads and
approves, which is not a gate; it is a vibe with a CI job attached. State that sentence in
`TESTS_TDD.md`.

### 7.1 Required fields for every eval gate

| Field | What it holds | Why |
|---|---|---|
| **Golden set** | Size, and **provenance** for every item: real user data (with the consent and privacy basis stated), hand-authored, synthetic-from-a-model, or scraped (with the license). | Provenance decides what the score means. A golden set generated by the same model family you are evaluating measures agreement, not correctness — the most common way an eval reports 0.95 and predicts nothing. |
| **Split policy** | Which items are development (visible while iterating) and which are held out. Held-out items are read only at gate time. | A set you tune against stops being a measurement the third time you look at it. |
| **Rubric** | The per-item criteria and their scale, precisely enough that two graders agree. Where a model is the grader, the grader prompt is versioned and pinned like code. | An unwritten rubric drifts with the grader's mood or the grader model's version, and the score becomes incomparable across runs — which destroys drift detection (§7.4). |
| **Metric** | The name **and the exact computation**: what counts as a hit, how ties are handled, macro vs micro averaging, the denominator, whether abstentions count as failures. | "Accuracy 0.91" is not reproducible. Two reasonable people compute three different numbers from the same outputs. |
| **Pass bar** | A number, with the reasoning for that number and the baseline it beats. | This is the gate. Without it there is no gate. |
| **Nondeterminism handling** | Repeat count per item, aggregation across repeats, and the tolerance band (§7.3). | A single sample from a stochastic system is a coin flip reported as a measurement. |
| **Cadence** | When it runs: per PR touching prompts/model config, nightly, per release, and the drift schedule (§7.4). | Evals are slow and cost money; running them on every commit is how they get disabled. |
| **Cost/runtime budget** | Tokens or dollars per run and wall-clock. | An eval whose cost nobody sized gets cut the first time the bill is reviewed. |
| **Failure behavior** | What a below-bar result does: blocks the merge, blocks the release, opens an issue. And who adjudicates. | "The eval failed" with no consequence is a report, not a gate. |

### 7.2 Sizing and provenance

Golden-set size follows from the decision you need to make, and the honest version of this is
that a small set has a wide confidence interval. A 20-item set cannot distinguish 0.85 from
0.75; treating a 2-item swing as a regression on that set will burn credibility until people
start overriding the gate. State the set size, state the resolution you are claiming, and where
the set is small say so in the document rather than implying precision the arithmetic does not
support.

Composition matters more than raw size. Cover, deliberately and in stated proportion: the
common case, each known failure mode from Phase 0 or production, adversarial and
prompt-injection inputs where the component reads untrusted text (`SECURITY.md` owns the threat
list; the eval owns the measurement), empty and degenerate inputs, and long inputs at the
context boundary. A set that is 90% happy-path reports a happy-path score and hides everything
that matters.

**Freeze and version the set.** Every change to the golden set is a commit with a reason, and
scores are only comparable within a set version. Silently adding easy items is how a metric
climbs while the product does not.

### 7.3 Nondeterminism — repeats and tolerance

Set the sampling parameters explicitly (temperature, top-p, seed where the provider supports
one) and record them beside every score, because a score from different parameters is a
different measurement.

For any stochastic component, state:

- **Repeat count** per item — the number of samples aggregated. One is not a measurement.
- **Aggregation** — mean, majority vote, or worst-case. Worst-case is the right choice for
  safety-relevant properties (a harmful output in one of five samples is a failure, not a 0.8).
- **Tolerance band** — the movement that counts as noise rather than regression, and how it was
  established (measure the same unchanged config across several runs and observe the spread;
  do not guess a band, because a guessed band is either a gate that never fires or one that
  fires constantly).

```
EVAL-SUMMARY-1
Golden set:   180 items, v4 (frozen 2026-05-02). Provenance: 120 real documents
              sampled from {{DATA_SOURCE}} under {{CONSENT_BASIS}}, 40 hand-authored
              adversarial (prompt injection, contradictory sources, empty input),
              20 held out and never inspected during iteration.
Rubric:       5 binary criteria per item (factual support, no fabricated citation,
              covers the stated key point, length within bound, refuses when the
              source is insufficient). Grader: human-labeled reference answers +
              programmatic checks. Model-graded criteria: none — the two that
              needed judgment were rewritten as programmatic checks instead.
Metric:       Per-item score = criteria passed / 5. Suite score = mean over items
              (macro, unweighted). Abstention counts as a pass on criterion 5 only
              when the source genuinely lacks the answer, per the reference label.
Pass bar:     mean >= 0.88 AND no single criterion below 0.80 AND zero fabricated
              citations across the whole set (that last is a hard zero, not a rate,
              because one fabricated citation is a product-credibility failure and
              averaging it away is the thing this bar exists to prevent).
Repeats:      3 samples per item at temperature 0.2, worst-case aggregation for the
              fabrication criterion, mean for the rest.
Tolerance:    +/- 0.02 on the mean is noise (measured: 5 runs of the unchanged
              config spanned 0.869-0.891). Below bar, or a drop > 0.02 without a
              deliberate change, blocks the release.
Cadence:      every PR touching prompts, model version, or retrieval config;
              nightly on main; full re-run per release.
Budget:       ~1.6M tokens, ~11 min, {{COST_PER_RUN}} per full run.
On failure:   Blocks merge. Adjudicated by {{EVAL_OWNER}}; an override requires an
              ADR (§10) recording the score, the reason, and the expiry.
```

### 7.4 Drift detection

Model providers change models under stable names, retrieval corpora grow, and prompts get
edited by people who did not read this document. Drift detection is a scheduled re-run of the
frozen set against the unchanged config, with the score stored over time.

Specify: the cadence (nightly for anything in a P0 path; weekly is defensible for a P2
feature), where the history is stored, the alert threshold in terms of the tolerance band, and
the **pinned model version** with an explicit statement of what happens when the provider
deprecates it. Pin the version; "latest" makes every score incomparable to the one before it and
turns a provider's Tuesday into your outage.

---

## 8. UI and end-to-end testing

### 8.1 What belongs at e2e, and what does not

E2E is the most expensive coverage available: slowest to run, slowest to write, most fragile
under redesign, and the only level that flakes for reasons unrelated to your code. Treat each
e2e test as a purchase and state the budget.

**Belongs at e2e:** the critical-path journeys (§8.2), and only those. Cross-cutting wiring that
no lower level sees — routing, auth session establishment through the real client, build and
bundling, environment configuration, third-party script interference, the actual navigation
between screens.

**Does not belong at e2e:** field-level validation rules (unit), error-message copy for every
error class (unit or integration), permission matrices (integration, against the real database),
computation and formatting (unit), every empty state (component/integration), and the
combinatorial explosion of form permutations. Each of those tested at e2e costs minutes,
flakes, and proves the same thing a millisecond-scale test proves.

The heuristic to state: **if the assertion could be made below the browser, make it below the
browser.** E2E's job is to prove the pieces are connected, not to re-verify the pieces.

### 8.2 The critical-path journey list

`TESTS_TDD.md` must contain an explicit, enumerated list of journeys that have e2e coverage.
Not a description of a policy — the list. Every product has one; a product whose list cannot be
written down does not know what it is for.

The minimum set, adapted to what the product actually has (omit with a stated reason, never
silently):

| Journey | Why it is on the list |
|---|---|
| First-run: land → sign up → reach the first moment of value | The path every user takes exactly once, and the one that breaks silently after a config change. |
| Returning: sign in → the primary task → sign out | The most-executed path in the product. |
| The core create/edit/delete loop for the primary entity | Where data loss lives. |
| Payment or upgrade, if money exists | Broken checkout is the highest-cost failure per minute in the product. Run against the provider's test mode, which is real infrastructure. |
| Permission boundary: a user attempts another user's resource through the UI and is refused | The e2e half of §3.1's authorization claim: proves the refusal reaches the interface rather than only the database. |
| Recovery: password reset / account recovery end to end, including the delivered message | Nobody exercises this until it is needed, and by then the user cannot report it to you. |
| Error and offline: a primary action while the network fails | Proves the product degrades visibly instead of hanging or silently discarding input. |
| Mobile: cold launch → primary task; and background → resume with state intact | Resume-with-state is the mobile bug class that desk-testing never sees. |

For each journey, name the suite ID, the substrate, and the platforms it runs on. A journey
listed without a suite is a gap, and gaps go in the gaps column (§2.2), not in the intent
column.

### 8.3 Selectors and stability

State the selector policy, because it is the difference between an e2e suite that survives a
redesign and one that is deleted after it. Prefer **role and accessible-name** queries, which
double as accessibility assertions (§8.5); fall back to explicit test IDs for things with no
accessible identity. Never select on CSS classes, DOM structure, or visible copy that the
content team owns — those change for reasons unrelated to behavior, and a suite that breaks on
copy edits teaches everyone that red means nothing.

State the waiting policy in the same breath: wait on conditions, never on durations. A fixed
sleep is either slower than needed or shorter than needed, and it becomes the latter on the CI
runner's worst day. Fixed sleeps are the single most common root cause in flake investigations
(§11).

### 8.4 Visual regression — and its flake cost

Visual regression testing catches the class nothing else catches: a layout that renders wrong
while every assertion passes. It also has a real and frequently underestimated cost, and a
visual suite that cries wolf gets approved blindly within two weeks, at which point it is worse
than nothing because it launders real changes through a rubber stamp.

If adopted, `TESTS_TDD.md` must specify all of:

- **Scope.** A small set of high-value surfaces (the design system's component gallery, and one
  or two composed screens), not every screen. Component-level shots are far more stable than
  page-level ones, and localize the diff to the actual change.
- **Determinism controls.** Pinned browser/renderer version, fixed viewport, fonts loaded and
  waited for, animations disabled, `prefers-reduced-motion` forced, time and randomness frozen,
  fixed seed data, images either local or stubbed. Every one of these is a source of false
  diffs, and the suite is only usable once all of them are controlled.
- **Rendering environment.** The same container CI uses. Font rendering differs between host
  operating systems, so baselines taken on a developer laptop will diff forever against CI.
- **Threshold.** The pixel/perceptual difference tolerated, and why. Zero-tolerance produces
  constant noise; a large tolerance hides the regressions you bought it for.
- **Approval flow.** Who reviews a diff, and the rule that approving a baseline is a deliberate
  act recorded in the PR. Baseline approval is where visual testing dies.
- **Blocking or reporting.** Given the flake cost, reporting-with-required-review is a
  legitimate and often better choice than blocking. Say which, and say why.

If the product cannot pay these costs, **say so and skip it** rather than adopting a suite that
will be rubber-stamped. Recording "visual regression: not adopted, because {{reason}}; layout
risk is carried by the component gallery review each release" is a stronger document than an
unusable suite.

### 8.5 Accessibility assertions in tests, not only in an audit

`NFR-A11Y-1` names a conformance level. An audit measures it once; tests hold it. Automated
tooling catches roughly a third of issues, so the split is stated explicitly rather than
implied:

**In the automated suite, blocking:**
- An axe (or equivalent) scan on every critical-path screen and every design-system component,
  with the ruleset and the version pinned, failing on violations at the stated conformance level.
- Assertions that are naturally accessibility assertions: every interactive element is reachable
  and operable by keyboard; focus order follows visual order on each P0 flow; focus is trapped
  in modals and returns to the trigger on close; every form field has a programmatic label;
  every image has alt text or is explicitly decorative; live regions announce async results.
- Selector policy from §8.3 doing double duty: a test that finds a button by role and accessible
  name **fails when the button loses its accessible name**, which is the most common
  accessibility regression there is. This is the cheapest accessibility coverage available and
  it costs nothing beyond the selector choice.
- Contrast checked at the token level (in the design system's own tests) rather than by
  screenshot, so it is verified once per token pair rather than approximately per screen.

**Manual, per release, with a recorded result:**
- Keyboard-only traversal of each P0 flow.
- A screen-reader pass on each P0 flow, naming the reader and version.
- Zoom/reflow at 200% and at the minimum viewport from the browser NFR.

The manual results are recorded in `AUDIT_LOG.md` with a date, because "we do a manual pass" is
unfalsifiable and stops happening the first busy release. On mobile, the equivalents are the
platform accessibility inspector plus a VoiceOver/TalkBack pass; the same recording rule
applies.

### 8.6 Cross-platform coverage

The matrix in `TESTS_TDD.md` **mirrors the NFR matrix exactly** (`NFR-BROWSER-1` or its mobile
equivalent). Restating it differently is how a browser gets claimed in the PRD and tested
nowhere.

For web, specify which browsers run the full journey list and which run a smoke subset, and note
that engine coverage (Chromium/Gecko/WebKit) matters more than brand coverage — Chrome and Edge
are one engine, and testing both while skipping WebKit is a matrix that looks broad and is not.

For mobile, specify the OS versions (oldest supported and newest, at minimum — the middle rarely
earns its runtime) and the device classes (smallest supported screen, a current mainstream
device, and a tablet if tablets are supported). Note that the oldest supported OS is where the
API-availability bugs live, so it is not the one to drop when the matrix is trimmed.

Anything not in the matrix is **not tested and not claimed**. Write that sentence down; it is
what makes the matrix a decision rather than an aspiration.

---

## 9. Coverage

### 9.1 The number, and what it is for

State a target percentage. The house default elsewhere in this configuration is 80% line/branch
coverage; adopt it or state a different number with a reason.

Then state, in the document, what the number does and does not prove:

**Coverage proves** that a line executed during the suite. That is genuinely useful: it makes
never-executed code visible, and never-executed code in a shipped product is either dead or a
latent crash.

**Coverage does not prove** that the line was *checked*. A test that calls a function and
asserts nothing produces identical coverage to a test that asserts everything. It says nothing
about whether the assertions are correct, whether the inputs were meaningful, or whether the
behavior matches the requirement. It is entirely possible — and, under an autonomous agent
optimizing a number, likely — to reach 90% coverage with a suite that would pass against a
substantially broken product.

Hence the rule to write down: **the percentage is a floor, never the goal.** The goal is the
traceability graph in §2 being complete. Coverage is the cheap mechanical check that runs
alongside it and catches the code nobody looked at.

A useful sharpening where the tooling supports it: **mutation testing** on the highest-value
modules (payment arithmetic, authorization decisions, the scoring algorithm). Mutation score
measures whether tests *detect* changed behavior, which is the question coverage is usually
being asked and cannot answer. Run it on a narrow scope and on a slow cadence — it is expensive
— and treat it as a periodic audit of test quality rather than a per-PR gate.

### 9.2 The paths that must be covered regardless of the number

These are covered even if the overall percentage is already met, because the percentage is an
average and averages hide exactly these:

| Path class | Why it is on the list |
|---|---|
| **Error paths** | Every catch block, every non-2xx branch, every retry-exhausted path. Untested error handling is where silent failures live, and silent failure is the Phase-0 defect class that recurs most. A catch block that has never executed under test is a guess. |
| **Authorization branches** | Both sides of every permission decision. Testing only the allow path proves the feature works; the deny path is the security control, and it is the one that gets inverted in a refactor. |
| **Migration paths** | Forward from empty, forward from the previous release's populated schema, and the rollback if one is claimed. A rollback nobody tested is not a rollback. |
| **Empty and boundary states** | Zero items, exactly one, exactly the page size, page size plus one, the maximum from the payload NFR, maximum plus one. The empty state also gets a UI test, because "no data" rendering identically to "failed to load" is a defect this configuration names explicitly. |
| **Null/absent/optional handling** | Every optional field absent, and present-but-empty, which is a different case and is routinely handled by the same branch incorrectly. |
| **Concurrency and idempotency** | The same request twice, two writers to one record, the retry after a timeout where the first attempt actually succeeded. |
| **Every P0 acceptance criterion** | By definition. A P0 AC with no passing test means the build is not done, whatever the coverage number says. |
| **Every configuration branch that ships** | Both states of any flag gating a P0 path; every environment-conditional code path that runs in production. |

State also what is deliberately excluded from the coverage measurement and why — generated
code, vendored code, migration files, framework glue — because an unexplained exclusion list is
where the number gets gamed, and a documented one is a decision.

---

## 10. The test-weakening protocol

A test going red is the system working. The cheapest way to make it green is to weaken it, and
that is the single most destructive edit available in this whole package: it converts a caught
defect into a shipped defect and removes the evidence.

**Rule: weakening, skipping, deleting, or `@expected_failure`-ing a test requires a
human-reviewed ADR. A build agent may never do it unilaterally.** State this in `TESTS_TDD.md`
and again in `CLAUDE.md`, because `CLAUDE.md` is what the agent reads first and this is the rule
most worth it encountering early.

### 10.1 What counts as weakening

Naming the forms matters, because "I didn't delete anything" is technically true of every one of
these:

- Deleting a test, or deleting an assertion within one.
- Adding `skip` / `xfail` / `@Ignore` / `.only` on a subset / commenting it out.
- Loosening an assertion: `==` to `>=`, an exact value to `is not None`, a tightened tolerance
  widened, an exact row count to a truthiness check.
- Removing a case from a parameterized set, or lowering a property suite's case count.
- Lowering a threshold: a coverage floor, an eval pass bar, a latency budget, a visual diff
  tolerance.
- Replacing a real substrate with a mock (§3) — this is weakening even when every assertion is
  preserved, because the assertions now run against the fake.
- Moving a suite from blocking to reporting in CI. Same effect as deleting it, with a paper
  trail that reads like configuration.
- Broadening a retry or adding a retry to make a test pass reliably (§11 — the correct response
  to a flake is diagnosis, not retries).

### 10.2 The ADR

Uses the repository's ADR format (the `architecture-decision-records` skill owns that format).
Location: `docs/decisions/`, matching the convention this configuration uses elsewhere.
Contents, at minimum:

```
ADR-<n>: Weaken TS-EXPORT-1 25k-row assertion
Date:            YYYY-MM-DD
Status:          accepted
Reviewed by:     {{HUMAN_REVIEWER}}   <- a person, not the build agent
Test affected:   tests/export/test_csv_large.py::test_25k_no_truncation (TS-EXPORT-1)
Requirement:     FR-EXPORT-3 AC-2, P1.  Regression for DR-07.
Change:          exact-count assertion relaxed to >= 24,900 rows
Reason:          <the actual reason, mechanically stated>
What is no longer proven:  Off-by-a-few truncation up to 100 rows would now pass.
                 DR-07's exact failure mode (truncation at 1,000) is still caught.
Risk accepted by: {{HUMAN_REVIEWER}}
Expiry:          YYYY-MM-DD — restore the exact assertion or renew this ADR.
Tracking:        {{ISSUE_REF}}
```

Two fields carry the weight. **What is no longer proven** forces the author to state the gap in
plain language, and stating it is usually the moment the weakening is abandoned in favor of
fixing the actual problem. **Expiry** prevents a temporary accommodation from becoming permanent
by silence — a weakening with no expiry is a permanent change described as a temporary one.

### 10.3 What a build agent does instead

Give the agent the alternative explicitly, because "never weaken a test" without a next step
produces a stuck agent, and a stuck agent improvises the thing you forbade.

When a test is red and the agent believes the test is wrong:

1. Re-read the acceptance criterion the test cites. Usually the test is right and the
   implementation is wrong; this is the normal case and it ends here.
2. If the test genuinely contradicts the criterion, the **test** is fixed to match the criterion
   — that is not weakening, it is correcting a transcription error, and it is recorded in the
   commit message with the AC quoted.
3. If the test matches the criterion but the criterion is wrong, that is a **PRD change**: raise
   it as a `D<n>` blocker per the never-stop protocol in `CLAUDE.md` and continue on other work.
   The requirement changes first; the test follows.
4. If the test is correct, the criterion is correct, and the implementation cannot satisfy it,
   that is a design finding. Raise it. Do not resolve a design problem by editing its detector.

---

## 11. Flake policy

A flaky test — one that passes and fails on the same code — is not a minor annoyance. It teaches
the team that red does not mean broken, and once that lesson lands, every real failure is
retried before it is read. One tolerated flake degrades the entire suite's signal, which is why
this needs a written policy rather than case-by-case judgment.

### 11.1 Detection

Specify the mechanism, not the intention:

- Re-run the full suite on a schedule against unchanged code (nightly on main). Any failure
  there is a flake by definition, since nothing changed.
- Record per-test pass/fail history in CI so intermittency is visible. Without history, a flake
  is only detectable by someone who happens to remember, and nobody remembers.
- Name the threshold that makes a test officially flaky (for example: two non-reproducible
  failures within ten runs) so quarantine is a mechanical decision rather than an argument.

### 11.2 The common causes, so diagnosis has a starting point

Worth listing in the document, because flake investigations otherwise start from zero every
time. In rough order of frequency: fixed sleeps instead of condition waits; shared mutable
fixture state across tests; test-order dependence (a suite that only passes in one order);
real clocks and timezone/DST boundaries; unseeded randomness; unawaited async work continuing
past the assertion; port and resource contention between parallel workers; external network
calls that should have been faked (§3.2); and CI runners that are simply slower than the
developer machine the timeouts were tuned on.

### 11.3 Quarantine — with an owner and an expiry

A quarantined test is removed from the blocking gate and moved to a reporting job so it still
runs and still reports. Quarantine requires, without exception:

- A **named owner** — a person, not a team, because a team-owned quarantine is unowned.
- An **expiry date**, typically short (two weeks is a reasonable default; say what you chose).
- A **tracking issue** with the failure output and the suspected cause.
- The requirement and suite it covers, so the gap is visible in the traceability table's gaps
  column (§2.2) rather than invisible in a CI config.

**A permanently quarantined test is a deleted test with extra steps.** At expiry the test is
either fixed, or deleted through the §10 ADR path with the coverage gap stated. Silent renewal
is not an option, and a quarantine list that only grows is the same failure as a suite nobody
runs, arrived at more slowly.

Two hard rules alongside it. **A P0 requirement's suite is never quarantined** — if it is
flaky, the flake is the top-priority defect, because the alternative is shipping a P0 path with
no gate. And **automatic retries are not a flake policy**: a retry hides intermittency instead
of diagnosing it, and an intermittent failure is very often a real race condition that users
will hit at a much higher rate than CI does. Where retries exist for infrastructure reasons,
they must report the retry so the flake remains visible.

---

## 12. Definition of done — Phase 6

Each line is mechanically checkable: a grep, a script, a count, or a yes/no with no
interpretation. Every line is checked before Phase 7 begins. A failing line is a blocker, not a
note.

**Suite entries**

- [ ] Every suite has a `TS-<GROUP>-<n>` ID; no duplicates; no IDs reused from deleted suites.
- [ ] Every suite entry has all required §1.2 fields; `n/a` entries carry a reason.
- [ ] Every `Proves` field states a claim, not a mechanism (no entry reads "tests the X function").
- [ ] Every suite names a level from `{unit, integration, e2e, property, eval, regression}`.
- [ ] Every suite names a specific substrate, not a category — "real Postgres 16, RLS enabled, application role", not "integration environment".
- [ ] Every suite names a CI job and states blocking or reporting.
- [ ] Every suite states a runtime budget with the machine class assumed.
- [ ] Every suite states an exit condition beyond exit code 0.
- [ ] At least one suite entry includes a runnable-looking skeleton with real assertions.

**Traceability**

- [ ] The FR→suite table exists, with one row per FR, including P2/P3 rows carrying their §1.2 exception explicitly rather than a blank.
- [ ] The suite→FR table exists, with one row per suite, and every orphan is marked and dispositioned.
- [ ] Every P0 and P1 FR maps to at least one suite; every acceptance criterion is either covered or listed in the gaps column.
- [ ] No suite has an empty `Covers` field.
- [ ] Every NFR maps to a named verification mechanism (suite, load script, dashboard panel, or scheduled drill) with an owner.
- [ ] Every `DR-<n>` from Phase 0 maps to a named regression test or an explicit not-carried-forward reason with a `D<n>`.
- [ ] `scripts/id-sweep.sh docs` exits 0, and its output is appended to `AUDIT_LOG.md`.
- [ ] Every weak-only ID in the sweep output has been checked by hand against a real defining entry in the owning document.
- [ ] The `TS-` ID-checking decision is stated: either the sweep's regex was extended, or the by-hand check carries it.
- [ ] The sweep has been observed FAILING on a deliberately broken ID in this package.

**Substrate**

- [ ] Every authorization/tenancy claim runs against a real database with policies enabled, and the entry names the connection role.
- [ ] No suite covering a security requirement lists a mock in its substrate — grep the substrate fields.
- [ ] Migrations are tested forward from empty and forward from the previous release's schema.
- [ ] Every fake in §3.2 names its constraint (HTTP-boundary recording, injected clock, seeded RNG, transport sink, sandbox endpoint) and its `Known limits`.
- [ ] Third-party contract suites exist for every faked vendor, with a stated re-record cadence.
- [ ] The compose/emulator file exists with pinned versions matching production's major/minor, and one documented command runs the suite from a clean checkout.
- [ ] Emulator fidelity gaps are listed where a managed service is emulated, each with a mitigation or a declared risk.
- [ ] Mobile: the simulator/device split is stated, and every untestable item touching a P0 requirement has an `UNTESTABLE-<n>` entry with a substitute, a residual risk, and an owner.

**Test-first protocol**

- [ ] The sequence appears in `TESTS_TDD.md`, including the confirm-it-fails-on-the-intended-assertion step, and cites `tdd-workflow` for execution mechanics rather than restating it.
- [ ] Every P0 requirement and every regression test has a recorded red state: the assertion failure text plus the test-only commit SHA.
- [ ] No recorded red-state output is an `ImportError`, `NameError`, fixture error, or collection error.
- [ ] The three exemptions (spike, generated code, pure refactor) are stated, with the pure-refactor rule that the existing suite passes unmodified.

**Property tests**

- [ ] Every algorithmic, scoring, ordering, parsing, or arithmetic FR has a property suite, or a stated reason it does not.
- [ ] Every property suite states its invariant as one sentence with an explicit quantifier and a stated domain.
- [ ] Every property suite names its generator, its boundary and hostile-shape coverage, and its case count.
- [ ] Every property suite records its seed on failure, and the seed reproduces the run.
- [ ] The library named supports shrinking, and generators are composed from its primitives.
- [ ] Every found counterexample has been pinned as a named example test citing the property suite and the date.

**Regression tests**

- [ ] One named test per `DR-<n>`, named for the defect.
- [ ] Every regression test's docstring or title cites its `DR-<n>` and states what the original defect did — grep for the `DR-` string across the test tree.
- [ ] Each `DR-<n>` records whether a class-level generalization was added, or one line saying why not.
- [ ] The rule extending this to post-launch incidents is written down.

**Eval gates** (or an explicit "no ML/LLM component — not applicable")

- [ ] Every eval names its golden set size and per-item provenance, including the consent/licence basis for any real data.
- [ ] No golden set is generated by the same model family being evaluated without that being stated as a limitation.
- [ ] A held-out split exists and is stated.
- [ ] Every eval has a written rubric; any model-graded criterion has a pinned, versioned grader prompt.
- [ ] Every metric states its exact computation: hit definition, averaging, denominator, abstention handling.
- [ ] **Every eval has a numeric pass bar.** An eval without one is a blocker, not a note.
- [ ] Every eval states repeat count, aggregation, and a tolerance band established by measurement, not by guess.
- [ ] Every eval states cadence, cost/runtime budget, failure behavior, and an adjudicating owner.
- [ ] The model version is pinned, and the deprecation response is stated.
- [ ] Drift detection has a cadence, a storage location for history, and an alert threshold.

**UI and e2e**

- [ ] The critical-path journey list is enumerated, and every journey names a suite ID or is in the gaps column.
- [ ] Every journey in the minimum set (§8.2) is present or omitted with a stated reason.
- [ ] The selector policy and the waiting policy are stated; grep the e2e tree for fixed sleeps and for CSS-class selectors.
- [ ] Visual regression is either specified with all six required elements (scope, determinism controls, rendering environment, threshold, approval flow, blocking-or-reporting) or explicitly not adopted with a reason and a stated alternative control.
- [ ] Accessibility assertions exist in the automated suite — axe scan with pinned ruleset, keyboard operability, focus order and trap, labels, alt text — not only in a manual audit.
- [ ] The manual accessibility pass has a named reader/tool, a per-release cadence, and a recording location.
- [ ] The browser/device matrix in `TESTS_TDD.md` matches the NFR matrix exactly — diff them.
- [ ] The statement "anything not in the matrix is not tested and not claimed" appears.

**Coverage**

- [ ] A target percentage is stated with the tool and the command that measures it.
- [ ] The document states what coverage does and does not prove, including that it does not prove assertions exist.
- [ ] Every path class in §9.2 is named with where it is covered.
- [ ] Coverage exclusions are enumerated with reasons.
- [ ] The floor-not-goal rule is written down.

**Weakening, flakes, and cross-references**

- [ ] The weakening protocol is in `TESTS_TDD.md` **and** in `CLAUDE.md`, and enumerates all the forms in §10.1.
- [ ] The ADR template names its location (`docs/decisions/`) and includes `What is no longer proven`, a human reviewer, and an expiry.
- [ ] The agent's alternative path (§10.3) is stated, so a red test produces a blocker rather than an edit.
- [ ] Flake detection names a mechanism and a numeric threshold for declaring a test flaky.
- [ ] Every quarantined test has an owner (a person), an expiry date, and a tracking issue; the quarantine list is in the document, not only in CI config.
- [ ] The rules that P0 suites are never quarantined and that retries are not a flake policy are both stated.
- [ ] `TESTS_TDD.md` cites `tdd-workflow` and `verification-loop` for execution mechanics instead of duplicating them.
- [ ] Every `{{PLACEHOLDER}}` remaining in the document is listed in the handoff message — grep for `{{`.
