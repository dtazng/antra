# Tasks: Premium Visual Design System

**Input**: Design documents from `specs/007-aurora-design-system/`
**Branch**: `007-aurora-design-system` | **Date**: 2026-03-12

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US6)
- Tests are included per plan.md requirements (widget tests for all new components)

---

## Phase 1: Setup

**Purpose**: Create new directory structure for design system files

- [ ] T001 Create `app/lib/theme/` directory and placeholder `app/lib/theme/.gitkeep`
- [ ] T002 [P] Create `app/lib/test/unit/` directory structure if not present (for `PersonColorService` unit test)

---

## Phase 2: Foundation (Blocking Prerequisites)

**Purpose**: The 6 shared components that ALL user story phases depend on. No screen work can begin until this phase is complete.

**⚠️ CRITICAL**: All user story phases (Phase 3–8) depend on every task in this phase completing first.

- [ ] T003 Create `app/lib/theme/app_theme.dart` with `AntraColors` (8 color constants), `AntraRadius` (card/modal/chip/avatar), and `AntraMotion` (6 durations + 5 curves)
- [ ] T004 [P] Create `app/lib/services/person_color.dart` with `PersonIdentity` model (gradientStart, gradientEnd, paletteIndex) and `PersonColorService.fromId(String personId)` using DJB2 hash % 12 over the curated identity palette
- [ ] T005 [P] Create `app/lib/widgets/aurora_background.dart` with `AuroraVariant` enum (dayView, people, collections, search, review, modal) and `AuroraBackground` widget — `AnimationController` (30s cycle) + `AnimatedBuilder` + `CustomPaint` with sine-wave interpolation; respects `MediaQuery.disableAnimations`
- [ ] T006 [P] Create `app/lib/widgets/glass_surface.dart` with `GlassElevation` enum (flat, card, modal), `GlassStyle` enum (card, bar, modal, chip, hero) with presets, and `GlassSurface` widget — `BackdropFilter → ClipRRect → Container` with luminous border, two-layer `BoxShadow`, and `onTap` scale animation (0.97 over `AntraMotion.tapFeedback`)
- [ ] T007 Create `app/lib/widgets/person_avatar.dart` with `PersonAvatar` widget — gradient `LinearGradient` from `PersonColorService.fromId()`, initials from displayName, optional `showRing` 2px annular gradient border (depends on T003, T004)
- [ ] T008 Create `app/lib/widgets/person_identity_accent.dart` with `AccentStyle` enum (dot, ring, edgeGlow, topBar) and `PersonIdentityAccent` widget — renders the appropriate gradient accent shape via `CustomPaint` (depends on T003, T004)
- [ ] T009 [P] Write unit test for `PersonColorService` in `app/test/unit/person_color_service_test.dart` — verify determinism (same UUID → same `PersonIdentity` across 100 iterations), verify all 12 palette indices reachable, verify no crash on empty string input
- [ ] T010 [P] Write widget test for `AuroraBackground` in `app/test/widgets/aurora_background_test.dart` — verify `CustomPaint` is present, verify static render when `disableAnimations = true`, verify each `AuroraVariant` renders without error
- [ ] T011 [P] Write widget test for `GlassSurface` in `app/test/widgets/glass_surface_test.dart` — verify `BackdropFilter` is in widget tree, verify all 5 `GlassStyle` presets render without error, verify `onTap` callback fires when tapped
- [ ] T012 [P] Write widget test for `PersonAvatar` in `app/test/widgets/person_avatar_test.dart` — verify initials render correctly for single-word and multi-word names, verify `showRing = true` renders a ring, verify gradient background is present
- [ ] T013 [P] Write widget test for `PersonIdentityAccent` in `app/test/widgets/person_identity_accent_test.dart` — verify all 4 `AccentStyle` variants render without error, verify size parameter affects rendered dimensions

**Checkpoint**: Run `flutter test app/test/unit/person_color_service_test.dart app/test/widgets/aurora_background_test.dart app/test/widgets/glass_surface_test.dart app/test/widgets/person_avatar_test.dart app/test/widgets/person_identity_accent_test.dart` — all tests must pass before proceeding

