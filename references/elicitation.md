# Elicitation — from one sentence to build-ready inputs

The rest of this skill assumes rich inputs: a predecessor codebase to audit, a written product
description, a brand to extend. The common case is none of that. The user has a sentence — "I want
to build a tool that helps freelancers track invoices" — and everything the fourteen documents need
is either in their head unarticulated, researchable but not yet researched, or genuinely undecided.

This file is the protocol for that case. Its job is to get from the sentence to inputs rich enough
that Phase 1 produces a PRD about *this* product rather than a generic one, and Phase 3 produces a
design with a point of view rather than a competent default.

The governing claim: **the quality ceiling of the whole package is set here.** Phases 1-9 are
faithful. They will render whatever they are given at high fidelity. Given a vague idea they produce
a beautifully formatted vague product — fourteen documents that could describe any of two hundred
apps. No later audit catches that, because nothing in the package is *wrong*; it is merely
characterless, and none of the audits in `references/audits.md` check for character.

Elicitation runs before the sizing gate's tier is final. It usually changes the tier: a user who
says "simple tool" and then says "my clients' accountants need access" has described multi-tenancy,
and Sketch is no longer available.

---

## 1. Intake triage — what does the user actually have?

First move, before any question: establish the starting state. It determines which phases run, which
questions are already answered, and how much research substitutes for interviewing.

| State | Signal | What changes in the pipeline |
|---|---|---|
| **Idea only** | One or two sentences, no artifacts | Full elicitation (§3), design elicitation (§4), heavy research (§5). Phase 0 skipped. Expect the longest interview and the largest number of recorded defaults. |
| **Written description** | A doc, notes, a pitch, a spec of some kind | Read it first, completely. Interview only the gaps. The description is *evidence of intent*, not requirements — it will be under-specified on scale, money, identity, and NFRs almost without exception. |
| **Existing product being rewritten** | "We have this, it's bad, rebuild it" | Phase 0 becomes mandatory even without code: interview for behavior, get screenshots, get a deployed instance. Parity list and defect list are the two products. The most valuable question is "what does the current one get *right* that we must not lose" — users volunteer complaints and forget the parts that work. |
| **Codebase** | A repo, a zip, a link | Phase 0 as written: read code, not README. Elicitation shrinks to intent, scope of the rewrite, and everything the code cannot tell you — audience, business model, growth expectations, what to *drop*. |
| **Design or brand exists** | Figma, style guide, live site, logo set | Skip §4's generation path. Instead extract: tokens from the artifact, semantic intent behind the choices, and the parts that are deliberate versus inherited from a template. Ask which are load-bearing. Phase 3 becomes codification, not invention. |
| **Competitor to beat** | "Like X, but ..." | The strongest starting state and the most under-used. Research X properly (§5), get the user to be specific about the "but", and turn the delta into the differentiating FR group. A named competitor converts half the question bank into research. |

These combine. A user can have a written description *and* a competitor *and* no design. Triage each
axis separately: material, predecessor, design, competitive frame.

**Two rules that govern everything after.**

