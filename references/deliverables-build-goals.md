# Build goals — the acceptance contract for Phase 7

SKILL.md says Phase 7 converts the build plan into "goals with machine-checkable exit criteria —
literal commands with expected outcomes, never prose — plus a dependency graph, an invariant gate,
and grep-enforced anti-goals". That is the intent. This file is the specification: the field
schemas, the command formats, and the pass/fail bar that `LOOP_GOALS.md` and `STATE_AND_DATA.md`
must clear before Phase 7 is allowed to end.

The reason it exists: an exit criterion that reads *"authentication works end to end"* cannot be
executed. An autonomous build agent facing it does the only thing available — it forms a judgment,
declares the goal met, and moves on. Every judgment call compounds, because the next goal builds on
a foundation that was never actually verified, and the failure surfaces four goals later where it
is ten times more expensive to diagnose. The whole point of Phase 7 is to remove judgment from the
loop. A goal file full of sentences reintroduces it.

**The bar for this file: every exit criterion is a string a shell can run, with a defined expected
exit code and a defined expected output.** If a human has to read the output and decide, it is not
an exit criterion; it is a review step, and review steps belong in BLOCKERS.md as human-gated
items, not in the autonomous loop.

`LOOP_GOALS.md` is consumed by the `foreman` skill — its boss/worker/checker loop reads
`CLAUDE.md` as the constitution and this file as the goal list, and its independent checkers
re-execute the exit criteria rather than trusting a worker's self-report. Write for that reader.
Anything a checker cannot re-execute mechanically is invisible to the mechanism that catches lying
workers. This file does not restate foreman's orchestration; it specifies the artifact foreman
consumes.

**Notation used throughout.** Goal IDs are `G-<phase>.<n>` per `document-set.md` §Numbering,
matching the build plan's deliverable numbering in `DESIGN_SPEC.md`. FR/NFR/AD/D IDs are as
defined in `deliverables-requirements.md`. Exit criteria are numbered `EC-<n>` **within a goal**
and cited as `G-3.2/EC-1` when referenced from elsewhere. Anti-goals are `AG-<n>`, global to the
package, not per goal.

---

## 1. The goal entry schema

### 1.1 Required fields

Every goal carries all of these. A field that does not apply is written `n/a` with a half-line
reason, never omitted — the pre-flight audit cannot distinguish an omitted field from a forgotten
one, and neither can a build agent.

| Field | Required | What it holds | Why it is required |
|---|---|---|---|
| **ID** | yes | `G-<phase>.<n>`. Stable forever; never renumbered, never reused after deletion. | Commit subjects, the dependency graph, STATUS.md, and BLOCKERS.md all key off this string. Renumbering breaks the build's memory, and git history is the build's memory. |
| **Title** | yes | One line, imperative, naming the artifact produced: "Owner-scoped CSV export endpoint and job runner". | The title is what appears in STATUS.md and the commit subject. A title naming an activity ("work on export") instead of an artifact cannot be checked as done. |
| **Implements** | yes | The FR / NFR / AD IDs this goal delivers, in full. | This is the FR→goal edge of the traceability graph (`deliverables-requirements.md` §8). A goal implementing nothing required is work with no justification; an FR in no goal is a plan silently smaller than the PRD. |
| **Depends on** | yes | Goal IDs that must be complete first, or `none`. | The dependency graph (§4) is built from this field alone. It is what makes the never-stop protocol computable: on a blocker, the agent needs the unblocked set, and the unblocked set is a graph query. |
| **Reading map** | yes | Exact document sections the executing agent loads, as `file § heading` or `file:anchor`. Never "read the docs". | A context window is finite and the package is fourteen documents. "Read the docs" means the agent reads the first N kilobytes and guesses the rest. Naming sections is the difference between a goal executed against the spec and a goal executed against a plausible memory of it. |
| **Deliverable artifacts** | yes | Paths of files created or modified, plus migrations, config, and generated assets. Globs allowed where a directory is the unit. | The checker verifies these exist. It is also the input to the anti-goal grep scope (§6) — a goal that touched files outside this list is a scope breach, detectable mechanically. |
| **Test suites** | yes | Suite names or paths that must be green, mapped to the FRs they verify. Written before the implementation per the TDD protocol. | Ties the goal to `TESTS_TDD.md`. A goal with no named suite has no acceptance oracle beyond its own exit commands, which is thinner than it looks. |
| **Exit criteria** | yes | `EC-<n>` entries, each with a literal command, expected exit code, expected output pattern, and a red-before note (§2). | This is the machine-checkable core. Everything else in the schema is bookkeeping around it. |
| **Estimated size** | yes | One of `S` / `M` / `L` with the definitions in §1.3, plus a rough changed-file count. | Size drives parallelism decisions and blocker thresholds. An `L` goal that has produced no green criterion after three loops is a decomposition failure, not a stuck build; the size field is what makes that judgment mechanical. |
| **Anti-goals** | yes | The `AG-<n>` IDs that bind here, plus any goal-specific forbidden path, each with its enforcing grep or check. | Global anti-goals apply to every goal; this field records the ones with teeth here and any local addition (e.g. "must not modify the auth kernel"). |
| **Blocked-by-credential** | yes | Which criteria cannot run without a human-supplied credential, and what the fixture substitute is. Or `none`. | Per the cloud-independence rule in `claude-md-template.md`: a credential gap blocks a verification step, never a phase. Recording it up front prevents an agent from stalling on a goal it could have completed against fixtures. |
| **Rollback** | no | How to revert if the goal lands and later proves wrong: migration down-path, feature flag, or "revert the commit, no state". | Only required for goals with irreversible side effects — schema migrations, data backfills, anything touching money or external systems. |

### 1.2 What goes in the reading map, concretely

The reading map is the single field build agents get wrong most often, because "read `DESIGN_SPEC.md`"
feels responsible. It is not: `DESIGN_SPEC.md` in a Full-tier package runs to tens of thousands of
tokens, and an agent that loads it whole has spent its budget on schema for subsystems it will not
touch.

A well-formed reading map for a UI-bearing goal names, at minimum:

- the FR entries it implements, by ID, from `PRD.md`
- the schema section for the tables it touches, from `DESIGN_SPEC.md`
- the AD rows that constrain its mechanism
- the screen specs from `SCREENS.md` and the state contract from `STATE_AND_DATA.md` for those screens
- the token groups it consumes from `DESIGN_TOKENS.md` (not the whole file)
- the security rules that bind its surface, from `SECURITY.md`
- the test skeletons from `TESTS_TDD.md`

Anything not named is anything the agent will not read. That is the point: the map is a budget, not
a bibliography. If a section genuinely matters and is not listed, the goal is under-specified and
the fix is to list it — not to widen the map to "the design spec".

### 1.3 Size definitions

| Size | Meaning | Rough shape | Loop consequence |
|---|---|---|---|
| **S** | One cohesive change, one test suite, one commit. | 1-3 files, under ~150 changed lines. | Two no-progress loops is already suspicious. |
| **M** | A feature slice: endpoint + persistence + UI + tests. | 4-10 files. | Three no-progress loops triggers the blocker protocol per `claude-md-template.md`. |
| **L** | A subsystem. Should usually have been split. | 10+ files, or a migration plus its backfill. | An `L` that yields no green criterion in three loops is decomposed into sub-goals `G-<phase>.<n>a/b/c`, not retried. |

Prefer `S` and `M`. The reason is not aesthetic: a goal's exit criteria are the only feedback the
loop gets, and a large goal delivers that feedback late. Small goals turn a build into a sequence of
short, verified steps; large goals turn it into a long unverified stretch ending in a surprise.

### 1.4 Worked example — a complete goal

This implements `FR-EXPORT-3` from `deliverables-requirements.md` §1.4. Read it as the shape every
entry must have; nothing here is optional decoration.