---

## Phase 3: User Story 1 — First Launch Impression (Priority: P1) 🎯 MVP

**Goal**: Day View opens to an aurora gradient scene with glass-styled cards. A new user immediately perceives the app as visually premium and distinct.

**Independent Test**: Launch the app on a fresh install (or simulator reset). Tab 0 (Day View) shows an animated aurora gradient background with at least two glass-styled surfaces (RelationshipBriefing and DailyGoalWidget). No flat white or default Material surfaces are visible. Text is legible. After 5 seconds the background has shifted slightly.

### Implementation for User Story 1

- [ ] T014 [US1] Wrap `DayViewScreen` body with `AuroraBackground(variant: AuroraVariant.dayView)` and set `AppBar.backgroundColor = Colors.transparent`, `elevation = 0` in `app/lib/screens/day_view/day_view_screen.dart`
- [ ] T015 [P] [US1] Replace `RelationshipBriefing` container with `GlassSurface(style: GlassStyle.hero)` — remove existing `Card`/`Container` decoration, preserve inner layout in `app/lib/widgets/relationship_briefing.dart`
- [ ] T016 [P] [US1] Replace `DailyGoalWidget` container with `GlassSurface(style: GlassStyle.card)` — remove existing opaque decoration, style progress bar using `AntraColors` gradient in `app/lib/widgets/daily_goal_widget.dart`
- [ ] T017 [P] [US1] Replace `SuggestionCard` outer container with `GlassSurface(style: GlassStyle.card, onTap: ...)` — remove existing `Card`/`Container` decoration in `app/lib/widgets/suggestion_card.dart`
- [ ] T018 [US1] Style Day View empty state (no suggestions, no briefing) with design system — gradient preserved behind the empty message, soft subdued text using `AntraColors` in `app/lib/screens/day_view/day_view_screen.dart`

**Checkpoint**: Launch app on iPhone 16e simulator. Day View has aurora background, two glass cards, transparent AppBar. Background subtly animates over 30 seconds. All text is readable.

---

## Phase 4: User Story 2 — Glass Card Interactions (Priority: P1)

**Goal**: Suggestion cards expand and collapse with spring animations. Dismissals are soft fades. Tap feedback is immediate and satisfying. Cards feel physically real.

**Independent Test**: Render a suggestion card in collapsed state. Tap it — expansion completes in ≤350ms with a spring curve and no overshoot. Complete an action — the card fades out rather than snapping away. Tap a card briefly — it compresses to 0.97 scale on press and springs back on release.

### Implementation for User Story 2

- [ ] T019 [US2] Add `AnimationController` + `CurvedAnimation` for expand/collapse to `SuggestionCard` — use `AntraMotion.springExpand` (280ms, `easeOutCubic`) to expand and `AntraMotion.springCollapse` (220ms, `easeInCubic`) to collapse; wrap content in `AnimatedSize` or `SizeTransition` in `app/lib/widgets/suggestion_card.dart`
- [ ] T020 [US2] Add fade/scale-down dismiss animation to completed suggestion cards — `FadeTransition` + `SizeTransition` using `AntraMotion.fadeDismiss` (200ms, `easeOut`) when card is removed from the list in `app/lib/widgets/suggestion_card.dart`
- [ ] T021 [US2] Add `PersonIdentityAccent(style: AccentStyle.edgeGlow)` to the left edge of expanded `SuggestionCard` — visible only in expanded state, fades in with `AntraMotion.springExpand` in `app/lib/widgets/suggestion_card.dart`
- [ ] T022 [US2] Verify `GlassSurface.onTap` scale animation (0.97, `AntraMotion.tapFeedback` 100ms) is wired to all `SuggestionCard` tap targets — ensure `GlassSurface` wraps the tappable region and `onTap` is passed through in `app/lib/widgets/suggestion_card.dart`

**Checkpoint**: Tap SuggestionCard — expansion spring animation plays without overshoot. Complete a suggestion — card fades smoothly. Briefly press card — 0.97 scale compression visible. All within timing budgets.

