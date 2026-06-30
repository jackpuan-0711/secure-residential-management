import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/announcement.dart';

/// The single chokepoint for all reads and writes to /announcements/{id}.
///
/// THREAT MODEL NOTE (read before adding methods):
///   This repository is a CONVENIENCE API over Firestore, not a security
///   boundary. Authorization for posting is enforced SERVER-SIDE by the
///   Firestore rule (next step), claim-gated to admin / superadmin. The
///   client cannot be trusted to gate itself — "security is server-enforced,
///   not client-enforced."
class AnnouncementRepository {
  final FirebaseFirestore _firestore;

  AnnouncementRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════
  // CREATE
  // ═══════════════════════════════════════════════════════════════

  /// Posts a new announcement to /announcements/{autoId}.
  ///
  /// `postedAt` is stamped with [FieldValue.serverTimestamp] so the time is
  /// server-authoritative — never the (forgeable, clock-skewed) client time.
  ///
  /// ─── VIVA NOTE: THIS METHOD DOES NOT DECIDE WHO MAY POST ────────────
  /// `postedBy` / `postedByRole` are recorded here, but they are NOT trusted
  /// on their own. The authoritative gate is the server-side Firestore rule
  /// (rules + indexes step), claim-gated to admin / superadmin, which will
  /// ALSO verify, at write time:
  ///     request.resource.data.postedBy     == request.auth.uid
  ///     request.resource.data.postedByRole == request.auth.token.role
  /// So a tampered client cannot forge another user's authorship, nor post
  /// at all without the claim. This is "security is server-enforced, not
  /// client-enforced" in practice — this method is a convenience layer over
  /// an already-authorized write, never the trust boundary.
  /// ───────────────────────────────────────────────────────────────────
  Future<void> postAnnouncement({
    required String title,
    required String body,
    required String postedBy,
    required UserRole postedByRole,
    AnnouncementPriority priority = AnnouncementPriority.info,
    bool pinned = false,
  }) async {
    await _firestore.collection('announcements').add({
      'title': title,
      'body': body,
      'postedBy': postedBy,
      'postedByRole': postedByRole.toFirestoreValue(),
      'priority': priority.toFirestoreValue(),
      'pinned': pinned,
      // Server-authoritative timestamp; the model never writes a client one.
      'postedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Edits mutable announcement content while preserving original authorship
  /// and post time. Firestore rules require the edit audit fields to match the
  /// signed-in administrator and the server request time.
  Future<void> updateAnnouncement({
    required String announcementId,
    required String title,
    required String body,
    required String editedBy,
    required AnnouncementPriority priority,
    required bool pinned,
  }) async {
    await _firestore.collection('announcements').doc(announcementId).update({
      'title': title,
      'body': body,
      'priority': priority.toFirestoreValue(),
      'pinned': pinned,
      'editedBy': editedBy,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // READ
  // ═══════════════════════════════════════════════════════════════

  /// Live feed of all announcements: pinned first, then newest first.
  ///
  /// Snapshots are mapped manually (not via `withConverter`) to match the
  /// UserRepository stream idiom (see `listPendingResidents`).
  ///
  /// ─── COMPOSITE INDEX NOTE ──────────────────────────────────────────
  /// The compound `orderBy('pinned', desc).orderBy('postedAt', desc)`
  /// requires a Firestore COMPOSITE INDEX on (pinned DESC, postedAt DESC).
  /// That index is declared in firestore.indexes.json in the rules + indexes
  /// step; without it, real Firestore returns FAILED_PRECONDITION. The unit
  /// tests assert membership / count only — fake_cloud_firestore does not
  /// faithfully reproduce multi-field ordering, so the true ordering is
  /// verified against the Firestore emulator in that later step.
  /// ───────────────────────────────────────────────────────────────────
  Stream<List<Announcement>> watchAnnouncements() {
    return _firestore
        .collection('announcements')
        .orderBy('pinned', descending: true)
        .orderBy('postedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Announcement.fromFirestore(d, null))
              .toList(),
        );
  }
}
