# Implementation Plan: Premium Visual Design System

**Branch**: `007-aurora-design-system` | **Date**: 2026-03-12 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/007-aurora-design-system/spec.md`

## Summary

Build a premium visual identity for Antra — aurora gradient backgrounds, frosted glass card surfaces, person identity colors, and a premium motion system — applied across the Day View and all major app screens. No new database schema or dependencies required. All techniques use Flutter's native rendering primitives (`BackdropFilter`, `CustomPaint`, `AnimationController`). Implementation produces six new shared components and restyled versions of all five main tabs and their modal sheets.

## Technical Context

**Language/Version**: Dart 3.3+ / Flutter 3.19+
**Primary Dependencies**: flutter_riverpod 2.5 (existing), drift 2.18 (existing) — **no new packages**
**Storage**: N/A — no DB changes; design tokens are compile-time constants
**Testing**: flutter_test (existing) — widget tests for all new components
**Target Platform**: iOS primary (iPhone 12+); Android parity expected
**Project Type**: Mobile app (cross-platform Flutter)
**Performance Goals**: 60 fps on all animated surfaces; aurora background cycle ≥ 30s; card animations ≤ 350ms; tap feedback ≤ 100ms
**Constraints**: No new pub dependencies; WCAG AA contrast (4.5:1) on all surfaces; Reduce Motion compliance; graceful `BackdropFilter` degradation
**Scale/Scope**: ~15 screens restyled; 6 new shared components; ~1 new service; ~1 new theme file

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I — Code Quality ✅

- **Readability**: All design tokens extracted to `AntraTheme` (named constants, not magic numbers). Glass surface logic encapsulated in `GlassSurface` widget — callers have no knowledge of `BackdropFilter` internals.
- **Single responsibility**: Each new file has one concern: `aurora_background.dart` (background), `glass_surface.dart` (surface), `person_color.dart` (identity derivation), `app_theme.dart` (tokens).
- **No dead code**: `CircleAvatar` instances replaced (not duplicated). Existing `_avatarColor()` helpers removed when `PersonAvatar` is adopted.
- **Consistency**: All screens use the same `GlassSurface` / `AuroraBackground` components — no one-off glass implementations.
- **Error handling at boundaries**: `PersonColorService.fromId()` accepts any non-null string — no error case. `AuroraBackground` never throws — animation failures fall back to a static gradient.

### Principle II — Testing Standards ✅

- Every public-facing component (US1–US6 acceptance scenarios) has at least one widget test covering the happy path and one edge case.
- Tests for `PersonColorService` verify determinism: same UUID → same `PersonIdentity` across 100 iterations.
- Tests for `AuroraBackground` verify static render when `disableAnimations = true`.
- Tests for `GlassSurface` verify `BackdropFilter` is present in the widget tree (blur enabled) and that tap feedback fires within tolerance.

### Principle III — UX Consistency ✅

- **Capture speed**: `GlassSurface` and `AuroraBackground` are purely visual — they add no async operations to the critical capture path. Bullet save latency is unchanged.
- **Calm by default**: Aurora animation is extremely slow (30s+ cycle), no pulsing badges, no attention-seeking motion.
- **Consistent affordances**: All glass cards use the same tap feedback animation. Person identity colors appear identically in every context.
- **Graceful empty states**: All empty states are restyled to match the design system — gradient background preserved, soft icon/text maintained.
- **Offline-transparent**: Design system has zero dependency on network state.

### Principle IV — Performance ✅

- `AuroraBackground` uses `CustomPaint` — single paint pass, no widget rebuilds on animation frames. The `child` is passed unchanged via `AnimatedBuilder`.
- `BackdropFilter` is GPU-bound on iOS Metal; iPhone 12+ handles one filter per scroll viewport at 60 fps. `RepaintBoundary` wraps each glass card to isolate repaint regions.
- Do NOT stack multiple `BackdropFilter` instances without `RepaintBoundary` isolation.
- The aurora animation controller uses `vsync: this` (no-op when off-screen) — no battery impact when the screen is not visible.
- Memory budget: each `BackdropFilter` adds ~2–5 MB GPU texture per viewport — within budget on target devices.

**No constitution violations. Complexity Tracking table not required.**

## Project Structure

### Documentation (this feature)

```text
specs/007-aurora-design-system/
├── plan.md              # This file
├── research.md          # Phase 0 output ✅
├── data-model.md        # Phase 1 output ✅
├── quickstart.md        # Phase 1 output ✅
├── contracts/
│   └── ui-contracts.md  # Phase 1 output ✅
└── tasks.md             # Phase 2 output (/speckit.tasks — NOT yet created)
```

### Source Code (new files this feature)

```text
app/lib/
├── theme/
│   └── app_theme.dart              # NEW: AntraColors, AntraRadius, AntraMotion tokens
├── services/
│   └── person_color.dart           # NEW: PersonColorService + PersonIdentity model
├── widgets/
│   ├── aurora_background.dart      # NEW: AuroraBackground widget + AuroraVariant enum
│   ├── glass_surface.dart          # NEW: GlassSurface widget + GlassStyle + GlassElevation
│   ├── person_avatar.dart          # NEW: PersonAvatar (replaces CircleAvatar)
│   └── person_identity_accent.dart # NEW: PersonIdentityAccent (dot, ring, edgeGlow, topBar)
└── screens/                        # MODIFIED: all major screens — AuroraBackground wrap + GlassSurface restyle
    ├── day_view/
    │   └── day_view_screen.dart    # MODIFIED
    ├── people/
    │   ├── people_screen.dart      # MODIFIED
    │   ├── person_profile_screen.dart # MODIFIED
    │   ├── person_picker_sheet.dart # MODIFIED
    │   └── create_person_sheet.dart # MODIFIED
    ├── collections/
    │   └── collections_screen.dart # MODIFIED
    ├── search/
    │   └── search_screen.dart      # MODIFIED
    ├── review/
    │   ├── review_screen.dart      # MODIFIED
    │   └── weekly_review_screen.dart # MODIFIED
    └── daily_log/
        └── daily_log_screen.dart   # MODIFIED (still used for past-day navigation)