```
G-3.2  Owner-scoped CSV export endpoint and job runner

Implements:     FR-EXPORT-3 (P1), NFR-THROUGHPUT-2, AD-6 (job queue: DB-backed, not broker)
Depends on:     G-1.4 (auth session middleware), G-2.1 (records schema + owner scoping),
                G-2.6 (job table migration and worker harness)
Estimated size: M (~7 files)

Reading map:
  docs/PRD.md § FR-EXPORT-3                       (all acceptance criteria, verbatim)
  docs/PRD.md § NFR-THROUGHPUT-2                  (the 25k-row bound and its measurement condition)
  docs/DESIGN_SPEC.md § Schema — records, export_jobs
  docs/DESIGN_SPEC.md § AD-6                      (why the queue is DB-backed; do not introduce a broker)
  docs/SECURITY.md § Rule S-4 authz-in-one-place, § Rule S-9 no-partial-artifact
  docs/SCREENS.md § SCR-SETTINGS-DATA, § SCR-EXPORT-STATUS
  docs/STATE_AND_DATA.md § SCR-EXPORT-STATUS data interface + polling contract
  docs/TESTS_TDD.md § Export suite skeletons (test_csv_scope, test_csv_large, test_csv_failure)

Deliverable artifacts:
  src/export/csv_writer.py            (streaming writer, no full-buffer)
  src/export/job_runner.py            (claims and executes export_jobs rows)
  src/api/routes/export.py            (POST /api/export, GET /api/export/:id)
  src/web/screens/ExportStatus.tsx    (SCR-EXPORT-STATUS)
  migrations/0014_export_jobs.sql     (already created in G-2.6; this goal must NOT alter it)
  tests/export/test_csv_scope.py
  tests/export/test_csv_large.py
  tests/export/test_csv_failure.py

Test suites (written first, red before implementation):
  tests/export/test_csv_scope.py      -> FR-EXPORT-3 AC-1, AC-3
  tests/export/test_csv_large.py      -> FR-EXPORT-3 AC-2 (regression for Phase-0 defect DR-07)
  tests/export/test_csv_failure.py    -> FR-EXPORT-3 AC-4

Exit criteria:
  EC-1  cmd:    pytest tests/export -q
        exit:   0
        match:  /^3 passed/m
        red-before: with src/export/ absent, pytest exits 4 (collection error) — confirmed
                    before implementation began.

  EC-2  cmd:    scripts/seed.sh --profile export-scope && \
                curl -sS -o /tmp/e.csv -w '%{http_code}' \
                  -H "Authorization: Bearer $(scripts/dev-token.sh owner-a)" \
                  -X POST localhost:8080/api/export/sync
        exit:   0
        match:  /^200$/
        and:    wc -l < /tmp/e.csv  ->  exit 0, match /^4$/     (3 data rows + 1 header)
        red-before: with the owner filter removed from the query, wc -l returns 6 — verified by
                    deliberately deleting the WHERE clause and re-running.

  EC-3  cmd:    curl -sS -o /dev/null -w '%{http_code}' -X POST localhost:8080/api/export/sync
        exit:   0
        match:  /^401$/
        red-before: with the auth decorator removed, returns 200. Verified.

  EC-4  cmd:    scripts/seed.sh --profile export-25k && scripts/run-export-job.sh owner-a && \
                wc -l < /tmp/export-owner-a.csv
        exit:   0
        match:  /^25001$/
        red-before: with the legacy LIMIT 1000 reintroduced, returns 1001. This is the DR-07
                    regression and it has been observed failing.

  EC-5  cmd:    EXPORT_FAULT_INJECT=storage_write_error scripts/run-export-job.sh owner-a; \
                echo "exit=$?"; ls /tmp/export-owner-a.csv 2>&1
        exit:   0
        match:  /exit=1/ and /No such file/
        red-before: before the partial-write guard, a truncated file was left on disk and the
                    job exited 0. Observed.

  EC-6  cmd:    scripts/invariant-gate.sh
        exit:   0
        match:  /GATE: PASS/
        red-before: the gate is negative-tested package-wide (§3.5), not per goal.

Anti-goals:
  AG-1 (no test weakening)        enforced: git diff --stat on tests/ shows additions only;
                                  scripts/check-test-weakening.sh
  AG-3 (no unvetted dependency)   enforced: git diff --exit-code -- requirements.txt package-lock.json
  AG-6 (no placeholder data)      enforced: scripts/check-placeholder-data.sh src/export
  Local: must not modify migrations/0014_export_jobs.sql
                                  enforced: git diff --exit-code -- migrations/0014_export_jobs.sql

Blocked-by-credential: none. Storage is the local MinIO container per the cloud-independence rule;
                       the production bucket is exercised only by G-9.3.

Rollback: no schema change in this goal. Revert the commit; export_jobs rows become orphaned but
          are harmless (the runner claims by status, and no runner exists after revert).
```

Read what makes this executable. Every EC is a command a shell runs unattended. Every EC has a
stated expected exit code and an expected output pattern, so "it printed something" is not success.
Every EC carries a `red-before` line naming the specific mutilation that made it fail, which is the
only evidence that the criterion tests anything at all (§2.4). The reading map is a budget of eight
named sections rather than four whole documents. The anti-goals name commands, not intentions. And
the local anti-goal — do not touch the migration another goal owns — is the kind of cross-goal
collision that costs an afternoon when it is discovered by symptom instead of by grep.

### 1.5 The inheritance rule for plan items without full entries

A build plan in `DESIGN_SPEC.md` typically lists more deliverables than you will write full goal
entries for, especially at Standard tier. That is acceptable, and `document-set.md` names the
inheritance rule as required content in `LOOP_GOALS.md`. State it explicitly, once, at the top of
the file:

> Any build-plan item without a full goal entry inherits: the invariant gate as its exit gate, the
> phase's reading map, every global anti-goal, and the commit protocol. It does **not** inherit
> permission to skip test-first. An item with no goal entry and no test suite named anywhere is
> unbuilt scope, not a small goal — promote it to a full entry before starting it.

Without that paragraph, an agent reaching an entry-less plan item invents its own acceptance
standard, which is the same failure as prose exit criteria arriving by a different door.

---

## 2. Exit criteria — the rules

### 2.1 What makes a criterion machine-checkable

Four properties, all required:

1. **Executable.** The criterion is a command line. Not a description of a check — the check.
   It runs from the repo root in the documented toolchain with no interactive input.
2. **Deterministic.** Same tree, same command, same result. Anything depending on wall-clock time,
   network weather, random seeds, or test-ordering is not a criterion until it is pinned (fixed
   seed, frozen clock, recorded fixture, `--runInBand`).
3. **Specifically asserted.** An expected exit code **and** an expected output pattern. Exit code
   alone is weak: many toolchains exit 0 on "0 tests ran", on a skipped suite, and on a build that
   produced no artifact. The output pattern is what distinguishes "passed" from "did nothing".
4. **Falsifiable.** There exists a stated change to the tree that makes it fail, and that change
   has been made and observed (§2.4).

A criterion missing any one of these is prose with a monospace font.

### 2.2 BAD versus GOOD

| BAD (prose — unexecutable) | GOOD (literal, asserted) |
|---|---|
| "Authentication works." | `cmd: pytest tests/auth -q` · `exit: 0` · `match: /^12 passed/m` — plus `curl -sS -o /dev/null -w '%{http_code}' localhost:8080/api/me` · `exit: 0` · `match: /^401$/` for the unauthenticated path. |
| "The app builds." | `cmd: pnpm build` · `exit: 0` · `match: /Compiled successfully/` · plus `test -f dist/index.html && wc -c < dist/main.js` · `exit: 0` · `match: /^[0-9]{5,}$/` (an empty bundle also "builds"). |
| "No type errors." | `cmd: pnpm tsc --noEmit` · `exit: 0` · `match: /^$/` on stdout — and confirm the config is not `"strict": false`: `cmd: node -e 'process.exit(require("./tsconfig.json").compilerOptions.strict?0:1)'` · `exit: 0`. |
| "Export is owner-scoped." | The EC-2 block in §1.4: seed two accounts, export as one, assert the exact row count. |
| "Handles large datasets." | `cmd: scripts/seed.sh --profile export-25k && scripts/run-export-job.sh owner-a && wc -l < /tmp/export-owner-a.csv` · `exit: 0` · `match: /^25001$/`. |
| "Errors are handled gracefully." | Fault injection with an asserted outcome: `EXPORT_FAULT_INJECT=storage_write_error scripts/run-export-job.sh owner-a` · `exit: 1` · and `ls /tmp/export-owner-a.csv` · `match: /No such file/`. |
| "The UI matches the design." | `cmd: pnpm test:visual -- --update=false` · `exit: 0` · `match: /0 diffs/` against committed reference screenshots — plus `pnpm test:a11y` · `exit: 0` · `match: /0 violations/`. |
| "Performance is acceptable." | `cmd: scripts/bench.sh search --p95` · `exit: 0` · `match: /p95=([0-9]+)ms/ where $1 <= 300` (cite `NFR-LATENCY-1`; the number lives in the NFR, the assertion lives here). |
| "The migration is safe." | `cmd: scripts/migrate.sh up && scripts/migrate.sh down && scripts/migrate.sh up && scripts/schema-dump.sh \| diff - fixtures/schema.expected` · `exit: 0` · `match: /^$/`. |
| "Secrets are not committed." | `cmd: scripts/scan-secrets.sh` · `exit: 0` · `match: /0 findings/` — and the scanner is negative-tested per §6. |
| "It runs on a device." | The mobile chain in §2.5. "It builds" and "it runs" are different claims and only one of them is what the user gets. |

The pattern in every GOOD cell: a command, a code, a match, and — where the naive check passes
vacuously — a second assertion that closes the vacuum. Two of these are worth stating as their own
rules, because they are the most common vacuous passes in practice: **a test command that exits 0
on zero collected tests**, and **a build command that exits 0 having emitted nothing**. Assert the
count and assert the artifact.

### 2.3 The green-twice rule

Every exit criterion must pass **twice, in separate invocations, with the second run after a clean
of the relevant caches and build artifacts.** Only the second run counts as the goal's evidence.

The reason is that a single green is frequently green for a reason unrelated to the work:

- The build artifact on disk is from the previous goal, and the current source does not compile.
- The test runner served a cached result for an unchanged-looking file graph.
- A dev server still running from an earlier session is answering the curl, from old code.
- A migration was applied by hand during debugging and is not in the migration file.
- The type checker used an incremental cache whose invalidation missed the changed file.

All five produce a confident green over a broken tree, and all five are caught by running again
from cold. State the clean command explicitly in `LOOP_GOALS.md` so it is not improvised:

```
Green-twice procedure (run per goal, after all EC pass once):
  scripts/clean.sh          # removes dist/, .next/, __pycache__/, .pytest_cache/, target/,
                            # DerivedData/, .gradle/build caches, and the test DB volume
  <re-run every EC in order>
Second-run results are the ones recorded in the commit message and STATUS.md.
```

Where a cold run is genuinely expensive (a full native rebuild in the tens of minutes), the rule
narrows rather than disappears: clean only the caches that can lie for that criterion, and record
in the goal which ones were cleaned. "Too slow" is a reason to scope the clean, never a reason to
trust one green.

### 2.4 The negative-test rule

**Every exit criterion must be observed FAILING before the goal's implementation exists.** Not
argued to be failable — observed, and the observation recorded in the `red-before` line.

This is the same rule SKILL.md applies to the ID sweep and the invariant gate, applied at goal
granularity, and it exists because a vacuous criterion is worse than no criterion. No criterion
leaves a goal visibly unverified. A vacuous criterion converts an unbuilt feature into a green
build, and green builds do not get re-examined.

Two ways to satisfy it:

