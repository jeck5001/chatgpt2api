import 'package:dio/dio.dart';

class ApiError implements Exception {
  const ApiError({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiError.fromDioException(DioException exception) {
    final response = exception.response;
    final statusCode = response?.statusCode;
    final data = response?.data;
    // Structured backend errors (our app's `detail.error` shape) are
    // actionable and should always win.
    final structured = _structuredMessage(data);
    if (structured != null) {
      return ApiError(message: structured, statusCode: statusCode);
    }
    // For known HTTP failure modes, prefer a friendly Chinese message
    // over FastAPI's generic `detail: "Method Not Allowed"` line.
    final friendly = _friendlyMessage(exception, statusCode);
    if (friendly != null) {
      return ApiError(message: friendly, statusCode: statusCode);
    }
    final genericServer = _genericServerMessage(data);
    return ApiError(
      message: genericServer ?? exception.message ?? '网络请求失败',
      statusCode: statusCode,
    );
  }

  static String? _friendlyMessage(DioException exception, int? statusCode) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '网络超时，请检查网络后重试';
      case DioExceptionType.connectionError:
        return '无法连接到服务端，请确认地址和网络';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.badCertificate:
        return '服务端证书无效';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }
    switch (statusCode) {
      case 401:
        return '登录已过期，请重新登录';
      case 403:
        return '没有权限执行此操作';
      case 404:
        return '资源不存在，可能已被删除';
      case 405:
        return '服务端版本过旧，请重启后端再试';
      case 408:
        return '请求超时，请重试';
      case 409:
        return '操作冲突，请刷新后重试';
      case 413:
        return '请求体过大';
      case 429:
        return '请求过于频繁，请稍后再试';
      case 500:
      case 502:
      case 503:
      case 504:
        return '服务端暂时不可用 ($statusCode)';
    }
    return null;
  }

  static String? _structuredMessage(Object? data) {
    if (data case {'detail': {'error': final Object error}}) {
      return error.toString();
    }
    return null;
  }

  static String? _genericServerMessage(Object? data) {
    if (data case {'error': final Object error}) {
      return error.toString();
    }
    if (data case {'detail': final Object detail}) {
      return detail.toString();
    }
    return null;
  }

  @override
  String toString() => message;
}