*Never ask for what they already gave you.* Re-asking is not thoroughness; it is a signal that their
input was not read, and it burns the small budget of attention the user has for questions. If a
document answers a question partially, confirm the specific gap ("your notes say teams — do team
members share one billing account, or does each pay separately?"), never the whole question again.

*Never assume what they have not given you.* The temptation is symmetric and worse. A missing answer
becomes a recorded decision in the open-decisions table (§6), never an invisible choice inside a
design document. The whole failure mode this skill exists to prevent is a build that goes six phases
deep on an assumption nobody made consciously.

---

## 2. The interview protocol

**Batch at phase boundaries.** All the questions needed for the PRD go in one exchange before
Phase 1, not dribbled out across twenty turns. Turn-by-turn interrogation is the single most
disliked pattern here: it makes a ten-minute task feel like an hour, it forces the user to hold
context they came here to offload, and it produces worse answers because each question arrives
without the frame of the others. Batching also lets the user answer *out of order* and skip what
they do not know, which is information in itself.

**Ask concrete multiple-choice, not open-ended.** A person who cannot answer "what are your
non-functional requirements" can answer "which matters more: this page loads instantly for everyone,
or it can show ten years of history?" The second question elicits the same architectural fork — read
path optimization versus retention and archival strategy — in language they actually possess. This
is the core translation move of the whole protocol: **take the architectural fork, and phrase it as
the user-visible tradeoff it causes.**

**Recommend.** Every question carries a recommendation and its one-line reason. Users are not being
tested; they are being consulted. A recommendation converts a hard question into an easy
confirmation or a productive disagreement, and disagreement is the highest-value answer available —
it means you had the wrong model and now you do not.

**Never more than a handful at once.** Four to six questions per batch. Beyond that, answer quality
collapses and later questions get rubber-stamped. If you have twenty questions, you have not
prioritized: cut the ones whose answers you could research (§5) or default (§6).

**Every question must change what gets built.** Before asking, state to yourself which document,
which requirement, or which architectural decision the answer moves. If nothing moves, drop it and
record a default. "What should we call it?" changes nothing structural in a blueprint and can wait
for the build. "Do users' documents ever need to be shared with someone outside their account?"
changes the authorization model, the schema, the threat model, and three screens.

### The AskUserQuestion pattern

Where the tool is available, use it. The shape that works:

- **2-4 options**, never more. Five options is a form, not a question.
- **Recommended option first**, marked as such, with its reason inside the option text.
- **Enough context in each option to pick without asking a follow-up** — name the consequence, not
  just the choice. "Personal accounts only" is a label; "Personal accounts only — simplest, but
  adding teams later means a schema migration and a re-auth flow" is a decision.
- **An explicit escape** where honest: "Not sure — pick a sensible default and flag it." That answer
  routes straight to §6 and is a legitimate outcome, not a failure.

### Worked examples — good versus bad

| Bad | Why it fails | Good |
|---|---|---|
| "What are your NFRs?" | Jargon; the user has no vocabulary for the answer they do possess. | "Which is worse for your users: the app is occasionally slow, or the app is occasionally missing the newest data? (Recommended: slow is worse — it's the one people quit over.)" |
| "What's your data model?" | Asks for output, not input. That is your job. | "When someone deletes a project, should its history disappear too, or stay recoverable for a while? (Recommended: soft-delete for 30 days — undeleting is the most-requested feature in tools like this.)" |
| "Who's your target user?" | Produces a marketing persona, not a design constraint. | "Picture the person who'll use this most. Are they doing it (a) as their whole job, many hours a day, (b) a few times a week between other work, or (c) once and probably never again?" |
| "Do you need to scale?" | Everyone says yes; the answer carries no information. | "A year in, if this goes well — is that 100 users, 10,000, or a million? (Recommended: design for 10,000 and note the fork to a million; over-building for a million costs a month you probably don't have.)" |
| "What's your budget?" | Feels like a sales question and often gets a defensive non-answer. | "Are there services you already pay for that this should use, and any you specifically want to avoid?" |
| "Should it be secure?" | Nobody says no. Zero-information question. | "If this leaked entirely tomorrow — every record public — what's the worst single consequence? Embarrassing, expensive, or legally reportable?" |
| "Make it look how?" | Unanswerable without vocabulary. See §4. | "Name two products you enjoy using, and one you find ugly or exhausting." |

---

## 3. The core question bank

Organized by what the answer unlocks. Ask what is not already known; batch by phase. Each entry
names its downstream effect — if the effect is not real for this product, do not ask.

### Audience and current behavior

> **Who uses this, and what do they do today instead?**
> Options when the user stalls: (a) nothing, they just live with the problem; (b) a spreadsheet;
> (c) a general tool bent to fit (email, a notes app, a chat thread); (d) a real competitor product;
> (e) they pay a person to do it.

*Unlocks:* PRD personas; the entire competitive-set research (§5); the migration/import requirement
(if the answer is a spreadsheet, import is an FR, not a nicety); the onboarding design. The "what
they do today" half is more valuable than the "who" half — the incumbent behavior is what the
product must beat, and it is usually a spreadsheet rather than a funded startup.

> **How often do they hit this problem — many times a day, a few times a week, or a few times a
> year?**

*Unlocks:* density decisions in §4, notification design, whether the product needs to be *learnable*
(rare use) or *fast* (constant use). These are opposed. A tool used all day should be dense and
keyboard-driven; a tool used quarterly should hold the user's hand and assume they have forgotten
everything.

### The single job

> **If the product does exactly one thing well and everything else badly, what is the one thing?**

*Unlocks:* the P0 message on the primary screen (Phase 3's design principle), the FR priority
ordering, and the v1 scope boundary. This is the highest-leverage question in the bank. A user who
cannot answer it does not yet have a product; they have a category. Push once, with options drawn
from their own description, before accepting "all of them equally."

> **Walk me through the first five minutes of a new user who has never seen this. What do they see,
> what do they do, when do they get something they'd pay for?**

*Unlocks:* the onboarding screens, the empty-state design (routinely forgotten and routinely the
first thing a real user sees), demo/seed-data policy, and the "first hour trap" the Phase 8 audit
checks for. If the honest answer involves substantial setup before any value, that is a named risk
in the PRD.

### Success as a number

> **Six months after launch, what number tells you this worked?**
> Options: (a) a count of active users; (b) a revenue figure; (c) time saved per user per week;
> (d) a quality/accuracy figure; (e) it's internal, success is "the team stopped complaining."

*Unlocks:* PRD launch metrics; the analytics/instrumentation requirements (a metric nobody
instrumented is a wish); and which NFR axis gets the engineering budget. A product whose success
metric is time-saved must be fast; one whose metric is accuracy can be slow and had better be right.

### Scale

> **A year in, if it goes well: how many users, and how much data per user?**
> **Is growth steady, or spiky (a launch, a season, a press hit)?**

*Unlocks:* every capacity decision in DESIGN_SPEC — database choice, indexing, pagination
requirements, caching, whether background jobs need a queue, and the cost model. Spiky growth
changes the answer even at low totals: burst capacity and cold-start behavior become real
requirements where steady growth would let both slide.

The honest framing when the user does not know: *design for the stated number, document the fork to
10x it, and record the fork as a decision.* Building for a million users a product that will have
four hundred is a well-documented way to never ship.

### Money

> **How does this make money, if it does?**
> Options: (a) free, no revenue path yet; (b) one-time purchase; (c) subscription; (d) usage-based;
> (e) enterprise contracts and invoicing; (f) free tier plus paid tier.
>
> **Follow-up, always: does v1 need to actually take payment, or can that wait?**

*Unlocks:* possibly the largest architectural fork in the bank. Subscription implies entitlements
checks on every gated path, a billing provider integration, webhook handling, dunning, plan-change
proration, and a whole tier of failure modes. Usage-based additionally requires metering that is
accurate enough to bill on, which is a correctness requirement, not a nice-to-have. Enterprise
implies invoicing, seats, procurement, and usually SSO (see identity). "Free for now" is a
legitimate answer and it must be *recorded*, because retrofitting entitlements into a product built
without them is a rewrite of the authorization layer.

The follow-up matters as much as the question. Many products should ship with the pricing decided
and the payment integration deferred; that is a scope decision worth surfacing rather than
defaulting either way.

### Accounts and identity

> **Who needs to be able to see whose data?**
> Options: (a) nobody logs in, it's anonymous/local; (b) personal accounts, everyone sees only their
> own; (c) small teams share a workspace; (d) organizations with roles and admins; (e) organizations
> that will demand SSO and provisioning.

*Unlocks:* the authorization model, the schema's tenancy shape, the security model's actor list, the
entire EXTENSIBILITY tenancy section, and roughly a third of the test suite. This is the single most
expensive question to get wrong. Anonymous → personal is an easy migration. Personal → team is a
schema change plus a permissions layer plus a re-design of every list view. Team → org-with-SSO adds
an identity-provider integration and an audit-log requirement.

Ask it even when the user's description implies the answer, and phrase the follow-up as a future
check: "is there any version of this in two years where a manager wants to see their team's data?"
A yes there means designing the ownership column now, even if teams ship later.

### Data sensitivity and compliance

> **What's the most sensitive thing this will ever store?**
> Options: (a) nothing sensitive, public-ish content; (b) personal details — names, emails,
> addresses; (c) financial data; (d) health data; (e) other people's customer data; (f) credentials
> or secrets belonging to users.
>
> **Are your users in the EU, California, or anywhere with a regime you already know about?**
> **Is this bound by anything specific — a regulation, a customer's security review, an
> industry standard?**

*Unlocks:* the threat model's asset list, encryption and retention requirements, the legal document
set (privacy policy, DPA, subprocessor list), data-residency architecture, deletion/export
requirements (a right-to-delete obligation is an FR with a test, not a policy sentence), and audit
logging. Compliance regimes are also §5 research targets: confirm the actual current obligations
from a primary source rather than from memory of what a regime required some years ago.

If the answer is (e) or (f), the tier is Full regardless of size, and the security phase leads rather
than follows.

### Platform

> **Where does this need to run, and which one comes first?**
> Options: (a) web only; (b) iOS first, web later; (c) Android first; (d) mobile both; (e) desktop;
> (f) several, and I don't know which leads.

*Unlocks:* the entire technology stack, the design system's constraints (iOS wants HIG conventions
and platform-native components; web wants responsive breakpoints), the release pipeline, the store
compliance surface, and the offline question below. Force a *primary* even when several are wanted:
a product designed for all platforms equally is designed for none well, and the second platform's
requirements are far cheaper to accommodate as a documented future than to build in parallel.

### Connectivity and offline

> **What should happen when the network drops mid-use?**
> Options: (a) show an error, it's fine — this is a desk tool on good wifi; (b) let them keep
> reading what's already loaded; (c) let them keep working and sync later; (d) it must work fully
> offline for long stretches.

*Unlocks:* one of the sharpest architectural forks available. (c) and (d) mean local persistence,
conflict resolution, sync protocol, and a data model that tolerates divergent histories — a
different product engineering-wise from (a). Users routinely say "offline would be nice" without
knowing it triples the data layer. Price it in the question: "(c) and (d) roughly double the data
layer's complexity — worth it only if users are genuinely on trains, planes, or job sites."

### Day-one integrations

> **What must this talk to on day one — and what would be nice but can wait?**
> Prompt categories when they stall: identity providers, payment, email/SMS delivery, calendar,
> storage/file services, accounting, CRM, whatever their industry's standard system of record is.

*Unlocks:* the API surface in DESIGN_SPEC, the cost model (per-call pricing), the failure modes
(every integration is a dependency that can be down, rate-limited, or deprecated), and a §5 research
task per integration — confirm the API exists, is open to new signups, is priced as remembered, and
has the specific capability assumed. A design built on an integration that turns out to be
enterprise-sales-only or waitlisted is the most expensive discoverable mistake in this phase.

Separate *must* from *nice*: the nice ones become EXTENSIBILITY surfaces rather than v1 work.

### Constraints

> **What's fixed that I should design around?**
> Sub-questions worth asking together: a deadline or event this must be ready for; a monthly cost
> ceiling; who is building it (you alone, an agent, a team, a contractor); anything in the existing
> stack that must be kept (a database already in use, a cloud account, a language the team knows, a
> host already paid for).

*Unlocks:* technology selection, the build plan's sequencing and parallelism, the cost model's
budget line, and the realism of the whole scope. A stated stack constraint is binding and should be
recorded as an AD with "constraint, not choice" as its reasoning, so nobody later "improves" it.

A deadline changes the shape of the package: it converts scope questions into cut-list questions and
makes the v1 boundary the most important artifact in the PRD.

### The out-of-scope list

> **Name three things people will ask for that v1 will deliberately not do.**

*Unlocks:* the PRD's non-goals section, the anti-goals with greps in LOOP_GOALS, and the
EXTENSIBILITY document's "what is NOT extensible" section. This question is worth asking last,
because by then the user has enumerated enough ambition to have something to cut, and it does
something no other question does: it makes scope *subtractive*, which is the only direction scope
ever moves usefully.

If the user cannot name three, offer candidates drawn from their own answers and from the
competitive set — features the competitors have that this one is choosing not to match, and why.

---

## 4. Eliciting a design direction when none exists

This section decides whether the output looks world-class or generic. Everything else in the
pipeline is faithful transmission; this is where a point of view gets created or does not.

**State the failure mode plainly, because it is the likely one.** The most common outcome of a
blueprint for a user with no brand is a *competent, characterless default*: a neutral blue-gray
system, a safe sans-serif, evenly-weighted cards, nothing wrong and nothing memorable. It happens
not because the design phase is weak but because **nobody was ever asked what it should feel like**,
so the design system had no input to derive from and fell back to the mean of everything.

**"Make it look good" is not a design direction, and neither is "modern," "clean," or
"professional."** Those words are the absence of a direction wearing its clothes. Every product ever
built wanted to look good. A direction is a *choice that excludes something* — and if the stated
direction excludes nothing, it has not been stated.

Do not ask a user with no brand "what are your brand colors." They do not have any, the question
signals you were not listening, and whatever they invent on the spot will be worse than what you
would derive. Ask these five things instead.

### 4.1 References, with reasons

> **Name two or three products you enjoy using — any category, they don't have to be like this one.
> For each: what specifically do you like? Is it how it looks, how it feels to use, or how it makes
> you feel about yourself while using it?**

The reason is the payload; the name alone is nearly useless. "I like [well-known finance app]"
could mean the density, the typography, the fact that it never nags, or the perceived
seriousness. Push once for the specific: "what would you miss if it changed?"

Where the reference is a real product you can examine, examine it (§5) — its actual type scale,
spacing rhythm, color count, and motion budget — rather than working from a remembered impression.
Bring back what you found and check it against what they said they liked; they are often different,
and the gap is informative.

### 4.2 Emotional register, as opposed pairs

Concrete forced choices, because "what feeling should it have" is unanswerable and "pick a point on
this line" is not. Use a slider or a three-point choice per pair, and ask for at most five pairs:

| | |
|---|---|
| Calm, quiet, gets out of the way | Energetic, alive, has opinions |
| Dense — a lot on screen, for someone who knows it | Spacious — one thing at a time, room to breathe |
| Playful, human, a little warm | Serious, precise, businesslike |
| Warm — approachable, soft edges, human color | Clinical — neutral, exact, instrument-like |
| Familiar — behaves like tools they already know | Distinctive — its own conventions, worth learning |

Each pair maps to concrete token consequences, and saying so out loud makes the answers better:
spacing scale and information density; chroma and hue temperature; type family, weight contrast, and
whether the type scale is dramatic or even; corner radius; motion budget and easing character;
whether illustration or iconography carries personality.

The last pair is the one people under-think and it is the most consequential: *familiar* means
inheriting conventions and being forgettable-in-a-good-way; *distinctive* means teaching the user
something and being remembered. Both are correct answers for different products. Neither is "modern."

### 4.3 Anti-references

> **Name one product that looks or feels wrong for this. What is it doing that yours must not do?**
> **Is there a whole category this must not be mistaken for?**

Often more informative than the references, for two reasons. People are far more articulate about
what irritates them than about what pleases them, and a stated anti-reference is a *constraint you
can check the output against* — a design that drifts toward the thing they named has failed a test,
not merely disappointed a taste.

Common and useful anti-answers to offer if they stall: "not another dashboard," "not a startup
landing page," "not enterprise software from 2012," "not a toy," "not something my clients would
think I built in a weekend."

### 4.4 Density, from the actual usage context

Do not ask this as a preference; derive it from the frequency answer in §3 and confirm.

> **You said people use this [many times a day / occasionally / once]. That points to
> [dense-and-fast / balanced / spacious-and-guided]. Does that match how you picture it?**

The rule, stated because it is routinely violated: **a tool used all day by an expert and a page seen
once by a stranger have opposite correct answers.** The expert tool wants information density,
keyboard paths, persistent state, minimal chrome, and no hand-holding — every pixel of whitespace is
a row they cannot see. The stranger's page wants one message, generous space, obvious affordances,
and progressive disclosure — every extra element is a chance to bounce.

Products that serve both need *two* density modes with an explicit default, not a compromise that
serves neither. That is a design-system decision (Phase 3, density opt-in) and it should be recorded
here as its input.

### 4.5 The accessibility floor

> **Is there a standard you need to meet — WCAG AA, a government requirement, an enterprise
> customer's checklist? (Recommended default if you're unsure: WCAG 2.2 AA. It is the common
> procurement bar, and retrofitting contrast and focus behavior later means re-deriving the whole
> palette.)**

