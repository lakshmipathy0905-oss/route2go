import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/providers/auth_provider.dart';
import '../../core/errors/app_exception.dart';

/// Thin wrapper around Dio that:
///  - points at the Supabase Edge Functions base URL
///  - attaches the Firebase ID token as a bearer token on every request
///  - falls back to a literal "guest" token for unauthenticated calls that
///    are explicitly allowed in guest mode (route calculation only)
///  - converts network/HTTP failures into typed AppException so the UI
///    layer never has to parse raw DioException/stack traces
class ApiClient {
  ApiClient(this._dio, this._authRepository);

  final Dio _dio;
  final AuthRepository _authRepository;

  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> body,
    bool allowGuest = false,
  }) async {
    try {
      final token = await _resolveToken(allowGuest: allowGuest);
      final response = await _dio.post(
        path,
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool allowGuest = false,
  }) async {
    try {
      final token = await _resolveToken(allowGuest: allowGuest);
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    required Map<String, dynamic> body,
    bool allowGuest = false,
  }) async {
    try {
      final token = await _resolveToken(allowGuest: allowGuest);
      final response = await _dio.patch(
        path,
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool allowGuest = false,
  }) async {
    try {
      final token = await _resolveToken(allowGuest: allowGuest);
      final response = await _dio.delete(
        path,
        queryParameters: queryParameters,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<String> _resolveToken({required bool allowGuest}) async {
    final token = await _authRepository.getIdToken();
    if (token != null) return token;
    if (allowGuest) return 'guest';
    throw const AppException(
      code: 'UNAUTHENTICATED',
      message: 'Please sign in to continue.',
      retryable: false,
    );
  }

  AppException _mapDioException(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['code'] != null) {
      return AppException(
        code: data['code'] as String,
        message: data['message'] as String? ?? 'Something went wrong.',
        retryable: data['retryable'] as bool? ?? false,
        requestId: data['requestId'] as String?,
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const AppException(
        code: 'NETWORK_UNAVAILABLE',
        message: 'No internet connection. Please check your connection and try again.',
        retryable: true,
      );
    }
    return const AppException(
      code: 'UNKNOWN_ERROR',
      message: 'Something went wrong. Please try again.',
      retryable: true,
    );
  }
}

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      // Set via --dart-define=SUPABASE_FUNCTIONS_URL=... at build time; see .env.example
      baseUrl: const String.fromEnvironment(
        'SUPABASE_FUNCTIONS_URL',
        defaultValue: 'https://YOUR_PROJECT_REF.supabase.co/functions/v1',
      ),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider), ref.watch(authRepositoryProvider));
});
