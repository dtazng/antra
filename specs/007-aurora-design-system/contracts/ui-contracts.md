# UI Contracts: Premium Visual Design System

**Feature**: 007-aurora-design-system
**Date**: 2026-03-12

These contracts define the public API of every new component introduced by this feature. All existing screens consume these components — any change to a component's constructor must be backward-compatible or accompanied by a migration of all callers.

---

## Component 1: `AuroraBackground`

**File**: `app/lib/widgets/aurora_background.dart`

**Purpose**: Full-bleed animated gradient background. Renders behind all other content on a screen. One instance per screen.

**Constructor**:

```dart
AuroraBackground({
  required AuroraVariant variant,
  required Widget child,
})
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `variant` | `AuroraVariant` | Yes | Which gradient composition to render (`dayView`, `people`, `collections`, `search`, `review`, `modal`) |
| `child` | `Widget` | Yes | The screen content rendered above the gradient |

**Behavior**:
- Renders a full-bleed `CustomPaint` gradient behind `child`
- Animates continuously with a 30-second cycle using sine-wave interpolation
- Stops animation (static gradient at midpoint) when `MediaQuery.disableAnimations` is true
- Restarts animation if accessibility setting is toggled while screen is active

**Screen usage pattern**:
```dart
Scaffold(
  body: AuroraBackground(
    variant: AuroraVariant.dayView,
    child: /* scrollable content */,
  ),
)
```

---

## Component 2: `GlassSurface`

**File**: `app/lib/widgets/glass_surface.dart`

**Purpose**: Reusable frosted glass card surface. Used as the base for all card, modal, and bar surfaces.

**Constructor**:

```dart
GlassSurface({
  required Widget child,
  GlassStyle style = GlassStyle.card,
  EdgeInsetsGeometry? padding,
  VoidCallback? onTap,
})
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `child` | `Widget` | Yes | — | Content rendered inside the glass surface |
| `style` | `GlassStyle` | No | `GlassStyle.card` | Blur sigma, tint opacity, border radius, shadow preset |
| `padding` | `EdgeInsetsGeometry?` | No | `EdgeInsets.all(16)` | Internal padding |
| `onTap` | `VoidCallback?` | No | null | Tap feedback — shows `tapFeedback` animation on press |

**`GlassStyle` presets**:

| Preset | blurSigma | tintOpacity | borderRadius | Elevation | Use |
|--------|-----------|-------------|--------------|-----------|-----|
| `card` | 12.0 | 0.14 | 20px | card | Suggestion cards, briefing, goal widget |
| `bar` | 10.0 | 0.10 | top 16px | flat | Quick log bar, tab bar overlay |
| `modal` | 15.0 | 0.18 | 28px | modal | Bottom sheets, person picker |
| `chip` | 8.0 | 0.08 | 16px | flat | Action chips, type buttons |
| `hero` | 12.0 | 0.16 | 24px | card | Relationship briefing hero surface |

**Behavior**:
- Renders `BackdropFilter → ClipRRect → Container` with two-layer `BoxShadow`
- Luminous `Border` around the card at 1px width, `white @ borderOpacity`
- When `onTap` is provided: scales to `0.97` over `tapFeedback` duration on press, restores on release

---

## Component 3: `PersonAvatar`

**File**: `app/lib/widgets/person_avatar.dart` (new, replaces `CircleAvatar` usage)

**Purpose**: Renders a person's avatar using their identity gradient as the background. Used everywhere a person's avatar is shown.

**Constructor**:

```dart
PersonAvatar({
  required String personId,
  required String displayName,
  double radius = 22,
  bool showRing = false,
})
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `personId` | `String` | Yes | — | Used to derive identity gradient via `PersonColorService` |
| `displayName` | `String` | Yes | — | Displayed as initials (first letter of first and last name) |
| `radius` | `double` | No | 22 | Avatar circle radius |
| `showRing` | `bool` | No | false | When true, renders a 2px gradient ring around the avatar (used in profile headers) |

**Behavior**:
- Background: `LinearGradient(identity.gradientStart, identity.gradientEnd)`
- Initials: first letter of first word + first letter of last word in `displayName`, rendered in white
- Ring (when `showRing = true`): a 2px annular gradient border using the same identity gradient at 80% opacity

---

## Component 4: `PersonIdentityAccent`

**File**: `app/lib/widgets/person_identity_accent.dart` (new)

**Purpose**: Renders a small color accent for a person (dot, ring, or edge glow). Used in suggestion cards, timeline entries, chips, and anywhere a person is referenced without a full avatar.

**Constructor**:

```dart
PersonIdentityAccent({
  required String personId,
  AccentStyle style = AccentStyle.dot,
  double size = 8,
})
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `personId` | `String` | Yes | — | Source for identity gradient |
| `style` | `AccentStyle` | No | `dot` | Rendering style: `dot`, `ring`, `edgeGlow`, `topBar` |
| `size` | `double` | No | 8 | Diameter for dot; width multiplier for other styles |

