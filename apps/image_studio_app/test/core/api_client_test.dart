import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/core/api/api_client.dart';
import 'package:image_studio_app/core/api/api_error.dart';

void main() {
  test('adds bearer token to requests', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    final client = ApiClient(dio: dio, tokenProvider: () async => 'sk-test');

    final options = RequestOptions(path: '/api/projects');
    final handler = _RequestHandler();
    client.authInterceptor.onRequest(options, handler);
    await Future<void>.delayed(Duration.zero);

    expect(handler.options.headers['Authorization'], 'Bearer sk-test');
  });

  test(
    'does not duplicate bearer scheme when user pastes a full header',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      final client = ApiClient(
        dio: dio,
        tokenProvider: () async => 'Bearer sk-test',
      );

      final options = RequestOptions(path: '/api/projects');
      final handler = _RequestHandler();
      client.authInterceptor.onRequest(options, handler);
      await Future<void>.delayed(Duration.zero);

      expect(handler.options.headers['Authorization'], 'Bearer sk-test');
    },
  );

  test('rejects html responses with a clear api compatibility error', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.httpClientAdapter = _StaticAdapter(
      ResponseBody.fromString(
        '<!DOCTYPE html><title>ChatGPT 号池管理</title>',
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['text/html; charset=utf-8'],
        },
      ),
    );
    final client = ApiClient(dio: dio, tokenProvider: () async => 'sk-test');

    await expectLater(
      client.getJson('/api/app/bootstrap'),
      throwsA(
        isA<ApiError>().having(
          (error) => error.message,
          'message',
          contains('不是可用的 chatgpt2api API'),
        ),
      ),
    );
  });

  test('normalizes structured backend errors', () {
    final error = ApiError.fromDioException(
      DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        response: Response<Object?>(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 401,
          data: <String, Object?>{
            'detail': <String, Object?>{'error': '密钥无效或已失效，请重新登录'},
          },
        ),
      ),
    );

    expect(error.message, '密钥无效或已失效，请重新登录');
    expect(error.statusCode, 401);
  });

  test('maps 405 from a stale backend to a friendly message', () {
    final error = ApiError.fromDioException(
      DioException(
        requestOptions: RequestOptions(path: '/api/image-turns/abc'),
        response: Response<Object?>(
          requestOptions: RequestOptions(path: '/api/image-turns/abc'),
          statusCode: 405,
          data: <String, Object?>{'detail': 'Method Not Allowed'},
        ),
      ),
    );

    expect(error.message, contains('服务端版本过旧'));
    expect(error.statusCode, 405);
  });

  test('maps connection errors to a friendly network message', () {
    final error = ApiError.fromDioException(
      DioException(
        requestOptions: RequestOptions(path: '/api/projects'),
        type: DioExceptionType.connectionError,
        error: 'connection refused',
      ),
    );

    expect(error.message, contains('无法连接到服务端'));
  });
}

class _RequestHandler extends RequestInterceptorHandler {
  late RequestOptions options;

  @override
  void next(RequestOptions requestOptions) {
    options = requestOptions;
  }
}

class _StaticAdapter implements HttpClientAdapter {
  const _StaticAdapter(this._body);

  final ResponseBody _body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _body;
  }

  @override
  void close({bool force = false}) {}
}
