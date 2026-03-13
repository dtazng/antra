# Feature Specification: Premium Visual Design System

**Feature Branch**: `007-aurora-design-system`
**Created**: 2026-03-12
**Status**: Draft
**Input**: User description: "Feature: Premium Visual Design System for Antra Day View and Core App Screens"

## User Scenarios & Testing *(mandatory)*

### User Story 1 — First Launch Impression (Priority: P1)

A new user opens Antra for the first time and immediately perceives the app as visually premium, emotionally intelligent, and distinct from ordinary productivity apps. The Day View screen opens into an aurora-gradient background with floating glass cards layered over it. The user feels this is a product worth trusting with their most important relationships.

**Why this priority**: First impressions are irreversible. This is the visual entry point that determines whether the product signals quality before any interaction happens. All other stories depend on the core aesthetic being established here.

**Independent Test**: Launch the app on a fresh install and observe Tab 0 (Day View). The screen displays an aurora gradient background, at least one glass-styled surface, and the overall composition reads as premium without any interaction.

**Acceptance Scenarios**:

1. **Given** the app is launched fresh, **When** the Day View is displayed, **Then** the background shows a flowing multi-color gradient (deep navy / indigo / violet tones) with no flat white or default material surfaces visible
2. **Given** the Day View is visible, **When** the relationship briefing section is rendered, **Then** it appears as a frosted glass card floating above the gradient — with visible translucency, subtle border, and soft shadow
3. **Given** the app is opened in low ambient light, **When** the Day View renders, **Then** the gradient and glass surfaces maintain full text legibility with strong contrast
4. **Given** the user has not interacted yet, **When** they view the screen for 5 seconds, **Then** the background gradient animates with an extremely slow, subtle shift — not jarring, not static

---

### User Story 2 — Glass Card Interactions (Priority: P1)

A user taps on a suggestion card. The card expands smoothly in place, revealing more information with an animation that feels like lifting a glass panel — responsive, spring-like, not snappy. When the user dismisses the card, it softly fades out. The user feels the interface is physically real and satisfying.

**Why this priority**: Cards are the primary interaction surface. Their visual and motion quality directly determines whether the interface feels premium or generic.

**Independent Test**: Render a suggestion card in collapsed state. Tap it. The expansion animation completes in under 350ms using a spring curve, and the card surface looks visually distinct (glass style) from the gradient background throughout the animation.

**Acceptance Scenarios**:

1. **Given** a suggestion card is collapsed, **When** tapped, **Then** it expands with a spring animation — smooth, no overshoot — in under 350ms
2. **Given** a card is expanded, **When** the user completes an action, **Then** the card softly fades or shrinks out of the feed rather than disappearing abruptly
3. **Given** the card is rendered, **When** visible in the list, **Then** the card surface shows frosted glass treatment — blurred background, soft white or tinted translucency, thin luminous border
4. **Given** two suggestion cards are visible, **When** both are rendered, **Then** they stack with visible depth separation — a slight positional offset or shadow difference between layers
5. **Given** a suggestion card is tapped, **When** pressure is applied, **Then** the card shows subtle compression feedback (scale or opacity shift) before releasing

---

### User Story 3 — Person Identity Colors (Priority: P1)

A user sees a suggestion card for a contact. The card has a soft gradient accent that is unique to that person — the same gradient used in their avatar, in their profile screen, and in any card or chip that references them. The user begins to associate colors with people instinctively, making the app feel emotionally intelligent.

**Why this priority**: Person identity through color is a differentiating visual idea that creates emotional resonance and recognition. It runs through the entire app and must be established before any screen-level work is complete.

**Independent Test**: Open the app with at least 3 contacts present. Verify that each contact has a consistent, distinct gradient identity visible in their avatar and in any card or surface that references them. The identities should differ from each other and harmonize with the app's overall palette.

**Acceptance Scenarios**:

1. **Given** a contact exists in the system, **When** they are displayed anywhere in the app, **Then** they always appear with the same gradient color identity (avatar background, card accent, ring)
2. **Given** two different contacts, **When** displayed side by side, **Then** their gradient identities are visually distinct — no two adjacent contacts share the same hue pair
3. **Given** a contact's gradient identity, **When** it appears in a suggestion card, **Then** the gradient is used as a subtle accent (not dominant) — visible in a ring, glow, or top edge color without overwhelming the glass surface
4. **Given** a contact's identity gradient, **When** their avatar is rendered, **Then** the gradient fills the avatar background with soft, elegant rendering — not flat, not harsh
5. **Given** any color identity assigned to a person, **When** it is viewed alongside the aurora background, **Then** it harmonizes with the overall palette — no clashing neons or mismatched saturation

---

### User Story 4 — Quick Log Glass Surface (Priority: P2)

