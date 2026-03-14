import 'package:drift/drift.dart';

// Table definitions — imported here and re-exported so DAO files importing
// app_database.dart automatically have access to all table classes.
export 'package:antra/database/tables/bullets.dart';
export 'package:antra/database/tables/bullet_person_links.dart';
export 'package:antra/database/tables/bullet_tag_links.dart';
export 'package:antra/database/tables/collections.dart';
export 'package:antra/database/tables/conflict_records.dart';
export 'package:antra/database/tables/day_logs.dart';
export 'package:antra/database/tables/people.dart';
export 'package:antra/database/tables/pending_sync.dart';
export 'package:antra/database/tables/reviews.dart';
export 'package:antra/database/tables/tags.dart';
export 'package:antra/database/tables/task_lifecycle_events.dart';

import 'package:antra/database/tables/bullets.dart';
import 'package:antra/database/tables/bullet_person_links.dart';
import 'package:antra/database/tables/bullet_tag_links.dart';
import 'package:antra/database/tables/collections.dart';
import 'package:antra/database/tables/conflict_records.dart';
import 'package:antra/database/tables/day_logs.dart';
import 'package:antra/database/tables/people.dart';
import 'package:antra/database/tables/pending_sync.dart';
import 'package:antra/database/tables/reviews.dart';
import 'package:antra/database/tables/tags.dart';
import 'package:antra/database/tables/task_lifecycle_events.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  DayLogs,
  Bullets,
  People,
  Tags,
  BulletPersonLinks,
  BulletTagLinks,
  Collections,
  Reviews,
  PendingSync,
  ConflictRecords,
  TaskLifecycleEvents,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          // v1_core_tables: primary entity tables
          await m.createAll();

          // v1_fts_tables: FTS5 virtual tables for full-text search
          await customStatement('''
            CREATE VIRTUAL TABLE IF NOT EXISTS bullets_fts
            USING fts5(
              content,
              content='bullets',
              content_rowid='rowid'
            )
          ''');

          await customStatement('''
            CREATE VIRTUAL TABLE IF NOT EXISTS people_fts
            USING fts5(
              name,
              notes,
              content='people',
              content_rowid='rowid'
            )
          ''');

          // FTS triggers: keep bullets_fts in sync with bullets table
          await customStatement('''
            CREATE TRIGGER bullets_ai AFTER INSERT ON bullets BEGIN
              INSERT INTO bullets_fts(rowid, content) VALUES (new.rowid, new.content);
            END
          ''');
          await customStatement('''
            CREATE TRIGGER bullets_ad AFTER DELETE ON bullets BEGIN
              INSERT INTO bullets_fts(bullets_fts, rowid, content)
                VALUES ('delete', old.rowid, old.content);
            END
          ''');
          await customStatement('''
            CREATE TRIGGER bullets_au AFTER UPDATE ON bullets BEGIN
              INSERT INTO bullets_fts(bullets_fts, rowid, content)
                VALUES ('delete', old.rowid, old.content);
              INSERT INTO bullets_fts(rowid, content) VALUES (new.rowid, new.content);
            END
          ''');

          // FTS triggers: keep people_fts in sync with people table
          await customStatement('''
            CREATE TRIGGER people_ai AFTER INSERT ON people BEGIN
              INSERT INTO people_fts(rowid, name, notes)
                VALUES (new.rowid, new.name, COALESCE(new.notes, ''));
            END
          ''');
          await customStatement('''
            CREATE TRIGGER people_ad AFTER DELETE ON people BEGIN
              INSERT INTO people_fts(people_fts, rowid, name, notes)
                VALUES ('delete', old.rowid, old.name, COALESCE(old.notes, ''));
            END
          ''');
          await customStatement('''
            CREATE TRIGGER people_au AFTER UPDATE ON people BEGIN
              INSERT INTO people_fts(people_fts, rowid, name, notes)
                VALUES ('delete', old.rowid, old.name, COALESCE(old.notes, ''));
              INSERT INTO people_fts(rowid, name, notes)
                VALUES (new.rowid, new.name, COALESCE(new.notes, ''));
            END
          ''');

          // v1_indexes: performance indexes
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_day_logs_date ON day_logs(date)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_day_logs_updated_at ON day_logs(updated_at)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_bullets_day_id ON bullets(day_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_bullets_updated_at ON bullets(updated_at)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_bullets_type ON bullets(type)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_bullets_status ON bullets(status)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_people_name ON people(name)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_people_updated_at ON people(updated_at)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_people_last_interaction ON people(last_interaction_at)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_pending_sync_entity ON pending_sync(entity_type, entity_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_pending_sync_is_synced ON pending_sync(is_synced)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_conflict_records_entity ON conflict_records(entity_type, entity_id)',
          );
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            // v1 → v2: task lifecycle columns on bullets + new events table
            await m.addColumn(bullets, bullets.scheduledDate);
            await m.addColumn(bullets, bullets.carryOverCount);
            await m.addColumn(bullets, bullets.completedAt);
            await m.addColumn(bullets, bullets.canceledAt);
            await m.createTable(taskLifecycleEvents);

            // Performance indexes for lifecycle queries
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_bullets_created_at ON bullets(created_at)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_task_events_bullet_id ON task_lifecycle_events(bullet_id)',
            );
          }
          if (from < 3) {
            // v2 → v3: Personal CRM profile fields on people + linkType on bullet_person_links
            await m.addColumn(people, people.company);
            await m.addColumn(people, people.role);
            await m.addColumn(people, people.email);
            await m.addColumn(people, people.phone);
            await m.addColumn(people, people.birthday);
            await m.addColumn(people, people.location);
            await m.addColumn(people, people.tags);
            await m.addColumn(people, people.relationshipType);
            await m.addColumn(people, people.needsFollowUp);
            await m.addColumn(people, people.followUpDate);

            // bullet_person_links: add linkType
            await m.addColumn(bulletPersonLinks, bulletPersonLinks.linkType);

            // Rebuild people_fts to add company to indexed columns
            await customStatement('DROP TABLE IF EXISTS people_fts');
            await customStatement('''
              CREATE VIRTUAL TABLE people_fts USING fts5(
                name,
                notes,
                company,
                content='people',
                content_rowid='rowid'
              )
            ''');
            await customStatement("INSERT INTO people_fts(people_fts) VALUES ('rebuild')");

            // Replace people FTS triggers to include company
            await customStatement('DROP TRIGGER IF EXISTS people_ai');
            await customStatement('DROP TRIGGER IF EXISTS people_ad');
            await customStatement('DROP TRIGGER IF EXISTS people_au');
            await customStatement('''
              CREATE TRIGGER people_ai AFTER INSERT ON people BEGIN
                INSERT INTO people_fts(rowid, name, notes, company)
                  VALUES (new.rowid, new.name, COALESCE(new.notes, ''), COALESCE(new.company, ''));
              END
            ''');
            await customStatement('''
              CREATE TRIGGER people_ad AFTER DELETE ON people BEGIN
                INSERT INTO people_fts(people_fts, rowid, name, notes, company)
                  VALUES ('delete', old.rowid, old.name, COALESCE(old.notes, ''), COALESCE(old.company, ''));
              END
            ''');
            await customStatement('''
              CREATE TRIGGER people_au AFTER UPDATE ON people BEGIN
                INSERT INTO people_fts(people_fts, rowid, name, notes, company)
                  VALUES ('delete', old.rowid, old.name, COALESCE(old.notes, ''), COALESCE(old.company, ''));
                INSERT INTO people_fts(rowid, name, notes, company)
                  VALUES (new.rowid, new.name, COALESCE(new.notes, ''), COALESCE(new.company, ''));
              END
            ''');

            // New index for follow-up filter performance
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_people_needs_follow_up ON people(needs_follow_up)',
            );
          }
          if (from < 4) {
            // v3 → v4: isPinned flag on bullet_person_links
            await m.addColumn(bulletPersonLinks, bulletPersonLinks.isPinned);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_bpl_person_pinned ON bullet_person_links(person_id, is_pinned) WHERE is_deleted = 0',
            );
          }
          if (from < 5) {
            // v4 → v5: follow-up columns + sourceId on bullets (life-log feature)
            await m.addColumn(bullets, bullets.followUpDate);
            await m.addColumn(bullets, bullets.followUpStatus);
            await m.addColumn(bullets, bullets.followUpSnoozedUntil);
            await m.addColumn(bullets, bullets.followUpCompletedAt);
            await m.addColumn(bullets, bullets.sourceId);

            // Index for Needs Attention queries (pending/snoozed follow-ups by date)
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_bullets_follow_up_status ON bullets(follow_up_status, follow_up_date) WHERE is_deleted = 0',
            );
            // Index for timeline query (all non-deleted bullets ordered by createdAt)
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_bullets_created_at_desc ON bullets(created_at DESC) WHERE is_deleted = 0',
            );
          }
        },
        beforeOpen: (OpeningDetails details) async {
          // Enable WAL mode for better concurrent read performance.
          await customStatement('PRAGMA journal_mode=WAL');
          // Enforce foreign key constraints.
          await customStatement('PRAGMA foreign_keys=ON');
        },
      );
}
