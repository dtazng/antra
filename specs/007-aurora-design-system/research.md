# Research: Premium Visual Design System

**Feature**: 007-aurora-design-system
**Date**: 2026-03-12

## Decision 1: Glass Surface Implementation

**Decision**: Use `BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12))` wrapping `ClipRRect` wrapping `Container(color: white/black with 0.12–0.18 opacity)`.

**Rationale**: This is the canonical Flutter glassmorphism widget tree. The order matters:
1. `BackdropFilter` captures and blurs everything rendered behind it in the compositing tree.
2. `ClipRRect` clips both the blurred backdrop and the translucent tint to rounded corners.
3. `Container` with low-opacity tint adds the glass "body" that separates the card from the background.

A luminous border is added via `BoxDecoration` on the `Container`: `Border.all(color: white.withOpacity(0.15–0.2), width: 1)`.

**Concrete values**:
- Blur sigma: 12–15 (tasteful, not overpowering; GPU-bound on iOS Metal, smooth on iPhone 12+)
- Tint opacity: 0.12–0.18 for dark mode glass (white tint), 0.08–0.12 for lighter surfaces
- Corner radius: 20–24px for cards, 28–32px for modals, 16px for small chips
- Shadows: two-layer diffuse (`BoxShadow`) — outer ambient (blur 32, opacity 0.25) + inner fill (blur 8, opacity 0.10)

**Degradation strategy**: iPhone 12+ (the target device floor) handles one `BackdropFilter` per scroll viewport smoothly. Multiple overlapping `BackdropFilter` instances (e.g., 3+ stacked cards) can cause frame drops — mitigate by: (a) using `RepaintBoundary` around each glass card to isolate repaint regions, (b) reducing sigma to 8 if `MediaQuery.devicePixelRatio > 3` (indicating a Pro Max display).

**Alternatives considered**:
- Pure `Container` with high opacity: simpler, but loses the "floating over gradient" depth effect; rejected.
- Third-party glass packages (glassmorphism pub): adds dependency risk; unnecessary since the primitive is native.

---

## Decision 2: Aurora Animated Gradient Background

**Decision**: `AnimationController` (duration ≥ 30s) + `AnimatedBuilder` + `CustomPaint` with sine-wave color interpolation.

**Rationale**:
- `CustomPaint` is the lowest-overhead rendering path for a full-bleed background — it draws directly to the canvas in a single paint pass with no widget overhead.
- `AnimationController.repeat()` drives an infinitely looping `0.0 → 1.0` ticker.
- Sine wave mapping (`sin(t * 2π) * 0.5 + 0.5`) ensures seamless looping — the gradient is identical at `t=0` and `t=1`, so there is no visible seam.
- `AnimatedBuilder` rebuilds only the `CustomPaint` leaf — the rest of the tree (glass cards, text) is passed as an unchanged `child` and is not rebuilt on each animation frame.

**Reduce Motion**: Check `MediaQuery.of(context).disableAnimations` in `initState` and `didChangeDependencies` (so it reacts if the user enables the setting mid-session). When true: `_controller.stop()` and paint with a static progress value of `0.5`. The static gradient remains visible; only motion is removed.

**Per-screen variants**: Each major screen uses a `variant` enum value (`dayView`, `people`, `review`, `search`, `collections`) passed to `AuroraBackground`. Each variant defines a slightly different set of anchor colors within the same navy/indigo/violet/electric-blue/magenta family — same palette, different composition (e.g., Day View leans cooler violet-blue; People leans warmer violet-coral; Review leans indigo-teal).

**Alternatives considered**:
- `TweenAnimationBuilder`: discrete state transitions, not continuous — produces "stepping" rather than flow; rejected.
- `AnimatedContainer` with gradient: triggers widget rebuilds; not efficient for a full-screen background repainting every frame; rejected.
- `DecoratedBox` with gradient: static only — cannot animate; rejected.

---

## Decision 3: Person Identity Color Assignment

**Decision**: DJB2 hash of the person's UUID string, modulo a curated palette of 12 gradient pairs.

**Rationale**: DJB2 (`hash = ((hash << 5) + hash) ^ byte`) distributes UUID strings evenly across the 12 palette entries with no external dependencies. The hash is deterministic (pure function), ensuring the same person always receives the same identity regardless of session, device, or data ordering.

**Curated palette (12 pairs)**:

