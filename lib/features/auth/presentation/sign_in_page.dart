import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import '../auth_cubit.dart';
import '../auth_state.dart';
import 'login_validators.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _companyCtrl = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _companyFocus = FocusNode();
  final _loginFocus = FocusNode();
  final _passFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _initApiUrl();
    _restoreCompanyCode();
  }

  Future<void> _restoreCompanyCode() async {
    final code = await session.getCompanyCode();
    if (code != null && code.isNotEmpty && mounted) {
      _companyCtrl.text = code;
    }
  }

  Future<void> _initApiUrl() async {
    final url = ApiUrlResolver.effectiveUrl;
    api.configure(baseUrl: url);
    if (ApiUrlResolver.isLocalWebHost) {
      await session.saveBaseUrl(url);
    }
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _loginCtrl.dispose();
    _passCtrl.dispose();
    _companyFocus.dispose();
    _loginFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final server = ApiUrlResolver.effectiveUrl;
    session.saveBaseUrl(server);
    context.read<AuthCubit>().signIn(
          login: LoginValidators.normalizeLogin(_loginCtrl.text),
          password: _passCtrl.text,
          companyCode: _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
          baseUrl: server,
          l10n: AppLocalizations.of(context),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.isAr;

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
                padding: const EdgeInsets.fromLTRB(24, 72, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 760;
                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: _LoginBranding(isAr: isAr)),
                            const Gap(48),
                            Expanded(
                              child: _LoginFormCard(
                                l10n: l10n,
                                showLogo: false,
                                formKey: _formKey,
                                companyCtrl: _companyCtrl,
                                loginCtrl: _loginCtrl,
                                passCtrl: _passCtrl,
                                companyFocus: _companyFocus,
                                loginFocus: _loginFocus,
                                passFocus: _passFocus,
                                obscurePassword: _obscurePassword,
                                onTogglePassword: () =>
                                    setState(() => _obscurePassword = !_obscurePassword),
                                onSubmit: _submit,
                              ),
                            ),
                          ],
                        );
                      }
                      return _LoginFormCard(
                        l10n: l10n,
                        showLogo: true,
                        formKey: _formKey,
                        companyCtrl: _companyCtrl,
                        loginCtrl: _loginCtrl,
                        passCtrl: _passCtrl,
                        companyFocus: _companyFocus,
                        loginFocus: _loginFocus,
                        passFocus: _passFocus,
                        obscurePassword: _obscurePassword,
                        onTogglePassword: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        onSubmit: _submit,
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Text(
                'Powered by CodeSolution © ${DateTime.now().year}',
                textAlign: TextAlign.center,
                style: AppThemeV2.caption.copyWith(
                  fontSize: 12,
                  color: AppThemeV2.textMuted,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Text(
                'Powered by CodeSolution © ${DateTime.now().year}',
                textAlign: TextAlign.center,
                style: AppThemeV2.caption.copyWith(
                  fontSize: 12,
                  color: AppThemeV2.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginBranding extends StatelessWidget {
  const _LoginBranding({required this.isAr});

  final bool isAr;

  @override
  Widget build(BuildContext context) {
    final features = isAr
        ? [
            (Icons.fingerprint_rounded, context.t('signIn.feature1')),
            (Icons.calendar_month_outlined, context.t('signIn.feature2')),
            (Icons.payments_outlined, context.t('signIn.feature3')),
          ]
        : const [
            (Icons.fingerprint_rounded, 'BioTime punch sync'),
            (Icons.calendar_month_outlined, 'Shifts & attendance'),
            (Icons.payments_outlined, 'Payroll, advances & deductions'),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const HudooriLogo(iconSize: 56, nameSize: 32, axis: Axis.horizontal),
        const Gap(20),
        Text(
          isAr ? context.t('signIn.pitchTitle') : 'Enterprise attendance & payroll',
          style: AppThemeV2.headline.copyWith(fontSize: 28),
        ),
        const Gap(10),
        Text(
          isAr
              ? context.t('signIn.pitchBody')
              : 'One dashboard for employees and HR — fast, clear, and connected to your biometric devices.',
          style: AppThemeV2.body.copyWith(fontSize: 15, height: 1.6),
        ),
        const Gap(28),
        for (final (icon, label) in features) ...[
          _FeatureRow(icon: icon, label: label),
          const Gap(12),
        ],
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppThemeV2.primarySoft,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppThemeV2.primary.withValues(alpha: 0.15)),
          ),
          child: Icon(icon, size: 20, color: AppThemeV2.primary),
        ),
        const Gap(12),
        Expanded(
          child: Text(
            label,
            style: AppThemeV2.body.copyWith(
              fontWeight: FontWeight.w600,
              color: AppThemeV2.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.l10n,
    required this.showLogo,
    required this.formKey,
    required this.companyCtrl,
    required this.loginCtrl,
    required this.passCtrl,
    required this.companyFocus,
    required this.loginFocus,
    required this.passFocus,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final AppLocalizations l10n;
  final bool showLogo;
  final GlobalKey<FormState> formKey;
  final TextEditingController companyCtrl;
  final TextEditingController loginCtrl;
  final TextEditingController passCtrl;
  final FocusNode companyFocus;
  final FocusNode loginFocus;
  final FocusNode passFocus;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final loading = state.status == AuthStatus.loading;
        final errorText =
            state.status == AuthStatus.error ? state.errorMessage?.trim() : null;

        return GlassCard(
          animated: false,
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showLogo) ...[
                  const HudooriLogo(iconSize: 52, nameSize: 26, axis: Axis.vertical),
                  const Gap(16),
                  Text(l10n.signIn, style: AppThemeV2.headline.copyWith(fontSize: 24)),
                  const Gap(6),
                  Text(
                    l10n.isAr
                        ? 'أدخل معرف الشركة وبيانات حسابك للمتابعة'
                        : 'Enter company ID and credentials to continue',
                    style: AppThemeV2.caption,
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Text(l10n.signIn, style: AppThemeV2.headline.copyWith(fontSize: 26)),
                  const Gap(6),
                  Text(
                    l10n.isAr
                        ? 'أدخل معرف الشركة وبيانات حسابك للمتابعة'
                        : 'Enter company ID and credentials to continue',
                    style: AppThemeV2.caption.copyWith(fontSize: 13),
                  ),
                ],
                const Gap(28),
                TextFormField(
                  controller: companyCtrl,
                  focusNode: companyFocus,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: AppThemeV2.body.copyWith(color: AppThemeV2.textPrimary),
                  decoration: _fieldDecoration(
                    label: l10n.isAr ? 'معرف الشركة' : 'Company ID',
                    icon: Icons.apartment_outlined,
                  ),
                  onChanged: (_) => context.read<AuthCubit>().clearError(),
                  onFieldSubmitted: (_) => loginFocus.requestFocus(),
                ),
                const Gap(8),
                Text(
                  l10n.isAr
                      ? 'اتركه فارغاً لحساب Super Admin فقط'
                      : 'Leave empty for Super Admin only',
                  style: AppThemeV2.caption.copyWith(fontSize: 12),
                ),
                const Gap(16),
                TextFormField(
                  controller: loginCtrl,
                  focusNode: loginFocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: AppThemeV2.body.copyWith(color: AppThemeV2.textPrimary),
                  decoration: _fieldDecoration(
                    label: l10n.emailOrLogin,
                    icon: Icons.person_outline_rounded,
                  ),
                  validator: (v) => LoginValidators.login(l10n, v),
                  onChanged: (_) => context.read<AuthCubit>().clearError(),
                  onFieldSubmitted: (_) => passFocus.requestFocus(),
                ),
                const Gap(16),
                TextFormField(
                  controller: passCtrl,
                  focusNode: passFocus,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.done,
                  enableSuggestions: false,
                  autocorrect: false,
                  style: AppThemeV2.body.copyWith(color: AppThemeV2.textPrimary),
                  decoration: _fieldDecoration(
                    label: l10n.password,
                    icon: Icons.lock_outline_rounded,
                    suffix: IconButton(
                      icon: Icon(
                        obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: AppThemeV2.textMuted,
                      ),
                      onPressed: onTogglePassword,
                    ),
                  ),
                  validator: (v) => LoginValidators.password(l10n, v),
                  onChanged: (_) => context.read<AuthCubit>().clearError(),
                  onFieldSubmitted: (_) => onSubmit(),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: loading
                        ? null
                        : () => context.push(AppRoutes.forgotPassword),
                    child: Text(
                      context.t('auth.forgotPassword'),
                      style: AppThemeV2.caption.copyWith(
                        color: AppThemeV2.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (errorText != null && errorText.isNotEmpty) ...[
                  const Gap(8),
                  _LoginErrorBanner(message: errorText),
                ],
                const Gap(20),
                _LoginButton(
                  loading: loading,
                  label: l10n.login,
                  onPressed: loading ? null : onSubmit,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppThemeV2.caption,
      prefixIcon: Icon(icon, size: 20, color: AppThemeV2.textMuted),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppThemeV2.surfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppThemeV2.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppThemeV2.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppThemeV2.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

class _LoginErrorBanner extends StatelessWidget {
  const _LoginErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppThemeV2.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemeV2.danger.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppThemeV2.danger, size: 22),
          const Gap(10),
          Expanded(
            child: Text(
              message,
              style: AppThemeV2.body.copyWith(
                color: AppThemeV2.danger,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.loading,
    required this.label,
    required this.onPressed,
  });

  final bool loading;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : AppThemeV2.primaryGradient,
        borderRadius: BorderRadius.circular(12),
        color: onPressed == null ? AppThemeV2.border : null,
        boxShadow: onPressed == null
            ? null
            : [
                BoxShadow(
                  color: AppThemeV2.primary.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: AppThemeV2.title.copyWith(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
