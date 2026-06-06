import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'tls_pinning.dart';

/// Construye instancias de [Dio] hacia el PC con pinning TLS por huella (TOFU)
/// y, opcionalmente, inyección del `Authorization: Bearer <device_token>`.
abstract final class NbApiClient {
  static const Duration _timeout = Duration(seconds: 12);

  /// Cliente para un PC concreto.
  /// - [fingerprint]: huella a fijar (null = sin TLS / sin pinning).
  /// - [token]: callback que entrega el device_token; si es null, no se
  ///   inyecta auth (p. ej. para `/pair`, que usa el token efímero del QR).
  static Dio create({
    required String baseUrl,
    String? fingerprint,
    Future<String?> Function()? token,
  }) {
    final Dio dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: _timeout,
        receiveTimeout: _timeout,
        sendTimeout: _timeout,
        responseType: ResponseType.json,
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => pinnedHttpClient(fingerprint),
    );
    if (token != null) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (
            RequestOptions options,
            RequestInterceptorHandler handler,
          ) async {
            final String? t = await token();
            if (t != null) {
              options.headers['Authorization'] = 'Bearer $t';
            }
            handler.next(options);
          },
        ),
      );
    }
    return dio;
  }
}