*Unlocks:* the token generation constraints (every semantic pair must clear its contrast ratio at
generation time, not by later audit), the motion contract's reduced-motion requirement, focus
handling, target sizing, and a test suite. Pin it before tokens exist, because contrast is a
constraint on palette *derivation*; discovering it afterward means throwing the palette away.

### 4.6 Converting answers into a direction

The output of this section is not a mood board and not a list of adjectives. It is **a stated point
of view with a defensible rationale** — a paragraph that could be argued with, of the form:

> *This product is [register], because [fact about the user and the usage context from §3].
> Therefore it is [density decision] with [type character] and [color strategy], and it deliberately
> avoids [anti-reference trait] because [consequence]. Where a choice is ambiguous, it resolves
> toward [the one pair that dominates].*

The test of a direction: **could a competent designer disagree with it?** If not, it says nothing.
"Clean and modern" cannot be disagreed with. "Dense, quiet, and typographically plain, because these
users live in this tool for six hours a day and anything decorative becomes noise by week two" can
be — and is therefore a direction.

Write it into the design system as the derivation for its principles, so later editors can see why
the tokens are what they are and do not "improve" the palette into the mean.

### 4.7 Handoff

Once the direction exists, this skill does not generate the visual system by hand:

- **`design-system`** — token generation from the direction: OKLCH ramps, type scale, spacing rhythm,
  WCAG-validated semantic pairs, dark mode as a token swap. This is Phase 3's DESIGN_TOKENS producer.
