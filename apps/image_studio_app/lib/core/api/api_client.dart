import 'package:dio/dio.dart';

typedef TokenProvider = Future<String?> Function();

class ApiClient {
  ApiClient({
    required Dio dio,
    required TokenProvider tokenProvider,
  }) : _dio = dio,
       _tokenProvider = tokenProvider {
    _dio.interceptors.add(authInterceptor);
  }

  final Dio _dio;
  final TokenProvider _tokenProvider;

  late final InterceptorsWrapper authInterceptor = InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await _tokenProvider();
      if (token != null && token.trim().isNotEmpty) {
        options.headers['Authorization'] = 'Bearer ${token.trim()}';
      }
      handler.next(options);
    },
  );

  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?>? query,
  }) async {
    final response = await _dio.get<Map<String, Object?>>(
      path,
      queryParameters: query,
    );
    return response.data ?? <String, Object?>{};
  }

  Future<Map<String, Object?>> postJson(String path, {Object? body}) async {
    final response = await _dio.post<Map<String, Object?>>(
      path,
      data: body ?? <String, Object?>{},
    );
    return response.data ?? <String, Object?>{};
  }

  Future<Map<String, Object?>> patchJson(String path, {Object? body}) async {
    final response = await _dio.patch<Map<String, Object?>>(
      path,
      data: body ?? <String, Object?>{},
    );
    return response.data ?? <String, Object?>{};
  }

  Future<Map<String, Object?>> deleteJson(String path) async {
    final response = await _dio.delete<Map<String, Object?>>(path);
    return response.data ?? <String, Object?>{};
  }
}
