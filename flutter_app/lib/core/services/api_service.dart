import 'dart:io';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(),
      _RetryInterceptor(dio: _dio),
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        error: true,
      ),
    ]);
  }

  Future<Map<String, dynamic>> analyzeObject({
    required File imageFile,
    required Map<String, dynamic> metadata,
  }) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(imageFile.path),
      'metadata': metadata,
    });

    final response = await _dio.post(
      ApiConstants.scanObject,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generateDigitalTwin(String objectId) async {
    final response = await _dio.post(
      ApiConstants.generateTwin,
      data: {'object_id': objectId},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> chat({
    required String objectId,
    required String message,
    required String sessionId,
  }) async {
    final response = await _dio.post(
      ApiConstants.chat,
      data: {
        'object_id': objectId,
        'message': message,
        'session_id': sessionId,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> analyzeDamage({
    required File imageFile,
    required String objectId,
  }) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(imageFile.path),
      'object_id': objectId,
    });

    final response = await _dio.post(
      ApiConstants.analyzeDamage,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> searchParts({
    required String objectId,
    String? query,
    String? category,
  }) async {
    final response = await _dio.get(
      ApiConstants.searchParts,
      queryParameters: {
        'object_id': objectId,
        if (query != null) 'q': query,
        if (category != null) 'category': category,
      },
    );
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> runSimulation({
    required String objectId,
    required String simulationType,
    required Map<String, dynamic> parameters,
  }) async {
    final response = await _dio.post(
      ApiConstants.runSimulation,
      data: {
        'object_id': objectId,
        'simulation_type': simulationType,
        'parameters': parameters,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Attach auth token from secure storage
    // final token = await SecureStorageService.getToken();
    // if (token != null) {
    //   options.headers['Authorization'] = 'Bearer $token';
    // }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Handle token refresh
    }
    handler.next(err);
  }
}

class _RetryInterceptor extends Interceptor {
  final Dio dio;
  int _retryCount = 0;

  _RetryInterceptor({required this.dio});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_retryCount < ApiConstants.maxRetries &&
        err.type == DioExceptionType.connectionTimeout) {
      _retryCount++;
      await Future.delayed(Duration(seconds: _retryCount * 2));
      try {
        final response = await dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (_) {}
    }
    _retryCount = 0;
    handler.next(err);
  }
}