- **`theme-factory`** — when the deliverable is a one-off artifact or the product needs a
  ready-made palette/font pairing rather than a derived system.
- **`brand-guidelines`** and **`brand-voice`** — when a brand needs establishing rather than
  extending: naming, mark, voice, the written register that Phase 3's exact copy must match.
- **`frontend-design`** — the router when several of the above apply and the sequencing is unclear.

Hand off with the direction paragraph, the register answers, the anti-references, the density
decision, and the accessibility floor. A handoff of "generate a design system for a freelancer
invoicing tool" throws away everything this section produced and returns the generic default.

---

## 5. Research that substitutes for user knowledge

Much of what the PRD needs is not in the user's head and should not be asked of them. Asking a user
to supply facts about the outside world produces guesses stated with confidence — the worst input
class available, because it arrives already sounding verified.

**The division of labor: ask the user about intent, constraints, and taste. Research everything
else, then bring it back for confirmation.**

### What to research

- **The competitive set** — not that competitors exist, but *how they actually solve this*: their
  pricing tiers and what gates each one, their onboarding, their data model as visible from the
  outside, what their users complain about publicly, and what they conspicuously do not do. Bring
  back a short comparison and ask "which of these is the one to beat, and where do you differ?"
- **Domain conventions and terminology** — every domain has words its practitioners use precisely
  and outsiders use loosely. Getting them wrong in the UI is the fastest way to signal the product
  was built by someone who has never done the job. Research the vocabulary and use it exactly.