1. **By construction (preferred).** Write the test suite first, run it against the empty
   implementation, watch it fail on the intended assertion — not on an import error, which proves
   only that the file is missing. Then implement. This is the TDD protocol from
   `claude-md-template.md`; the `red-before` line just records what was already seen.
2. **By mutilation (for criteria that are not tests).** For a criterion that asserts an HTTP status,
   a row count, an artifact's existence, or a grep's silence, make the specific change that should
   break it, observe the failure, revert. EC-2 in §1.4 does this by deleting the `WHERE` clause;
   EC-4 does it by reintroducing the legacy `LIMIT`.

The `red-before` line records the *specific* mutilation and the *specific* observed failure. "Would
fail if broken" is not a red-before note; it is a restatement of the criterion. And a criterion
whose only red-before is an import error is not yet negative-tested: an import error fires for
every missing file and therefore distinguishes nothing about the behavior under test.

Where a criterion genuinely cannot be made to fail — most often a build command that is green on an
empty project — that is the finding. Either strengthen it (assert the artifact and its size) or
delete it, because it is measuring nothing.

### 2.5 Mobile exit criteria — build is not run

"It compiles" and "a user can open it" are separated by installation, launch, entitlements,
permissions, and the first screen actually rendering. On mobile that gap is where most real defects
live, and a goal whose only criterion is a build command certifies nothing a user experiences.

Every mobile goal that changes runtime behavior needs the full chain: **boot → install → launch →
assert**. Each link asserted separately, because each fails for different reasons and a collapsed
chain cannot tell you which one broke.

**iOS (simulator, no credentials required):**

```
EC-1  build
      cmd:   xcodebuild -scheme App -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' \
               -derivedDataPath build build
      exit:  0
      match: /\*\* BUILD SUCCEEDED \*\*/

EC-2  boot
      cmd:   xcrun simctl boot "iPhone 16" 2>/dev/null; \
             xcrun simctl bootstatus "iPhone 16" -b
      exit:  0
      match: /Device booted/

EC-3  install
      cmd:   xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/App.app && \
             xcrun simctl get_app_container booted {{APP_BUNDLE_ID}}
      exit:  0
      match: /App\.app$/

EC-4  launch and stay up
      cmd:   xcrun simctl launch --console-pty booted {{APP_BUNDLE_ID}} & sleep 5; \
             xcrun simctl spawn booted launchctl list | grep -c {{APP_BUNDLE_ID}}
      exit:  0
      match: /^1$/
      why:   a launch that crashes on the first frame still "launches". This asserts it is
             still resident five seconds later.

EC-5  UI assertion
      cmd:   xcodebuild test -scheme AppUITests \
               -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.2' \
               -only-testing:AppUITests/ExportTests/testExportButtonStartsJob
      exit:  0
      match: /Test Suite 'ExportTests' passed/
      why:   this is the only link in the chain that asserts the product does what FR-EXPORT-3
             says. The four above assert it is possible to find out.

EC-6  no crash log produced
      cmd:   find ~/Library/Logs/DiagnosticReports -name '*App*' -newermt '-5 minutes' | wc -l
      exit:  0
      match: /^0$/
```

**Android (emulator):** same chain — `./gradlew assembleDebug` asserting `BUILD SUCCESSFUL`;
`emulator -avd <pinned AVD> -no-window` plus `adb wait-for-device shell getprop sys.boot_completed`
matching `1`; `adb install -r` matching `Success`; `adb shell am start -W -n <pkg>/.MainActivity`
matching `Status: ok` **and** `adb shell pidof <pkg>` returning a pid after a sleep; then a
Espresso or Maestro assertion on the actual screen; and `adb logcat -d -b crash | wc -l` matching
`0`.

**React Native / Flutter:** the chain is the same. Do not substitute `flutter build` or
`npx react-native build` for it — a JS-bundle or Dart-compile success says nothing about the native
shell, and the native shell is where signing, permissions, and native module linkage fail.

Three mobile-specific rules worth stating in `LOOP_GOALS.md` directly:

- **Pin the simulator/emulator image**, by device name and OS version, in the toolchain block (§5).
  "iPhone 16" without an OS resolves differently on two machines and silently changes what was
  tested.
- **Never make a physical device an exit criterion** in the autonomous loop. A device is not
  reliably present. Device verification is a `Blocked-by-credential`-style deferred item recorded
  in BLOCKERS.md, with the simulator criterion standing as the loop's gate.
- **Signing-gated criteria are credential-gated.** A goal needing a real provisioning profile
  records the fixture path (simulator build, unsigned) as its loop criterion and the signed
  verification as a blocker entry, per the cloud-independence rule.

### 2.6 Web and API criteria worth naming

- **A rendered page, not a 200.** `curl -sf localhost:3000/settings/data | grep -c 'Export CSV'`
  matching `1` asserts the page contains what `SCREENS.md` says it contains. A 200 with an empty
  React root is a very common green.
- **Console errors are failures.** A headless run asserting `0 console errors` catches the class of
  breakage that leaves the DOM intact and the app dead.
- **Accessibility as a gate, not a review.** `pnpm test:a11y` matching `0 violations` on every
  screen the goal touches, per the a11y requirements in `deliverables-design.md`.
- **The empty and error states, explicitly.** Per §8, a screen has four states. An exit criterion
  that only exercises the loaded state leaves three unbuilt and untested, and the empty state is
  precisely where fabricated placeholder data gets introduced (§6.2).

---

## 3. The invariant gate

### 3.1 What it is

**One command, run after every goal, that asserts everything true of the repo at all times.**
`LOOP_GOALS.md` defines it once; every goal cites it as its final exit criterion; `CLAUDE.md`
names it in the loop. It is the difference between a build that degrades slowly and one that
cannot.

```
scripts/invariant-gate.sh     exit: 0     match: /GATE: PASS/
```

The gate is a script in the repo, not a list in a document. A list gets partially run. A script
runs all of it or reports which part failed, and its output is appendable to a commit message.

### 3.2 Required contents

| Check | Command shape | Why it is in the gate rather than a goal |
|---|---|---|
| **Build** | `pnpm build` / `xcodebuild build` / `cargo build --release` | A goal that greens its own tests while breaking the build is the most common cross-goal regression. |
| **Typecheck** | `tsc --noEmit`, `mypy src`, `swift build` warnings-as-errors | Types are a global property. Checking them per goal misses the goal that broke another module's inference. |
| **Lint / format** | `eslint . --max-warnings 0`, `ruff check`, `swiftlint --strict` | Zero-warning is the only enforceable state. "Warnings are fine for now" is a ratchet that only turns one way. |
| **Fast test suite** | The unit + fast-integration tier, not the full suite | The gate runs after every goal, so its budget is minutes. The slow tier runs at phase boundaries and is named separately (§3.4). |
| **Security greps** | `scripts/scan-secrets.sh`, SQL-concatenation grep, the SECURITY.md-enforced rules | `SECURITY.md` requires every rule to name a machine enforcement. The gate is where those enforcements actually execute. |
| **ID sweep** | `scripts/id-sweep.sh docs` | Goals edit documents (README, STATUS, the living-docs requirement). Every edit can dangle an ID. Catching it at the goal boundary takes seconds; catching it at Phase 8 is an archaeology session. |
| **Doc-drift check** | `scripts/check-doc-drift.sh` | Per `claude-md-template.md`, a README diagram that no longer matches the code is a failing test. §3.3 specifies what this actually checks. |
| **Anti-goal sweep** | `scripts/check-anti-goals.sh` | The global anti-goals from §6, all of them, every time. An anti-goal enforced only in the goals that remember to cite it is not enforced. |
| **Migration reversibility** | `scripts/migrate.sh up && down && up`, schema diff | Only where a schema exists. Down-paths rot silently because nothing exercises them until the day they are needed. |

### 3.3 The doc-drift check, specified

"Docs match code" is unenforceable in general. These four are enforceable and cover the drift that
actually bites:

1. **Every file path named in `README.md` and `CLAUDE.md` exists.** Extract path-shaped tokens,
   `test -e` each. Catches the directory tree that describes a refactor from three goals ago.
2. **Every command named in the docs is runnable.** Extract fenced commands tagged as invocable,
   check the script exists and is executable. Catches `scripts/foo.sh` referenced after a rename.
3. **The Build State section is current.** The last-pushed commit recorded in `CLAUDE.md` matches
   `git rev-parse HEAD` at commit time, and the README-verified date is within the current session.
4. **The ID sweep passes on documents this goal edited** (covered above; listed here because doc
   drift and ID drift are the same failure with different symptoms).

What it deliberately does not check: prose accuracy. No script can tell you a paragraph became a
lie. That is what the goal's living-docs step and the Phase 8 audit are for; pretending otherwise
produces a gate that is either toothless or full of false positives, and a gate with false
positives gets disabled.

### 3.4 Runtime budget

**Target: under 3 minutes. Hard ceiling: 10 minutes.** State the measured number in
`LOOP_GOALS.md` next to the gate definition, and re-measure when the suite grows.

The budget is not a nicety. The gate runs after every goal, so a 20-minute gate on a 40-goal build
spends over 13 hours gating. What actually happens is worse than the cost: the agent starts
batching goals to amortize the gate, which defeats the one-goal-one-commit protocol and destroys
the bisectability that makes a long autonomous run recoverable.

Keep it in budget by tiering, and name the tiers explicitly:

| Tier | Contents | When it runs |
|---|---|---|
| **Gate** (< 3 min) | Build, typecheck, lint, unit + fast integration, greps, sweeps | After every goal |
| **Phase gate** (< 20 min) | Full integration, E2E, visual regression, a11y sweep, migration up/down/up, load smoke | At each phase boundary, as an EC on the phase's last goal |
| **Release gate** | Everything, plus the credential-gated live checks | Definition of done, once |

