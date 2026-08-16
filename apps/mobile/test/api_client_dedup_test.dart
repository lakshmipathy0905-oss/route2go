import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:route2go/data/datasources/api_client.dart';
import 'package:route2go/presentation/providers/auth_provider.dart';

/// AuthRepository stub — no Firebase involved; returns a fixed guest token.
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => 'test-token';

  @override
  Future<UserCredential> signInWithGoogle() =>
      throw UnimplementedError('not used in this test');

  @override
  Future<UserCredential> signUpWithEmail(String email, String password) =>
      throw UnimplementedError('not used in this test');

  @override
  Future<UserCredential> signInWithEmail(String email, String password) =>
      throw UnimplementedError('not used in this test');

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      throw UnimplementedError('not used in this test');

  @override
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException e) onError,
  }) =>
      throw UnimplementedError('not used in this test');

  @override
  Future<UserCredential> confirmOtp({
    required String verificationId,
    required String smsCode,
  }) =>
      throw UnimplementedError('not used in this test');

  @override
  Future<void> signOut() => throw UnimplementedError('not used in this test');

  @override
  Future<void> deleteAccount() =>
      throw UnimplementedError('not used in this test');
}

/// Counts every HTTP fetch that reaches the transport layer.
class _CountingAdapter implements HttpClientAdapter {
  int requests = 0;
  final Duration? delay;

  _CountingAdapter({this.delay});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    if (delay != null) await Future<void>.delayed(delay!);
    return ResponseBody.fromString(
      '{"data":{"ok":true},"requestId":"r1"}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json']
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _client(_CountingAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://example.invalid'));
  dio.httpClientAdapter = adapter;
  return ApiClient(dio, _FakeAuthRepository());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('concurrent identical GETs share one HTTP request', () async {
    final adapter = _CountingAdapter(delay: const Duration(milliseconds: 50));
    final client = _client(adapter);

    final results = await Future.wait([
      client.get('/trips', queryParameters: {'limit': '10'}),
      client.get('/trips', queryParameters: {'limit': '10'}),
      client.get('/trips', queryParameters: {'limit': '10'}),
    ]);

    expect(adapter.requests, 1, reason: 'identical in-flight GETs are deduped');
    expect(results, hasLength(3));
    expect(results[0]['data'], results[1]['data']);
    expect(results[2]['requestId'], 'r1');
  });

  test('an immediate re-fetch of the same GET is served from the short memo',
      () async {
    final adapter = _CountingAdapter();
    final client = _client(adapter);

    await client.get('/profile');
    await client.get('/profile');

    expect(adapter.requests, 1,
        reason: 'second identical GET within TTL reuses the memoized answer');
  });

  test('dedup key includes query parameters (no cross-query sharing)',
      () async {
    final adapter = _CountingAdapter();
    final client = _client(adapter);

    await client.get('/trips', queryParameters: {'limit': '10'});
    await client.get('/trips', queryParameters: {'limit': '20'});

    expect(adapter.requests, 2,
        reason: 'different query parameters are distinct requests');
  });

  test('memo does not apply across different paths', () async {
    final adapter = _CountingAdapter();
    final client = _client(adapter);

    await client.get('/trips');
    await client.get('/vehicles');

    expect(adapter.requests, 2);
  });
}