---

## Phase 5: User Story 3 — Person Identity Colors (Priority: P1)

**Goal**: Every person in the app has a consistent gradient identity — same gradient in their avatar, in suggestion card accents, in timeline dots, and on their profile. The user begins to recognise people by color.

**Independent Test**: Open the app with at least 3 contacts present. Check avatar colors in `RelationshipBriefing`, `SuggestionCard` ring accents, and timeline `PersonIdentityAccent` dots. The same person must show the same gradient in all three locations. Two different people must show different gradients.

### Implementation for User Story 3

- [ ] T023 [P] [US3] Replace `CircleAvatar` instances in `RelationshipBriefing` with `PersonAvatar(personId: person.id, displayName: person.name)` — remove all `_avatarColor()` helpers in `app/lib/widgets/relationship_briefing.dart`
- [ ] T024 [P] [US3] Add `PersonIdentityAccent(personId: suggestion.personId, style: AccentStyle.ring, size: 20)` to collapsed `SuggestionCard` header alongside the person name in `app/lib/widgets/suggestion_card.dart`
- [ ] T025 [P] [US3] Replace any `CircleAvatar` in `SuggestionCard` with `PersonAvatar(personId:, displayName:)` in `app/lib/widgets/suggestion_card.dart`
- [ ] T026 [US3] Add `PersonIdentityAccent(personId: interaction.personId, style: AccentStyle.dot, size: 8)` to each `TodayTimeline` entry row — left of the timestamp or person name label in `app/lib/widgets/today_timeline.dart`

**Checkpoint**: Open app with 3+ contacts. Each person's avatar gradient matches the ring in their suggestion card. Timeline dots for that person show the same gradient. All identities are visually distinct from each other.

---

## Phase 6: User Story 4 — Quick Log Glass Surface (Priority: P2)

**Goal**: The Quick Log bar is a premium glass panel. Interaction type buttons provide immediate tactile feedback within 100ms. The person picker sheet rises as a glass modal.

**Independent Test**: Tap Coffee button in QuickLogBar within 100ms the button shows visual feedback (glow, pulse, or compression). The bar background appears translucent and blurred, not flat. Open the person picker — it rises with a spring animation and renders as a glass modal.

### Implementation for User Story 4

- [ ] T027 [US4] Wrap the `QuickLogBar` outer container with `GlassSurface(style: GlassStyle.bar)` — remove existing flat `Container` / `Card` background decoration in `app/lib/widgets/quick_log_bar.dart`
- [ ] T028 [US4] Add per-button tap glow/brightness animation to Quick Log type buttons using `AnimatedContainer` + `AnimationController` with `AntraMotion.tapFeedback` (100ms) — button scales or brightens on press in `app/lib/widgets/quick_log_bar.dart`
- [ ] T029 [US4] Apply `GlassSurface(style: GlassStyle.modal)` to person picker bottom sheet and pass `backgroundColor: Colors.transparent` to `showModalBottomSheet` in `app/lib/widgets/quick_log_bar.dart`
- [ ] T030 [US4] Add smooth reset animation (`AntraMotion.fadeDismiss`, 200ms) when interaction is saved — bar resets to idle state with a fade rather than a layout snap in `app/lib/widgets/quick_log_bar.dart`

**Checkpoint**: Tap Coffee button — visual feedback appears within 100ms. QuickLogBar background is glass (translucent, blurred). Open person picker — glass modal slides up. Log an interaction — bar resets with a fade.

---

## Phase 7: User Story 5 — Timeline as Premium Journal (Priority: P2)

**Goal**: Timeline entries are styled as premium journal fragments. New interactions animate smoothly into the list. The empty state is graceful, not blank.

**Independent Test**: Log an interaction via QuickLogBar while the timeline is visible. Within 500ms the new entry slides in from below with a smooth animation. Each entry shows timestamp, interaction type, and person name in a clearly readable layout with a glass chip treatment. A `PersonIdentityAccent` dot reflects the person's identity.

### Implementation for User Story 5