| Index | Name | Start Color | End Color |
|-------|------|-------------|-----------|
| 0 | Violet → Blue | `0xFF7C3AED` | `0xFF3B82F6` |
| 1 | Coral → Magenta | `0xFFF97316` | `0xFFEC4899` |
| 2 | Teal → Cyan | `0xFF14B8A6` | `0xFF06B6D4` |
| 3 | Purple → Fuchsia | `0xFF8B5CF6` | `0xFFD946EF` |
| 4 | Indigo → Violet | `0xFF6366F1` | `0xFF7C3AED` |
| 5 | Blue → Indigo | `0xFF3B82F6` | `0xFF6366F1` |
| 6 | Rose → Pink | `0xFFF43F5E` | `0xFFEC4899` |
| 7 | Cyan → Teal | `0xFF06B6D4` | `0xFF14B8A6` |
| 8 | Emerald → Teal | `0xFF10B981` | `0xFF14B8A6` |
| 9 | Magenta → Purple | `0xFFD946EF` | `0xFF8B5CF6` |
| 10 | Electric Blue → Cyan | `0xFF2563EB` | `0xFF06B6D4` |
| 11 | Amber → Coral | `0xFFF59E0B` | `0xFFF97316` |

All pairs use `LinearGradient` with 40–50% opacity when used as card accents (so the underlying glass remains dominant).

**Anti-collision at display**: Adjacent person entries are not guaranteed to differ by the hash alone. Callers (e.g., the People list screen) that display multiple contacts in sequence can optionally offset index by 1 if two adjacent people resolve to the same palette entry — but this is a display-layer concern; the identity itself does not change.

**Alternatives considered**:
- HSL hue rotation (divide hue space by person count): depends on knowing total person count; not deterministic for a single person; rejected.
- `Random(seed)` from UUID: non-deterministic across platforms (Dart's Random is platform-dependent); rejected.

---

## Decision 4: Motion Curve System

**Decision**: Define named animation presets as `const` Dart constants. No animation library needed — Flutter's built-in curves and `AnimationController` cover all required behaviors.

**Presets**:

| Name | Curve | Duration | Use |
|------|-------|----------|-----|
| `springExpand` | `Curves.easeOutCubic` | 280ms | Card expand, modal open |
| `springCollapse` | `Curves.easeInCubic` | 220ms | Card collapse, modal close |
| `fadeDismiss` | `Curves.easeOut` | 200ms | Suggestion card completion fade |
| `slideInsert` | `Curves.easeOutBack` (subtle) | 350ms | Timeline entry insertion |
| `tapFeedback` | `Curves.easeOut` | 100ms | Button press glow/scale |
| `backgroundDrift` | Sine wave (custom) | 30000ms | Aurora background cycle |

`easeOutBack` with a spring factor of `1.1` (just barely perceptible) gives the slide-insert a subtle "settle" without aggressive bounce. The spring factor MUST be ≤ 1.2 to comply with the "no aggressive bounce" requirement from the spec.

**Alternatives considered**:
- `spring_animation` package: unnecessary for this use case; Flutter curves are sufficient; rejected.
- `Hero` transitions between screens: not applicable to in-place card expansion; rejected.

---

## Decision 5: Theme Architecture

**Decision**: Extend the existing `_buildTheme()` in `main.dart` with new token constants, rather than replacing the existing Material 3 seed-color theme.

**Rationale**: The existing project uses `ColorScheme.fromSeed()` with seed `0xFF5B6AF5` (purple-blue). The aurora design system overlays custom visual treatments on top — it does not replace the semantic color system. This preserves accessibility, text contrast, and Material widget defaults while adding the premium visual layer.

**New additions**:
- `app/lib/theme/app_theme.dart` — exports `AntraColors` (aurora palette constants), `AntraMotion` (duration/curve constants), `AntraRadius` (border-radius constants)
- `app/lib/widgets/glass_surface.dart` — reusable `GlassSurface` widget
- `app/lib/widgets/aurora_background.dart` — reusable `AuroraBackground` widget
- `app/lib/services/person_color.dart` — `PersonColorService.fromId(String id) → PersonIdentity`

**No new pubspec dependencies are required.** All techniques use:
- `dart:math` (for `sin()` in aurora animation)
- `dart:convert` (for `utf8.encode()` in DJB2 hash)
- `dart:ui` (for `ImageFilter.blur()`) — already available via Flutter SDK