- **Applicable regulation** — what the identified data class and user geography actually require
  today, from the regulator or the official text, not from recollection. Regimes change; a
  requirement remembered from three years ago may be obsolete or may have grown teeth.
- **Platform constraints** — store review rules, permission models, background execution limits,
  file size caps, whatever the chosen platform actually enforces this year. These kill designs
  quietly and late.
- **Real API and service availability** — for every integration named in §3: does it exist, is it
  open to new developers today, does it have the specific capability the design assumes, what does
  it cost at the projected scale, and what are its rate limits. Half of "we'll integrate with X"
  survives contact with X's actual documentation; find out which half before the design depends on it.

### The hard rules

**Every external claim carries a primary-source URL and a fetch date.** A price, a limit, a
capability, a regulatory obligation. The source is the vendor's own page or the regulator's own
text, not a summary article. The date matters as much as the URL because the next reader needs to
know how stale the figure is. A date stamped on a remembered price is the specific failure this rule
exists to prevent — it launders a guess into a citation.

**Anything unverifiable is recorded as "could not verify," never estimated.** An unverifiable cost
is an open item in the verification backlog with a named fallback, not a plausible number in the
cost model. A number with no source is indistinguishable from a number with a bad source once it is
three documents deep, and by then the whole capacity plan rests on it.