- [ ] T031 [US5] Restyle each `TodayTimeline` entry row with `GlassSurface(style: GlassStyle.chip)` treatment — translucent background, luminous border, soft shadow around each entry in `app/lib/widgets/today_timeline.dart`
- [ ] T032 [US5] Add slide-insert animation for new timeline entries using `AnimatedList` + `SlideTransition` with `AntraMotion.slideInsert` (350ms, `easeOutBack`) — triggered when a new interaction is added to the provider stream in `app/lib/widgets/today_timeline.dart`
- [ ] T033 [US5] Style timeline empty state with design system — soft centered icon/text with `AntraColors` palette, gradient background preserved behind the empty message in `app/lib/widgets/today_timeline.dart`

**Checkpoint**: Log an interaction — new entry slides into timeline within 500ms with smooth `easeOutBack` animation. Each entry has glass chip styling. Empty state shows soft, styled placeholder (not blank).

---

## Phase 8: User Story 6 — Full App Design Coverage (Priority: P3)

**Goal**: Every major screen and modal uses the design system — aurora gradient, glass surfaces, identity colors. No flat white Material defaults visible anywhere at the top level.

**Independent Test**: Navigate all 5 main tabs. Each tab displays: (1) a gradient background, (2) at least one glass-styled surface, (3) no flat white surfaces at top level. Open any modal — it renders as a glass sheet, not a white bottom sheet. Open a person profile — identity gradient is featured prominently.

### Implementation for User Story 6

- [ ] T034 [P] [US6] Restyle `PeopleScreen` — wrap body with `AuroraBackground(variant: AuroraVariant.people)`, make AppBar transparent, replace person list tile avatars with `PersonAvatar`, restyle search bar as `GlassSurface(style: GlassStyle.chip)` in `app/lib/screens/people/people_screen.dart`
- [ ] T035 [P] [US6] Restyle `PersonProfileScreen` — wrap body with `AuroraBackground(variant: AuroraVariant.people)`, make AppBar transparent, use `PersonAvatar(showRing: true)` as hero header avatar, wrap interaction history cards with `GlassSurface(style: GlassStyle.card)`, add `PersonIdentityAccent(style: AccentStyle.topBar)` to the profile header in `app/lib/screens/people/person_profile_screen.dart`
- [ ] T036 [P] [US6] Apply `GlassSurface(style: GlassStyle.modal)` wrapper to `PersonPickerSheet` and pass `backgroundColor: Colors.transparent` on all `showModalBottomSheet` calls that open it in `app/lib/screens/people/person_picker_sheet.dart`
- [ ] T037 [P] [US6] Apply `GlassSurface(style: GlassStyle.modal)` wrapper to `CreatePersonSheet` and pass `backgroundColor: Colors.transparent` on all `showModalBottomSheet` calls that open it in `app/lib/screens/people/create_person_sheet.dart`
- [ ] T038 [P] [US6] Restyle `CollectionsScreen` — wrap body with `AuroraBackground(variant: AuroraVariant.collections)`, make AppBar transparent, wrap each collection card with `GlassSurface(style: GlassStyle.card)` in `app/lib/screens/collections/collections_screen.dart`
- [ ] T039 [P] [US6] Restyle `SearchScreen` — wrap body with `AuroraBackground(variant: AuroraVariant.search)`, make AppBar transparent, restyle search input field as `GlassSurface(style: GlassStyle.chip)`, restyle result items with `GlassSurface(style: GlassStyle.card)` in `app/lib/screens/search/search_screen.dart`
- [ ] T040 [P] [US6] Restyle `ReviewScreen` — wrap body with `AuroraBackground(variant: AuroraVariant.review)`, make AppBar transparent, wrap each review option card with `GlassSurface(style: GlassStyle.card)` in `app/lib/screens/review/review_screen.dart`
- [ ] T041 [P] [US6] Restyle `WeeklyReviewScreen` — wrap body with `AuroraBackground(variant: AuroraVariant.review)`, make AppBar transparent, wrap task cards and summary surfaces with `GlassSurface(style: GlassStyle.card)` in `app/lib/screens/review/weekly_review_screen.dart`
- [ ] T042 [US6] Restyle `DailyLogScreen` — wrap body with `AuroraBackground(variant: AuroraVariant.dayView)`, make AppBar transparent, replace `CircleAvatar` on bullet items that reference a person with `PersonAvatar`, restyle empty state in `app/lib/screens/daily_log/daily_log_screen.dart`

