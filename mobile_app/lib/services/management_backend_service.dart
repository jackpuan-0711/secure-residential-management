import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/app_user.dart';
import 'user_repository.dart';

class ManagementBackendException implements Exception {
  final String message;

  const ManagementBackendException(this.message);

  @override
  String toString() => message;
}

class ManagedAdminAccount {
  final String uid;
  final String email;
  final String name;
  final DateTime createdAt;

  const ManagedAdminAccount({
    required this.uid,
    required this.email,
    required this.name,
    required this.createdAt,
  });

  factory ManagedAdminAccount.fromMap(Map<dynamic, dynamic> data) {
    return ManagedAdminAccount(
      uid: data['uid'] as String,
      email: data['email'] as String,
      name: data['name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (data['createdAtMillis'] as num).toInt(),
      ),
    );
  }
}

class ManagedAdminAccounts {
  final List<ManagedAdminAccount> admins;

  const ManagedAdminAccounts({required this.admins});
}

class ManagementBackendService {
  static const String _region = 'asia-southeast1';

  final FirebaseFunctions _functions;
  final UserRepository? _usersOverride;
  final FirebaseAuth? _authOverride;

  ManagementBackendService({
    FirebaseFunctions? functions,
    UserRepository? users,
    FirebaseAuth? auth,
  }) : _functions = functions ?? FirebaseFunctions.instanceFor(region: _region),
       _usersOverride = users,
       _authOverride = auth;

  UserRepository get _users => _usersOverride ?? UserRepository();
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  ManagedAdminAccount _toManagedAccount(AppUser user) {
    return ManagedAdminAccount(
      uid: user.uid,
      email: user.email,
      name: user.name,
      createdAt: user.createdAt,
    );
  }

  Future<ManagedAdminAccounts> listAdminAccounts() async {
    try {
      final admins = await _users.watchAdministrators().first;
      return ManagedAdminAccounts(
        admins: admins.map(_toManagedAccount).toList(growable: false),
      );
    } catch (error) {
      throw ManagementBackendException(
        'Could not read administrator accounts: $error',
      );
    }
  }

  Stream<ManagedAdminAccounts> watchAdminAccounts() {
    return _users.watchAdministrators().map(
      (admins) => ManagedAdminAccounts(
        admins: admins.map(_toManagedAccount).toList(growable: false),
      ),
    );
  }

  Future<ManagedAdminAccount> findAdminCandidate({
    required String email,
  }) async {
    try {
      final candidate = await _users.findAdminCandidateByEmail(email);
      return _toManagedAccount(candidate);
    } on UserRepositoryException catch (error) {
      throw ManagementBackendException(error.message);
    } catch (error) {
      throw ManagementBackendException('Account search failed: $error');
    }
  }

  Future<void> addAdmin({required String email}) async {
    final actor = _auth.currentUser;
    if (actor == null) {
      throw const ManagementBackendException('Please sign in again.');
    }
    try {
      final candidate = await _users.findAdminCandidateByEmail(email);
      await _users.promoteToAdministrator(
        targetUid: candidate.uid,
        approvedByUid: actor.uid,
      );
    } on UserRepositoryException catch (error) {
      throw ManagementBackendException(error.message);
    } catch (error) {
      throw ManagementBackendException('Could not add administrator: $error');
    }
  }

  Future<void> removeAdmin({required String targetUid}) async {
    final actor = _auth.currentUser;
    if (actor == null) {
      throw const ManagementBackendException('Please sign in again.');
    }
    try {
      await _users.removeAdministratorPermission(
        targetUid: targetUid,
        removedByUid: actor.uid,
      );
    } on UserRepositoryException catch (error) {
      throw ManagementBackendException(error.message);
    } catch (error) {
      throw ManagementBackendException(
        'Could not remove administrator: $error',
      );
    }
  }

  Future<String> startEvCharging({required String stationId}) async {
    final result = await _call('startEvCharging', {'stationId': stationId});
    final data = result.data;
    if (data is Map && data['sessionId'] is String) {
      return data['sessionId'] as String;
    }
    throw const ManagementBackendException(
      'Charging started, but the server did not return a session id.',
    );
  }

  Future<void> stopEvCharging({required String stationId}) async {
    await _call('stopEvCharging', {'stationId': stationId});
  }

  Future<HttpsCallableResult<dynamic>> _call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    try {
      return await _functions.httpsCallable(name).call<dynamic>(data);
    } on FirebaseFunctionsException catch (e) {
      throw ManagementBackendException(_humanizeFunctionsError(e));
    } catch (e) {
      throw ManagementBackendException('Server request failed: $e');
    }
  }

  String _humanizeFunctionsError(FirebaseFunctionsException e) {
    final message = e.message;
    if (message != null && message.trim().isNotEmpty) {
      return message;
    }

    switch (e.code) {
      case 'unauthenticated':
        return 'Please sign in again.';
      case 'permission-denied':
        return 'You do not have permission to perform this action.';
      case 'failed-precondition':
        return 'This action is not available for the current record.';
      case 'not-found':
        return 'The requested record was not found.';
      case 'unavailable':
        return 'The server is temporarily unavailable. Please try again.';
      default:
        return 'Server request failed (${e.code}).';
    }
  }
}