**Nothing about the user's own business is ever invented.** Company name, legal entity, support and
contact addresses, physical address, domains, policy URLs, officer names, tax or registration
identifiers, store publisher name. These become explicit `{{PLACEHOLDER}}` tokens or open questions
in the PRD, always. This is not a style preference: fabricated business details reach legal
documents, app store metadata, and email footers, where they are wrong in a way that is expensive
and slow to discover. If a placeholder blocks a later phase, that is a blocking question (§6), not a
prompt to fill it in plausibly.

**Bring research back for confirmation, not as fact.** Research establishes what is true about the
world; only the user can say which parts matter. Present findings as a short digest with a
question attached: "the three tools in this space all charge per-seat and all gate the export
feature — do you want to match that shape or undercut it?"

---

## 6. Assumptions and defaults

The user will say "you decide," or answer four of six questions, or go quiet for a day. That is
normal and the protocol must work through it. What must never happen is the assumption disappearing
into a design document as though it were a requirement.

**The mechanism.** Every unanswered question becomes a numbered entry in the PRD's open-decisions
table (`D<n>`), with five fields:

| Field | Content |
|---|---|
| **Decision** | The question, phrased as the fork it actually is |
| **Default taken** | What the package assumes in the meantime, stated concretely |
| **Reasoning** | Why this default and not the alternative — one or two sentences, arguable |
| **Cost to change later** | Cheap (a config value), moderate (a migration), expensive (a rewrite of a layer) |
| **Confirm by** | The phase at which proceeding without an answer becomes unsafe |