A check that cannot fit the gate budget goes to the phase gate. It does not get dropped, and it
does not get "run occasionally" — an occasional check is an unowned check.

### 3.5 The gate blocks the commit

**A failing gate blocks the commit. It is never noted and deferred.** Write this rule into
`LOOP_GOALS.md` in those words, because the deferral is the most attractive shortcut available to
an autonomous agent: the goal's own criteria are green, the failure looks unrelated, and continuing
feels like progress.

It is not progress. A deferred gate failure means every subsequent goal builds on a tree with a
known defect, every subsequent gate run reports the same failure, and within three goals the agent
has learned to ignore the gate's output entirely. The gate's whole value is that its red is rare
and therefore meaningful.

The correct response to a gate failure the goal did not cause is the blocker protocol: fix it if
the fix is inside the goal's scope; if it is not, write the BLOCKERS.md entry (§9), revert the
goal's working tree, and take the next unblocked goal. Reverting an uncommitted goal costs one
loop. Building onto a broken tree costs the rest of the run.

**Negative-test the gate before trusting it**, per SKILL.md. Break each of its checks deliberately —
introduce a type error, add a key-shaped string, dangle an ID, delete a README-referenced file — and
confirm the gate goes red on each, naming the check that caught it. A gate assembled from nine
checks where two are silently misconfigured reports PASS with confidence, which is strictly worse
than having no gate: it converts an unexamined tree into a certified one.

---

## 4. The dependency graph

### 4.1 Format

The graph is derived entirely from the `Depends on` field of each goal. Do not maintain a second
copy in prose — a duplicated graph diverges, and then neither copy can be trusted. What
`LOOP_GOALS.md` carries in addition is a machine-readable edge list and a rendering, both generated
from the entries:

```
# scripts/goal-graph.sh emits this; it is regenerated, never hand-edited
G-1.1 ->
G-1.2 -> G-1.1
G-1.4 -> G-1.2
G-2.1 -> G-1.1
G-2.6 -> G-2.1
G-3.2 -> G-1.4, G-2.1, G-2.6
```

Render it as a Mermaid diagram for humans and keep the edge list as the source the tooling reads.
Where the two disagree, the goal entries win and the renderer is the thing that is broken.

### 4.2 Acyclicity

**The graph must be a DAG, and this is checked by a script, not by reading.** A cycle is not a
subtle modeling error; it is an autonomous build that cannot start. Two goals each waiting for the
other produce an agent that either stalls at zero unblocked goals on the first loop or — worse —
picks one arbitrarily and builds against an interface that does not exist yet.

```
scripts/goal-graph.sh --check     exit: 0     match: /DAG: OK, ([0-9]+) goals, 0 cycles/
```

Run it in the Phase 8 pre-flight and as a check in the invariant gate, since goals get edited
mid-build. Negative-test it by introducing a deliberate two-node cycle and confirming it reports
the cycle's members.

### 4.3 Computing the unblocked set

This is the mechanism that makes the never-stop protocol work. When a goal blocks, the agent needs
to know what it may do instead, and that answer must be computable rather than judged:

```
unblocked(t) = { g : status(g) = pending
                   and every d in depends_on(g) has status(d) = done
                   and no d in depends_on(g) has status(d) = blocked }
```

Note the second clause. A goal whose dependency is *blocked* is itself blocked transitively, and an
agent that ignores this starts work it cannot finish, thrashes, and produces a second blocker entry
that is really the first one wearing a different name. Record transitive blockage explicitly in
STATUS.md so the human reading it sees `G-3.2 blocked (transitively, via G-2.6)` rather than a
mystery.

```
scripts/goal-graph.sh --unblocked   # reads STATUS.md for status, prints the ready set
```

The stop condition follows directly: **the build stops only when the unblocked set is empty.** Not
when a goal is hard, not when a criterion is confusing — those are blocker entries and the loop
continues. An empty unblocked set, and only that, ends the session with a STATUS.md a human can act
on in five minutes (§9).

### 4.4 Root validation

The graph's roots — goals with `Depends on: none` — are where the first hour happens, and they get
their own check, because a bad root is a build that never starts:

- **At least one root exists.** A graph with no roots is a graph of cycles.
- **Every root is genuinely independent.** Walk each one and ask what it assumes exists. A root
  that assumes a database, a schema, or a running service has an unrecorded dependency, and the
  fact that it is unrecorded is exactly why it fails at minute zero.
- **The roots are collectively sufficient to produce a running skeleton.** If executing every root
  leaves the repo unable to start, the scaffold work is missing from the graph entirely — a §5
  failure surfacing as a graph failure.
- **No root is credential-gated.** Per `claude-md-template.md`, no prerequisite may block the early
  phases. A root needing a human-supplied token means the autonomous run begins by stopping.

### 4.5 The protocol-killer class

`audits.md` §Pre-flight names protocol killers: "gates required before the goal that creates them,
frozen files the goals must edit, push targets that don't exist". This is the class that survives a
clean acyclicity check and kills the build anyway, because it is not an edge the graph records.

The shape: **G-2.4's exit criterion runs `scripts/bench.sh`, and `scripts/bench.sh` is a deliverable
artifact of G-5.1.** The graph is a perfect DAG. The build stalls at G-2.4 on a missing file, and
the agent has no dependency edge telling it where that file comes from — so it either writes its own
inferior `bench.sh`, silently forking the acceptance oracle, or blocks on something that was never
actually blocked.

Detect it before the build starts, mechanically:

1. **Extract every command, script path, and fixture path from every exit criterion** across all
   goals. This is a grep over the `cmd:` lines.
2. **Determine each extracted path's provenance**: it exists in the repo today (fine); it is a
   deliverable artifact of some goal G-x.y (then the citing goal must depend on G-x.y — assert that
   edge exists); it exists nowhere (a §5 first-hour failure — the toolchain block must create it,
   or it is undefined scope).
3. **The same sweep for fixtures and seed profiles.** `scripts/seed.sh --profile export-25k` names
   a profile; that profile is defined somewhere or it is not.
4. **The same sweep for frozen files.** Any file an anti-goal forbids editing, cross-checked against
   every goal's deliverable artifacts. A file that is both frozen and listed as a deliverable is a
   contradiction the agent will resolve by guessing.

```
scripts/check-protocol-killers.sh     exit: 0     match: /0 unresolved references/
```

Run it in Phase 8 and negative-test it by pointing a goal's criterion at a script that does not
exist. The three-minute version, if no script is written: grep every `cmd:` line for `scripts/`,
sort unique, and `test -e` each against the repo-plus-deliverables union. It finds most of them.

---

## 5. Toolchain pinning and the first hour

### 5.1 Why this section is load-bearing

**The first hour of an autonomous build is where unpinned assumptions become stalls.** Not
architecture, not algorithms — package manager versions, a missing scaffold command, a database
nobody said how to start. Every one is trivially preventable and each costs a full blocker cycle,
which on an unattended overnight run means the whole run.

The failure has a specific shape worth naming: the docs assume a state of the world that was true
on the machine where they were written. `pnpm` is installed. The database is running. There is a
`.env`. Someone ran the codegen once. None of that is true in the container the build starts in,
and none of it is written down, because it was never noticed.

The test for this section: **could an agent, in an empty container with only the pinned toolchain,
reach a running skeleton by following `LOOP_GOALS.md` alone?** If any step requires knowledge not in
the document, that knowledge is the defect.

### 5.2 The pin table

Exact versions. Not ranges, not "latest", not "18+". A range means two runs of the same build used
different compilers, and the difference surfaces as a nondeterministic test failure nobody can
reproduce.

| Category | Pin | Verify command |
|---|---|---|
| Language runtime | `node 22.11.0` / `python 3.12.7` / `swift 6.1` / `go 1.23.4` | `node --version` → `/^v22\.11\.0$/` |
| Package manager | `pnpm 9.12.3` / `uv 0.5.4` / exact bundler | `pnpm --version` → exact match |
| Lockfile policy | frozen; install with `--frozen-lockfile` / `--locked` | `pnpm install --frozen-lockfile` → exit 0 |
| Database | `postgres 16.4` by **image digest**, not tag | `psql -tAc 'show server_version'` → `/^16\.4/` |
| Cache / queue | `redis 7.4.1`, or "none — DB-backed per AD-6" | version assertion or an explicit `none` |
| Every CLI the build invokes | each pinned by version | one assertion each |
| Container runtime | `docker` or `podman`, minimum version | `docker compose version` |
| Formatter / linter | pinned; drift rewrites every file | `ruff --version`, `eslint --version` |
| Test runner | pinned | version assertion |
| **iOS: Xcode** | `16.2 (16C5032a)` — build number, not just marketing version | `xcodebuild -version` → exact |
| **iOS: SDK / deployment target** | SDK `18.2`, minimum deployment `17.0` | `xcodebuild -showsdks` |
| **iOS: simulator image** | device name + OS: `iPhone 16 / 18.2` | `xcrun simctl list devices available` |
| **Android: Studio / AGP / Gradle / JDK** | AGP `8.7.3`, Gradle `8.11.1`, JDK `17.0.13` | `./gradlew --version` |
| **Android: SDK / NDK / AVD** | compileSdk `35`, AVD name + system image | `sdkmanager --list_installed`, `avdmanager list avd` |
| **Dependency resolution files** | `Package.resolved`, `Podfile.lock` committed | `git diff --exit-code` on each |

Pin the *image digest* rather than the tag for anything containerized. `postgres:16` moves. A build
green on Tuesday and red on Thursday with no commits between is almost always a moving tag, and it
burns hours because the agent looks in the diff, where the cause is not.

### 5.3 Scaffold commands that must actually run

Not "set up the project" — the literal sequence, in order, each with its expected outcome. Every one
has been run by you, in this session, on a clean tree, before Phase 7 ends. A scaffold command
copied from a framework's documentation and never executed is the highest-yield first-hour stall,
because framework CLIs change their flags between minor versions.

