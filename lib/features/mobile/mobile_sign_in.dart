import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/locale/locale_cubit.dart';
import '../../core/router/app_router.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';
import '../auth/presentation/login_validators.dart';
import 'mobile_ui.dart';

/// Native mobile sign-in: brand hero on top, form sheet below. State and
/// submission are owned by `SignInPage`.
class MobileSignInView extends StatefulWidget {
  const MobileSignInView({
    super.key,
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
    this.onBiometric,
  });

  /// Shown as a fingerprint button next to sign-in when saved credentials exist.
  final VoidCallback? onBiometric;
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

  static const Color heroTop = Color(0xFF4C8DFF);

  @override
  State<MobileSignInView> createState() => _MobileSignInViewState();
}

class _MobileSignInViewState extends State<MobileSignInView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => mobileStatusBarColor.value = MobileSignInView.heroTop,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mobileStatusBarColor.value == MobileSignInView.heroTop) {
        mobileStatusBarColor.value = MobileUi.background;
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final heroHeight = math.max(280.0, size.height * 0.34);
    final w = widget;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              SizedBox(
                height: heroHeight,
                child: _Hero(l10n: l10n),
              ),
              Transform.translate(
                offset: const Offset(0, -34),
                child: _FormSheet(
                  l10n: l10n,
                  formKey: w.formKey,
                  companyCtrl: w.companyCtrl,
                  loginCtrl: w.loginCtrl,
                  passCtrl: w.passCtrl,
                  companyFocus: w.companyFocus,
                  loginFocus: w.loginFocus,
                  passFocus: w.passFocus,
                  obscurePassword: w.obscurePassword,
                  onTogglePassword: w.onTogglePassword,
                  onSubmit: w.onSubmit,
                  onBiometric: w.onBiometric,
                )
                    .animate()
                    .fadeIn(duration: 450.ms)
                    .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                MobileSignInView.heroTop,
                Color(0xFF2563EB),
                Color(0xFF1E40AF),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        const CustomPaint(painter: _HeroDecor()),
        PositionedDirectional(
          top: top + 6,
          end: 16,
          child: _LanguagePill(l10n: l10n),
        ),
        Padding(
          padding: EdgeInsets.only(top: top, bottom: 34),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0B1F66).withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: OverflowBox(
                      maxWidth: 150,
                      maxHeight: 150,
                      child: const HudooriMark(size: 150),
                    ),
                  ),
                )
                    .animate()
                    .scaleXY(begin: 0.7, end: 1, duration: 550.ms, curve: Curves.easeOutBack)
                    .fadeIn(duration: 300.ms),
                const SizedBox(height: 14),
                Text(
                  l10n.appName,
                  style: MobileUi.text(32, weight: FontWeight.w800, color: Colors.white, height: 1.1),
                ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.3, end: 0),
                const SizedBox(height: 4),
                Text(
                  l10n.t('m.splashTagline'),
                  style: MobileUi.text(14, weight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.85)),
                ).animate().fadeIn(delay: 260.ms, duration: 400.ms),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroDecor extends CustomPainter {
  const _HeroDecor();

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final c1 = Offset(size.width * 0.92, size.height * 0.12);
    for (var i = 1; i <= 4; i++) {
      ring.color = Colors.white.withValues(alpha: 0.10 - i * 0.015);
      canvas.drawCircle(c1, 40.0 * i, ring);
    }
    final c2 = Offset(size.width * 0.05, size.height * 0.88);
    for (var i = 1; i <= 3; i++) {
      ring.color = Colors.white.withValues(alpha: 0.09 - i * 0.02);
      canvas.drawCircle(c2, 46.0 * i, ring);
    }
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.2),
      90,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.18, size.height * 0.2),
          radius: 90,
        )),
    );
  }

  @override
  bool shouldRepaint(_HeroDecor old) => false;
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: StadiumBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => context
            .read<LocaleCubit>()
            .setLocale(Locale(l10n.isAr ? 'en' : 'ar')),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.translate_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                l10n.isAr ? 'English' : 'العربية',
                style: MobileUi.text(13, weight: FontWeight.w700, color: Colors.white, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormSheet extends StatelessWidget {
  const _FormSheet({
    required this.l10n,
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
    this.onBiometric,
  });

  final VoidCallback? onBiometric;
  final AppLocalizations l10n;
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
        final error =
            state.status == AuthStatus.error ? state.errorMessage?.trim() : null;
        void clear(String _) => context.read<AuthCubit>().clearError();

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            22,
            30,
            22,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
          ),
          child: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.t('m.welcomeBack'),
                  style: MobileUi.text(26, weight: FontWeight.w800, height: 1.2),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.t('m.signInSub'),
                  style: MobileUi.text(14, weight: FontWeight.w500, color: MobileUi.muted),
                ),
                const SizedBox(height: 26),
                _Field(
                  controller: companyCtrl,
                  focusNode: companyFocus,
                  label: l10n.t('m.companyId'),
                  icon: Icons.apartment_rounded,
                  action: TextInputAction.next,
                  onChanged: clear,
                  onSubmitted: (_) => loginFocus.requestFocus(),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6, top: 6),
                  child: Text(
                    l10n.t('m.companyHint'),
                    style: MobileUi.text(11.5, weight: FontWeight.w500, color: MobileUi.muted),
                  ),
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: loginCtrl,
                  focusNode: loginFocus,
                  label: l10n.emailOrLogin,
                  icon: Icons.person_rounded,
                  keyboard: TextInputType.emailAddress,
                  action: TextInputAction.next,
                  validator: (v) => LoginValidators.login(l10n, v),
                  onChanged: clear,
                  onSubmitted: (_) => passFocus.requestFocus(),
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: passCtrl,
                  focusNode: passFocus,
                  label: l10n.password,
                  icon: Icons.lock_rounded,
                  obscure: obscurePassword,
                  action: TextInputAction.done,
                  validator: (v) => LoginValidators.password(l10n, v),
                  onChanged: clear,
                  onSubmitted: (_) => onSubmit(),
                  suffix: IconButton(
                    onPressed: onTogglePassword,
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                      color: MobileUi.muted,
                    ),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: loading
                        ? null
                        : () => context.push(AppRoutes.forgotPassword),
                    child: Text(
                      l10n.t('auth.forgotPassword'),
                      style: MobileUi.text(13, weight: FontWeight.w700, color: MobileUi.primary),
                    ),
                  ),
                ),
                if (error != null && error.isNotEmpty) ...[
                  _ErrorBox(message: error),
                  const SizedBox(height: 14),
                ] else
                  const SizedBox(height: 6),
                _SubmitButton(
                  label: l10n.login,
                  loading: loading,
                  onPressed: loading ? null : onSubmit,
                ),
                if (onBiometric != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : onBiometric,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        foregroundColor: MobileUi.primary,
                        backgroundColor: MobileUi.primarySoft,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      icon: const Icon(Icons.fingerprint_rounded, size: 28),
                      label: Text(
                        l10n.t('m.bioLogin'),
                        style: MobileUi.text(15, weight: FontWeight.w700, color: MobileUi.primary),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_user_rounded, size: 15, color: MobileUi.muted),
                    const SizedBox(width: 6),
                    Text(
                      'Powered by CodeSolution © ${DateTime.now().year}',
                      style: MobileUi.text(12, weight: FontWeight.w500, color: MobileUi.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.icon,
    this.keyboard,
    this.action,
    this.obscure = false,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final IconData icon;
  final TextInputType? keyboard;
  final TextInputAction? action;
  final bool obscure;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: c, width: w),
        );

    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboard,
          textInputAction: action,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: false,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          style: MobileUi.text(15, weight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: MobileUi.text(14, weight: FontWeight.w500, color: MobileUi.muted),
            floatingLabelStyle: MobileUi.text(14, weight: FontWeight.w700, color: MobileUi.primary),
            filled: true,
            fillColor: focused ? Colors.white : const Color(0xFFF4F7FC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            prefixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(start: 10, end: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: focused ? MobileUi.primary : MobileUi.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: focused ? Colors.white : MobileUi.primary,
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 56, minHeight: 38),
            suffixIcon: suffix,
            border: border(Colors.transparent),
            enabledBorder: border(const Color(0xFFEDF1F7)),
            focusedBorder: border(MobileUi.primary, 1.6),
            errorBorder: border(MobileTone.danger.withValues(alpha: 0.6)),
            focusedErrorBorder: border(MobileTone.danger, 1.6),
          ),
        );
      },
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MobileTone.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MobileTone.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_rounded, color: MobileTone.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: MobileUi.text(13, weight: FontWeight.w600, color: MobileTone.danger),
            ),
          ),
        ],
      ),
    ).animate().shakeX(hz: 4, amount: 4, duration: 350.ms);
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4C8DFF), Color(0xFF1D4ED8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: MobileUi.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 58,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: MobileUi.text(16, weight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 17,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
