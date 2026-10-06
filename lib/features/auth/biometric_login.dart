import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/platform/mobile_platform.dart';
import '../../l10n/app_localizations.dart';
import '../mobile/mobile_ui.dart';

typedef SavedLogin = ({String company, String login, String password});

/// Fingerprint / face sign-in for native mobile: the last successful
/// credentials are kept in the platform keystore and released only after the
/// device's biometric prompt succeeds.
abstract final class BiometricLogin {
  static const _storage = FlutterSecureStorage();
  static final _auth = LocalAuthentication();

  static const _kCompany = 'bio.company';
  static const _kLogin = 'bio.login';
  static const _kPassword = 'bio.password';
  static const _kAsked = 'bio.asked';

  static Future<bool> isAvailable() async {
    if (!isNativeMobile) return false;
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<SavedLogin?> saved() async {
    if (!isNativeMobile) return null;
    try {
      final login = await _storage.read(key: _kLogin);
      final password = await _storage.read(key: _kPassword);
      if (login == null || login.isEmpty || password == null || password.isEmpty) {
        return null;
      }
      final company = await _storage.read(key: _kCompany) ?? '';
      return (company: company, login: login, password: password);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isEnabled() async => await saved() != null;

  /// Whether the user was already offered biometric sign-in for [login].
  static Future<bool> wasOffered(String login) async =>
      await _storage.read(key: _kAsked) == login;

  static Future<void> markOffered(String login) =>
      _storage.write(key: _kAsked, value: login);

  static Future<void> enable({
    required String company,
    required String login,
    required String password,
  }) async {
    await _storage.write(key: _kCompany, value: company);
    await _storage.write(key: _kLogin, value: login);
    await _storage.write(key: _kPassword, value: password);
    await markOffered(login);
  }

  static Future<void> disable() async {
    await _storage.delete(key: _kCompany);
    await _storage.delete(key: _kLogin);
    await _storage.delete(key: _kPassword);
  }

  /// Credentials of the password sign-in in flight; offered for biometric
  /// sign-in once the user lands in the app.
  static SavedLogin? pending;

  /// Credentials of this session's sign-in, kept in memory so fingerprint
  /// sign-in can be switched on later from the More page.
  static SavedLogin? last;

  /// Asks once per account whether to enable fingerprint sign-in.
  static Future<void> offerIfPending(BuildContext context) async {
    final creds = pending;
    pending = null;
    if (creds == null) return;
    last = creds;
    if (!await isAvailable()) return;
    if (await wasOffered(creds.login)) {
      if (await isEnabled()) {
        await enable(company: creds.company, login: creds.login, password: creds.password);
      }
      return;
    }
    await markOffered(creds.login);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final yes = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 20 + MediaQuery.viewPaddingOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(color: MobileUi.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.fingerprint_rounded, size: 44, color: MobileUi.primary),
            ),
            const SizedBox(height: 14),
            Text(l10n.t('m.bioOfferTitle'), style: MobileUi.text(19, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              l10n.t('m.bioOfferBody'),
              textAlign: TextAlign.center,
              style: MobileUi.text(13.5, weight: FontWeight.w500, color: MobileUi.muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.fingerprint_rounded),
                label: Text(l10n.t('m.bioEnable')),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: MobileUi.muted,
                  side: const BorderSide(color: Color(0xFFE3E9F5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(l10n.t('m.notNow')),
              ),
            ),
          ],
        ),
      ),
    );
    if (yes != true) return;
    if (!await authenticate(l10n.t('m.bioReason'))) return;
    await enable(company: creds.company, login: creds.login, password: creds.password);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('m.bioEnabled'))),
      );
    }
  }

  static Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