**`AccentStyle` variants**:

| Style | Visual | Use |
|-------|--------|-----|
| `dot` | Gradient-filled circle | Timeline entries, list rows |
| `ring` | Annular gradient ring | Collapsed suggestion cards |
| `edgeGlow` | Left-edge gradient stroke on a card | Expanded suggestion cards |
| `topBar` | Thin gradient top border on a card | Person profile header accent |

---

## Component 5: `PersonColorService`

**File**: `app/lib/services/person_color.dart`

**Purpose**: Derives a deterministic `PersonIdentity` from a person's UUID. Pure function — no state, no async, no DB access.

**API**:

```dart
class PersonColorService {
  static PersonIdentity fromId(String personId);
}
```

| Method | Input | Output | Description |
|--------|-------|--------|-------------|
| `fromId` | `String personId` | `PersonIdentity` | Returns gradient pair derived from DJB2 hash of `personId` mod 12 |

**Contract**:
- Same input ALWAYS produces the same output (deterministic)
- No side effects, no async
- Safe to call synchronously in `build()` methods

---

## Component 6: `AntraTheme`

**File**: `app/lib/theme/app_theme.dart`

**Purpose**: Exports all design tokens as typed constants. All styled components reference these tokens — never hardcoded values.

**Exports**:

```dart
class AntraColors {
  static const Color auroraDeepNavy = Color(0xFF0D0F1A);
  static const Color auroraNavy = Color(0xFF121428);
  static const Color auroraIndigo = Color(0xFF1E1F5E);
  static const Color auroraViolet = Color(0xFF2D1B6B);
  static const Color auroraElectricBlue = Color(0xFF2563EB);
  static const Color auroraMagenta = Color(0xFFD946EF);
  static const Color auroraTeal = Color(0xFF14B8A6);
  static const Color auroraCoralHint = Color(0xFFF97316);
}

class AntraRadius {
  static const double card = 20;
  static const double modal = 28;
  static const double chip = 16;
  static const double avatar = 22;
}

class AntraMotion {
  static const Duration springExpand = Duration(milliseconds: 280);
  static const Duration springCollapse = Duration(milliseconds: 220);
  static const Duration fadeDismiss = Duration(milliseconds: 200);
  static const Duration slideInsert = Duration(milliseconds: 350);
  static const Duration tapFeedback = Duration(milliseconds: 100);
  static const Duration backgroundCycle = Duration(seconds: 30);

  static const Curve expandCurve = Curves.easeOutCubic;
  static const Curve collapseCurve = Curves.easeInCubic;
  static const Curve dismissCurve = Curves.easeOut;
  static const Curve insertCurve = Curves.easeOutBack;
  static const Curve tapCurve = Curves.easeOut;
}
```

---

## Migration: Existing Screens

Each existing screen must be updated to wrap its `Scaffold.body` with `AuroraBackground` and replace `Card` / flat `Container` surfaces with `GlassSurface`. `CircleAvatar` instances that display person avatars must be replaced with `PersonAvatar`.

| Screen | AuroraVariant | Primary surfaces to restyle |
|--------|--------------|----------------------------|
| `DayViewScreen` | `dayView` | RelationshipBriefing, DailyGoalWidget, SuggestionCard, QuickLogBar, TodayTimeline |
| `PeopleScreen` | `people` | Person list tiles, search bar, filter chips |
| `PersonProfileScreen` | `people` | Profile header, interaction list, notes card |
| `CollectionsScreen` | `collections` | Collection cards |
| `SearchScreen` | `search` | Search input, result items |
| `ReviewScreen` | `review` | Review option cards |
| `WeeklyReviewScreen` | `review` | Task cards, summary surfaces |
| All bottom sheets | `modal` | PersonPickerSheet, CreatePersonSheet, EditPersonSheet, QuickLogBar confirm row |
