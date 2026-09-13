import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/api_url_resolver.dart';
import '../../../core/di/injection.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme_v2.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/hudoori_logo.dart';
import '../../../core/widgets/language_toggle.dart';
import '../../../features/dashboard/widgets/dashboard_page_background.dart';
import '../../../l10n/l10n_extension.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.token});

  final String token;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _done = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    api.configure(baseUrl: ApiUrlResolver.effectiveUrl);
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.token.trim().isEmpty) {
      setState(() => _error = context.t('auth.resetInvalidLink'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await api.resetPassword(
        token: widget.token.trim(),
        password: _passwordCtrl.text,
        confirmPassword: _confirmCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _done = true;
        _loading = false;
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r['message']?.toString() ?? context.t('auth.resetDone'))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final tokenMissing = widget.token.trim().isEmpty;

    return Scaffold(
      body: DashboardPageBackground(
        child: Stack(
          children: [
            const PositionedDirectional(
              top: 20,
              start: 20,
              child: LanguageToggle(),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 440 : 420),
                  child: GlassCard(
                    animated: false,
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const HudooriLogo(
                            iconSize: 52,
                            nameSize: 26,
                            axis: Axis.vertical,
                          ),
                          const Gap(16),
                          Text(
                            context.t('auth.resetTitle'),
                            style: AppThemeV2.headline.copyWith(fontSize: 24),
                            textAlign: TextAlign.center,
                          ),
                          const Gap(8),
                          Text(
                            context.t('auth.resetSubtitle'),
                            style: AppThemeV2.caption,
                            textAlign: TextAlign.center,
                          ),
                          const Gap(28),
                          if (_done || tokenMissing) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: tokenMissing
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: tokenMissing
                                      ? const Color(0xFFFCA5A5)
                                      : const Color(0xFF86EFAC),
                                ),
                              ),
                              child: Text(
                                tokenMissing
                                    ? context.t('auth.resetInvalidLink')
                                    : context.t('auth.resetDone'),
                                style: AppThemeV2.body.copyWith(
                                  color: tokenMissing
                                      ? const Color(0xFF991B1B)
                                      : const Color(0xFF166534),
                                  height: 1.45,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const Gap(24),
                            FilledButton(
                              onPressed: () => context.go(AppRoutes.signIn),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(context.t('auth.backToLogin')),
                            ),
                          ] else ...[
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscure,
                              decoration: InputDecoration(
                                labelText: context.t('auth.newPassword'),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                                filled: true,
                                fillColor: AppThemeV2.surfaceElevated,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.length < 6) {
                                  return context.t('auth.passwordTooShort');
                                }
                                return null;
                              },
                            ),
                            const Gap(12),
                            TextFormField(
                              controller: _confirmCtrl,
                              obscureText: _obscure,
                              decoration: InputDecoration(
                                labelText: context.t('auth.confirmPassword'),
                                prefixIcon: const Icon(Icons.lock_outline),
                                filled: true,
                                fillColor: AppThemeV2.surfaceElevated,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (v) {
                                if (v != _passwordCtrl.text) {
                                  return context.t('auth.passwordMismatch');
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            if (_error != null) ...[
                              const Gap(12),
                              Text(
                                _error!,
                                style: const TextStyle(color: Color(0xFFB91C1C)),
                              ),
                            ],
                            const Gap(24),
                            FilledButton(
                              onPressed: _loading ? null : _submit,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(context.t('auth.saveNewPassword')),
                            ),
                            const Gap(12),
                            TextButton(
                              onPressed: () => context.go(AppRoutes.signIn),
                              child: Text(context.t('auth.backToLogin')),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