```
Bootstrap (from an empty container with the pinned toolchain):
  1. pnpm install --frozen-lockfile         exit 0
  2. docker compose up -d db minio          exit 0; scripts/wait-for-db.sh exits 0 within 60s
  3. scripts/migrate.sh up                  exit 0; match /applied 14 migrations/
  4. pnpm codegen                           exit 0   (generated clients are NOT committed — say so)
  5. scripts/seed.sh --profile dev          exit 0; match /seeded: 2 accounts, 40 records/
  6. cp .env.example .env                   exit 0   (.env.example is committed and complete)
  7. pnpm dev &                             curl -sf localhost:3000/health → /^ok$/ within 30s
  8. scripts/invariant-gate.sh              exit 0; match /GATE: PASS/ on a clean checkout
```

Step 8 matters more than it looks: **the gate must pass on the scaffold before any goal runs.** If
the gate is red at hour zero, every goal inherits a red gate and the blocking rule (§3.5) becomes
unenforceable on day one.

### 5.4 Seed and demo data

Three distinct datasets, named and kept distinct, because conflating them is how fake records reach
production:

| Profile | Purpose | Requirement |
|---|---|---|
| `dev` | Local development and manual inspection | Small, obviously synthetic, loaded only by an explicit command. |
| `test` | Deterministic fixtures for the suites | Fixed IDs, frozen clock, fixed random seed. Reproducible byte-for-byte, or the tests are flaky. |
| `demo` | First-run experience, if the product has one | Marked as demo **in the data model**, deletable in one action, never mixed with a real account's records. |

Two rules bind all three, and both connect to the placeholder-data anti-goal in §6.2:

- **Seed data is loaded by an explicit command, never by application startup.** An app that seeds
  itself when a table looks empty will seed production the first time a migration runs on a fresh
  replica.
- **Demo data is distinguishable from real data by the schema, not by a naming convention.** A
  boolean column queries filter on. "Records named Example Corp" is a convention, and conventions
  are not enforcement.

### 5.5 Everything the docs assume but never define

Walk this list explicitly before closing Phase 7. Each item is a real stall, and each is invisible
from inside the document set — you only see it by asking what a fresh container lacks.

- **Environment variables.** `.env.example` exists, is committed, and lists every variable the code
  reads, each with a comment stating whether it is required at boot and what happens without it.
  Assert it: `scripts/check-env-completeness.sh` compares vars grepped from source against
  `.env.example` and exits nonzero on any missing.
- **Service startup order and readiness.** "The DB is up" is not `docker compose up` returning; it
  is a health probe. A `wait-for-*` script per service, invoked in the scaffold.
- **Ports.** Every port the stack binds, listed, with the collision behavior stated.
- **Generated code.** Is the ORM client, the protobuf output, the API client committed or generated?
  Say which; if generated, name the command and put it in the scaffold.
- **Fixture and test-data files** referenced by any exit criterion — they exist, or a goal creates
  them (§4.5).
- **The scripts themselves.** Every `scripts/*.sh` cited anywhere either exists in the delivered
  repo or is a named deliverable of a root goal. This is the first-hour trap's most common form.
- **Git remote and push target.** The remote exists and is writable, or `CLAUDE.md` says commits are
  local-only and why. An agent discovering at its first push that the remote is imaginary loses the
  commit protocol.
- **Test database lifecycle.** Created how, reset between suites how, torn down when.
- **The clean command** referenced by the green-twice rule (§2.3).

### 5.6 Mobile first-hour additions, and which are credential-gated

Mobile has a harder first hour than web, because parts of it cannot be satisfied without human-held
credentials. The rule from `claude-md-template.md` applies: implement and fixture-test everything,
defer only the live verification. Mark each item honestly.

| Item | Credential-gated? | Loop behavior |
|---|---|---|
| Xcode / Android Studio installed, versions pinned | No | Assert in the gate; a mismatch is a hard stop at hour zero, not a mid-build blocker. |
| Simulator / emulator image present | No | `xcrun simctl list` / `avdmanager list avd` assertion; create the AVD in the scaffold if absent. |
| Debug build and simulator run | No | The full §2.5 chain runs unattended. This is the loop's real gate. |
| Bundle / application identifier | No — but never invent one | `{{APP_BUNDLE_ID}}` placeholder until the user supplies it; a `D<n>` row if it blocks. |
| Signing certificate + provisioning profile | **Yes** | Build config is implemented; the loop verifies the unsigned simulator build; signed device verification is a BLOCKERS.md entry. |
| App Store Connect / Play Console API key | **Yes** | Nothing in the loop depends on it. Upload steps are release-gate items, never goal criteria. |
| Push certificates / FCM keys | **Yes** | Push code written against a local fixture harness; live delivery deferred. |
| Paid-tier capabilities (iCloud, App Groups, HealthKit) | **Yes**, entitlement-dependent | Entitlement files written and committed; simulator behavior fixture-tested; device verification deferred. |
| In-app purchase products | **Yes** | Local StoreKit configuration for the loop; live product verification deferred. |
| Physical device | **Yes** (availability) | Never an exit criterion (§2.5). |

The point of the table is that a mobile build should still complete twenty goals unattended. What
kills mobile autonomy is not the credential gaps but the failure to mark them, which leaves the
agent stalling on a signing error at goal three and ending the run.

---

## 6. Anti-goals

### 6.1 The enumerated list

Anti-goals are the things the build must never do, stated globally with stable `AG-<n>` IDs, each
carrying the literal check that enforces it. They live in `LOOP_GOALS.md`, run in the invariant gate
via `scripts/check-anti-goals.sh`, and are cited per goal where one has particular teeth.

An anti-goal without a check is a wish. An autonomous agent under pressure to make a criterion green
takes the shortest path available, and the shortest path is frequently one of these. The check is
what makes the shortcut cost more than doing the work.

| ID | Anti-goal | Enforcement |
|---|---|---|
| **AG-1** | Never weaken, skip, or delete a test to make a build green. | `scripts/check-test-weakening.sh`: fails on any diff to `tests/` that removes an assertion, adds `skip`/`xfail`/`.only`/`@Ignore`/`@Disabled`, loosens a numeric bound, or reduces the test count below the previous commit's. Per `TESTS_TDD.md`, weakening a test requires a human-reviewed ADR — so the check fails and the agent writes a blocker instead of deciding. |
| **AG-2** | Never lower a gate: no disabled lint rules, no `strict: false`, no raised warning ceiling, no removed gate check. | `git diff --exit-code` on `.eslintrc*`, `tsconfig.json`, `ruff.toml`, `.swiftlint.yml`, `scripts/invariant-gate.sh` inside a goal; changes require an ADR. Plus a positive assertion that strict mode is on, so it cannot be disabled in a file the diff check does not cover. |
| **AG-3** | Never add a dependency that has not passed the supply-chain rule. | `git diff --exit-code` on `package.json`, lockfiles, `requirements.txt`, `Package.resolved`, `Podfile.lock`, `go.sum` inside a goal, unless the goal declares the dependency with its vetting record (license, maintenance, transitive count, why not the standard library). Plus `pnpm audit --audit-level high` / `pip-audit` in the gate. |
| **AG-4** | Never hardcode a value that belongs in configuration. | `scripts/check-hardcoded.sh`: greps source for literal URLs, hostnames, ports, region strings, and price/quota/threshold numerics outside `config/` or a constants module, plus every threshold named in `DESIGN_SPEC.md`. Per `document-set.md`, every threshold is configuration with a recorded default; a hardcoded threshold is a named anti-pattern. |
| **AG-5** | Never bypass a hook, gate, or protocol step. | `git config core.hooksPath` asserted; grep the session's commands for hook-skipping commit flags, `SKIP=`, `HUSKY=0`, and force-push; CI asserts every commit carries hook evidence. `claude-md-template.md` already forbids skipping verification on commit; this is where it is caught. |
| **AG-6** | Never introduce placeholder, mock, seeded, or fabricated data standing in for a real value on a runtime path. | §6.2 — it gets its own treatment. |
| **AG-7** | Never commit a secret. | `scripts/scan-secrets.sh` over the diff and the full tree (key-shaped strings, PEM blocks, cloud key prefixes, any `.env` not named `.example`), plus `git check-ignore` asserting `.env` is ignored. A committed secret is unfixable by continuing: it means rotation, which is a blocker. |
| **AG-8** | Never invent a business specific — entity name, support email, address, domain, legal URL, tax ID, application identifier. | `grep -rn '{{' src/ docs/` lists placeholders (expected, and each must appear in the handoff list); a companion grep for candidate emails, domains, and entity names in shipped strings fails on anything not user-supplied. Same rule as `deliverables-requirements.md` §7, enforced at build time because that is where a placeholder becomes a production footer. |
| **AG-9** | Never expand scope inside a goal. Discovered work goes to `BACKLOG.md`. | `git diff --name-only` must be a subset of the goal's declared deliverable artifacts, plus README/STATUS. A superset is a scope breach and fails the check. |
| **AG-10** | Never leave a swallowed error or a silent fallback on a data path. | `scripts/check-silent-failure.sh`: empty catch/except blocks, bare `except:`, discarded `try?` on a data path, a `.catch` returning a default, a nullish-coalesce to an empty object or array on a fetch result. A caught error either propagates or is logged with context and surfaces a state to the user. |
| **AG-11** | Never modify another goal's frozen artifacts — shipped migrations, the fixed kernel from `EXTENSIBILITY.md`, committed reference screenshots without a recorded design decision. | `git diff --exit-code` on `migrations/`, `src/kernel/`, `docs/screenshots/` unless the goal declares them. |
| **AG-12** | Never mark a goal done with a criterion unrun, run once, or run with a modified command. | The checker re-executes every EC verbatim from the goal entry and compares against the recorded expectations. This is `foreman`'s independent-checker role; the anti-goal is what makes "the worker said it passed" inadmissible. |

