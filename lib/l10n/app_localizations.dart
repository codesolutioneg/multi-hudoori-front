import 'package:flutter/material.dart';

import '../core/config/api_config.dart';

import 'app_strings.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('ar'), Locale('en')];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  bool get isAr => locale.languageCode == 'ar';

  /// Translate a key with optional `{param}` placeholders.
  String t(String key, [Map<String, Object?> params = const {}]) {
    final map = isAr ? AppStrings.ar : AppStrings.en;
    var text = map[key] ?? AppStrings.ar[key] ?? key;
    for (final e in params.entries) {
      text = text.replaceAll('{${e.key}}', e.value?.toString() ?? '');
    }
    return text;
  }

  String get appName {
    if (ApiConfig.isDevEnv) {
      return isAr ? 'حضوري · DEV' : 'Hudoori · DEV';
    }
    return isAr ? 'حضوري' : 'Hudoori';
  }
  String get appTagline => isAr ? 'الحضور والرواتب' : 'Attendance & Payroll';
  String get signIn => isAr ? 'تسجيل الدخول' : 'Sign in';
  String get odooUrl => isAr ? 'رابط Odoo' : 'Odoo URL';
  String get emailOrLogin => isAr ? 'البريد / اسم المستخدم' : 'Email / Username';
  String get password => isAr ? 'كلمة المرور' : 'Password';
  String get login => isAr ? 'دخول' : 'Login';
  String get loginRequired => isAr ? 'أدخل البريد أو اسم المستخدم' : 'Enter email or username';
  String get passwordRequired => isAr ? 'أدخل كلمة المرور' : 'Enter your password';
  String get invalidEmail => isAr ? 'البريد الإلكتروني غير صحيح' : 'Enter a valid email address';
  String loginTooShort(int min) =>
      isAr ? 'اسم المستخدم قصير جداً (الحد الأدنى $min أحرف)' : 'Login is too short (min $min characters)';
  String loginTooLong(int max) =>
      isAr ? 'اسم المستخدم طويل جداً (الحد الأقصى $max حرف)' : 'Login is too long (max $max characters)';
  String passwordTooShort(int min) =>
      isAr ? 'كلمة المرور قصيرة جداً (الحد الأدنى $min أحرف)' : 'Password is too short (min $min characters)';
  String passwordTooLong(int max) =>
      isAr ? 'كلمة المرور طويلة جداً' : 'Password is too long (max $max characters)';
  String get invalidCredentials =>
      isAr ? 'بيانات الدخول غير صحيحة' : 'Invalid login or password';
  String get accountInactive =>
      isAr ? 'هذا الحساب غير مفعّل — تواصل مع المسؤول' : 'This account is inactive — contact your admin';
  String get logout => isAr ? 'تسجيل الخروج' : 'Logout';
  String get language => isAr ? 'اللغة' : 'Language';
  String get arabic => isAr ? 'العربية' : 'Arabic';
  String get english => 'English';
  String get home => isAr ? 'الرئيسية' : 'Home';

  String roleLabel({
    required bool isSystemAdmin,
    required bool isHrManager,
    required bool isHrSupervisor,
    required bool isBranchManager,
    required bool isEmployee,
  }) {
    if (isSystemAdmin) return isAr ? 'مدير النظام' : 'System Admin';
    if (isHrManager) return t('role.hrManager');
    if (isHrSupervisor) return t('role.hrSupervisor');
    if (isBranchManager) return t('role.branchManager');
    if (isEmployee) return t('role.employee');
    return t('role.user');
  }

  String hrRoleLabel({required bool isHrManager, required bool isHrSupervisor}) {
    if (isHrManager) return t('role.hrManager');
    if (isHrSupervisor) return t('role.hrSupervisor');
    return t('role.hrUser');
  }

  String greetingForHour(int hour) {
    if (hour < 12) return t('greeting.morning');
    if (hour < 17) return t('greeting.afternoon');
    return t('greeting.evening');
  }

  String formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return t('common.now');
    if (diff.inMinutes < 60) return t('common.minutesAgo', {'n': diff.inMinutes});
    if (diff.inHours < 24) return t('common.hoursAgo', {'n': diff.inHours});
    return t('common.daysAgo', {'n': diff.inDays});
  }

  String menuLabel(String id, {String? fallback}) {
    final labels = _menus[isAr] ?? _menus[true]!;
    return labels[id] ?? fallback ?? id;
  }

  static const Map<bool, Map<String, String>> _menus = {
    true: {
      'dashboard': 'الرئيسية',
      'my_schedule': 'جدولي',
      'my_attendance': 'حضوري',
      'my_requests': 'طلبات',
      'my_payslip': 'كشف راتبي',
      'hr_dashboard': 'لوحة HR',
      'employees': 'الموظفين',
      'shifts': 'الشيفتات',
      'shift_assignments': 'تعيين الشيفتات',
      'shift_grid': 'جدول الشيفتات',
      'attendance': 'الحضور',
      'deductions': 'الاستقطاعات',
      'advances': 'السلف',
      'my_advance_request': 'طلب سلفة',
      'mobile_punch': 'بصمة الموقع',
      'advance_requests': 'طلبات السلف',
      'tips': 'العمولة',
      'payroll': 'الرواتب',
      'reports': 'تقارير المتابعة',
      'hiring_appointments': 'التعيينات',
      'settings': 'إعدادات',
      'org_chart': 'الهيكل التنظيمي',
    },
    false: {
      'dashboard': 'Home',
      'my_schedule': 'My schedule',
      'my_attendance': 'My Attendance',
      'my_requests': 'Requests',
      'my_payslip': 'My Payslip',
      'hr_dashboard': 'HR Dashboard',
      'employees': 'Employees',
      'shifts': 'Shifts',
      'shift_assignments': 'Shift Assignments',
      'shift_grid': 'Shift Grid',
      'attendance': 'Attendance',
      'deductions': 'Deductions',
      'advances': 'Advances',
      'my_advance_request': 'Advance request',
      'mobile_punch': 'Location punch',
      'advance_requests': 'Advance requests',
      'tips': 'Commission',
      'payroll': 'Payroll',
      'reports': 'Compliance reports',
      'hiring_appointments': 'Hiring',
      'settings': 'Settings',
      'org_chart': 'Organization chart',
    },
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
