# Quickstart: Person Detail View (004)

**Branch**: `004-person-detail-view` | **Date**: 2026-03-10

## Implementation Order

### Phase 1: Schema + DAO (blocking)

1. Add `is_pinned INTEGER NOT NULL DEFAULT 0` to `BulletPersonLinks` table in `app/lib/database/tables/bullet_person_links.dart`
2. Bump `schemaVersion` 3 → 4 in `app/lib/database/app_database.dart`, add `ALTER TABLE` migration and new index
3. Run `dart run build_runner build --delete-conflicting-outputs` — confirm regenerated without error
4. Add `getInteractionSummary(personId)` to `PeopleDao`
5. Add `getRecentBulletsForPerson(personId, {limit})` to `PeopleDao`
6. Add `getBulletsForPersonPaged(personId, {typeFilter, limit, offset})` to `PeopleDao`
7. Add `getPinnedBulletsForPerson(personId)` to `PeopleDao`
8. Add `setPinned(bulletId, personId, {required bool pinned})` to `PeopleDao`

### Phase 2: Providers (blocking for UI)

9. Add `InteractionSummary` data class to `app/lib/database/daos/people_dao.dart` (or a new model file)
10. Add `TimelineItem`, `TimelineMonthHeader`, `TimelineActivityRow` sealed classes (new file `app/lib/models/timeline_item.dart`)
11. Add `PersonTimelineState` data class (same file or provider file)
12. Add `interactionSummaryProvider(personId)` to `app/lib/providers/people_provider.dart`
13. Add `recentBulletsForPersonProvider(personId)` to `app/lib/providers/people_provider.dart`
14. Add `pinnedBulletsForPersonProvider(personId)` to `app/lib/providers/people_provider.dart`
15. Add `PersonTimelineNotifier` (paginated) to `app/lib/providers/people_provider.dart`
16. Run `dart run build_runner build --delete-conflicting-outputs` — confirm providers regenerated

### Phase 3: LogInteractionSheet (new widget)

17. Create `app/lib/widgets/log_interaction_sheet.dart` with content field, type chips, person badge, save logic

### Phase 4: Rewrite PersonProfileScreen sections

18. Rewrite `_ProfileBody` in `person_profile_screen.dart`: implement `_HeaderSection` (avatar, name, metadata, last interaction, status badge, follow-up badge)
19. Add `_QuickActionsBar` (Log / Note / Follow-up / Edit buttons)
20. Add `_RelationshipSummaryCard` (watches `interactionSummaryProvider`)
21. Add `_RecentActivitySection` (watches `recentBulletsForPersonProvider`, 5→10 expand, "View All" link)
22. Add `_PinnedNotesSection` (watches `pinnedBulletsForPersonProvider`, hidden when empty, long-press to unpin)
23. Add `_InsightsSection` (computed from `person` data — no provider needed; pure logic)
24. Retain `_DeleteButton` at bottom (existing behavior)

### Phase 5: PersonFullTimelineScreen (new screen)

25. Create `app/lib/screens/people/person_full_timeline_screen.dart`
26. Implement `CustomScrollView` with sticky filter chip bar, `SliverList` of `TimelineItem` list, `ScrollController` for pagination, load-more indicator, end-of-list message, empty states

### Phase 6: Wire navigation + polish

27. Wire "View All Activity" `TextButton` to push `PersonFullTimelineScreen`
28. Wire `_QuickActionsBar` buttons to `LogInteractionSheet` and `EditPersonSheet`
29. Ensure `ref.invalidate` chains are correct after all mutations (log, pin/unpin, edit)
30. Run `flutter analyze` and fix all warnings in touched files

---

## Testing Focus Areas (manual, iOS simulator)

### US1: At-a-Glance Overview
- Open a person with 50+ interactions → confirm ≤10 rows in Recent Activity, summary stats visible above fold
- Open a person with 0 interactions → confirm all empty states show (no crashes)
- Check follow-up badge appears in header when `needsFollowUp = 1`

### US2: Quick Actions
- Tap "Log" → sheet opens pre-attached to person → save → new entry appears in Recent Activity
- Tap "Note" → type selector pre-set to Note → save → entry appears, summary count increments
- Tap "Follow-up" → date picker works, clears via header "Clear" button
- Tap "Edit" → EditPersonSheet opens, save reflects in header

### US3: Full Activity Timeline
- Open a person with 60 interactions → "View All" opens timeline, grouped by month
- Apply "Notes" filter → only note rows remain
- Scroll to bottom → next 20 load automatically
- Apply filter with no matching type → empty state shown

### US4: Pinned Notes
- Add a note → long-press → pin → appears in Pinned section on profile
- Reopen profile → pinned note still at top
- Long-press pinned note → "Unpin" → disappears from Pinned section
- Profile with no pins → Pinned section hidden entirely

### US5: Relationship Insights
- Set `reminderCadenceDays = 7`, set `lastInteractionAt` to 10 days ago → insights shows stale warning
- Set future follow-up date → "Due in N days" shown
- Set past follow-up date → "Overdue" shown in red
- Clear follow-up, recent interaction, no cadence → insights section hidden

---

## Commands

```bash
# Generate drift code after schema/DAO changes
cd app && dart run build_runner build --delete-conflicting-outputs

# Run app on simulator
flutter run -d "iPhone 16"

# Analyze
flutter analyze app/
```
