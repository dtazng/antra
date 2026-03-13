# Quickstart: Premium Visual Design System

**Feature**: 007-aurora-design-system
**Date**: 2026-03-12

This guide shows how to integrate the aurora design system into existing screens and how to use the new shared components.

---

## Scenario 1: Wrap a Screen with the Aurora Background

**Before** (existing `DayViewScreen`):
```dart
Scaffold(
  appBar: AppBar(title: Text('Today')),
  body: ListView(...),
)
```

**After**:
```dart
Scaffold(
  appBar: AppBar(
    backgroundColor: Colors.transparent, // Let aurora show through
    elevation: 0,
    title: Text('Today'),
  ),
  body: AuroraBackground(
    variant: AuroraVariant.dayView,
    child: ListView(...),
  ),
)
```

The `AuroraBackground` fills behind all content. The `AppBar` must be made transparent so the gradient shows through the title area.

---

## Scenario 2: Replace a Card with a Glass Surface

**Before** (existing suggestion card container):
```dart
Container(
  decoration: BoxDecoration(
    color: cs.surfaceContainerLow,
    borderRadius: BorderRadius.circular(16),
  ),
  padding: EdgeInsets.all(16),
  child: cardContent,
)
```

**After**:
```dart
GlassSurface(
  style: GlassStyle.card,
  onTap: () => notifier.expand(suggestion.personId),
  child: cardContent,
)
```

`GlassSurface` handles the `BackdropFilter`, `ClipRRect`, border, shadow, and tap animation internally.

---

## Scenario 3: Display a Person's Avatar with Identity Color

**Before** (existing `CircleAvatar`):
```dart
CircleAvatar(
  radius: 22,
  backgroundColor: _avatarColor(context),
  child: Text(initials, style: TextStyle(color: Colors.white)),
)
```

**After**:
```dart
PersonAvatar(
  personId: person.id,
  displayName: person.name,
  radius: 22,
)
```

`PersonAvatar` derives and caches the identity gradient from `PersonColorService.fromId(person.id)`. The avatar is always consistent.

---

## Scenario 4: Add a Person Identity Accent to a Timeline Entry

```dart
Row(
  children: [
    PersonIdentityAccent(
      personId: interaction.personId,
      style: AccentStyle.dot,
      size: 8,
    ),
    SizedBox(width: 8),
    Text('${interaction.timestamp} — ${interaction.label} with ${interaction.personName}'),
  ],
)
```

---

## Scenario 5: Render a Glass Bottom Bar (Quick Log)

```dart
Scaffold(
  body: AuroraBackground(
    variant: AuroraVariant.dayView,
    child: Stack(
      children: [
        ListView(...), // scrollable content
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: GlassSurface(
            style: GlassStyle.bar,
            child: SafeArea(
              top: false,
              child: QuickLogBar(date: _dateKey, onInteractionLogged: (_) {}),
            ),
          ),
        ),
      ],
    ),
  ),
)
```

---

## Scenario 6: Open a Glass Bottom Sheet

```dart
showModalBottomSheet(
  context: context,
  backgroundColor: Colors.transparent, // Required — sheet must be transparent
  builder: (_) => GlassSurface(
    style: GlassStyle.modal,
    child: PersonPickerSheet(),
  ),
);
```

Setting `backgroundColor: Colors.transparent` on the sheet route is required so `GlassSurface` can blur the content beneath it.

---

## Scenario 7: Accessing Design Tokens

Instead of hardcoded values:
```dart
// Before
borderRadius: BorderRadius.circular(20),
duration: Duration(milliseconds: 280),

// After
borderRadius: BorderRadius.circular(AntraRadius.card),
duration: AntraMotion.springExpand,
```

---

## Scenario 8: Respecting Reduce Motion

`AuroraBackground` handles this internally. For custom animations:

```dart
final reduceMotion = MediaQuery.of(context).disableAnimations;

AnimationController(
  duration: reduceMotion
    ? Duration.zero
    : AntraMotion.springExpand,
  vsync: this,
)
```

---

## Integration Checklist for Each Screen

When restyling an existing screen:

- [ ] Wrap `Scaffold.body` with `AuroraBackground(variant: <screen-variant>, child: ...)`
- [ ] Set `AppBar.backgroundColor = Colors.transparent` and `elevation = 0`
- [ ] Replace `Card` / flat `Container` surfaces with `GlassSurface(style: ...)`
- [ ] Replace `CircleAvatar` with `PersonAvatar(personId:, displayName:)`
- [ ] Add `PersonIdentityAccent` to timeline entries and suggestion card headers
- [ ] Set `backgroundColor: Colors.transparent` on any `showModalBottomSheet` calls
- [ ] Replace hardcoded radii, durations, and curves with `AntraRadius.*`, `AntraMotion.*`
- [ ] Verify text contrast ratio ≥ 4.5:1 on all glass/gradient surfaces
