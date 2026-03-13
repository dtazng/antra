# Data Model: Premium Visual Design System

**Feature**: 007-aurora-design-system
**Date**: 2026-03-12

> This feature introduces no new database tables or persistent data. All entities are in-memory, derived, or compile-time constants.

---

## Entity 1: `AntraColors` (Compile-time constants)

The global aurora palette. Defined in `app/lib/theme/app_theme.dart`.

| Token | Role | Value (approx) |
|-------|------|----------------|
| `auroraDeepNavy` | Darkest background anchor | `0xFF0D0F1A` |
| `auroraNavy` | Dark background mid | `0xFF121428` |
| `auroraIndigo` | Background cool mid | `0xFF1E1F5E` |
| `auroraViolet` | Background warm mid | `0xFF2D1B6B` |
| `auroraElectricBlue` | Accent pop | `0xFF2563EB` |
| `auroraMagenta` | Warm accent | `0xFFD946EF` |
| `auroraTeal` | Cool accent highlight | `0xFF14B8A6` |
| `auroraCoralHint` | Occasional warm note | `0xFFF97316` |
| `glassWhiteTint` | Glass surface tint | `Colors.white` @ 0.12 opacity |
| `glassBorderLight` | Glass border | `Colors.white` @ 0.15 opacity |
| `glassShadowAmbient` | Outer shadow | `Colors.black` @ 0.25 opacity |
| `glassShadowFill` | Inner shadow | `Colors.black` @ 0.10 opacity |

---

## Entity 2: `AntraRadius` (Compile-time constants)

| Token | Value | Use |
|-------|-------|-----|
| `cardRadius` | 20px | Suggestion cards, briefing card |
| `modalRadius` | 28px | Bottom sheets, person picker |
| `chipRadius` | 16px | Action chips, type buttons |
| `avatarRadius` | 22px | Person avatars (circle diameter 44) |
| `tabBarRadius` | 30px | Floating tab bar (existing) |

---

## Entity 3: `AntraMotion` (Compile-time constants)

| Token | Duration | Curve | Use |
|-------|----------|-------|-----|
| `springExpand` | 280ms | `easeOutCubic` | Card expand, modal open |
| `springCollapse` | 220ms | `easeInCubic` | Card collapse, modal close |
| `fadeDismiss` | 200ms | `easeOut` | Suggestion card removal |
| `slideInsert` | 350ms | `easeOutBack` (factor 1.1) | Timeline entry insertion |
| `tapFeedback` | 100ms | `easeOut` | Button press response |
| `backgroundCycleDuration` | 30000ms | Sine wave (custom) | Aurora background drift |

---

## Entity 4: `PersonIdentity` (Derived, in-memory)

Assigned per-person from their UUID. Not stored in the database — recomputed on demand.

| Field | Type | Description |
|-------|------|-------------|
| `gradientStart` | `Color` | First color of the person's identity gradient |
| `gradientEnd` | `Color` | Second color of the person's identity gradient |
| `paletteIndex` | `int` | 0–11, derived via DJB2 hash of person ID |

**Identity Palette** (12 curated pairs, same as research.md):

| Index | Name | Start | End |
|-------|------|-------|-----|
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

**Derivation**: `DJB2(utf8.encode(personId)) % 12`

**Usage**: `PersonIdentity` is returned by `PersonColorService.fromId(String id)` and used wherever a person is visually represented.

---

## Entity 5: `AuroraVariant` (Enum — compile-time)

Controls which gradient composition an `AuroraBackground` renders.

| Variant | Dominant Hues | Screen |
|---------|--------------|--------|
| `dayView` | Navy → Indigo → Violet | Tab 0 (Today) |
| `people` | Indigo → Violet → Coral hint | Tab 1 (People) |
| `collections` | Navy → Indigo → Teal | Tab 2 (Collections) |
| `search` | Navy → Electric Blue → Indigo | Tab 3 (Search) |
| `review` | Indigo → Teal → Violet | Tab 4 (Review) |
| `modal` | Darkened `dayView` (for sheet backgrounds) | Modals |

---

## Entity 6: `GlassStyle` (Value object — in-memory)

Parameterizes a `GlassSurface` widget instance.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `blurSigma` | `double` | `12.0` | Gaussian blur intensity |
| `tintOpacity` | `double` | `0.14` | Translucency of the tint layer |
| `borderOpacity` | `double` | `0.15` | Luminous border visibility |
| `borderRadius` | `BorderRadius` | `cardRadius` | Corner treatment |
| `elevation` | `GlassElevation` | `card` | Which shadow preset to use |

`GlassElevation` enum:
- `flat` — no shadow (for inline surfaces)
- `card` — standard two-layer shadow
- `modal` — deeper shadow for sheets

---

## Relationships

```text
AuroraBackground
  └── AuroraVariant (1:1 per screen)

GlassSurface
  └── GlassStyle (1:1)

Person (existing DB entity)
  └── PersonIdentity (1:1, derived)
      └── paletteIndex from IdentityPalette[0..11]

AntraTheme
  ├── AntraColors (constants)
  ├── AntraRadius (constants)
  └── AntraMotion (constants)
```

No database migrations required. All entities in this feature are in-memory, compile-time constants, or derived values.
