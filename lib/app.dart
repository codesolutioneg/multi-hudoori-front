import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/config/api_url_resolver.dart';
import 'core/di/injection.dart';
import 'core/locale/locale_cubit.dart';
import 'core/platform/mobile_platform.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_v2.dart';
import 'core/theme/app_typography.dart';
import 'core/utils/web_splash.dart';
import 'features/auth/auth_cubit.dart';
import 'features/auth/auth_state.dart';
import 'l10n/app_localizations.dart';

class HudooriApp extends StatefulWidget {
  const HudooriApp({super.key});

  @override
  State<HudooriApp> createState() => _HudooriAppState();
}

/// Kept for backwards compatibility in imports/tests.
typedef BioTimeApp = HudooriApp;

class _HudooriAppState extends State<HudooriApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    api.configure(baseUrl: ApiUrlResolver.effectiveUrl);
    final auth = sl<AuthCubit>();
    _router = createRouter(auth);
    auth.restoreSession();
    sl<LocaleCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<AuthCubit>()),
        BlocProvider.value(value: sl<LocaleCubit>()),
      ],
      child: BlocListener<AuthCubit, AuthState>(
        listenWhen: (prev, next) =>
            (prev.status == AuthStatus.initial || prev.status == AuthStatus.loading) &&
            next.status != AuthStatus.initial &&
            next.status != AuthStatus.loading,
        listener: (_, _) => notifyWebAppReady(),
        child: BlocBuilder<LocaleCubit, Locale>(
          builder: (context, locale) {
            return MaterialApp.router(
              title: AppLocalizations(locale).appName,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) {
                final isAr = locale.languageCode == 'ar';
                Widget content = DefaultTextStyle(
                  style: AppTypography.body.copyWith(color: AppThemeV2.textPrimary),
                  child: child ?? const SizedBox.shrink(),
                );
                // Native mobile only — web layout is the baseline and stays unchanged.
                if (isNativeMobile) {
                  content = SafeArea(bottom: false, child: content);
                }
                return Directionality(
                  textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                  child: content,
                );
              },
              routerConfig: _router,
            );
          },
        ),
      ),
    );
  }
}
