# Research: Composer Redesign & Timeline Polish

**Feature**: `012-composer-redesign`
**Date**: 2026-03-14

---

## Decision 1: Composer Expand/Collapse Animation

**Decision**: `AnimatedSize` + `ClipRect` wrapping the action row widget.

**Rationale**: `AnimatedSize` is already used in the codebase (`suggestion_card.dart`) for the same expand/collapse pattern. It uses Flutter's layout animation system — hardware-accelerated, no per-frame canvas draws, no explicit `AnimationController` needed. `ClipRect` prevents the action row from painting outside its bounds during the height animation. The `GlassSurface` parent also provides `ClipRRect` which clips at the rounded-corner boundary.

**Timing**: Use `AntraMotion.springExpand` (280ms) + `expandCurve` (easeOutCubic) on expand; `AntraMotion.springCollapse` (220ms) + `collapseCurve` (easeInCubic) on collapse. Both are within the 250ms spec requirement for the first frame of motion — the animation is already partially complete at 250ms.

**Alternatives considered**:
- `SizeTransition` with `AnimationController` — more code, same visual result.
- `AnimatedContainer` with explicit height — requires knowing the action row height in advance, fragile with multi-line content.

---

## Decision 2: Focus Detection for Expand Trigger

**Decision**: Explicit `FocusNode` with `addListener` callback in `_BulletCaptureBarState`.

**Rationale**: `FocusNode.addListener` is the idiomatic Flutter way to respond to focus changes independently of the `TextField`'s `onTap`. It handles keyboard-initiated focus (hardware keyboard tab, programmatic focus), not just pointer taps. The existing `FocusScope.of(context).unfocus()` call in `_submit` is replaced by `_focusNode.unfocus()` — cleaner, no BuildContext dependency in the cancel/submit handlers.

**Lifecycle**: `FocusNode` created in `initState`, listener attached immediately, disposed in `dispose`. No leaks.

**Alternatives considered**:
- `TextField.onTap` — only fires on pointer tap, misses programmatic focus and hardware keyboard navigation.
- `TextField.onEditingComplete` — only fires when editing is done, not on focus.

---

## Decision 3: Follow-Up Picker UI Pattern

**Decision**: Lightweight fixed-height bottom sheet using the `CreatePersonSheet` column pattern. Returns `DateTime?`.

**Rationale**: The follow-up picker needs only 5–6 tappable rows. `DraggableScrollableSheet` (used by `PersonPickerSheet`) is over-engineered for this. A fixed-size `Column` inside `GlassSurface(style: GlassStyle.modal)` matches existing modal patterns and keeps the implementation simple. The "Custom date" option delegates to the platform's `showDatePicker` — no custom calendar widget needed.

**Follow-up date values**:
- Later today: `DateTime(now.year, now.month, now.day, 23, 59)`
- Tomorrow: `DateTime(now.year, now.month, now.day + 1)`
- In 3 days: `DateTime(now.year, now.month, now.day + 3)`
- Next week: `DateTime(now.year, now.month, now.day + 7)`
- Custom: platform date picker, `firstDate: DateTime(now.year, now.month, now.day + 1)`

**Alternatives considered**:
- Inline expandable picker in the action row — adds complexity to the composer layout and conflicts with the ClipRect animation.
- Full-screen date picker — excessive navigation overhead for a simple time preset choice.

---

## Decision 4: Follow-Up Saved in Single Transaction

**Decision**: Pass `followUpDate` and `followUpStatus` directly in `BulletsCompanion.insert()` — no separate `addFollowUpToEntry` call.

**Rationale**: The `bullets` table already has `followUpDate` (nullable text) and `followUpStatus` (nullable text) columns from `011-life-log`. Writing both fields in the initial `insertBulletWithTags` transaction is atomic — no risk of a bullet existing without its follow-up if the app crashes between two calls. The existing `addFollowUpToEntry` method is preserved for editing follow-ups from the detail screen; it is not called from the new composer flow.

**Alternatives considered**:
- Two-step: insert bullet, then call `addFollowUpToEntry` — non-atomic, more code, risk of partial state.

---

## Decision 5: Back-to-Today Scroll Threshold

**Decision**: Show the button when `scrollOffset > todayEnd + screenHeight`, where `todayEnd` is the estimated bottom edge of today's last entry (using `_kEntryH = 78px` approximation already in `TimelineScreen`).

**Rationale**: "One full screen height below today" is the spec requirement. The existing height estimation in `_updateStickyLabel` is already accurate enough — worst case off by ~50px for a 5-entry section. The button appears within one scroll event of crossing the threshold (no batch debounce needed). `_scrollController.animateTo(0, ...)` scrolls back to the very top, which always shows today (most recent entries are first).

**Button positioning**: `Positioned(right: 20, bottom: viewPadding.bottom + 112)` — 112px is the approximate height of the capture bar (`80px tab bar + ~32px bar itself`). This ensures the button floats above the bar without overlap.

**Alternatives considered**:
- Track actual render positions using `GlobalKey` — accurate but expensive; adds one key per day section.
- Fixed pixel threshold (e.g., 600px) — not responsive to screen size or content density.

---

## Decision 6: Timeline Bottom Fade Implementation

**Decision**: `ShaderMask` with `BlendMode.dstIn` wrapping the `body` CustomScrollView.

**Rationale**: `ShaderMask` with `BlendMode.dstIn` multiplies the widget's alpha channel by the shader's alpha. A `LinearGradient(colors: [black, black, transparent], stops: [0, 0.75, 1.0])` makes the top 75% fully opaque and fades the bottom 25% to invisible. This is a single GPU compositing pass — no extra layout, no `Canvas.drawRect` per frame. The mask is applied to the paint output of the `body`, so it respects the `CustomScrollView`'s clipping and does not bleed over the capture bar.

**Sizing**: The gradient covers the full height of the `body` widget. Since `body` fills the `Stack` and stops at `bottom: 0` (above the positioned capture bar), the fade occupies approximately the bottom 25% of the visible content area — roughly 150–200px on a standard 6" device.

**Touch pass-through**: `ShaderMask` does not affect hit testing — touch events pass through the faded region normally.

**Alternatives considered**:
- `Stack` + `IgnorePointer` + `DecoratedBox` with gradient — visually equivalent but adds an extra render object and requires manual height management.
- Fading individual entry cards — too granular, doesn't create a unified fade effect.