**Checkpoint**: Navigate all 5 tabs — each has gradient background, at least one glass surface, no flat white defaults. Open PersonPickerSheet and CreatePersonSheet — both render as glass modals. Open a person profile — identity gradient is prominent in the header.

---

## Phase 9: Polish & Validation

**Purpose**: Analysis, test run, and manual verification across all 6 user stories

- [ ] T043 [P] Run `flutter analyze` from `app/` and fix all new analyzer warnings introduced by files created or modified in this feature — zero new warnings allowed
- [ ] T044 [P] Run `flutter test` from `app/` — confirm all 5 foundation tests (T009–T013) and any existing tests pass with zero failures
- [ ] T045 [P] Verify WCAG AA contrast ratio (≥4.5:1) on all glass and gradient surfaces via visual inspection on the iPhone 16e simulator — check against all 6 `AuroraVariant` backgrounds and all 5 `GlassStyle` presets
- [ ] T046 Manual verification on iPhone 16e simulator — navigate all 6 user story flows, toggle Reduce Motion on/off (aurora animation pauses/resumes), verify 60fps smoothness on card expand and slide-insert animations

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundation (Phase 2)**: Depends on Phase 1 — **BLOCKS all user story phases**
- **US1 (Phase 3)**: Depends on Foundation (T003–T008 complete) — no dependency on US2/US3
- **US2 (Phase 4)**: Depends on Foundation + US1 (SuggestionCard glass base from T017) — builds on T017
- **US3 (Phase 5)**: Depends on Foundation (T007, T008 complete) — can run in parallel with US2
- **US4 (Phase 6)**: Depends on Foundation — independent of US1/US2/US3
- **US5 (Phase 7)**: Depends on Foundation + US3 (PersonIdentityAccent from T026) — builds on T026
- **US6 (Phase 8)**: Depends on Foundation + all P1 stories (US1, US2, US3) — requires components established in Phases 3–5
- **Polish (Phase 9)**: Depends on all desired user stories being complete

### User Story Dependencies

- **US1 (P1)**: Can start immediately after Foundation — no dependency on other stories
- **US2 (P1)**: Depends on US1 (T017 — SuggestionCard must have GlassSurface base) — otherwise independent
- **US3 (P1)**: Can start immediately after Foundation — can run in parallel with US2
- **US4 (P2)**: Can start immediately after Foundation — fully independent of US1/US2/US3
- **US5 (P2)**: Depends on US3 (T026 — PersonIdentityAccent dot on timeline) — otherwise independent of US4
- **US6 (P3)**: Depends on US1 (aurora+glass patterns established), US3 (PersonAvatar available), and Foundation

### Parallel Opportunities Within Foundation (Phase 2)

Tasks T004, T005, T006 can run in parallel (different files):
- T004: `person_color.dart`
- T005: `aurora_background.dart`
- T006: `glass_surface.dart`

Tasks T009–T013 can all run in parallel (different test files):
- T009: `person_color_service_test.dart`
- T010: `aurora_background_test.dart`
- T011: `glass_surface_test.dart`
- T012: `person_avatar_test.dart`
- T013: `person_identity_accent_test.dart`

### Parallel Opportunities Within US1 (Phase 3)

Tasks T015, T016, T017 can run in parallel (different widget files):
- T015: `relationship_briefing.dart`
- T016: `daily_goal_widget.dart`
- T017: `suggestion_card.dart`

### Parallel Opportunities Within US3 (Phase 5)

