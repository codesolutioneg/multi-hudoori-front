import 'package:flutter/foundation.dart' show kIsWeb;

import 'api_config.dart';

/// Chooses the backend URL for web vs mobile and local vs deployed builds.
abstract final class ApiUrlResolver {
  ApiUrlResolver._();

  static bool get isLocalWebHost {
    if (!kIsWeb) return false;
    final host = Uri.base.host;
    return host == 'localhost' || host == '127.0.0.1';
  }

  /// True when the app was built without a remote API (default localhost compile flag).
  static bool get usesCompileTimeLocalDefault {
    return ApiConfig.baseUrl.contains('localhost') || ApiConfig.baseUrl.contains('127.0.0.1');
  }

  static bool get shouldPinLocalhost {
    if (!ApiConfig.pinLocalhost) return false;
    return isLocalWebHost || usesCompileTimeLocalDefault;
  }

  static String get effectiveUrl => shouldPinLocalhost ? ApiConfig.localBackendUrl : ApiConfig.baseUrl;

  static String resolve(String? savedOrConfigured) {
    if (shouldPinLocalhost) return ApiConfig.localBackendUrl;

    final raw = (savedOrConfigured?.trim().isNotEmpty == true)
        ? savedOrConfigured!.trim()
        : ApiConfig.baseUrl;

    // Never use a saved localhost URL when the app runs on a production host.
    if (!isLocalWebHost && _isLocalhostUrl(raw)) {
      return ApiConfig.baseUrl;
    }

    if (raw.contains('odoo.com')) return ApiConfig.localBackendUrl;
    // Legacy ngrok dev tunnels only — Cloudflare production URL is allowed.
    if (raw.contains('ngrok-free.app') || raw.contains('ngrok.io')) {
      return ApiConfig.localBackendUrl;
    }
    return raw;
  }

  static bool _isLocalhostUrl(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host == 'localhost' || host == '127.0.0.1';
  }
}
