import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/models/announcement.dart';
import 'package:mobile_app/services/announcement_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late AnnouncementRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = AnnouncementRepository(firestore: fakeFirestore);
  });

  // Lets a stream subscription pump its microtasks before we assert.
  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // postAnnouncement
  // ═══════════════════════════════════════════════════════════════

  group('postAnnouncement', () {
    test(
      'writes a doc with all expected fields and a server postedAt',
      () async {
        await repository.postAnnouncement(
          title: 'Pool Maintenance',
          body: 'The pool will be closed Monday.',
          postedBy: 'admin-001',
          postedByRole: UserRole.admin,
          priority: AnnouncementPriority.warning,
          pinned: true,
        );

        final snap = await fakeFirestore.collection('announcements').get();
        expect(snap.docs.length, 1);

        final data = snap.docs.first.data();
        expect(data['title'], 'Pool Maintenance');
        expect(data['body'], 'The pool will be closed Monday.');
        expect(data['postedBy'], 'admin-001');
        expect(data['postedByRole'], 'admin');
        expect(data['priority'], 'warning');
        expect(data['pinned'], isTrue);
        expect(
          data['postedAt'],
          isA<Timestamp>(),
          reason: 'postedAt must be a server timestamp, not a client clock',
        );
      },
    );

    test('defaults priority to info and pinned to false', () async {
      await repository.postAnnouncement(
        title: 'General Notice',
        body: 'A general notice for residents.',
        postedBy: 'super-001',
        postedByRole: UserRole.superadmin,
      );

      final snap = await fakeFirestore.collection('announcements').get();
      final data = snap.docs.first.data();
      expect(data['priority'], 'info');
      expect(data['pinned'], isFalse);
    });

    test('serializes postedByRole as its claim string', () async {
      await repository.postAnnouncement(
        title: 'By Superadmin',
        body: 'Posted by a superadmin.',
        postedBy: 'super-001',
        postedByRole: UserRole.superadmin,
      );

      final snap = await fakeFirestore.collection('announcements').get();
      expect(snap.docs.first.data()['postedByRole'], 'superadmin');
    });
  });

  group('updateAnnouncement', () {
    test(
      'updates content and records the editor without changing authorship',
      () async {
        await repository.postAnnouncement(
          title: 'Original',
          body: 'Original body',
          postedBy: 'admin-001',
          postedByRole: UserRole.admin,
        );
        final original =
            (await fakeFirestore.collection('announcements').get()).docs.single;
        final originalPostedAt = original.data()['postedAt'];

        await repository.updateAnnouncement(
          announcementId: original.id,
          title: 'Corrected',
          body: 'Corrected body',
          editedBy: 'super-001',
          priority: AnnouncementPriority.warning,
          pinned: true,
        );

        final data = (await original.reference.get()).data()!;
        expect(data['title'], 'Corrected');
        expect(data['body'], 'Corrected body');
        expect(data['priority'], 'warning');
        expect(data['pinned'], isTrue);
        expect(data['editedBy'], 'super-001');
        expect(data['editedAt'], isA<Timestamp>());
        expect(data['postedBy'], 'admin-001');
        expect(data['postedAt'], originalPostedAt);
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════
  // Serialization round-trip (write via repo → read via fromFirestore)
  // ═══════════════════════════════════════════════════════════════

  group('serialization round-trip', () {
    test('round-trips every field through fromFirestore', () async {
      await repository.postAnnouncement(
        title: 'Fire Drill',
        body: 'Scheduled fire drill at 10am.',
        postedBy: 'super-001',
        postedByRole: UserRole.superadmin,
        priority: AnnouncementPriority.critical,
        pinned: true,
      );

      final snap = await fakeFirestore.collection('announcements').get();
      final doc = snap.docs.first;
      final announcement = Announcement.fromFirestore(doc, null);

      expect(announcement.id, doc.id);
      expect(announcement.title, 'Fire Drill');
      expect(announcement.body, 'Scheduled fire drill at 10am.');
      expect(announcement.postedBy, 'super-001');
      expect(announcement.postedByRole, UserRole.superadmin);
      expect(announcement.priority, AnnouncementPriority.critical);
      expect(announcement.pinned, isTrue);
      expect(announcement.postedAt, isA<DateTime>());
    });

    test('fromFirestore falls back to info on a malformed priority '
        '(does NOT throw on bad data)', () async {
      // A corrupt / future-version doc written directly, bypassing the repo.
      await fakeFirestore.collection('announcements').doc('bad-1').set({
        'title': 'Mystery',
        'body': 'Posted with an unknown priority.',
        'postedBy': 'admin-001',
        'postedByRole': 'admin',
        'priority': 'extraterrestrial', // not a known tier
        'pinned': false,
        'postedAt': FieldValue.serverTimestamp(),
      });

      final doc = await fakeFirestore
          .collection('announcements')
          .doc('bad-1')
          .get();
      final announcement = Announcement.fromFirestore(doc, null);

      expect(
        announcement.priority,
        AnnouncementPriority.info,
        reason: 'a malformed priority must degrade, not crash the feed',
      );
    });

    test('fromFirestore tolerates a null/pending postedAt but stays strict on '
        'corrupt identity fields', () async {
      // A null postedAt mimics Firestore's latency-compensation / pending-write
      // window, where the author's own local snapshot sees serverTimestamp()
      // as null before it resolves. fromFirestore must yield a non-null
      // DateTime and must NOT throw.
      await fakeFirestore.collection('announcements').doc('pending-1').set({
        'title': 'Pending',
        'body': 'Posted moments ago.',
        'postedBy': 'admin-001',
        'postedByRole': 'admin',
        'priority': 'info',
        'pinned': false,
        'postedAt': null,
      });

      final pendingDoc = await fakeFirestore
          .collection('announcements')
          .doc('pending-1')
          .get();
      final announcement = Announcement.fromFirestore(pendingDoc, null);
      expect(
        announcement.postedAt,
        isA<DateTime>(),
        reason: 'a pending/null postedAt must resolve to a non-null DateTime',
      );
      expect(
        announcement.title,
        'Pending',
        reason: 'the rest of a valid doc still hydrates normally',
      );

      // Strictness is TARGETED, not blanket: a genuinely corrupt doc (missing
      // title) must still throw — identity fields are never leniently defaulted.
      await fakeFirestore.collection('announcements').doc('corrupt-1').set({
        // 'title' intentionally omitted — simulates data corruption.
        'body': 'No title.',
        'postedBy': 'admin-001',
        'postedByRole': 'admin',
        'priority': 'info',
        'pinned': false,
        'postedAt': FieldValue.serverTimestamp(),
      });

      final corruptDoc = await fakeFirestore
          .collection('announcements')
          .doc('corrupt-1')
          .get();
      expect(
        () => Announcement.fromFirestore(corruptDoc, null),
        throwsA(isA<TypeError>()),
        reason: 'missing title must surface as a cast error, not be masked',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // AnnouncementPriority enum mapping
  // ═══════════════════════════════════════════════════════════════

  group('AnnouncementPriority', () {
    test('serializes every value to its Firestore string', () {
      expect(AnnouncementPriority.info.toFirestoreValue(), 'info');
      expect(AnnouncementPriority.warning.toFirestoreValue(), 'warning');
      expect(AnnouncementPriority.critical.toFirestoreValue(), 'critical');
    });

    test('deserializes every known value', () {
      expect(
        AnnouncementPriority.fromFirestoreValue('info'),
        AnnouncementPriority.info,
      );
      expect(
        AnnouncementPriority.fromFirestoreValue('warning'),
        AnnouncementPriority.warning,
      );
      expect(
        AnnouncementPriority.fromFirestoreValue('critical'),
        AnnouncementPriority.critical,
      );
    });

    test('round-trips every value through serialize → deserialize', () {
      for (final p in AnnouncementPriority.values) {
        expect(
          AnnouncementPriority.fromFirestoreValue(p.toFirestoreValue()),
          p,
        );
      }
    });

    test('falls back to info on unknown / empty / missing / wrong-typed', () {
      expect(
        AnnouncementPriority.fromFirestoreValue('emergency'),
        AnnouncementPriority.info,
        reason: 'forward-compat: an unknown future tier must not crash',
      );
      expect(
        AnnouncementPriority.fromFirestoreValue(''),
        AnnouncementPriority.info,
      );
      expect(
        AnnouncementPriority.fromFirestoreValue(null),
        AnnouncementPriority.info,
        reason: 'a missing priority field must not crash the feed',
      );
      expect(
        AnnouncementPriority.fromFirestoreValue(42),
        AnnouncementPriority.info,
        reason: 'a wrong-typed value must not crash the feed',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // watchAnnouncements
  // ═══════════════════════════════════════════════════════════════
  //
  // NOTE ON ORDERING: these tests assert MEMBERSHIP and COUNT, not order.
  // The compound orderBy (pinned desc, postedAt desc) needs a composite
  // index, and fake_cloud_firestore does not faithfully reproduce
  // multi-field ordering. True ordering is verified against the Firestore
  // emulator in the rules + index step.

  group('watchAnnouncements', () {
    test('emits all posted announcements', () async {
      await repository.postAnnouncement(
        title: 'A',
        body: 'body a',
        postedBy: 'admin-001',
        postedByRole: UserRole.admin,
      );
      await repository.postAnnouncement(
        title: 'B',
        body: 'body b',
        postedBy: 'admin-001',
        postedByRole: UserRole.admin,
        pinned: true,
      );

      final emissions = <List<Announcement>>[];
      final sub = repository.watchAnnouncements().listen(emissions.add);
      await settle();
      await sub.cancel();

      expect(emissions, isNotEmpty);
      expect(emissions.last.length, 2);
      expect(emissions.last.map((a) => a.title).toSet(), {'A', 'B'});
    });

    test('emits an empty list when there are no announcements', () async {
      final emissions = <List<Announcement>>[];
      final sub = repository.watchAnnouncements().listen(emissions.add);
      await settle();
      await sub.cancel();

      expect(emissions, isNotEmpty);
      expect(emissions.last, isEmpty);
    });

    test('reflects a newly posted announcement on the live stream', () async {
      final emissions = <List<Announcement>>[];
      final sub = repository.watchAnnouncements().listen(emissions.add);
      await settle();

      await repository.postAnnouncement(
        title: 'Live',
        body: 'just posted',
        postedBy: 'admin-001',
        postedByRole: UserRole.admin,
      );
      await settle();
      await sub.cancel();

      expect(emissions.last.map((a) => a.title), contains('Live'));
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Security invariants (mirrors the UserRepository discipline)
  // ═══════════════════════════════════════════════════════════════

  group('security invariants', () {
    test('INVARIANT: postedBy / postedByRole are REQUIRED — no API path to an '
        'unauthored announcement', () async {
      // Type-level assertion. postedBy and postedByRole are required named
      // params: the method surface offers NO way to create an announcement
      // with a missing or defaulted author. Forging another user's
      // authorship is additionally blocked server-side — the write rule
      // pins postedBy == request.auth.uid and
      // postedByRole == request.auth.token.role.
      await repository.postAnnouncement(
        title: 'Authored',
        body: 'Has an author by construction.',
        postedBy: 'admin-001',
        postedByRole: UserRole.admin,
      );

      final snap = await fakeFirestore.collection('announcements').get();
      final data = snap.docs.single.data();
      expect(data['postedBy'], 'admin-001');
      expect(data['postedByRole'], 'admin');
    });
  });
}
