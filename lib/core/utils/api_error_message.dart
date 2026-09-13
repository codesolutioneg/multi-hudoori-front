import 'package:flutter/material.dart';

import '../../data/api/biotime_api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_extension.dart';

/// Maps API / network exceptions to user-facing copy (no stack traces or URIs).
String friendlyApiError(BuildContext context, Object error) =>
    friendlyApiErrorL10n(context.l10n, error);

String friendlyApiErrorL10n(AppLocalizations l10n, Object error) {
  String t(String key, [Map<String, Object?> params = const {}]) => l10n.t(key, params);

  if (error is BioTimeApiException) {
    switch (error.code) {
      case 'NETWORK_ERROR':
        return t('errors.network');
      case 'TIMEOUT':
        return t('errors.timeout');
      case 'MISSING_TOKEN':
      case 'INVALID_TOKEN':
        return t('errors.sessionExpired');
      case 'ACCESS_DENIED':
        return t('errors.accessDenied');
      default:
        if (error.message.startsWith('HTTP ')) {
          final code = error.message.replaceFirst('HTTP ', '').trim();
          return t('errors.http', {'code': code});
        }
        final msg = error.message.trim();
        if (msg.isNotEmpty && !_looksTechnical(msg)) return msg;
        return t('errors.server');
    }
  }

  final raw = error.toString();
  if (_isNetworkFailure(raw)) return t('errors.network');
  if (raw.contains('TimeoutException')) return t('errors.timeout');
  if (_looksTechnical(raw)) return t('errors.generic');
  return raw;
}

bool _isNetworkFailure(String raw) {
  final lower = raw.toLowerCase();
  return lower.contains('clientexception') ||
      lower.contains('failed to fetch') ||
      lower.contains('socketexception') ||
      lower.contains('connection refused') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection reset') ||
      lower.contains('handshakeexception');
}

bool _looksTechnical(String raw) {
  final lower = raw.toLowerCase();
  return lower.contains('exception') ||
      lower.contains('error:') ||
      lower.contains('uri=') ||
      lower.contains('http://') ||
      lower.contains('https://') ||
      lower.startsWith('instance of ');
}