The "cost to change later" field is what makes the table useful rather than decorative. It converts
a flat list of open items into a priority order, and it tells the user which questions deserve their
attention — most people will engage seriously with three decisions and rubber-stamp fifteen.

**The rule that governs the whole mechanism: a silently assumed decision is the failure mode this
exists to prevent.** Not the wrong default — a wrong default that is *recorded* costs one
conversation. An unrecorded one costs the phases built on top of it, and it is typically discovered
by a build agent halfway through implementation, which is the most expensive place to discover it.

**An assumption that is expensive to reverse is a blocking question, not a default.** The test:
if the answer flips, does the change land in one config file, or does it propagate through the
schema, the authorization model, and half the screens? Identity model, tenancy shape, offline
capability, payment presence, and platform primacy are almost always blocking. Retention windows,
notification defaults, pagination sizes, and empty-state copy are almost never. When a blocking
question is unanswered, say so plainly and stop rather than proceeding on a guess that will be
expensive to unwind — proceeding is not helpfulness, it is deferred cost with interest.

**Defaults must be visible in the artifact, not only in the table.** Where a document depends on an
open decision, mark the dependency inline (`per D4`) so a reader of that section alone learns that
the ground is provisional.

---

## 7. Elicitation completeness gate

Phase 1 does not start until every line below is a true statement. "Known" includes "recorded as
`D<n>` with a default and a confirm-by phase" — the gate is about *nothing being unexamined*, not
about everything being decided.

- [ ] The intake state is established, and everything the user already provided has been read in
      full — not skimmed, not summarized from its title.
- [ ] The primary user is described in terms of what they do today instead, and how often.
- [ ] The single job the product must do is stated in one sentence the user agreed with.
- [ ] Success is expressed as a number with a time frame.
- [ ] Scale is stated for one year out: user count, data per user, and whether growth is steady or
      spiky.
- [ ] The revenue model is known, and whether payment ships in v1 is explicitly decided.
- [ ] The identity model is known — anonymous, personal, team, or org — and the two-year question
      ("could a manager ever need to see their team's data?") has been asked.
