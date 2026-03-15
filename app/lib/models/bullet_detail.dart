import 'package:antra/database/app_database.dart';
import 'package:antra/models/linked_person.dart';

/// Rich detail model for displaying a bullet's full detail view.
///
/// Combines [Bullet] data with resolved [LinkedPerson] list.
class BulletDetail {
  final String bulletId;
  final String content;
  final String type;
  final String? status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<LinkedPerson> persons;
  final String? followUpDate;
  final String? followUpStatus;
  final String? scheduledDate;
  final String? sourceId;

  const BulletDetail({
    required this.bulletId,
    required this.content,
    required this.type,
    this.status,
    required this.createdAt,
    this.updatedAt,
    required this.persons,
    this.followUpDate,
    this.followUpStatus,
    this.scheduledDate,
    this.sourceId,
  });

  factory BulletDetail.fromBullet(Bullet bullet, List<LinkedPerson> persons) {
    return BulletDetail(
      bulletId: bullet.id,
      content: bullet.content,
      type: bullet.type,
      status: bullet.status,
      createdAt: DateTime.tryParse(bullet.createdAt)?.toLocal() ?? DateTime.now(),
      updatedAt: DateTime.tryParse(bullet.updatedAt)?.toLocal(),
      persons: persons,
      followUpDate: bullet.followUpDate,
      followUpStatus: bullet.followUpStatus,
      scheduledDate: bullet.scheduledDate,
      sourceId: bullet.sourceId,
    );
  }
}
