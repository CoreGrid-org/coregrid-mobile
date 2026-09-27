import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

/// Debug builds only: lets [dio] accept the self-signed dev certs that the
/// local backend (`dotnet dev-certs`) and ThunderID serve on `localhost`
/// (reached over `adb reverse` — doc/setup/local-dev-networking.md).
///
/// Needed because Dart's own `HttpClient`, which dio uses, does **not** honour
/// Android's `network_security_config.xml` — that file only covers native
/// networking (e.g. `flutter_appauth`'s discovery/token requests), so without
/// this every dio call to the dev backend fails the TLS handshake. Mirrors the
/// backend's Development-only relaxation for its ThunderID backchannel
/// (`Program.cs`).
///
/// Scoped to host `localhost` and compiled out of release builds
/// ([kDebugMode] is a const `false` there), so real deployments keep full
/// certificate validation.
void trustLocalDevCerts(Dio dio) {
  if (!kDebugMode) return;
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => HttpClient()
      ..badCertificateCallback = (_, host, _) => host == 'localhost',
  );
}