A user taps a quick log button to record a coffee meeting. The quick log bar appears as a premium glass panel. The interaction type icons look tactile and tappable. After tapping Coffee, the button gives subtle visual feedback — a glow or soft pulse. The experience feels fast, satisfying, and premium.

**Why this priority**: The Quick Log bar is used multiple times per day. Its tactile quality directly affects perceived product quality in everyday use.

**Independent Test**: Tap a Quick Log type button (Coffee, Call, Message, Note). The button shows immediate visual feedback within 100ms. The surface the button is on appears as a glass panel, not a flat opaque bar.

**Acceptance Scenarios**:

1. **Given** the Quick Log bar is visible, **When** the user views it, **Then** the bar surface appears as a glass panel — translucent, with soft border, not a flat opaque fill
2. **Given** a Quick Log type button is tapped, **When** the tap registers, **Then** the button shows visual feedback within 100ms — a soft glow, brightness pulse, or spring compression
3. **Given** the person picker sheet is opened, **When** it appears, **Then** it rises with a smooth spring animation and renders as a glass modal, consistent with the design system
4. **Given** an interaction is saved, **When** the UI resets, **Then** the reset animates smoothly — no abrupt layout jump

---

### User Story 5 — Timeline as Premium Journal (Priority: P2)

A user scrolls through the Today timeline and sees their logged interactions rendered as premium journal fragments — timestamp, emoji label, and person name are cleanly laid out. When a new interaction is logged via Quick Log, it slides into the timeline with a graceful insertion animation. The timeline feels like a beautiful record of a meaningful day.

**Why this priority**: The timeline is a passive but emotionally significant surface. It reinforces the feeling that the app is tracking something important.

**Independent Test**: Log an interaction via Quick Log while the timeline is visible. A new entry animates into the list within 500ms of the save completing. The entry is styled distinctly from a plain list item.

**Acceptance Scenarios**:

1. **Given** the timeline has interactions, **When** rendered, **Then** each entry shows timestamp, interaction type label, and person name in a clearly readable, premium-feeling layout
2. **Given** a new interaction is logged, **When** saved, **Then** the new entry slides into the timeline from below with a smooth insertion animation within 500ms
3. **Given** the timeline is empty, **When** rendered, **Then** the empty state is graceful — soft text or illustration, not a blank screen
4. **Given** a person has an identity color, **When** their name appears in the timeline, **Then** a subtle accent (color dot, ring, or tint) reflects their identity gradient

---

### User Story 6 — Full App Design Coverage (Priority: P3)

A user navigates across different tabs and screens (People, Review, Search, Collections). Every major screen uses the design system — aurora gradient backgrounds, glass surfaces, and identity colors — creating a seamless, premium experience throughout the app rather than a patchwork where only Day View was styled.

**Why this priority**: Inconsistent styling creates a "concept app" impression — impressive in one place, unfinished everywhere else. Full coverage is required for a production-quality result, but it naturally comes after the Day View is established.

**Independent Test**: Navigate through each of the 5 main tabs. Each tab shows: (1) a gradient background appropriate to that screen, (2) at least one glass-styled surface, (3) no flat white Material Design default surfaces visible at the top level.

**Acceptance Scenarios**:

1. **Given** the user navigates to the People tab, **When** it renders, **Then** it shows a gradient background and person cards styled with glass treatment
2. **Given** the user opens a person profile, **When** the detail screen renders, **Then** the person's identity gradient is featured prominently (header, avatar, accent zones)
3. **Given** the user navigates to the Review tab, **When** it renders, **Then** a cohesive gradient (slightly different composition from Day View) is used as the background
4. **Given** any modal or bottom sheet is opened, **When** it appears, **Then** it uses glass styling consistent with the system — not a default white sheet

---

### Edge Cases

