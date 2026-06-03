import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_role.dart';
// Re-exported so callers that `import '.../announcement.dart'` also see
// UserRole (the type of postedByRole) without a second import — mirroring
// how app_user.dart re-exports it.
export 'user_role.dart';

/// The visual / urgency tier of an announcement.
///
/// ─── WHY THIS PARSES DEFENSIVELY (UNLIKE UserRole / UserStatus) ──────
/// UserRole and UserStatus THROW on an unknown Firestore value because they
/// are SECURITY state — a malformed role must fail loud, never silently
/// degrade. Priority is the opposite: cosmetic display metadata on a
/// resident-facing feed. Two benign failure modes must NOT crash that feed:
///   1. Forward-compat: a newer app version posts an AnnouncementPriority
///      value an older client has never heard of.
///   2. A corrupt / hand-written doc with a missing or wrong-typed field.
/// In both cases we degrade to the LEAST-alarming tier ([info]) rather than
/// throw. This is deliberate, asymmetric, defensive input handling.
enum AnnouncementPriority {
  info,
  warning,
  critical;

  String toFirestoreValue() => name;

  /// Total, non-throwing parse: any unknown / missing / wrong-typed value
  /// maps to [info]. Accepts `Object?` (not `String`) so a null or a
  /// non-string read straight from `data['priority']` is handled without a
  /// cast that could itself throw.
  static AnnouncementPriority fromFirestoreValue(Object? value) {
    return AnnouncementPriority.values.firstWhere(
      (p) => p.name == value,
      orElse: () => AnnouncementPriority.info,
    );
  }
}

/// Domain representation of an announcement at /announcements/{id}.
///
/// ─── READ-SHAPED BY DESIGN ──────────────────────────────────────────
/// This model intentionally has NO `toFirestore()` / write map. Writes go
/// exclusively through [AnnouncementRepository.postAnnouncement], which
/// stamps `postedAt` with `FieldValue.serverTimestamp()` — a
/// server-authoritative time the client cannot forge or skew. Letting the
/// model emit a client-clock `postedAt` would reintroduce exactly that
/// trust problem, so the model only ever READS.
class Announcement {
  final String id;
  final String title;
  final String body;

  /// The Firebase Auth UID of the poster. The write rule (next step) pins
  /// this to `request.auth.uid`, so it cannot be forged at write time.
  final String postedBy;

  /// The role the poster held when posting (admin / superadmin). A mirror of
  /// the signed `{role}` claim; the write rule pins it to
  /// `request.auth.token.role`. Kept for display ("Posted by Admin") and
  /// audit — never a read-time security boundary.
  final UserRole postedByRole;

  /// Server-authoritative post time (FieldValue.serverTimestamp at write).
  final DateTime postedAt;

  final AnnouncementPriority priority;
  final bool pinned;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.postedBy,
    required this.postedByRole,
    required this.postedAt,
    required this.priority,
    required this.pinned,
  });

  /// Hydrates an [Announcement] from a Firestore document.
  ///
  /// The two-argument shape (with [SnapshotOptions]) mirrors
  /// `AppUser.fromFirestore` so this factory is drop-in compatible with
  /// `withConverter` if we adopt it later; today the repository maps
  /// snapshots manually (matching the UserRepository stream idiom).
  ///
  /// DEFENSIVE READS:
  ///   - `priority` falls back to [AnnouncementPriority.info] on any bad
  ///     value (see the enum doc) — never throws.
  ///   - `postedAt` tolerates a null / pending server timestamp (see the
  ///     inline note at the parse site below) — never throws.
  /// Genuinely corrupt identity fields (missing title / body / postedBy /
  /// postedByRole) still throw — that is data corruption we WANT to surface,
  /// matching the AppUser precedent for email / name / role.
  factory Announcement.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Announcement document "${snapshot.id}" has no data');
    }

    return Announcement(
      id: snapshot.id,
      title: data['title'] as String,
      body: data['body'] as String,
      postedBy: data['postedBy'] as String,
      postedByRole:
          UserRole.fromFirestoreValue(data['postedByRole'] as String),
      // postedAt is always a server timestamp when persisted: the repository writes
      // FieldValue.serverTimestamp() and this model is read-only (never writes postedAt
      // back). The `?? DateTime.now()` fallback applies ONLY to the transient local
      // snapshot during Firestore's latency-compensation / pending-write window in the
      // author's own session — it is never persisted and reconciles to the server value
      // on the next snapshot. Hence not client-controllable.
      postedAt: (data['postedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      priority: AnnouncementPriority.fromFirestoreValue(data['priority']),
      pinned: data['pinned'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'Announcement(id: $id, title: $title, '
      'postedByRole: ${postedByRole.name}, priority: ${priority.name}, '
      'pinned: $pinned)';
}
