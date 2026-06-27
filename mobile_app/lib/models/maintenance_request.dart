import 'package:cloud_firestore/cloud_firestore.dart';

/// The kind of issue a maintenance request is about. Cosmetic, resident-chosen
/// metadata used for grouping / icons on the admin queue.
///
/// Parses DEFENSIVELY (non-throwing → [other]) for the same reason as
/// [AnnouncementPriority]: a forward-compat value from a newer client, or a
/// hand-edited doc, must NEVER crash the admin queue. This is display metadata,
/// not a security boundary, so degrading is correct (contrast UserRole, which
/// throws because a bad role is security state).
enum MaintenanceCategory {
  plumbing,
  electrical,
  appliance,
  commonArea,
  other;

  String toFirestoreValue() => name;

  static MaintenanceCategory fromFirestoreValue(Object? value) {
    return MaintenanceCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => MaintenanceCategory.other,
    );
  }
}

/// Lifecycle state of a maintenance request.
///
/// Transitions are admin-driven: pending → inProgress → resolved (an admin may
/// also jump pending → resolved). The client cannot self-advance status; the
/// Firestore rule allows status writes ONLY to an admin / superadmin claim.
///
/// Parses DEFENSIVELY (non-throwing → [pending]). [pending] is the SAFEST
/// degrade: an unrecognised value surfaces as "still needs attention" rather
/// than silently reading as resolved and vanishing from the work queue.
enum MaintenanceStatus {
  pending,
  inProgress,
  resolved;

  String toFirestoreValue() => name;

  static MaintenanceStatus fromFirestoreValue(Object? value) {
    return MaintenanceStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => MaintenanceStatus.pending,
    );
  }
}

/// Domain representation of a maintenance request at
/// /maintenance_requests/{id}.
///
/// ─── READ-SHAPED FOR WRITES IT DOESN'T OWN ──────────────────────────────
/// Like [Announcement], this model never emits the server-authoritative
/// timestamps (createdAt / updatedAt) or the admin audit fields — those are
/// stamped by [MaintenanceRepository] with [FieldValue.serverTimestamp] and the
/// admin's uid. [toFirestoreCreate] emits ONLY the fields a resident legitimately
/// supplies at creation; status transitions and audit stamps flow through the
/// repository's admin methods, never this object.
class MaintenanceRequest {
  final String id;

  /// Owner: the Firebase Auth uid of the resident who filed it. The rule pins
  /// this to `request.auth.uid`, so authorship cannot be forged.
  final String residentId;

  /// The resident's VERIFIED unit at filing time. The rule pins it to the
  /// caller's profile `unitNumber`, so it is the real unit, not a claim.
  final String unitNumber;

  final MaintenanceCategory category;
  final String title;
  final String description;
  final MaintenanceStatus status;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// The admin/superadmin uid who last advanced the status. Null until an admin
  /// touches it. Audit / display only.
  final String? handledBy;

  /// When the request reached [MaintenanceStatus.resolved]. Null otherwise.
  final DateTime? resolvedAt;

  const MaintenanceRequest({
    required this.id,
    required this.residentId,
    required this.unitNumber,
    required this.category,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.handledBy,
    this.resolvedAt,
  });

  /// Hydrates from a Firestore document.
  ///
  /// DEFENSIVE READS: category / status degrade to safe defaults on bad values
  /// (see the enums); createdAt / updatedAt tolerate the transient null of
  /// Firestore's pending-write window (mirrors Announcement.postedAt). Identity
  /// fields (residentId / unitNumber / title / description) stay STRICT — a
  /// genuinely corrupt doc must surface, not be masked.
  factory MaintenanceRequest.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError(
          'MaintenanceRequest document "${snapshot.id}" has no data');
    }

    return MaintenanceRequest(
      id: snapshot.id,
      residentId: data['residentId'] as String,
      unitNumber: data['unitNumber'] as String,
      category: MaintenanceCategory.fromFirestoreValue(data['category']),
      title: data['title'] as String,
      description: data['description'] as String,
      status: MaintenanceStatus.fromFirestoreValue(data['status']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      handledBy: data['handledBy'] as String?,
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  String toString() =>
      'MaintenanceRequest(id: $id, unit: $unitNumber, '
      'category: ${category.name}, status: ${status.name})';
}
