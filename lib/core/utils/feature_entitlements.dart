import '../../features/auth/auth_state.dart';
import '../router/app_router.dart';

/// Route prefix / exact path → product entitlement key (matches backend catalog).
const Map<String, String> kRouteFeatureMap = {
  AppRoutes.hrPayroll: 'payroll',
  AppRoutes.myPayroll: 'payroll',
  AppRoutes.hrDeductions: 'deductions',
  AppRoutes.hrAdvances: 'advances',
  AppRoutes.hrAdvanceRequests: 'advances',
  AppRoutes.hrAdvanceLoanImport: 'advances',
  AppRoutes.myAdvanceRequest: 'advances',
  AppRoutes.hrTips: 'payroll',
  AppRoutes.hrTipImport: 'payroll',
  AppRoutes.hrOvertime: 'overtime',
  AppRoutes.hrAttendance: 'attendance',
  AppRoutes.hrShifts: 'attendance',
  AppRoutes.hrShiftAssignments: 'attendance',
  AppRoutes.hrShiftGrid: 'attendance',
  AppRoutes.myAttendance: 'employee_app',
  AppRoutes.mySchedule: 'employee_app',
  AppRoutes.hrEmployees: 'hr_employees',
  AppRoutes.hrAbsentEmployees: 'hr_employees',
  AppRoutes.hrHiringAppointments: 'hr_employees',
  AppRoutes.hrHiringAppointmentCreate: 'hr_employees',
  AppRoutes.hrHealthCertificates: 'hr_employees',
  AppRoutes.orgChart: 'hr_employees',
  AppRoutes.hrReports: 'hr_reports',
  // Resolved in isRouteEntitled: HR inbox vs employee self-service.
  AppRoutes.requests: 'employee_app',
  // Settings stay available for HR managers — sections inside are gated.
};

/// Menu id → feature (same as backend `MENU_FEATURE_MAP`).
const Map<String, String> kMenuFeatureMap = {
  'hiring_appointments': 'hr_employees',
  'employees': 'hr_employees',
  'org_chart': 'hr_employees',
  'shifts': 'attendance',
  'shift_grid': 'attendance',
  'attendance': 'attendance',
  'my_attendance': 'employee_app',
  'my_schedule': 'employee_app',
  'my_advance_request': 'advances',
  'my_requests': 'employee_app',
  'my_payroll': 'payroll',
  'hr_requests': 'hr_requests',
  'advance_requests': 'advances',
  'advances': 'advances',
  'deductions': 'deductions',
  'tips': 'payroll',
  'payroll': 'payroll',
  'reports': 'hr_reports',
  'overtime': 'overtime',
};

/// End-user labels for entitlement keys (AR / EN).
const Map<String, ({String ar, String en})> kFeatureLabels = {
  'attendance': (ar: 'الحضور والشيفتات', en: 'Attendance & shifts'),
  'hr_employees': (ar: 'إدارة الموظفين', en: 'Employee management'),
  'hr_leaves': (ar: 'الإجازات', en: 'Leaves'),
  'hr_requests': (ar: 'الطلبات', en: 'HR requests'),
  'employee_app': (ar: 'تطبيق الموظف', en: 'Employee app'),
  'hr_reports': (ar: 'تقارير المتابعة', en: 'HR reports'),
  'payroll': (ar: 'الرواتب', en: 'Payroll'),
  'overtime': (ar: 'الساعات الإضافية', en: 'Overtime'),
  'advances': (ar: 'السلف', en: 'Advances'),
  'deductions': (ar: 'الاستقطاعات', en: 'Deductions'),
  'loans': (ar: 'القروض', en: 'Loans'),
  'fawry': (ar: 'فوري', en: 'Fawry'),
  'bank_export': (ar: 'تصدير بنكي', en: 'Bank export'),
  'advanced_reports': (ar: 'تقارير متقدمة', en: 'Advanced reports'),
  'api_access': (ar: 'واجهة API', en: 'API access'),
  'integrations': (ar: 'التكاملات (مثل Odoo)', en: 'Integrations (e.g. Odoo)'),
  'advanced_permissions': (ar: 'صلاحيات متقدمة', en: 'Advanced permissions'),
};

String featureLabel(String? key, {required bool isAr}) {
  if (key == null || key.isEmpty) {
    return isAr ? 'هذه الميزة' : 'This feature';
  }
  final row = kFeatureLabels[key];
  if (row == null) return isAr ? 'هذه الميزة' : 'This feature';
  return isAr ? row.ar : row.en;
}

/// Longest-prefix match so `/hr/payroll/123` resolves to `payroll`.
String? featureKeyForRoute(String location) {
  final path = location.split('?').first;
  if (kRouteFeatureMap.containsKey(path)) return kRouteFeatureMap[path];
  String? bestKey;
  var bestLen = 0;
  for (final entry in kRouteFeatureMap.entries) {
    final prefix = entry.key;
    if (path == prefix || path.startsWith('$prefix/')) {
      if (prefix.length > bestLen) {
        bestLen = prefix.length;
        bestKey = entry.value;
      }
    }
  }
  return bestKey;
}

/// Enabled feature keys for the current session.
///
/// Prefers `/me` entitlements; if missing, derives from API menus (already
/// filtered server-side) so Home shortcuts stay in sync with the sidebar.
Set<String> effectiveEnabledFeatures(AuthState state) {
  if (state.isPlatformAdmin || state.roles.isPlatformAdmin) {
    return {for (final k in kRouteFeatureMap.values) k};
  }
  final fromMe = <String>{};
  for (final e in state.features.entitlements.entries) {
    if (e.value) fromMe.add(e.key);
  }
  if (fromMe.isNotEmpty) return fromMe;

  final fromMenus = <String>{};
  for (final m in state.menus) {
    final f = kMenuFeatureMap[m.id];
    if (f != null) fromMenus.add(f);
  }
  return fromMenus;
}

bool isFeatureEnabled(AuthState state, String featureKey) {
  if (state.isPlatformAdmin || state.roles.isPlatformAdmin) return true;
  final enabled = effectiveEnabledFeatures(state);
  // Before profile load: don't hide the whole app.
  if (enabled.isEmpty && state.menus.isEmpty && state.features.entitlements.isEmpty) {
    return true;
  }
  return enabled.contains(featureKey);
}

/// Whether a UI entry that opens [route] should be shown.
bool isRouteEntitled(AuthState state, String route) {
  final path = route.split('?').first;
  if (path == AppRoutes.requests || path.startsWith('${AppRoutes.requests}/')) {
    return isFeatureEnabled(state, 'hr_requests') ||
        isFeatureEnabled(state, 'employee_app');
  }
  final feat = featureKeyForRoute(route);
  if (feat == null) return true;
  return isFeatureEnabled(state, feat);
}
