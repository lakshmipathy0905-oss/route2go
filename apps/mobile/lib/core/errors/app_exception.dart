/// A typed, user-safe error. Every repository/provider in Route2Go throws
/// this instead of letting a raw platform/network exception reach the UI,
/// so screens can always show human language ("Route data is temporarily
/// unavailable") instead of "Exception: DioError 502".
class AppException implements Exception {
  const AppException({
    required this.code,
    required this.message,
    required this.retryable,
    this.requestId,
  });

  final String code;
  final String message;
  final bool retryable;
  final String? requestId;

  @override
  String toString() => 'AppException($code): $message';
}
