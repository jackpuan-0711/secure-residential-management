import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/models/maintenance_request.dart';
import 'package:mobile_app/services/maintenance_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MaintenanceRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = MaintenanceRepository(firestore: firestore);
  });

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<String> createOne({
    String residentId = 'resident-1',
    String unitNumber = 'A-12-5',
    MaintenanceCategory category = MaintenanceCategory.plumbing,
    String title = 'Leaking tap',
    String description = 'The kitchen tap drips constantly.',
  }) async {
    await repository.createRequest(
      residentId: residentId,
      unitNumber: unitNumber,
      category: category,
      title: title,
      description: description,
    );
    final snap = await firestore
        .collection('maintenance_requests')
        .where('residentId', isEqualTo: residentId)
        .where('title', isEqualTo: title)
        .get();
    return snap.docs.first.id;
  }

  // ═══════════════════════════════════════════════════════════════
  // createRequest
  // ═══════════════════════════════════════════════════════════════

  group('createRequest', () {
    test(
      'writes a pending request with server timestamps + null audit',
      () async {
        await repository.createRequest(
          residentId: 'resident-1',
          unitNumber: 'A-12-5',
          category: MaintenanceCategory.electrical,
          title: 'No power in bedroom',
          description: 'The bedroom sockets are dead.',
        );

        final snap = await firestore.collection('maintenance_requests').get();
        expect(snap.docs.length, 1);
        final data = snap.docs.first.data();
        expect(data['residentId'], 'resident-1');
        expect(data['unitNumber'], 'A-12-5');
        expect(data['category'], 'electrical');
        expect(data['title'], 'No power in bedroom');
        expect(data['status'], 'pending');
        expect(data['handledBy'], isNull);
        expect(data['resolvedAt'], isNull);
        expect(
          data['createdAt'],
          isA<Timestamp>(),
          reason: 'createdAt must be a server timestamp',
        );
        expect(data['updatedAt'], isA<Timestamp>());
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════
  // watch
  // ═══════════════════════════════════════════════════════════════

  group('watchMyRequests / watchAllRequests', () {
    test('watchMyRequests returns only the caller\'s requests', () async {
      await createOne(residentId: 'resident-1', title: 'Mine');
      await createOne(residentId: 'resident-2', title: 'Theirs');

      final emissions = <List<MaintenanceRequest>>[];
      final sub = repository
          .watchMyRequests('resident-1')
          .listen(emissions.add);
      await settle();
      await sub.cancel();

      expect(emissions.last.length, 1);
      expect(emissions.last.single.title, 'Mine');
    });

    test('watchAllRequests returns every request', () async {
      await createOne(residentId: 'resident-1', title: 'A');
      await createOne(residentId: 'resident-2', title: 'B');

      final emissions = <List<MaintenanceRequest>>[];
      final sub = repository.watchAllRequests().listen(emissions.add);
      await settle();
      await sub.cancel();

      expect(emissions.last.length, 2);
      expect(emissions.last.map((r) => r.title).toSet(), {'A', 'B'});
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // updateStatus
  // ═══════════════════════════════════════════════════════════════

  group('updateStatus', () {
    test('resolving stamps handledBy + resolvedAt', () async {
      final id = await createOne();
      await repository.updateStatus(
        requestId: id,
        newStatus: MaintenanceStatus.resolved,
        handledByUid: 'admin-1',
      );

      final data = await firestore
          .collection('maintenance_requests')
          .doc(id)
          .get();
      expect(data.data()!['status'], 'resolved');
      expect(data.data()!['handledBy'], 'admin-1');
      expect(data.data()!['resolvedAt'], isA<Timestamp>());
    });

    test('a non-resolved status clears any stale resolvedAt', () async {
      final id = await createOne();
      // Resolve, then reopen to in-progress.
      await repository.updateStatus(
        requestId: id,
        newStatus: MaintenanceStatus.resolved,
        handledByUid: 'admin-1',
      );
      await repository.updateStatus(
        requestId: id,
        newStatus: MaintenanceStatus.inProgress,
        handledByUid: 'admin-1',
      );

      final data = await firestore
          .collection('maintenance_requests')
          .doc(id)
          .get();
      expect(data.data()!['status'], 'inProgress');
      expect(
        data.data()!['resolvedAt'],
        isNull,
        reason: 'a reopened request must lose its stale resolution time',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Model defensive parsing (mirrors Announcement discipline)
  // ═══════════════════════════════════════════════════════════════

  group('MaintenanceRequest.fromFirestore', () {
    test(
      'degrades unknown category → other and unknown status → pending',
      () async {
        await firestore.collection('maintenance_requests').doc('bad-1').set({
          'residentId': 'resident-1',
          'unitNumber': 'A-12-5',
          'category': 'teleportation', // unknown
          'title': 'Mystery',
          'description': 'Unknown category and status.',
          'status': 'levitating', // unknown
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'handledBy': null,
          'resolvedAt': null,
        });

        final doc = await firestore
            .collection('maintenance_requests')
            .doc('bad-1')
            .get();
        final req = MaintenanceRequest.fromFirestore(doc, null);
        expect(req.category, MaintenanceCategory.other);
        expect(req.status, MaintenanceStatus.pending);
      },
    );

    test('throws on a corrupt identity field (missing title)', () async {
      await firestore.collection('maintenance_requests').doc('corrupt').set({
        'residentId': 'resident-1',
        'unitNumber': 'A-12-5',
        'category': 'plumbing',
        // title intentionally omitted
        'description': 'No title.',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final doc = await firestore
          .collection('maintenance_requests')
          .doc('corrupt')
          .get();
      expect(
        () => MaintenanceRequest.fromFirestore(doc, null),
        throwsA(isA<TypeError>()),
      );
    });

    test('every category and status round-trips', () {
      for (final c in MaintenanceCategory.values) {
        expect(MaintenanceCategory.fromFirestoreValue(c.toFirestoreValue()), c);
      }
      for (final s in MaintenanceStatus.values) {
        expect(MaintenanceStatus.fromFirestoreValue(s.toFirestoreValue()), s);
      }
    });
  });
}