Every one of these must be **negative-tested** before the package ships: introduce the violation,
confirm the check goes red, revert. A twelve-check script where three checks silently match nothing
reports clean forever, and the build that follows it is unprotected in exactly the three ways
nobody is watching.

### 6.2 AG-6, the placeholder-data anti-goal

This one is separated because it is the most frequently violated, the hardest to detect after the
fact, and the one whose damage is silent by construction.

**The rule: a fabricated value that renders identically to a real value is forbidden.** Not
discouraged. The whole failure mode is that nobody can see it — a `0.5` where a score should be, a
default object where a fetch failed, a stub avatar, a lorem paragraph, a seeded row that looks like
a user's row. Each renders as a plausible product. Each hides the fact that the real source
returned nothing. And each survives review, because review looks at rendered output and the
rendered output looks correct.

The three-part contract every data path satisfies:

1. **Missing data returns `null` or empty upstream.** The fetch layer does not substitute. A
   function that cannot get the value returns the absence, and the absence is a distinct value from
   any real one — never a zero, never a default object, never an empty string that means the same
   thing a real empty string would mean.
2. **The UI surfaces an explicit state.** "Not yet assessed", "No data", "Couldn't load — retry":
   text a user reads as absence and a screenshot test can assert. Per §8, every screen specifies its
   empty and error states, and this is why — unspecified states are where placeholders get invented
   at implementation time.
3. **A fake value and a real value must not be indistinguishable.** If demo or sample content exists
   at all, it is flagged in the data model (§5.4), rendered with a visible marker, and removable in
   one action.

Enforcement, `scripts/check-placeholder-data.sh`, over the goal's changed source:

```
Fails on any of:
  - lorem ipsum, generic person names, example domains, "Acme", "Foo Bar", "TODO: real data"
    in a shipped string (excluding tests/ and fixtures/)
  - a fallback literal applied to a fetch or query result: a nullish-coalesce or logical-or
    to an object, array, or number literal on an expression whose source is a network or db call
  - a numeric literal assigned to a field named *score|confidence|rating|progress|percent*
    outside config/ and tests/
  - placeholder image and asset paths in shipped code: placeholder\., /150x150, stock
    placeholder-image hosts, the 1x1 transparent gif data URI
  - a default parameter value on a function whose job is to retrieve real data
Passes only when absence is representable: the check also asserts that every screen component
touched declares its empty state (§8.6), so "no placeholder" cannot be satisfied by rendering
nothing at all.
```

That last clause matters. Removing a placeholder and rendering a blank region is not compliance; it
is the same defect with less evidence. The empty state is the deliverable.

**When placeholder-shaped content is legitimate** — a form input's placeholder attribute, a skeleton
loader during a known-pending fetch, a design mock under `docs/`, a test fixture — it is allowed in
those specific locations, and the check's exclusions say so by path. Never by a comment the agent
can add to silence the check. If a genuinely new case arises it is a blocker, not a judgment call:
the reason this anti-goal exists is that "this one is fine" is exactly what the agent tells itself
each time.

---

## 7. Budget and spend controls

### 7.1 What must be capped

An autonomous loop has no natural stopping cost. It will retry, and each retry costs tokens and
sometimes real money. State every cap in `LOOP_GOALS.md` with a number and an enforcement point; a
cap that exists only as an intention is not a cap.

| Cap | Shape | Enforcement |
|---|---|---|
| **Per-session token/cost budget** | A number, with the action on reaching it: finish the current goal, commit, write STATUS.md, stop. | The orchestrator's accounting, recorded in STATUS.md each loop so a human can see burn rate. |
| **Per-goal loop cap** | Three no-progress loops on one goal → blocker (per `claude-md-template.md`). "No progress" means no exit criterion moved from red to green. | Counted mechanically from EC results, not judged. |
| **Paid-API spend per session** | A currency amount per external metered vendor (LLM inference, geocoding, email, SMS, maps). | A wrapper that counts calls and refuses past the cap, **and** the vendor's own hard spend limit where one exists. Both: the wrapper catches the loop, the vendor limit catches the wrapper's bug. |
| **Test-run cost** | Any suite calling a paid API runs against recorded fixtures by default; live runs are flagged and counted. | The default test profile has no network egress; live is opt-in per suite. |
| **Cloud resource creation** | The build creates nothing billable that outlives the session without a human decision. | Emulators and containers per the cloud-independence rule; any real provisioning is a blocker. |
| **Retry bounds** | Bounded, jittered retries everywhere the build calls anything external. | Specified in `DESIGN_SPEC.md`; asserted by the gate's fast tests. |

### 7.2 Spend-relevant decisions are blockers, not judgment calls

Write this rule verbatim into `LOOP_GOALS.md`:

> Any decision that creates recurring cost, provisions a paid resource, changes a pricing tier,
> raises a rate limit, or increases per-request spend is a **blocker**. The agent writes the
> BLOCKERS.md entry with the options and their costs and continues with the next unblocked goal.
> It does not choose.

The reason is not that the agent chooses badly. It is that spend decisions are irreversible in a way
code is not: a provisioned resource keeps billing after the session ends, and nobody is watching.
The same logic that makes security-ambiguous changes blockers in `claude-md-template.md` applies
here, and for the same reason — the cost of asking is one blocker entry, and the cost of guessing is
unbounded and delayed.

Record the caps as a first-class block near the top of `LOOP_GOALS.md`, not buried in a goal. An
agent reading only its current goal must still find the budget; that is why `CLAUDE.md`'s never-stop
protocol names the cap too.

---

## 8. `STATE_AND_DATA.md` requirements

`document-set.md` gives this document the role "UI state + data shapes" and requires a state model,
URL-addressable view state, handlers, and per-screen data interfaces matching the schema. This
section specifies what each of those means concretely.

Why it is a Phase 7 deliverable rather than a Phase 3 one: it is the document that turns screens
into buildable units. `SCREENS.md` says what a screen looks like; `DESIGN_SPEC.md` says what the
database holds; `STATE_AND_DATA.md` is the contract between them, and without it a build agent
invents that contract per screen. Inconsistently. That is where placeholder data, mismatched field
names, and screens that cannot express "loading" come from.

### 8.1 The client state model

Enumerate every piece of client state and classify each. The classification is the deliverable,
because the failure this prevents is state that lives in three places and disagrees with itself.

| Field | Content |
|---|---|
| **Name** | Stable identifier used in code. |
| **Kind** | `server-cache` (a copy of server truth) / `url` (§8.2) / `session` (survives navigation, dies on reload) / `local-persistent` (survives reload; name the storage) / `ephemeral` (component-local). |
| **Owner** | The single component, store, or hook allowed to write it. One writer. Multiple writers to one state is the defect this field exists to prevent. |
| **Shape** | The type, referencing the schema type from `DESIGN_SPEC.md` where it mirrors server data. |
| **Lifetime** | When created, when discarded, what clears it (logout, tenant switch, navigation). |
| **Derived from** | If computed, the inputs. Derived state that is also stored is a cache; say so and give it an invalidation rule (§8.4). |

State the ownership rule outright: **server state is never duplicated into client state that can
diverge.** A server value is either read through the cache layer or read fresh. Copying it into a
component store creates two truths and no arbiter, and the symptom appears three screens away as a
stale number nobody can reproduce.

### 8.2 URL-addressable state and the URL contract (web)

Decide, per screen, what belongs in the URL. The test is simple and mechanical: **if a user would
reasonably paste the link to someone, the state must be in the URL.**

Typically in: the record being viewed, the active tab, filters, sort, pagination cursor, search
query, an open modal that is a destination rather than a transient confirmation.
Typically out: transient toasts, focus, hover, in-flight form drafts, scroll position, anything
containing personal or sensitive data (per privacy rules, never in query strings).

The contract per screen states:

```
SCR-RECORDS-LIST
  path:        /records
  params:      ?q=<string>&status=<open|closed|all>&sort=<created|updated>&dir=<asc|desc>&cursor=<opaque>
  defaults:    status=all, sort=updated, dir=desc, q empty, no cursor
  omission:    a param equal to its default is omitted from the URL, never written explicitly
  invalid:     an unrecognized value falls back to the default AND surfaces a dismissible notice;
               it never 500s and never silently renders a different result set than the URL claims
  restoration: a cold load of any valid URL reproduces the same view without additional interaction
  shareable:   yes — contains no identifiers private to the viewer
```

The `invalid` line is the one that gets skipped and the one that matters. A URL is user-editable
input arriving at the client, so it is untrusted input and gets the same treatment as any other:
validated, defaulted, and reported.

**Mobile equivalent.** The same requirement, different mechanism, and it must be specified rather
than assumed:

- **Deep links.** Every screen reachable from outside gets a URL scheme or universal/app link path,
  with its parameters, its behavior when the app is cold vs. warm, and its behavior when the target
  no longer exists (deleted record) or the user lacks access. Deep links are untrusted input in
  exactly the way query strings are.
- **Restoration state.** What survives process death: the OS may kill and relaunch the app, and the
  user expects to land where they were. Name what is restored (navigation stack, selected item,
  scroll offset, in-progress form draft), where it is persisted, and what is deliberately not
  restored — the deliberate exclusions are as important, because restoring an in-flight payment
  screen is a bug, not a feature.
- **The back stack** as an explicit contract: what the system back gesture does from each screen,
  and where deep-link entry places the user in the stack.

### 8.3 Server versus client ownership

A single table, per data domain, that ends the argument before it starts:

