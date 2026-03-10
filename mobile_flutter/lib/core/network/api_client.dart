import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/secure_storage.dart';

/// Base URL — override with environment variable in build flavors.
const String kApiBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3001');

/// Provides the configured [Dio] instance with auth + org interceptors.
final apiClientProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return _buildDioClient(storage);
});

Dio _buildDioClient(SecureStorageService storage) {
  final dio = Dio(
    BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(AuthInterceptor(storage: storage, dio: dio));
  dio.interceptors.add(LogInterceptor(
    requestBody: false,
    responseBody: false,
    logPrint: (obj) => debugPrint('[API] $obj'),
  ));

  return dio;
}

/// Injects `Authorization` and `X-Organization-Id` headers from secure storage.
/// Handles 401 by clearing tokens and signalling re-login.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.storage, required this.dio});

  final SecureStorageService storage;
  final Dio dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await storage.getToken();
    final orgId = await storage.getOrganizationId();

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    if (orgId != null) {
      options.headers['X-Organization-Id'] = orgId;
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      // Avoid refresh loop for auth endpoints themselves
      final path = err.requestOptions.path;
      if (path.contains('/auth/refresh') || path.contains('/auth/login')) {
        await storage.clearAll();
        handler.next(err);
        return;
      }

      try {
        final currentToken = await storage.getToken();
        if (currentToken == null) {
          await storage.clearAll();
          handler.next(err);
          return;
        }

        // Use a separate Dio instance to avoid triggering this interceptor again
        final refreshDio = Dio(BaseOptions(
          baseUrl: dio.options.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        ));

        final refreshResp = await refreshDio.post<Map<String, dynamic>>(
          '/api/v1/auth/refresh',
          options: Options(
            headers: {'Authorization': 'Bearer $currentToken'},
          ),
        );

        final newToken =
            (refreshResp.data?['data'] as Map<String, dynamic>?)?['token']
                as String?;

        if (newToken != null && newToken.isNotEmpty) {
          await storage.saveToken(newToken);

          // Retry the original request with the refreshed token
          final retryOptions = err.requestOptions;
          retryOptions.headers['Authorization'] = 'Bearer $newToken';
          final retryResp = await dio.fetch<dynamic>(retryOptions);
          handler.resolve(retryResp);
          return;
        }
      } catch (_) {
        // Refresh failed — fall through to clear credentials
      }

      // Could not refresh — force re-login
      await storage.clearAll();
    }
    handler.next(err);
  }
}

// ignore: depend_on_referenced_packages
void debugPrint(String message) {
  // ignore: avoid_print
  print(message);
}