- What happens when a contact has no identifier yet (e.g., mid-creation)? The system must fall back to a neutral gradient without crashing.
- How does the gradient background behave when the system Reduce Motion setting is enabled? Animation stops; static gradient remains visible.
- What happens on lower-powered devices where blur effects are expensive? The glass surface must degrade gracefully — reduced blur — without breaking layout or legibility.
- What happens in bright ambient light? All text on glass and gradient surfaces must meet WCAG AA contrast (4.5:1) at all times.
- What happens when 50+ contacts exist? Identity color assignment must remain deterministic, consistent, and non-colliding at scale.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST display an aurora-style multi-layered gradient as the primary background on the Day View, People, and Review screens — each with a subtly different gradient composition within the same palette family
- **FR-002**: The background gradient MUST animate with an extremely slow, continuous shift — completing one full cycle in no less than 30 seconds — and MUST respect the device's Reduce Motion accessibility setting by pausing the animation when that setting is enabled
- **FR-003**: All primary card surfaces — suggestion cards, relationship briefing, daily goal, timeline entries, quick log bar, person summary cards, and modal sheets — MUST use a glass-style treatment: translucent background, soft blur effect, thin luminous border, and diffuse multi-layer shadow
- **FR-004**: Each person MUST be assigned a gradient identity (a unique start and end color) that is determined consistently from their identifier — ensuring the same person always receives the same colors across sessions and devices
- **FR-005**: A person's gradient identity MUST appear consistently in their avatar background, any card or surface that references them, their profile header, and any chip or badge that displays their name
- **FR-006**: Two people displayed adjacently MUST have visually distinguishable gradient identities — the assignment approach must prevent identical or perceptually indistinguishable adjacent hues
- **FR-007**: All card expand and collapse interactions MUST animate using a spring curve — smooth, with no visible overshoot — completing within 350ms
- **FR-008**: All dismissal animations (suggestion card completion, modal close) MUST use a soft fade or scale-down — no abrupt disappearance
- **FR-009**: Timeline entry insertion MUST animate with a smooth slide-in from below, completing within 500ms of the save action completing
- **FR-010**: Quick Log type buttons MUST provide visible feedback within 100ms of a tap — via glow, brightness shift, or spring compression effect
- **FR-011**: The Quick Log surface MUST render as a glass panel consistent with the glass card system — not a flat opaque bar
- **FR-012**: All text rendered on glass or gradient surfaces MUST maintain a contrast ratio of at least 4.5:1 (WCAG AA) against the underlying surface at all times
- **FR-013**: The glass blur effect MUST degrade gracefully on lower-powered devices — reducing blur intensity — without breaking layout or text legibility
- **FR-014**: Empty states across all styled screens MUST use the design system — gradient background, soft illustration or icon, subdued text — rather than default blank layouts
- **FR-015**: The design system MUST apply consistently to all 5 main tabs and all modal or detail screens — no screen should render with flat white Material Design defaults at the top level

### Key Entities

- **DesignToken**: A named visual value (color stop, border radius, spacing unit, animation duration, opacity level) that all styled components reference — enabling consistent and maintainable theming
- **PersonIdentity**: A deterministically assigned gradient pair (two color values) associated with a person record — stable across sessions and rendered wherever that person is represented
- **GlassSurface**: A reusable UI surface component implementing the frosted glass treatment — blur, translucency, border, and shadow — used as the base for all card, bar, and modal surfaces
- **AuroraBackground**: A reusable animated background component that renders the flowing gradient — accepts a palette variant per screen, respects Reduce Motion, and renders behind all glass surfaces
- **MotionCurve**: Named animation presets (spring-expand, spring-collapse, fade-dismiss, slide-insert) used consistently across all interactive elements

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A first-time user shown the app alongside 3 competitor productivity apps can correctly identify Antra as the most visually distinctive within 10 seconds — verified by user observation with at least 10 participants
- **SC-002**: 90% of users in a perception test rate the app as "premium" or "high quality" on first view of the Day View screen, before any interaction
- **SC-003**: All card expand and collapse animations complete within 350ms with no dropped frames, on iPhone 12 or equivalent and above
- **SC-004**: Timeline entry insertion animation appears within 500ms of a save action completing, with no visible layout jump
- **SC-005**: All text on gradient and glass surfaces achieves a contrast ratio of 4.5:1 or above, verified across all gradient color stops and glass opacity levels
- **SC-006**: Person identity colors are assigned and rendered consistently — the same person shows the same gradient on 100% of renderings across sessions and devices
- **SC-007**: The aurora background animation completes one full cycle in no less than 30 seconds, with no visible stutter during the animation
- **SC-008**: The design system is applied to 100% of the main tab screens and all modal surfaces — zero screens rendering with default flat white backgrounds at the top level
- **SC-009**: The app renders correctly and legibly on devices with Reduce Motion enabled — gradient is static, all content remains readable and accessible
- **SC-010**: Screenshots of the styled app are recognizable as the same product across Day View, People tab, and a person profile — visual consistency is identifiable at a glance across screens

## Assumptions

- The app targets iOS first (iPhone 12 and above); Android visual parity is expected but not a hard constraint for this feature
- Dark mode is the primary design mode; light mode adaptation may follow in a later iteration
- The gradient palette direction (deep navy, indigo, violet, electric blue, magenta, teal, coral) is approved directionally — exact color values will be finalized during implementation
- Person identity gradient assignment uses a deterministic derivation from the person's existing unique identifier — no manual color selection by users in this version
- Blur-based glass effects are acceptable for the target device range; graceful degradation handles lower-powered devices without crashing or breaking layout
- No new third-party animation or design libraries are introduced — the implementation uses existing platform primitives already available in the project
- Accessibility compliance targets WCAG AA (4.5:1 contrast ratio) as the minimum standard
- The design system is applied to existing screens by restyling current components — no new screen routes or navigation restructuring is required
