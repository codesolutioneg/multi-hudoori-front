import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_extension.dart';

abstract final class LoginValidators {
  LoginValidators._();

  static const int loginMinLength = 3;
  static const int loginMaxLength = 255;
  static const int passwordMinLength = 6;
  static const int passwordMaxLength = 128;

  static final RegExp _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? login(AppLocalizations l10n, String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return l10n.loginRequired;
    if (trimmed.length < loginMinLength) return l10n.loginTooShort(loginMinLength);
    if (trimmed.length > loginMaxLength) return l10n.loginTooLong(loginMaxLength);
    if (trimmed.contains('@') && !_emailRe.hasMatch(trimmed)) return l10n.invalidEmail;
    return null;
  }

  static String? password(AppLocalizations l10n, String? value) {
    if (value == null || value.isEmpty) return l10n.passwordRequired;
    if (value.length < passwordMinLength) return l10n.passwordTooShort(passwordMinLength);
    if (value.length > passwordMaxLength) return l10n.passwordTooLong(passwordMaxLength);
    return null;
  }

  static String normalizeLogin(String raw) {
    final trimmed = raw.trim();
    if (trimmed.contains('@')) return trimmed.toLowerCase();
    return trimmed;
  }

  static String? serverUrl(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return tr('login.urlRequired');
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return tr('login.urlInvalid');
    }
    if (!['http', 'https'].contains(uri.scheme)) {
      return tr('login.urlScheme');
    }
    return null;
  }
}
