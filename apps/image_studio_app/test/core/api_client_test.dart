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
}

class _RequestHandler extends RequestInterceptorHandler {
  late RequestOptions options;

  @override
  void next(RequestOptions requestOptions) {
    options = requestOptions;
  }
}
