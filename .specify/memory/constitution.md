<!--
SYNC IMPACT REPORT
==================
Version change: (none → initial) → 1.0.0
Modified principles: N/A — initial ratification; all principles are new
Added sections:
  - Core Principles (I. Code Quality, II. Testing Standards, III. UX Consistency, IV. Performance)
  - Privacy & Data Integrity Standards
  - Development Workflow
  - Governance
Removed sections: N/A
Templates reviewed:
  - .specify/templates/plan-template.md     ✅ no changes required; Constitution Check section populated dynamically per feature by /speckit.plan
  - .specify/templates/spec-template.md     ✅ no changes required; existing mandatory sections align with all four principles
  - .specify/templates/tasks-template.md    ✅ no changes required; optional-test model is consistent with Principle II
Deferred items: None — all placeholders resolved
-->

# Antra Log Constitution

## Core Principles

### I. Code Quality (NON-NEGOTIABLE)

Every piece of code merged into the main branch MUST meet the following standards:

- **Readability first**: Code MUST be written for the next reader, not the computer. Names MUST
  express intent without requiring comments to decode them.
- **Single responsibility**: Each function, class, or module MUST have one clear reason to change.
  Cross-cutting logic MUST be extracted into shared utilities rather than duplicated.
- **No dead code**: Unused variables, unreachable branches, commented-out blocks, and obsolete
  flags MUST be removed before merging. Backward-compatibility shims are not permitted unless
  explicitly approved via the governance amendment process.
- **Consistency over cleverness**: Platform idioms and existing project conventions MUST be
  followed. Non-standard patterns require written justification in the PR description.
- **Error handling at boundaries**: Errors MUST be handled at system entry points (user input,
  external data, OS events). Internal code MUST NOT defensively guard against invariants that
  the architecture already guarantees.

*Rationale*: Antra Log is a long-lived personal app. Readable, consistent, debt-free code is the
primary enabler of a small team moving quickly with confidence over months and years.

### II. Testing Standards

Testing is required where it provides durable value; it is not required as a ritual.

- **Coverage scope**: Every public-facing behavior described in a feature spec's Acceptance
  Scenarios MUST have at least one automated test covering the happy path and at least one
  covering a defined edge case.
- **Test-before-implement (when explicitly requested)**: When a spec or task explicitly requests
  tests, those tests MUST be written and confirmed to fail before implementation begins. The
  red-green-refactor cycle MUST be observable in the commit history.
- **Independence**: Tests MUST NOT depend on execution order. Each test MUST set up its own
  state and clean up after itself.
- **Meaningful assertions**: Tests MUST assert on outcomes observable by users or dependent
  systems — not on internal implementation details such as call counts or private state.
- **No flaky tests**: A test that fails intermittently MUST be fixed or removed immediately.
  Flaky tests are treated as P1 bugs.
- **Offline behavior**: All features that interact with local storage or operate offline MUST
  have tests that exercise the offline path explicitly.

*Rationale*: Undetected regressions in data persistence, sync, or encryption are unacceptable
for an app users trust with private, personal data. Tests protect data integrity and enable
safe, fast iteration.

### III. User Experience Consistency

Every screen, interaction, and feedback pattern MUST follow a unified and predictable system.

- **Capture speed is sacred**: Any interaction on the critical path (launch → log a bullet)
  MUST complete within 1 second of user intent. No loading state or blocking UI element may
  appear on this path.
- **Calm by default**: The app MUST NOT surface unsolicited notifications, badges, streaks,
  scores, or productivity pressure. All prompts MUST be passive and dismissible without penalty.
- **Consistent affordances**: Interactive elements of the same type MUST behave identically
  across all screens. A gesture learned in the Daily Log MUST behave the same in Collections
  and People Profiles.
- **Graceful empty states**: Every list, timeline, or collection view MUST display a meaningful
  empty state guiding the first action — never a blank screen or generic placeholder.
- **Destructive actions require confirmation**: Any action that permanently removes user data
  MUST require explicit confirmation and MUST offer a brief undo window before permanent removal.
