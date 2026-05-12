import 'package:dio/dio.dart';

class ApiError implements Exception {
  const ApiError({
    required this.message,
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  factory ApiError.fromDioException(DioException exception) {
    final response = exception.response;
    final data = response?.data;
    final message =
        _extractMessage(data) ?? exception.message ?? 'Network request failed';
    return ApiError(message: message, statusCode: response?.statusCode);
  }

  static String? _extractMessage(Object? data) {
    if (data case {'detail': {'error': final Object error}}) {
      return error.toString();
    }
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
