import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/api_config.dart';
import '../../core/config/api_url_resolver.dart';
import '../../core/config/platform_admin_config.dart';
import '../../core/storage/session_storage.dart';
import '../../core/utils/api_error_message.dart';
import '../../data/api/biotime_api_client.dart';
import '../../l10n/app_localizations.dart';
import 'auth_state.dart';
import 'presentation/login_validators.dart';
import '../../l10n/l10n_extension.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required BioTimeApiClient api,
    required SessionStorage session,
  })  : _api = api,
        _session = session,
        super(const AuthState());

  final BioTimeApiClient _api;
  final SessionStorage _session;

  Future<void> restoreSession() async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true, clearProfileWarning: true));
    try {
      final token = await _session.getToken();
      final savedUrl = await _session.getBaseUrl();
      final baseUrl = ApiUrlResolver.resolve(savedUrl);
      _api.configure(baseUrl: baseUrl, token: token);
      if (ApiUrlResolver.isLocalWebHost && savedUrl != baseUrl) {
        await _session.saveBaseUrl(baseUrl);
      }
      if (token == null || token.isEmpty) {
        emit(state.copyWith(status: AuthStatus.unauthenticated, clearToken: true));
        return;
      }
      if (PlatformAdminConfig.isLocalToken(token)) {
        final activeId = await _session.getActiveCompanyId();
        _api.setActiveCompanyId(activeId);
        emit(AuthState(
          status: AuthStatus.authenticated,
          token: token,
          isPlatformAdmin: true,
          activeCompanyId: activeId,
          user: const BioTimeUser(
            id: 'platform-admin',
            name: 'Platform Admin',
            email: PlatformAdminConfig.login,
            isPlatformAdmin: true,
          ),
        ));
        return;
      }
      final valid = await _api.validateToken();
      if (!valid) {
        await _session.clearToken();
        emit(state.copyWith(status: AuthStatus.unauthenticated, clearToken: true));
        return;
      }
      final isPlatformAdmin = await _session.getPlatformAdmin();
      if (isPlatformAdmin) {
        final activeId = await _session.getActiveCompanyId();
        _api.setActiveCompanyId(activeId);
        String? name;
        String? code;
        if (activeId != null && activeId.isNotEmpty) {
          try {
            final data = await _api.adminCompaniesList();
            final companies = data['companies'];
            if (companies is List) {
              for (final raw in companies) {
                if (raw is Map && raw['id']?.toString() == activeId) {
                  name = raw['name']?.toString();
                  code = raw['code']?.toString();
                  break;
                }
              }
            }
          } catch (_) {}
        }
        emit(AuthState(
          status: AuthStatus.authenticated,
          token: token,
          isPlatformAdmin: true,
          activeCompanyId: activeId,
          activeCompanyName: name,
          activeCompanyCode: code,
          user: const BioTimeUser(id: '', name: 'Platform Admin', isPlatformAdmin: true),
        ));
        return;
      }
      await _loadProfile(baseUrl: baseUrl, token: token);
    } catch (_) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, clearToken: true));
    }
  }

  Future<void> signIn({
    required String login,
    required String password,
    String? baseUrl,
    String? database,
    String? companyCode,
    AppLocalizations? l10n,
  }) async {
    final validationLogin = LoginValidators.login(l10n ?? _fallbackL10n, login);
    if (validationLogin != null) {
      emit(state.copyWith(status: AuthStatus.error, errorMessage: validationLogin));
      return;
    }
    final validationPassword = LoginValidators.password(l10n ?? _fallbackL10n, password);
    if (validationPassword != null) {
      emit(state.copyWith(status: AuthStatus.error, errorMessage: validationPassword));
      return;
    }

    emit(state.copyWith(status: AuthStatus.loading, clearError: true, clearProfileWarning: true));
    try {
      final trimmedLogin = LoginValidators.normalizeLogin(login);
      final trimmedCompanyCode = companyCode?.trim();
      if (PlatformAdminConfig.matches(trimmedLogin, password)) {
        final server = _resolveServerUrl(baseUrl);
        _api.configure(baseUrl: server);
        try {
          final data = await _api.login(login: trimmedLogin, password: password);
          final token = data['token']?.toString() ?? '';
          if (token.isNotEmpty) {
            await _session.saveToken(token);
            await _session.saveBaseUrl(server);
            await _session.savePlatformAdmin(true);
            await _session.saveCompanyCode(null);
            final loginUser = data['user'];
            final user = loginUser is Map
                ? BioTimeUser.fromJson(Map<String, dynamic>.from(loginUser))
                : const BioTimeUser(
                    id: 'platform-admin',
                    name: 'Platform Admin',
                    email: PlatformAdminConfig.login,
                    isPlatformAdmin: true,
                  );
            emit(AuthState(
              status: AuthStatus.authenticated,
              token: token,
              isPlatformAdmin: true,
              user: user,
            ));
            return;
          }
        } catch (_) {
          // Backend offline — fall back to local session for dashboard only
        }
        const token = PlatformAdminConfig.localToken;
        _api.configure(baseUrl: server, token: token);
        await _session.saveToken(token);
        await _session.saveBaseUrl(server);
        await _session.savePlatformAdmin(true);
        emit(AuthState(
          status: AuthStatus.authenticated,
          token: token,
          isPlatformAdmin: true,
          user: const BioTimeUser(
            id: 'platform-admin',
            name: 'Platform Admin',
            email: PlatformAdminConfig.login,
            isPlatformAdmin: true,
          ),
        ));
        return;
      }

      final server = _resolveServerUrl(baseUrl);
      final db = database?.trim();
      _api.configure(baseUrl: server);
      final data = await _api.login(
        login: trimmedLogin,
        password: password,
        db: db?.isNotEmpty == true ? db : ApiConfig.database,
        companyCode: trimmedCompanyCode,
      );
      final token = data['token']?.toString() ?? '';
      await _session.saveToken(token);
      await _session.saveBaseUrl(server);
      if (db?.isNotEmpty == true) await _session.saveDatabase(db!);
      if (trimmedCompanyCode != null && trimmedCompanyCode.isNotEmpty) {
        await _session.saveCompanyCode(trimmedCompanyCode);
      }
      final loginUser = data['user'];
      if (loginUser is Map && loginUser['isPlatformAdmin'] == true) {
        final user = BioTimeUser.fromJson(Map<String, dynamic>.from(loginUser));
        await _session.saveToken(token);
        await _session.savePlatformAdmin(true);
        emit(AuthState(
          status: AuthStatus.authenticated,
          token: token,
          user: user,
          isPlatformAdmin: true,
        ));
        return;
      }
      await _session.savePlatformAdmin(false);
      // Prefer company from login payload for branding before /me.
      final companyRaw = data['company'];
      String? loginCompanyName;
      String? loginCompanyCode;
      String? loginCompanyId;
      if (companyRaw is Map) {
        loginCompanyName = companyRaw['name']?.toString();
        loginCompanyCode = companyRaw['code']?.toString();
        loginCompanyId = companyRaw['id']?.toString();
      }
      if (loginCompanyId != null) {
        emit(state.copyWith(
          activeCompanyId: loginCompanyId,
          activeCompanyName: loginCompanyName,
          activeCompanyCode: loginCompanyCode,
        ));
      }
      await _loadProfile(baseUrl: server, token: token, loginUser: loginUser);
    } on BioTimeApiException catch (e) {
      emit(state.copyWith(status: AuthStatus.error, errorMessage: _mapLoginError(e, l10n)));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: _mapGenericError(e, l10n),
      ));
    }
  }

  static final _fallbackL10n = AppLocalizations(const Locale('ar'));

  String _mapLoginError(BioTimeApiException e, AppLocalizations? l10n) {
    final loc = l10n ?? _fallbackL10n;
    switch (e.code) {
      case 'INVALID_CREDENTIALS':
        return loc.invalidCredentials;
      case 'LOGIN_REQUIRED':
        return loc.loginRequired;
      case 'PASSWORD_REQUIRED':
        return loc.passwordRequired;
      case 'INVALID_EMAIL':
        return loc.invalidEmail;
      case 'LOGIN_TOO_SHORT':
        return loc.loginTooShort(LoginValidators.loginMinLength);
      case 'PASSWORD_TOO_SHORT':
        return loc.passwordTooShort(LoginValidators.passwordMinLength);
      default:
        return e.message;
    }
  }

  String _mapGenericError(Object e, AppLocalizations? l10n) {
    return friendlyApiErrorL10n(l10n ?? _fallbackL10n, e);
  }

  Future<void> _loadProfile({
    required String baseUrl,
    required String token,
    dynamic loginUser,
  }) async {
    _api.configure(baseUrl: baseUrl, token: token);
    BioTimeUser? user;
    var roles = const BioTimeRoles();
    var menus = <BioTimeMenuItem>[];
    String? profileWarning;

    if (loginUser is Map) {
      final loginMap = Map<String, dynamic>.from(loginUser);
      user = BioTimeUser.fromJson(loginMap);
      final fromLogin = _profileFromBiotime(loginMap['biotime']);
      roles = fromLogin.roles;
      menus = fromLogin.menus;
    }

    try {
      final me = await _api.me();
      final userJson = me['user'];
      if (userJson is Map) user = BioTimeUser.fromJson(Map<String, dynamic>.from(userJson));
      final employee = me['employee'];
      final empName = employee is Map ? employee['name']?.toString() ?? '' : '';
      final empCode = employee is Map ? employee['code']?.toString() ?? '' : '';
      roles = BioTimeRoles.fromJson(me['roles'] as Map<String, dynamic>?);
      menus = (me['menus'] as List? ?? [])
          .whereType<Map>()
          .map((e) => BioTimeMenuItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final features = AuthFeatures.fromJson(
        me['features'] is Map
            ? Map<String, dynamic>.from(me['features'] as Map)
            : null,
      );
      String? companyName;
      String? companyCode;
      String? companyId;
      final companyRaw = me['company'];
      if (companyRaw is Map) {
        companyName = companyRaw['name']?.toString();
        companyCode = companyRaw['code']?.toString();
        companyId = companyRaw['id']?.toString();
      }
      emit(AuthState(
        status: AuthStatus.authenticated,
        token: token,
        user: user,
        employeeName: empName,
        employeeCode: empCode,
        roles: roles,
        menus: menus,
        features: features,
        isPlatformAdmin: roles.isPlatformAdmin,
        activeCompanyId: companyId ?? state.activeCompanyId,
        activeCompanyName: companyName ?? state.activeCompanyName,
        activeCompanyCode: companyCode ?? state.activeCompanyCode,
        profileWarning: menus.length <= 1
            ? tr('auth.menusInsufficient')
            : null,
      ));
      return;
    } on BioTimeApiException catch (e) {
      profileWarning = e.message;
    } catch (e) {
      profileWarning = e.toString();
    }

    profileWarning ??= menus.isEmpty ? tr('auth.profileLoadFailed') : null;

    emit(AuthState(
      status: AuthStatus.authenticated,
      token: token,
      user: user,
      roles: roles,
      menus: menus,
      profileWarning: profileWarning,
    ));
  }

  ({BioTimeRoles roles, List<BioTimeMenuItem> menus}) _profileFromBiotime(dynamic biotime) {
    if (biotime is! Map) {
      return (roles: const BioTimeRoles(), menus: <BioTimeMenuItem>[]);
    }
    final map = Map<String, dynamic>.from(biotime);
    final roles = BioTimeRoles.fromJson(map['roles'] as Map<String, dynamic>?);
    final menus = (map['menus'] as List? ?? [])
        .whereType<Map>()
        .map((e) => BioTimeMenuItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return (roles: roles, menus: menus);
  }

  String _resolveServerUrl(String? baseUrl) => ApiUrlResolver.resolve(baseUrl);

  Future<void> signOut() async {
    if (!PlatformAdminConfig.isLocalToken(state.token)) {
      try {
        await _api.logout();
      } catch (_) {}
    }
    await _session.clearToken();
    await _session.savePlatformAdmin(false);
    await _session.saveActiveCompanyId(null);
    _api.setActiveCompanyId(null);
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> setActiveCompany({
    required String id,
    String? name,
    String? code,
  }) async {
    await _session.saveActiveCompanyId(id);
    _api.setActiveCompanyId(id);
    emit(state.copyWith(
      activeCompanyId: id,
      activeCompanyName: name,
      activeCompanyCode: code,
    ));
  }

  Future<void> clearActiveCompany() async {
    await _session.saveActiveCompanyId(null);
    _api.setActiveCompanyId(null);
    emit(state.copyWith(clearActiveCompany: true));
  }

  /// Reload company labels after create/update (platform admin).
  Future<void> refreshCompanies() async {
    if (!state.isPlatformAdmin) return;
    final activeId = state.activeCompanyId;
    if (activeId == null || activeId.isEmpty) return;
    try {
      final data = await _api.adminCompaniesList();
      final companies = data['companies'];
      if (companies is! List) return;
      for (final raw in companies) {
        if (raw is Map && raw['id']?.toString() == activeId) {
          emit(state.copyWith(
            activeCompanyName: raw['name']?.toString(),
            activeCompanyCode: raw['code']?.toString(),
          ));
          return;
        }
      }
    } catch (_) {}
  }

  void clearError() {
    if (state.status != AuthStatus.error) {
      emit(state.copyWith(clearError: true));
      return;
    }
    emit(state.copyWith(status: AuthStatus.unauthenticated, clearError: true));
  }
}
