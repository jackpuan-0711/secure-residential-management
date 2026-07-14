import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/maintenance_request.dart';

/// The single chokepoint for all reads and writes to
/// /maintenance_requests/{id}.
///
/// THREAT MODEL NOTE (read before adding methods):
///   A CONVENIENCE API over Firestore, not a security boundary. Authorization
///   is enforced SERVER-SIDE by firestore.rules:
///     • create — only a VERIFIED resident (profile role=resident,
///       status=active, unitNumber set), filing for THEMSELVES and THEIR unit,
///       with status pinned to 'pending' and server-stamped timestamps.
///     • updateStatus — only an admin / superadmin CLAIM may advance status or
///       write the audit fields; the resident who filed it cannot.
///   "Security is server-enforced, not client-enforced."
class MaintenanceRepository {
  final FirebaseFirestore _firestore;

  MaintenanceRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collection = 'maintenance_requests';

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection(_collection);

  // ═══════════════════════════════════════════════════════════════
  // CREATE
  // ═══════════════════════════════════════════════════════════════

  /// Files a new request. `status` is forced to pending, audit fields to null,
  /// and createdAt/updatedAt are server-authoritative — none are client input.
  /// `unitNumber` MUST be the caller's verified unit (the rule pins it to the
  /// profile), so passing another unit is rejected server-side.
  Future<void> createRequest({
    required String residentId,
    required String unitNumber,
    required MaintenanceCategory category,
    required String title,
    required String description,
  }) async {
    await _ref.add({
      'residentId': residentId,
      'unitNumber': unitNumber,
      'category': category.toFirestoreValue(),
      'title': title.trim(),
      'description': description.trim(),
      'status': MaintenanceStatus.pending.toFirestoreValue(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'handledBy': null,
      'resolvedAt': null,
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // READ
  // ═══════════════════════════════════════════════════════════════

  /// Live list of the calling resident's own requests, newest first.
  ///
  /// COMPOSITE INDEX: where('residentId') + orderBy('createdAt', desc) requires
  /// a (residentId ASC, createdAt DESC) index (firestore.indexes.json).
  Stream<List<MaintenanceRequest>> watchMyRequests(String residentId) {
    return _ref
        .where('residentId', isEqualTo: residentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => MaintenanceRequest.fromFirestore(d, null))
              .toList(),
        );
  }

  /// Live list of ALL requests for the admin queue, newest first. Single-field
  /// orderBy → served by Firestore's automatic single-field index (no composite
  /// declaration needed). Readable only by an admin/superadmin claim (rule).
  Stream<List<MaintenanceRequest>> watchAllRequests() {
    return _ref
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => MaintenanceRequest.fromFirestore(d, null))
              .toList(),
        );
  }

  // ═══════════════════════════════════════════════════════════════
  // UPDATE — admin status transitions (claim-gated by the rule)
  // ═══════════════════════════════════════════════════════════════

  /// Advances a request's status and stamps the audit fields. Only an
  /// admin/superadmin claim may call this successfully — the rule rejects the
  /// write otherwise, and rejects any attempt to also mutate the immutable
  /// request body (CWE-915).
  ///
  /// resolvedAt is set to the server time when moving to [MaintenanceStatus.resolved]
  /// and CLEARED (null) on any other status, so a reopened request loses its
  /// stale resolution time.
  Future<void> updateStatus({
    required String requestId,
    required MaintenanceStatus newStatus,
    required String handledByUid,
  }) async {
    await _ref.doc(requestId).update({
      'status': newStatus.toFirestoreValue(),
      'handledBy': handledByUid,
      'updatedAt': FieldValue.serverTimestamp(),
      'resolvedAt': newStatus == MaintenanceStatus.resolved
          ? FieldValue.serverTimestamp()
          : null,
    });
  }
}
