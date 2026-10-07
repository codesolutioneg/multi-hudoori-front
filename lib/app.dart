import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'core/push/push_notification_service.dart';
import 'features/auth/auth_cubit.dart';
import 'features/auth/auth_state.dart';
import 'features/mobile/hudoori_splash.dart';
import 'features/mobile/mobile_ui.dart';
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
  bool _splashDone = !isNativeMobile;

  @override
  void initState() {
    super.initState();
    api.configure(baseUrl: ApiUrlResolver.effectiveUrl);
    final auth = sl<AuthCubit>();
    _router = createRouter(auth);
    PushNotificationService.instance.attachRouter(_router);
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
        child: BlocListener<AuthCubit, AuthState>(
          listenWhen: (prev, next) =>
              isNativeMobile &&
              next.status == AuthStatus.authenticated &&
              (prev.status != AuthStatus.authenticated ||
                  prev.activeCompanyId != next.activeCompanyId),
          listener: (_, state) {
            PushNotificationService.instance.syncSession(
              companyId: state.activeCompanyId,
            );
          },
        child: BlocBuilder<LocaleCubit, Locale>(
          builder: (context, locale) {
            return MaterialApp.router(
              title: AppLocalizations(locale).appName,
              debugShowCheckedModeBanner: false,
              theme: isNativeMobile ? AppTheme.mobile() : AppTheme.light(),
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
                  content = ValueListenableBuilder<Color>(
                    valueListenable: mobileStatusBarColor,
                    child: SafeArea(bottom: false, child: content),
                    builder: (context, color, child) {
                      final darkFill =
                          ThemeData.estimateBrightnessForColor(color) ==
                              Brightness.dark;
                      return AnnotatedRegion<SystemUiOverlayStyle>(
                        value: (darkFill
                                ? SystemUiOverlayStyle.light
                                : SystemUiOverlayStyle.dark)
                            .copyWith(
                          statusBarColor: Colors.transparent,
                          systemNavigationBarColor: Colors.white,
                          systemNavigationBarIconBrightness: Brightness.dark,
                        ),
                        child: ColoredBox(color: color, child: child),
                      );
                    },
                  );
                }
                if (!_splashDone) {
                  content = Stack(
                    fit: StackFit.expand,
                    children: [
                      content,
                      BlocBuilder<AuthCubit, AuthState>(
                        builder: (context, auth) => HudooriSplash(
                          ready: auth.status != AuthStatus.initial &&
                              auth.status != AuthStatus.loading,
                          onFinished: () => setState(() => _splashDone = true),
                        ),
                      ),
                    ],
                  );
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
      ),
    );
  }
}