- [ ] The most sensitive data class is named, and any compliance regime is either confirmed against
      a primary source or recorded as "could not verify."
- [ ] The platform set is known with one declared primary.
- [ ] Offline/connectivity expectation is decided, with its data-layer cost acknowledged.
- [ ] Day-one integrations are separated from later ones, and every day-one integration has been
      verified to exist, be open, and have the assumed capability, with a URL and a date.
- [ ] Constraints are captured: deadline, budget ceiling, who builds it, stack that must be kept.
- [ ] At least three explicit non-goals for v1 are written down.
- [ ] A design direction exists as a paragraph a competent designer could disagree with — not a set
      of adjectives — with references, anti-references, density, and an accessibility floor behind it.
- [ ] Every external claim carries a primary-source URL and a fetch date; every unverifiable one is
      marked "could not verify."
- [ ] Every business specific is either user-supplied or a `{{PLACEHOLDER}}`; none is invented.
- [ ] Every unanswered question is a numbered decision with default, reasoning, reversal cost, and a
      confirm-by phase.
- [ ] No blocking-cost assumption is sitting unconfirmed.
- [ ] The sizing tier has been re-checked against what elicitation revealed, and any change is
      stated with the finding that forced it.

### The escape hatch

Some questions have no answer yet — not in the user's head, not in the research, not derivable.
"Will people pay for this?" "Will they use it weekly or abandon it?" "Is the AI output good enough
to trust?" These are not requirements-gathering failures; they are genuine unknowns about the world.

**Build the smallest thing that makes the answer observable, and record it as an experiment rather
than a requirement.** An experiment entry names: the question, the observation that would answer it,
the smallest build that produces that observation, and the decision that follows each outcome. It
goes in the PRD as an experiment, not as an FR, because an FR is something the build must satisfy
and an experiment is something the build must *reveal*.

The distinction matters downstream: FRs get acceptance tests, experiments get instrumentation. A
question turned into an FR by force ("the AI output shall be accurate") produces an untestable
requirement and a test suite that lies. Turned into an experiment ("ship the output with a
thumbs-up/down and a stored rationale; at 200 responses, decide whether to keep the feature") it
produces a real measurement and a real decision point.

---

## 8. Anti-patterns

**Interrogating turn by turn.** Twenty single-question exchanges instead of four batches. It burns
the user's patience, degrades answer quality because each question arrives without the frame of its
siblings, and makes an assistant feel like a form. Batch at phase boundaries.

**Asking questions whose answers change nothing.** Every question spends attention that is in short
supply. If you cannot name the document, requirement, or fork the answer moves, the question is
theater. Drop it and record a default. The cost is not the question; it is that the three questions
that *did* matter now get less thought.

**Asking for jargon the user does not have.** "What are your NFRs," "what's your data model,"
"what's your tenancy strategy." These produce either a stall or a confident wrong answer, and the
confident wrong answer is worse — it enters the package as a stated requirement. Translate the
architectural fork into its user-visible consequence and ask about that instead.

**Accepting "make it modern" as a design direction.** It is the absence of a direction, and taking it
at face value guarantees the characterless default: safe palette, safe type, nothing excluded,
nothing memorable. A direction must exclude something. Run §4 instead.

**Proceeding on an unrecorded assumption.** The failure the open-decisions table exists to prevent.
A wrong recorded default costs one conversation; a silent one costs every phase built on top of it
and is usually discovered mid-build. If it is unanswered, it is `D<n>` — always, even when the
default seems obvious. Especially then.

**Asking the user for facts that research could establish.** Prices, API capabilities, regulatory
obligations, what competitors do, platform limits. The user's answer is a guess wearing the clothes
of a fact, and once it is in a document nobody can tell the difference. Research it, cite it with a
date, and bring it back for confirmation of *relevance*, not of truth.

**Producing a fourteen-document package for a product whose scope was never pinned.** The most
expensive failure available here, because it looks like success — a large, well-formatted,
internally consistent package describing a product nobody has decided on. The sizing gate cannot
save you if elicitation never established what is being built. Pin the single job, the identity
model, the money question, and the non-goals *first*; then pick the tier; then write.