- **Offline-transparent UX**: The app MUST behave identically in offline and online states for
  all local-first features. Sync status MUST be surfaced passively and MUST NOT block any action.

*Rationale*: Antra Log's core promise is calm, intentional capture. Inconsistency and friction
erode user trust. A user who cannot rely on predictable behavior will stop logging.

### IV. Performance Requirements

Performance targets on the critical user path are non-negotiable.

- **App launch to ready**: The app MUST be interactive and displaying today's daily log within
  2 seconds of cold launch on a supported device.
- **Capture latency**: A bullet MUST be saved and visible in the log within 500 milliseconds
  of the user confirming the entry.
- **Search results**: Full-text search across up to 10,000 entries MUST return results within
  2 seconds.
- **Scroll performance**: All list and timeline views MUST maintain 60 fps without visible jank
  on supported devices.
- **Sync transparency**: Background sync MUST NOT cause any perceptible UI slowdown, frame drop,
  or input delay.
- **Memory budget**: The app MUST NOT exceed 150 MB of memory during typical journaling sessions.
  Background sync MUST NOT wake the app into active memory state unnecessarily.
- **Battery impact**: Background sync MUST use the platform's low-priority background scheduling
  APIs and MUST NOT prevent the device from entering low-power states.

*Rationale*: The promise of instant capture is meaningless if the app itself is slow. Performance
is a feature, not an afterthought — users will abandon a journaling tool that feels heavy.

## Privacy & Data Integrity Standards

These standards apply to all features and are not negotiable for any tier.

- All user data MUST be encrypted at rest on-device using platform-standard encryption.
  This applies to both Free and Pro tiers.
- The sync layer MUST treat the local database as the source of truth. No remote write MUST
  ever silently overwrite unsynced local data.
- Sync conflicts MUST produce explicit, user-recoverable copies. Silent data loss is a P0
  critical bug.
- End-to-end encryption (Pro tier) MUST ensure the sync server stores only ciphertext. The
  server MUST have zero access to encryption keys.
- The app MUST NOT collect analytics, telemetry, or behavioral data without explicit, informed
  opt-in consent.
- No user data MUST ever be transmitted to third-party services outside the sync infrastructure
  without the user's explicit knowledge and consent.

## Development Workflow

- **Spec-first**: No feature implementation begins without a completed, validated `spec.md`.
  The spec MUST be reviewed before planning (`/speckit.plan`) begins.
- **Branch per feature**: Every feature MUST be developed on its own numbered branch following
  the `NNN-feature-name` convention. No direct commits to `main`.
- **Constitution Check in plans**: Every `plan.md` MUST include a Constitution Check section
  verifying the design against Principles I–IV and Privacy & Data Integrity Standards before
  implementation begins.
- **Complexity justification**: Any design that violates a principle MUST be documented in the
  plan's Complexity Tracking table with a written justification and evidence that simpler
  alternatives were evaluated and rejected.
- **Review before merge**: All code changes MUST be reviewed for compliance with this
  constitution before merging. Reviewers MUST explicitly check Principles I–IV.

## Governance

This constitution supersedes all other development guidelines, conventions, and informal
agreements. In the event of conflict, this document takes precedence.

**Amendment procedure**:
1. Proposed amendments are submitted as a PR modifying this file.
2. The PR description MUST state the version bump type (MAJOR/MINOR/PATCH) with rationale:
   - MAJOR: Removing or fundamentally redefining an existing principle.
   - MINOR: Adding a new principle or section, or materially expanding guidance.
   - PATCH: Clarifications, wording improvements, typo fixes.
3. All amendments MUST update the Sync Impact Report comment at the top of this file.
4. After ratification, all dependent templates MUST be reviewed for consistency within one
   working session.

**Compliance review**: Every PR that introduces or modifies a feature MUST be reviewed against
this constitution. Compliance is not optional and is not subject to deadline pressure.

**Version policy**: Semantic versioning (MAJOR.MINOR.PATCH) applies to this document.
The version line below MUST be updated with every ratified amendment.

**Version**: 1.0.0 | **Ratified**: 2026-03-09 | **Last Amended**: 2026-03-09
