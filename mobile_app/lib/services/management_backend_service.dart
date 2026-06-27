import 'package:cloud_functions/cloud_functions.dart';

class ManagementBackendException implements Exception {
  final String message;

  const ManagementBackendException(this.message);

  @override
  String toString() => message;
}

class ManagementBackendService {
  static const String _region = 'asia-southeast1';

  final FirebaseFunctions _functions;

  ManagementBackendService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instanceFor(region: _region);

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
