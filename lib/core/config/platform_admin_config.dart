/// Local platform super-admin (works without API for dashboard access).
/// Create/manage users still requires biotime_backend on [ApiConfig.baseUrl].
class PlatformAdminConfig {
  static const login = 'bioadmin@admin.bio';
  static const password = 'Hudoori\$BioAdmin#2026!xK9mQ2';
  static const localToken = 'platform-admin-local-session';

  static bool matches(String inputLogin, String inputPassword) {
    return inputLogin.trim().toLowerCase() == login.toLowerCase() &&
        inputPassword == password;
  }

  static bool isLocalToken(String? token) =>
      token != null && token == localToken;
}
