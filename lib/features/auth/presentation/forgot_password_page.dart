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
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_extension.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  bool _loading = false;
  bool _done = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    api.configure(baseUrl: ApiUrlResolver.effectiveUrl);
  }

  @override
  void dispose() {
    _loginCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await api.forgotPassword(
        loginOrEmail: _loginCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _done = true;
        _successMessage =
            r['message']?.toString() ?? context.t('auth.forgotSuccess');
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Still show generic success to avoid account enumeration on client errors
        _done = true;
        _successMessage = context.t('auth.forgotSuccess');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;

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
                            context.t('auth.forgotTitle'),
                            style: AppThemeV2.headline.copyWith(fontSize: 24),
                            textAlign: TextAlign.center,
                          ),
                          const Gap(8),
                          Text(
                            context.t('auth.forgotSubtitle'),
                            style: AppThemeV2.caption,
                            textAlign: TextAlign.center,
                          ),
                          const Gap(28),
                          if (_done) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: Text(
                                _successMessage ?? context.t('auth.forgotSuccess'),
                                style: AppThemeV2.body.copyWith(
                                  color: const Color(0xFF166534),
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
                              controller: _loginCtrl,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              autocorrect: false,
                              decoration: InputDecoration(
                                labelText: l10n.emailOrLogin,
                                prefixIcon: const Icon(Icons.person_outline_rounded),
                                filled: true,
                                fillColor: AppThemeV2.surfaceElevated,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return context.t('auth.loginRequired');
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
                                  : Text(context.t('auth.sendReset')),
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