Tasks T023, T024, T025 can run in parallel (same file but distinct changes; coordinate carefully):
- T023: `relationship_briefing.dart` — different file, fully parallel
- T024: `suggestion_card.dart` — adding ring accent (different from T025's avatar replacement)
- T025: `suggestion_card.dart` — replacing CircleAvatar (**NOTE**: T024 and T025 touch the same file; coordinate sequentially if working alone, or split regions carefully in a team)

### Parallel Opportunities Within US6 (Phase 8)

Tasks T034–T041 can all run in parallel (different screen files):
- T034: `people_screen.dart`
- T035: `person_profile_screen.dart`
- T036: `person_picker_sheet.dart`
- T037: `create_person_sheet.dart`
- T038: `collections_screen.dart`
- T039: `search_screen.dart`
- T040: `review_screen.dart`
- T041: `weekly_review_screen.dart`

---

## Implementation Strategy

### MVP First (US1 Only — Day View First Launch)

1. Complete Phase 2: Foundation (T003–T013) — all 6 components + tests
2. Complete Phase 3: US1 (T014–T018) — Day View with aurora + glass
3. **STOP and VALIDATE**: Launch app on simulator, confirm aurora background + glass cards visible
4. Demo/screenshot ready

### Incremental Delivery

1. Foundation → US1 (P1) → Day View premium first impression (MVP)
2. Add US2 (P1) → Glass card spring interactions → interactions feel premium
3. Add US3 (P1) → Person identity colors throughout Day View → people are visually distinct
4. Add US4 (P2) → Quick Log glass surface → daily logging feels premium
5. Add US5 (P2) → Timeline as premium journal → timeline styled and animated
6. Add US6 (P3) → Full app coverage → every screen part of the system
7. Polish → analyze + test + contrast check + simulator verification

### Parallel Team Strategy (3 developers after Foundation)

Once Foundation (Phase 2) is complete:
- Developer A: US1 (Day View aurora + glass) → US2 (card animations)
- Developer B: US3 (person identity colors) → US5 (timeline journal)
- Developer C: US4 (quick log glass) → US6 screens (people, collections, search, review)

---

## Summary

| Phase | Tasks | User Story | Priority |
| --- | --- | --- | --- |
| Phase 1: Setup | T001–T002 | — | — |
| Phase 2: Foundation | T003–T013 | — (blocking) | — |
| Phase 3: US1 First Launch | T014–T018 | US1 | P1 |
| Phase 4: US2 Card Interactions | T019–T022 | US2 | P1 |
| Phase 5: US3 Person Identity | T023–T026 | US3 | P1 |
| Phase 6: US4 Quick Log | T027–T030 | US4 | P2 |
| Phase 7: US5 Timeline Journal | T031–T033 | US5 | P2 |
| Phase 8: US6 Full Coverage | T034–T042 | US6 | P3 |
| Phase 9: Polish | T043–T046 | — | — |
| **Total** | **46 tasks** | **6 stories** | — |

### Tasks per user story

| Story | Count | Description |
| --- | --- | --- |
| US1 | 5 | Day View aurora + glass surfaces |
| US2 | 4 | Spring animations + dismiss + tap feedback |
| US3 | 4 | PersonAvatar + PersonIdentityAccent rollout |
| US4 | 4 | QuickLogBar glass + button feedback |
| US5 | 3 | Timeline styling + slide animation + empty state |
| US6 | 9 | All remaining screens + modals |
| Foundation | 11 | 6 components + 5 test files |
| Setup + Polish | 6 | Setup directories + analyze/test/verify |

### Parallel opportunities identified: 7 groups

1. Foundation component creation (T004, T005, T006)
2. Foundation test writing (T009–T013)
3. US1 widget restyling (T015, T016, T017)
4. US3 PersonAvatar/Accent rollout (T023, T025 separate files)
5. US6 screen restyling (T034–T041, 8 different files)
6. Polish tasks (T043, T044, T045)
7. US1/US3/US4 can run in parallel once Foundation completes (different widgets)

### Suggested MVP scope: Phase 2 (Foundation) + Phase 3 (US1)

Completing T003–T018 delivers the core visual identity: aurora background, glass surfaces, and premium first impression on Day View — fully functional and demoable.
