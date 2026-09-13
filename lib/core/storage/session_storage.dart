import 'package:shared_preferences/shared_preferences.dart';

class SessionStorage {
  static const _tokenKey = 'biotime_api_token';
  static const _baseUrlKey = 'biotime_base_url';
  static const _dbKey = 'biotime_db';
  static const _localeKey = 'hudoori_locale';
  static const _platformAdminKey = 'biotime_platform_admin';
  static const _activeCompanyIdKey = 'hudoori_multi_active_company_id';
  static const _companyCodeKey = 'hudoori_multi_company_code';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<String?> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey);
  }

  Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
  }

  Future<String?> getDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dbKey);
  }

  Future<void> saveDatabase(String db) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dbKey, db);
  }

  Future<String?> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localeKey);
  }

  Future<void> saveLocale(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, code);
  }

  Future<bool> getPlatformAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_platformAdminKey) ?? false;
  }

  Future<void> savePlatformAdmin(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_platformAdminKey, value);
  }

  Future<String?> getActiveCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeCompanyIdKey);
  }

  Future<void> saveActiveCompanyId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await prefs.remove(_activeCompanyIdKey);
    } else {
      await prefs.setString(_activeCompanyIdKey, id);
    }
  }

  Future<String?> getCompanyCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_companyCodeKey);
  }

  Future<void> saveCompanyCode(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null || code.isEmpty) {
      await prefs.remove(_companyCodeKey);
    } else {
      await prefs.setString(_companyCodeKey, code);
    }
  }
}