app/test/
└── widgets/
    ├── aurora_background_test.dart  # NEW
    ├── glass_surface_test.dart      # NEW
    ├── person_avatar_test.dart      # NEW
    └── person_identity_accent_test.dart # NEW

app/test/
└── unit/
    └── person_color_service_test.dart # NEW
```

**Structure Decision**: All new code is additive — new files under `theme/`, `services/`, and `widgets/`. Existing screens are modified in-place (no new routes, no new navigation). The existing Material 3 seed-color theme is preserved; aurora tokens layer on top.

---

## Phase 0: Research ✅ Complete

See [research.md](research.md).

**Key decisions resolved**:

| Decision | Resolution |
| --- | --- |
| Glass technique | `BackdropFilter(blur 12–15) → ClipRRect → Container(opacity 0.12–0.18)` |
| Aurora animation | `AnimationController` + `AnimatedBuilder` + `CustomPaint` + sine-wave interpolation, 30s+ cycle |
| Person identity | DJB2 hash of UUID % 12-pair curated gradient palette |
| Motion curves | Flutter native curves — no animation packages |
| Theme architecture | Extend existing `_buildTheme()` with `AntraTheme` token file; no theme replacement |
| New dependencies | None — uses `dart:math`, `dart:convert`, `dart:ui` (already in Flutter SDK) |

---

## Phase 1: Design & Contracts ✅ Complete

**Artifacts generated**:

- [data-model.md](data-model.md) — 6 entities: `AntraColors`, `AntraRadius`, `AntraMotion`, `PersonIdentity`, `AuroraVariant`, `GlassStyle`
- [contracts/ui-contracts.md](contracts/ui-contracts.md) — 6 component contracts: `AuroraBackground`, `GlassSurface`, `PersonAvatar`, `PersonIdentityAccent`, `PersonColorService`, `AntraTheme`
- [quickstart.md](quickstart.md) — 8 integration scenarios + per-screen migration checklist

---

## Implementation Phases (for `/speckit.tasks`)

The following is a high-level implementation order. Detailed tasks are generated by `/speckit.tasks`.

### Phase 2: Foundation (Blocking — all screens depend on this)

1. Create `app/lib/theme/app_theme.dart` with `AntraColors`, `AntraRadius`, `AntraMotion`
2. Create `app/lib/services/person_color.dart` with `PersonColorService` + `PersonIdentity`
3. Create `app/lib/widgets/aurora_background.dart` with `AuroraBackground` + `AuroraVariant`
4. Create `app/lib/widgets/glass_surface.dart` with `GlassSurface` + `GlassStyle` + `GlassElevation`
5. Create `app/lib/widgets/person_avatar.dart` replacing `CircleAvatar`
6. Create `app/lib/widgets/person_identity_accent.dart` with `AccentStyle` variants
7. Write unit and widget tests for all 6 foundation components

### Phase 3: Day View (MVP — highest visual impact, P1 stories US1–US3)

1. Restyle `DayViewScreen` — `AuroraBackground(dayView)`, transparent AppBar
2. Restyle `SuggestionCard` — `GlassSurface(card)`, spring expand/collapse, `PersonIdentityAccent(ring)`
3. Restyle `RelationshipBriefing` — `GlassSurface(hero)`, `PersonAvatar` in briefing rows
4. Restyle `DailyGoalWidget` — `GlassSurface(card)`, progress bar styled against gradient
5. Restyle `TodayInteractionTimeline` — `GlassSurface(chip)` per entry, `PersonIdentityAccent(dot)`, slide-insert animation
6. Restyle `QuickLogBar` — `GlassSurface(bar)`, tap glow on type buttons, glass confirm row

### Phase 4: People & Profiles (US3 person identity, US6 coverage)

1. Restyle `PeopleScreen` — `AuroraBackground(people)`, person list tiles with `PersonAvatar`
2. Restyle `PersonProfileScreen` — `AuroraBackground(people)`, `PersonAvatar(showRing: true)` hero header, `GlassSurface` for interaction cards
3. Restyle `PersonPickerSheet` — `GlassSurface(modal)`, transparent sheet background
4. Restyle `CreatePersonSheet` / `EditPersonSheet` — `GlassSurface(modal)`

### Phase 5: Remaining Screens (US6 full coverage, P3)

1. Restyle `CollectionsScreen` — `AuroraBackground(collections)`, collection cards as `GlassSurface`
2. Restyle `SearchScreen` — `AuroraBackground(search)`, search bar as `GlassSurface(chip)`
3. Restyle `ReviewScreen` + `WeeklyReviewScreen` — `AuroraBackground(review)`, task cards as `GlassSurface`
4. Restyle `DailyLogScreen` — `AuroraBackground(dayView)`, empty state, bullet items with `PersonAvatar`

### Phase 6: Polish & Validation

1. Run `flutter analyze` — fix all new warnings
2. Run full `flutter test` — confirm all tests pass, zero failures
3. Verify WCAG AA contrast on all glass/gradient surfaces using visual inspection + tool
4. Manual verification on iPhone 16e simulator — all 6 user stories, Reduce Motion toggle, animation smoothness
