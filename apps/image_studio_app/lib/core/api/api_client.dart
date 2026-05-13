import 'package:dio/dio.dart';

import 'api_error.dart';

typedef TokenProvider = Future<String?> Function();

class ApiClient {
  ApiClient({required Dio dio, required TokenProvider tokenProvider})
    : _dio = dio,
      _tokenProvider = tokenProvider {
    _dio.interceptors.add(authInterceptor);
  }

  final Dio _dio;
  final TokenProvider _tokenProvider;

  late final InterceptorsWrapper authInterceptor = InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = _normalizeToken(await _tokenProvider());
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
  );

  String? _normalizeToken(String? rawToken) {
    final token = rawToken?.trim() ?? '';
    if (token.isEmpty) {
      return null;
    }
    if (token.toLowerCase().startsWith('bearer ')) {
      return token.substring(7).trim();
    }
    return token;
  }

  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, Object?>? query,
  }) async {
    final response = await _dio.get<Object?>(
      path,
      queryParameters: query,
      options: Options(responseType: ResponseType.json),
    );
    return _decodeMap(response, path);
  }

  Future<Map<String, Object?>> postJson(String path, {Object? body}) async {
    final response = await _dio.post<Object?>(
      path,
      data: body ?? <String, Object?>{},
      options: Options(responseType: ResponseType.json),
    );
    return _decodeMap(response, path);
  }

  Future<Map<String, Object?>> patchJson(String path, {Object? body}) async {
    final response = await _dio.patch<Object?>(
      path,
      data: body ?? <String, Object?>{},
      options: Options(responseType: ResponseType.json),
    );
    return _decodeMap(response, path);
  }

  Future<Map<String, Object?>> deleteJson(String path) async {
    final response = await _dio.delete<Object?>(
      path,
      options: Options(responseType: ResponseType.json),
    );
    return _decodeMap(response, path);
  }

  Map<String, Object?> _decodeMap(Response<Object?> response, String path) {
    final data = response.data;
    if (data == null) {
      return <String, Object?>{};
    }
    if (data is Map<String, Object?>) {
      return data;
    }
    if (data is Map) {
      return Map<String, Object?>.from(data);
    }
    throw ApiError(
      message:
          '这个地址返回的不是可用的 chatgpt2api API 响应。请确认后端已更新到当前分支，并且地址指向后端 API 服务：$path',
      statusCode: response.statusCode,
    );
  }
}