| Data | Server owns | Client owns | Sync direction | Conflict rule |
|---|---|---|---|---|
| Record content | canonical rows | edit buffer while a form is open | client → server on save | last-write-wins with a version check; 409 surfaces a merge prompt |
| Entitlements / plan | canonical | read-only cache | server → client | client never writes; a stale entitlement fails closed |
| UI preferences | optional mirror | canonical while offline | client → server, debounced | client wins |
| Session / auth | canonical | token only | server → client | expiry forces re-auth |

Two rules to state explicitly, because both are routinely violated by generated code:

- **Anything security-relevant is server-owned and re-checked server-side.** A client-held
  entitlement is a display convenience, never an authorization. `SECURITY.md`'s authz-in-one-place
  rule is what this table must not contradict.
- **Fail closed.** When ownership is ambiguous at runtime — a cached entitlement of unknown
  freshness — the restrictive answer wins.

### 8.4 Cache and invalidation policy

For every cached server resource: the key, the TTL or staleness rule, what invalidates it, and what
the user sees while it revalidates.

```
records.list(ownerId, filters)
  key:          ['records', ownerId, serialize(filters)]
  staleness:    30s stale-while-revalidate
  invalidated:  create/update/delete of any record owned by ownerId; tenant switch; logout
  on refetch:   previous data stays visible; a subtle refreshing indicator; NOT a full skeleton
                (a skeleton on every background refresh reads as a broken app)
  on error:     previous data stays visible with a retry affordance; the error is not silently
                swallowed (AG-10) and stale data is never presented as fresh
```

The invalidation list is the part that must be exhaustive. A mutation that invalidates two of the
three caches it affects produces a UI that is correct on the screen you are looking at and wrong on
the one you navigate to, which is the hardest class of bug to attribute.

### 8.5 Optimistic updates and rollback

Optimistic UI is opt-in per mutation, not a default, because the rollback path is real work and it
is the part that gets skipped. For each mutation that is optimistic, specify:

- **The predicted state** written locally, and how it is marked as unconfirmed in the model (not
  only visually — a pending row must be distinguishable in the data, or a refetch mid-flight will
  reconcile it wrong).
- **The confirmation** that promotes it: the server response, and what is reconciled from it
  (server-assigned IDs and timestamps always come back from the server; a client-invented ID that
  survives is a fabricated value, AG-6).
- **The rollback**: exact previous state restored, and what the user sees — a specific message
  naming what failed and whether their input was lost. "Something went wrong" after content
  disappears is the worst available outcome.
- **The conflict case**: the server accepted a different version. Which wins, and whether the user
  is told.
- **Which mutations are never optimistic**: anything involving money, deletion, or an irreversible
  external effect. State the list.

### 8.6 Per-screen data interface

One block per screen, and it must **match the schema in `DESIGN_SPEC.md` field-for-field**. Not
"similar to" — the same names, the same types, the same nullability. Where the screen needs a
different shape, the transform is named and lives in one place, so that the mapping exists as code
rather than as a per-component improvisation.

```
SCR-EXPORT-STATUS
  requires:
    job: {
      id: string                    // export_jobs.id            (uuid, not null)
      status: 'queued'|'running'|'done'|'failed'   // export_jobs.status (enum, not null)
      rowCount: number | null       // export_jobs.row_count     (int, NULL until done)
      errorCode: string | null      // export_jobs.error_code    (text, NULL unless failed)
      downloadUrl: string | null    // derived: signed URL, null unless status='done'
      createdAt: ISO8601            // export_jobs.created_at    (timestamptz, not null)
    }
  source:      GET /api/export/:id
  polling:     2s while status in (queued, running); stops on terminal status; stops after 10 min
               and surfaces the timeout state (a poller with no ceiling is a cost leak)
  authorization: owner-scoped server-side; a non-owner receives 404, not 403 (per SECURITY.md S-7,
               existence is not disclosed)
  writes:      none (the start action lives on SCR-SETTINGS-DATA)
```

Note the nullability annotations. `rowCount: number | null` is what makes "no data yet" expressible
at the type level, which is what makes a fabricated `0` a type error rather than a design choice.
This is AG-6 enforced by the type system rather than by a grep, and it is the stronger form —
prefer constructions that make a failure inexpressible over checks that detect it.

**Traceability requirement:** every field cites its schema column or names its derivation. A field
citing neither is either an invented field or an undocumented schema column, and both are
pre-flight blockers.

### 8.7 The four states every screen must handle

Every screen, every data-bearing region, specifies all four. An unspecified state gets invented at
implementation time, and the invention is usually a placeholder.

| State | Requirement |
|---|---|
| **Loading** | First load vs. background refresh are visually different (§8.4). Skeleton dimensions approximate real content so layout does not jump. A loading state that can persist forever must have a timeout that transitions to error. |
| **Empty** | Distinguishes *no data yet* from *no results for this filter* from *not applicable to you* — three different messages with three different actions. Exact copy comes from `SCREENS.md`. This is where AG-6 is won or lost. |
| **Error** | Names what failed in the user's terms, says whether their data is safe, and offers exactly one recovery action. Never a raw error string; never a message implying success. |
| **Partial** | Some regions loaded, some failed. Which regions can fail independently, what the page does when a non-critical region fails (render the rest, mark the failed region) and when a critical one does (the whole screen goes to error). A screen with no partial policy renders a plausible-looking page missing a section nobody notices. |

Add the fifth where it applies: **stale** — data known to be out of date while a refresh is in
flight or has failed. It is not the same as loading and must not look like fresh data.

### 8.8 Offline queue and conflict resolution

Required for mobile and for any web app claiming offline support; explicitly marked `n/a — online
only, and the app states so to the user` otherwise. The `n/a` is not a formality: a product that
degrades silently without connectivity has an unspecified offline behavior, which is worse than a
stated one.

Where offline is supported, specify:

- **What is readable offline** — which caches persist across launches, their eviction policy, and
  their staleness ceiling before the UI marks them stale.
- **What is writable offline** and what is refused, with the refusal message.
- **The queue**: where mutations are persisted, ordering guarantees, retry schedule with backoff,
  what happens when a queued mutation's target no longer exists on reconnect, and the queue's size
  ceiling and its behavior at the ceiling.
- **Idempotency**: every queued mutation carries a client-generated idempotency key so a retry after
  an ambiguous failure cannot double-apply. Without this, a flaky reconnect duplicates records.
- **Conflict resolution**, per entity: last-write-wins, server-wins, field-level merge, or
  user-prompted. Name the rule per entity — one global rule is almost always wrong, since a
  preference and a financial record do not deserve the same policy.
- **Visibility**: the user can see there are unsynced changes, and see when sync completes or fails.
  A silent queue that drops work is indistinguishable from data loss.

---

## 9. `BLOCKERS.md` and `STATUS.md`

Both are referenced by the never-stop protocol in `claude-md-template.md`. Their schemas belong
here, because the protocol's value depends entirely on whether a human can act on the output.

**The bar for both: a human who has not read the transcript can act within five minutes.** The
transcript is long, private to the session, and gone after compaction. If the file does not contain
the answer, the answer does not exist.

### 9.1 `BLOCKERS.md` entry schema

```
## B-3  G-4.2  Live email delivery cannot be verified
Opened:      2026-08-19T14:22Z          Status: OPEN
Blocks:      G-4.2, and transitively G-6.1 (welcome-flow E2E)
Severity:    blocks 2 of 31 goals; the build continues on 7 other unblocked goals

What was attempted:
  1. scripts/send-test-email.sh --to fixture@localhost  → passed against MailHog (fixture path
     works; the templating and the send call are verified).
  2. scripts/send-test-email.sh --provider live         → failed, see output below.
  3. Checked .env.example — MAIL_API_KEY is listed as required-at-send, not required-at-boot,
     so the app still starts and every other goal is unaffected.

Verbatim output:
  $ scripts/send-test-email.sh --provider live
  POST https://api.{{MAIL_PROVIDER}}/v1/send
  HTTP 401
  {"error":"invalid_api_key","message":"No API key provided"}
  exit status 1

What a human must provide:
  A sending API key for the transactional email provider, with the "send" scope, placed in
  .env as MAIL_API_KEY. Also confirm the verified sender domain — the code currently reads
  {{SENDER_DOMAIN}} and no value has been supplied (this is a business specific and was NOT
  invented, per AG-8).

What is unblocked by it:
  G-4.2 EC-3 (live send returns a provider message ID)
  G-6.1 EC-2 (welcome email arrives within 60s of signup)
  Everything else in G-4.2 is complete and committed: templates, queue, retry, fixture tests green.

Workaround in place:
  The fixture path (MailHog container) is wired and green, so the feature is implemented and
  tested end-to-end minus the live provider. Nothing is stubbed in shipped code.
```

Required fields, and what each prevents:

| Field | Prevents |
|---|---|
| **ID + goal ID + one-line title** | A blocker nobody can reference or count. |
| **Opened timestamp + status** | Blockers that were resolved but never closed, which make the next session's STATUS.md lie. |
| **Blocks (direct and transitive)** | A human fixing the wrong thing first. Transitive blockage is computed from the graph (§4.3), not remembered. |
| **Severity as a count** | "Is this urgent" answered by arithmetic instead of tone. |
| **What was attempted, numbered** | The human repeating the agent's failed attempts. Each entry names the command and its outcome. |
| **Verbatim output** | The single most valuable field. Paraphrased errors are unsearchable and frequently wrong. Include the command, the full error, the exit status. |
| **What a human must provide, specifically** | "Credentials are needed." Name the credential, the scope, the place it goes, and the format. |
| **What is unblocked by it** | Over-fixing, and the assumption that the whole goal is dead when one criterion is. |
| **Workaround in place** | A human undoing a working fixture path, and — critically — records that no stub shipped (AG-6). |

Two standing rules: a blocker is **closed by an entry edit with a resolution note**, never by
deletion, because the history of what blocked a build is how the next package avoids the same
gap. And **security-ambiguous and spend-relevant items are always blockers** (§7.2), even when the
agent believes it knows the answer.

