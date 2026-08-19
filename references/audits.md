# Adversarial audits

Run each as a FRESH subagent with no authorship context, prompted to attack, with file:line
citations required for every finding and severity tiers (CRITICAL/MAJOR/MINOR). Always request
two extra sections: "what the spec gets right — do not fix" (prevents over-correction) and a
ranked remediation order. After applying fixes, run a *separate* verification pass on the fixed
document — patches introduce their own defects (missing commas in DDL, dangling cross-refs,
contradicted counts) at a startling rate.

**Every audit writes to `docs/AUDIT_LOG.md`** — one section per audit: findings with severity,
what was fixed and where, what was deliberately not fixed and why, the verification pass's
verdict, and the "gets right" list. This artifact is how a later session (or the pre-flight
audit) knows the work happened; produce it even when an audit finds nothing.

## Database scale audit

Target the declared scale (rows, writes/day, tenancy model). Check: index coverage for every query
shown (leading columns, ORDER BY servability, partial-index predicates matching, FK columns —
the DB does not auto-index FKs); dead/redundant indexes under row-level security; vector/search
index parameters actually set (e.g. HNSW ef_search vs. LIMIT — silent under-fetch); full-text
storage (stored generated columns vs. per-query computation; size limits as insert failures);
partitioning legality against PK/unique constraints (partition key must be in every unique
constraint; exclusion constraints block partitioning); write amplification and hot rows (counters
updated in place = row-lock convoys; state columns in wide indexed rows); autovacuum/bloat per
high-churn table; connection pooling mode vs. session state (LISTEN/NOTIFY, advisory locks,
per-connection settings all break under transaction pooling); unbounded-growth tables absent from
the capacity plan; long transactions blocking vacuum.

## System scale audit

Check: concurrency arithmetic (max instances × concurrency vs. connection ceilings — autoscaling
turns saturation into metastable collapse); backpressure at every stage boundary; retry design
(bounded, jittered, deterministic-failure short-circuit, DLQs); external-API quota handling
(429 path, circuit breakers); cold starts on the hot path; cache/counter durability (an evicted
budget counter must fail toward the ledger, never toward zero); tenant fairness (bulkhead queues
for backfills); N+1 patterns on the hottest consumer; observability that can actually detect its
own stall (a heartbeat measured independently of the thing it monitors); cost-DoS (instance caps).

## User/subscriber scale review

The people axis, distinct from data volume: stateless auth, read-path ceilings and the
read-replica step, realtime fan-out (per-view subscriptions, the largest connection population),
tenant packing into cells with a provisioning path that never builds infrastructure, entitlements
as data (plan change = row update), billing wiring, concurrency correctness at high seat counts
(optimistic versioning, alert digesting).

## Cost model verification

Every price fetched from a primary source, with the **source URL and fetch date recorded beside
the figure** — the check is that the fetch happened, not that a date appears; anything
unfetchable is listed as "could not verify" rather than estimated silently. Produce per-scale-tier tables, name the
floors that don't scale down, the levers ranked by savings-per-architectural-damage, alternatives
evaluated-and-rejected with numbers, and the two or three things that break the model (price
cliffs, per-unit features that explode at volume, drifting assumptions) each with a monitored
guard.

## Security checklist (build into SECURITY.md, then audit against it)

SQL only through parameterized builders (CI grep for concatenation); input validation by shared
schemas at every boundary; output encoding + strict CSP, sanitizer on the one rich-text surface;
SSRF containment on any URL-fetching component (private-IP/metadata deny post-DNS, redirect
re-validation, egress allowlists); authn by default with a reviewed public-route allowlist, authz
server-side in one place; rate limits + quotas + instance caps (cost-DoS); secrets in a manager
only with CI scanning; supply chain (frozen lockfiles, audits, pinned digests, postinstall
allowlist); for LLM components: channel separation (fetched content is data, never instructions),
structured outputs only, model output treated as untrusted input, expensive tools human-gated;
and tests for all of it: injection corpora, SSRF units, authz matrix (route × role), isolation
proof. Every rule names its enforcement mechanism or it is not a rule.

## Pre-flight readiness audit (the last gate before "GO")

Question: can an autonomous session execute this package without stalling or producing a mediocre
product? Start with the **mechanical ID sweep** — a script (not eyeballing) that greps every
FR/NFR/AD/D/G/suite ID referenced in any doc and fails on IDs never defined; append its output to
AUDIT_LOG.md. Then check: (1) broken references — every goal/section/file/command cited actually exists as
described; the dependency graph has no cycles, orphans, or contradictions at its root; (2) the
first-hour trap — toolchain versions pinned, scaffold commands runnable, everything the docs
assume exists but never define; (3) contradictions from successive edit passes — renamed IDs,
dangling cross-refs, decisions cited but missing; (4) buildability of the UI from the visual docs
alone; (5) world-class blind spots — i18n of the UI itself, transactional email deliverability,
billing actually built (not just decided), client-side error tracking, status page, ToS/privacy
artifacts, demo/seed data for first-run, per-tier SLAs; (6) protocol killers — instructions that
are self-contradictory (gates required before the goal that creates them, frozen files the goals
must edit, push targets that don't exist). Verdict: GO / NO-GO with the minimal fix set. Fix,
re-verify, then ship.