### 9.2 `STATUS.md` schema

Regenerated every loop, overwritten rather than appended, and short enough to read in one screen.
It answers three questions: where is the build, what stopped it, what happens next.

```
# Build status — 2026-08-19T14:22Z — session 3

Goals:      31 total · 18 done · 1 in progress · 2 blocked · 10 pending
Gate:       PASS (last run 14:19Z, 2m41s)
Head:       a3f9c21  "G-4.1 transactional email templates and queue"  pushed ✓
Budget:     tokens 61% of session cap · paid-API spend $0.00 of $5.00 cap

In progress
  G-4.2  Live provider send path — 3 of 4 EC green; EC-3 blocked by B-3

Blocked
  B-3  G-4.2  live email delivery — needs MAIL_API_KEY + verified sender domain
  B-5  G-7.1  App Store Connect key — needs an ASC API key with App Manager role
       (transitively blocks G-7.2, G-7.3)

Unblocked and ready (from scripts/goal-graph.sh --unblocked)
  G-4.3, G-5.1, G-5.2, G-5.4, G-6.2, G-8.1

Next action if unattended
  Take G-4.3 (next by phase order among unblocked).

Next action if a human is available
  Resolve B-3 first: it unblocks 2 goals for one credential, the best ratio open.

Docs verified
  README 14:19Z · id-sweep PASS · doc-drift PASS
```

Two things make this file work. **The unblocked list is generated, not written** — a hand-written
list drifts from the graph and then the human is reasoning about a fiction. And **the two "next
action" lines are separate**, because the best move for an unattended loop (keep building) and the
best move for a human at a keyboard (unblock the highest-leverage credential) are almost never the
same, and collapsing them into one line loses whichever reader was not addressed.

When the unblocked set empties, STATUS.md is the session's final artifact and every open blocker
must be actionable on its own terms. That is the moment the five-minute bar is actually tested.

---

## 10. Definition of done — Phase 7

Each line is mechanically checkable: a grep, a script, a count, or a yes/no with no interpretation.
Every line is checked before Phase 8 begins. A failing line is a blocker, not a note.

**Goal entries**

- [ ] Every goal has all required fields from §1.1; `n/a` entries carry a reason.
- [ ] Every goal ID matches `G-<phase>.<n>`; no duplicates; no IDs reused from deleted goals.
- [ ] Every goal's `Implements` IDs resolve to defined FR/NFR/AD entries (`scripts/id-sweep.sh docs` exits 0).
- [ ] Every P0 FR appears in at least one goal's `Implements`. No P0 is unbuilt scope.
- [ ] Every goal implements at least one FR, NFR, or AD — no goals with no user justification.
- [ ] Every goal's reading map names `file § section`, never a bare filename, and every named section exists.
- [ ] Every goal names its deliverable artifacts as paths, and names at least one test suite that exists in `TESTS_TDD.md`.
- [ ] Every goal has an estimated size from `{S,M,L}`; the `L` count is justified or decomposed.
- [ ] The inheritance rule for plan items without full entries appears verbatim in `LOOP_GOALS.md` (§1.5).

**Exit criteria**

- [ ] Every goal has ≥ 1 exit criterion, and every criterion is a literal command, not a sentence.
- [ ] `grep -c 'cmd:'` per goal ≥ 1 and every `cmd:` line is followed by an `exit:` and a `match:`.
- [ ] No exit criterion contains an unquantified adjective (`works`, `correct`, `properly`, `gracefully`, `acceptable`, `reasonable`) — grep for them.
- [ ] Every criterion states an expected exit code AND an expected output pattern; exit-code-only criteria are flagged and strengthened.
- [ ] Every test-command criterion asserts a test count, not merely exit 0 (guards the zero-collected-tests vacuum).
- [ ] Every build-command criterion asserts the artifact exists and is non-trivially sized.
- [ ] Every criterion carries a `red-before` line naming a specific mutilation and its observed failure — no criterion is negative-tested by an import error alone.
- [ ] The green-twice procedure, including the literal clean command, is stated in `LOOP_GOALS.md` (§2.3).
- [ ] Every mobile goal changing runtime behavior has the full boot → install → launch → UI-assert chain (§2.5), and no criterion requires a physical device.
- [ ] No criterion depends on wall-clock time, network weather, or an unpinned random seed.

**Invariant gate**

- [ ] `scripts/invariant-gate.sh` exists, is executable, and exits 0 on a clean checkout of the scaffold.
- [ ] It contains every check in §3.2 that applies to this stack; each inapplicable one is explicitly listed as inapplicable with a reason.
- [ ] Its measured runtime is recorded and is under the stated ceiling.
- [ ] The gate/phase-gate/release-gate tiering is stated, and every check is assigned to exactly one tier.
- [ ] The gate-blocks-the-commit rule appears verbatim in `LOOP_GOALS.md` and `CLAUDE.md`.
- [ ] **Each gate check has been observed failing** on a deliberately broken input, and the check that caught it was named. Recorded in `AUDIT_LOG.md`.

**Dependency graph**

- [ ] `scripts/goal-graph.sh --check` exits 0 with 0 cycles, and has been observed reporting a deliberately introduced cycle.
- [ ] At least one root exists; every root has been walked for unrecorded assumptions; no root is credential-gated.
- [ ] Executing all roots produces a running skeleton (verified by actually doing it, §5.3).
- [ ] Every goal is reachable from a root; no orphan goals.
- [ ] `scripts/check-protocol-killers.sh` (or the manual equivalent) reports 0 unresolved references: every script, fixture, and seed profile named in any criterion exists or is a deliverable of a goal the citer depends on.
- [ ] No file is both frozen by an anti-goal and listed as a deliverable artifact.

**Toolchain and first hour**

- [ ] Every category in §5.2 is pinned to an exact version, with a verify command; containers pinned by digest, not tag.
- [ ] The full bootstrap sequence (§5.3) has been executed on a clean tree in this session, and its actual output recorded.
- [ ] The invariant gate passes on the scaffold before any goal runs.
- [ ] `.env.example` is complete against a grep of the source for env reads.
- [ ] All three seed profiles are defined; demo data is schema-flagged; no seeding happens at application startup.
- [ ] Every item in §5.5 is either present or explicitly recorded as absent with its consequence.
- [ ] Mobile: every row in §5.6 is marked credential-gated or not, and no credential-gated item blocks a loop criterion.

**Anti-goals**

- [ ] All twelve global anti-goals from §6.1 appear in `LOOP_GOALS.md` with stable `AG-<n>` IDs.
- [ ] Every anti-goal names a literal grep, script, or `git diff` check — none is stated as intent only.
- [ ] `scripts/check-anti-goals.sh` runs all of them and is wired into the invariant gate.
- [ ] **Every anti-goal check has been observed failing** on a deliberately introduced violation. Recorded in `AUDIT_LOG.md`.
- [ ] AG-6's check includes the empty-state assertion, so removing a placeholder cannot be satisfied by rendering nothing.
- [ ] AG-6's legitimate-placeholder exclusions are by path, not by an in-code comment the agent can add.

**Budget**

- [ ] A per-session token/cost cap, a per-goal loop cap, and a per-vendor paid-API spend cap are each stated as numbers with an enforcement point.
- [ ] Where a vendor supports a hard spend limit, it is set as well as wrapped.
- [ ] The spend-decisions-are-blockers rule appears verbatim.
- [ ] Default test profiles make no paid API calls; live profiles are opt-in and counted.

**`STATE_AND_DATA.md`**

- [ ] Every client state entry has all §8.1 fields and exactly one owner.
- [ ] No server value is duplicated into divergent client state.
- [ ] Every screen has a URL contract (web) or a deep-link + restoration contract (mobile), including invalid-input behavior.
- [ ] No URL or deep link carries personal or sensitive data in its parameters.
- [ ] The server/client ownership table covers every data domain; security-relevant data is server-owned and fails closed.
- [ ] Every cached resource names its key, staleness rule, exhaustive invalidation triggers, refetch presentation, and error presentation.
- [ ] Every optimistic mutation specifies predicted state, confirmation, rollback, conflict case, and user-visible failure copy; the never-optimistic list exists.
- [ ] Every screen has a data interface whose fields cite a schema column or a named derivation — and it matches `DESIGN_SPEC.md` field-for-field, including nullability.
- [ ] Every polling contract has a stop condition and a ceiling.
- [ ] Every screen specifies loading, empty, error, and partial states, with the empty state distinguishing no-data-yet from no-results from not-applicable.
- [ ] Offline behavior is specified with queue, idempotency keys, per-entity conflict rules, and sync visibility — or explicitly `n/a` with the user-facing statement that the app is online-only.

**Blockers and status**

- [ ] `BLOCKERS.md` and `STATUS.md` exist with the §9 schemas, seeded with any Phase-7 known gaps (credential-gated items in particular).
- [ ] The blocker schema requires verbatim output, and the template shows it.
- [ ] `STATUS.md`'s unblocked list is generated by the graph script, not hand-maintained.
- [ ] `STATUS.md` separates the unattended next action from the human next action.

**Package coherence**

- [ ] `scripts/id-sweep.sh docs` exits 0 with output appended to `AUDIT_LOG.md`, and has been shown failing on a deliberately broken ID.
- [ ] Every FR↔goal edge resolves in both directions (`deliverables-requirements.md` §8).
- [ ] `grep -rn '{{' docs/` returns only intentional placeholders, every one listed in the handoff message.
- [ ] No invented business specifics anywhere in `LOOP_GOALS.md` or `STATE_AND_DATA.md`.
- [ ] The handoff message names `foreman` as the executor and states that `CLAUDE.md` + `LOOP_GOALS.md` are its constitution and goal list.
