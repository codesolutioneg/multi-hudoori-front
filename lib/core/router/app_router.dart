import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/my_attendance_page.dart';
import '../../features/auth/auth_cubit.dart';
import '../../features/auth/auth_state.dart';
import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/auth/presentation/reset_password_page.dart';
import '../../features/auth/presentation/sign_in_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/dashboard/dashboard_page_v2.dart';
import '../../features/hr/absent_employees_page.dart';
import '../../features/hr/employee_detail_page.dart';
import '../../features/hr/employees_page.dart';
import '../../features/hr/hiring_appointment_create_page.dart';
import '../../features/hr/hiring_appointments_page.dart';
import '../../features/hr/health_certificates_page.dart';
import '../../features/attendance/my_schedule_page.dart';
import '../../features/employee/location_punch_page.dart';
import '../../features/hr/reports_page.dart';
import '../../features/notifications/app_notifications_page.dart';
import '../../features/hr/org_chart_page.dart';
import '../../features/hr/hr_dashboard_page.dart';
import '../../features/hr/hr_attendance_page.dart';
import '../../features/hr/overtime_page.dart';
import '../../features/hr/settings_page.dart';
import '../../features/requests/requests_page.dart';
import '../../features/advances/advance_loan_import_page.dart';
import '../../features/advances/advance_requests_queue_page.dart';
import '../../features/advances/advances_page.dart';
import '../../features/advances/my_advance_request_page.dart';
import '../../features/advances/tips_page.dart';
import '../../features/deductions/deductions_page.dart';
import '../../features/payroll/my_payroll_page.dart';
import '../../features/payroll/payroll_detail_page.dart';
import '../../features/payroll/payroll_list_page.dart';
import '../../features/placeholder/placeholder_page.dart';
import '../../features/shift_assignments/shift_assignments_page.dart';
import '../../features/shift_grid/shift_grid_detail_page.dart';
import '../../features/shift_grid/shift_grid_list_page.dart';
import '../../features/shifts/shifts_page.dart';
import '../../features/admin/admin_companies_page.dart';
import '../../features/admin/admin_create_user_page.dart';
import '../../features/admin/admin_dashboard_page.dart';
import '../../features/admin/admin_audit_access_page.dart';
import '../../features/admin/admin_plans_page.dart';
import '../../features/admin/admin_sales_requests_page.dart';
import '../../features/admin/admin_shell.dart';
import '../../features/admin/admin_users_page.dart';
import '../../features/audit/audit_log_page.dart';
import '../../features/common/access_denied_page.dart';
import '../../features/mobile/mobile_home_page.dart';
import '../../features/mobile/mobile_punch_page.dart';
import '../../features/shell/biotime_shell.dart';
import '../platform/mobile_platform.dart';
import '../utils/feature_entitlements.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const signIn = '/sign-in';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const accessDenied = '/access-denied';
  static const adminDashboard = '/admin/dashboard';
  static const adminCompanies = '/admin/companies';

  /// Platform Admin on native mobile — Super Admin console is web-only.
  static String accessDeniedWebOnly() => '$accessDenied?reason=web_only';
  static const adminSalesRequests = '/admin/sales-requests';
  static const adminPlans = '/admin/plans';
  static const adminUsers = '/admin/users';
  static const adminCreateUser = '/admin/users/create';
  static const adminAuditAccess = '/admin/audit-access';
  static const adminAssistantAccess = '/admin/assistant-access';
  static const adminEmployeeDeleteAccess = '/admin/employee-delete-access';
  static const dashboard = '/dashboard';
  static const myAttendance = '/attendance/my';
  static const mySchedule = '/my/schedule';
  static const myAdvanceRequest = '/my/advance-request';
  static const myLocationPunch = '/my/location-punch';
  static const requests = '/requests';
  static const notifications = '/notifications';
  static const myPayroll = '/payroll/my';
  static const hrDashboard = '/hr/dashboard';
  static const hrAbsentEmployees = '/hr/absent-employees';
  static const hrEmployees = '/hr/employees';
  static const hrShifts = '/hr/shifts';
  static const hrShiftAssignments = '/hr/shift-assignments';
  static const hrShiftGrid = '/hr/shift-grid';
  static const hrAttendance = '/hr/attendance';
  static const hrOvertime = '/hr/overtime';
  static const hrDeductions = '/hr/deductions';
  static const hrAdvances = '/hr/advances';
  static const hrAdvanceRequests = '/hr/advance-requests';
  static const hrAdvanceLoanImport = '/hr/advances/loan-import';
  static const hrTips = '/hr/tips';
  static const hrTipImport = '/hr/tips/import';
  static const hrPayroll = '/hr/payroll';
  static const hrSettings = '/hr/settings';
  static const hrHealthCertificates = '/hr/health-certificates';
  static const hrReports = '/hr/reports';
  static const hrAudit = '/hr/audit';
  static const hrHiringAppointments = '/hr/hiring-appointments';
  static const hrHiringAppointmentCreate = '/hr/hiring-appointments/create';
  static const orgChart = '/org-chart';
  /// Kept for older links; redirects handled by same page route.
  static const hrOrgChart = '/org-chart';

  static String hrEmployeeDetail(String id) => '/hr/employees/$id';

  static String accessDeniedFeature(String key) =>
      '$accessDenied?reason=feature&key=${Uri.encodeComponent(key)}';
  static String accessDeniedRole() => '$accessDenied?reason=role';
}

GoRouter createRouter(AuthCubit auth) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthRefresh(auth),
    redirect: (context, state) {
      final s = auth.state;
      final loggedIn = s.isAuthenticated;
      final location = state.matchedLocation;
      final boot =
          s.status == AuthStatus.initial || s.status == AuthStatus.loading;
      final isAuth =
          location == AppRoutes.signIn ||
          location == AppRoutes.forgotPassword ||
          location == AppRoutes.resetPassword;

      final isAdminRoute = location.startsWith('/admin');
      final isPlatformAdmin = s.isPlatformAdmin;
      // Native mobile: same HR/employee dashboard as web (drawer menus + /hr routes).
      // Super Admin (/admin) stays web-only.
      final isMobile = !kIsWeb;
      String homeForUser() {
        if (isPlatformAdmin) {
          return isMobile
              ? AppRoutes.accessDeniedWebOnly()
              : AppRoutes.adminDashboard;
        }
        if (s.roles.isHrStaff || s.roles.isBranchManager) {
          return AppRoutes.hrDashboard;
        }
        return AppRoutes.dashboard;
      }

      if (boot) return location == AppRoutes.splash ? null : AppRoutes.splash;
      if (location == AppRoutes.splash) {
        if (!loggedIn) {
          final q = state.uri.query;
          return q.isEmpty ? AppRoutes.signIn : '${AppRoutes.signIn}?$q';
        }
        return homeForUser();
      }
      if (!loggedIn && !isAuth) {
        final q = state.uri.query;
        return q.isEmpty ? AppRoutes.signIn : '${AppRoutes.signIn}?$q';
      }
      if (loggedIn && isAuth) {
        return homeForUser();
      }
      // Super Admin console is web-only on native apps.
      if (isMobile && loggedIn && isPlatformAdmin) {
        final isWebOnlyDenied =
            location == AppRoutes.accessDenied &&
            state.uri.queryParameters['reason'] == 'web_only';
        if (!isWebOnlyDenied) return AppRoutes.accessDeniedWebOnly();
      } else if (isMobile && loggedIn && isAdminRoute) {
        return AppRoutes.accessDeniedWebOnly();
      }
      if (loggedIn && isPlatformAdmin && !isAdminRoute && !isMobile) {
        if (location == AppRoutes.hrAudit ||
            location == AppRoutes.orgChart ||
            location == '/hr/org-chart') {
          return null;
        }
        return AppRoutes.adminDashboard;
      }
      if (loggedIn && !isPlatformAdmin && isAdminRoute)
        return AppRoutes.dashboard;
      if (loggedIn && location == AppRoutes.accessDenied) {
        return null;
      }
      if (loggedIn &&
          location == AppRoutes.hrSettings &&
          !s.roles.isHrManager) {
        return AppRoutes.accessDeniedRole();
      }
      if (loggedIn && location == AppRoutes.hrAudit && !s.canViewAudit) {
        return AppRoutes.accessDeniedRole();
      }
      // The branch queue belongs to branch managers. HR grants requests from the
      // «طلبات الفروع» tab in «السلف», so send them there instead.
      if (loggedIn &&
          location == AppRoutes.hrAdvanceRequests &&
          s.roles.isHrStaff) {
        return AppRoutes.hrAdvances;
      }
      // The org chart lays out the whole company, so it is HR-manager-only.
      // The menu already hides it; this stops anyone reaching it by URL.
      if (loggedIn &&
          (location == AppRoutes.orgChart || location == '/hr/org-chart') &&
          !s.roles.isHrManager &&
          !s.isPlatformAdmin) {
        return AppRoutes.accessDeniedRole();
      }
      // Plan entitlements: blocked modules show a clear page instead of a blank API error.
      if (loggedIn && !isAdminRoute) {
        final feat = featureKeyForRoute(location);
        if (feat != null && !isFeatureEnabled(s, feat)) {
          return AppRoutes.accessDeniedFeature(feat);
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashPage()),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => SignInPage(
          prefillCompanyCode: state.uri.queryParameters['companyCode'],
          prefillLogin: state.uri.queryParameters['login'],
          prefillPassword: state.uri.queryParameters['password'],
          fromDemo: state.uri.queryParameters['demo'] == '1',
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (_, state) => ResetPasswordPage(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      ShellRoute(
        builder: (_, __, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.adminDashboard,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AdminDashboardPage()),
          ),
          GoRoute(
            path: AppRoutes.adminCompanies,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AdminCompaniesPage()),
          ),
          GoRoute(
            path: AppRoutes.adminSalesRequests,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AdminSalesRequestsPage()),
          ),
          GoRoute(
            path: AppRoutes.adminPlans,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AdminPlansPage()),
          ),
          GoRoute(
            path: AppRoutes.adminUsers,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AdminUsersPage()),
          ),
          GoRoute(
            path: AppRoutes.adminCreateUser,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AdminCreateUserPage()),
          ),
          GoRoute(
            path: AppRoutes.adminAuditAccess,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AdminAuditAccessPage()),
          ),
          GoRoute(
            path: AppRoutes.adminAssistantAccess,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: AdminAuditAccessPage(
                feature: 'help_assistant',
                strings: 'assistPerm',
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.adminEmployeeDeleteAccess,
            pageBuilder: (_, __) => const NoTransitionPage(
              child: AdminAuditAccessPage(
                feature: 'employee_delete',
                strings: 'delPerm',
              ),
            ),
          ),
        ],
      ),
      ShellRoute(
        builder: (_, __, child) => BioTimeShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            pageBuilder: (_, __) => NoTransitionPage(
              child: isNativeMobile
                  ? const MobileHomePage()
                  : const DashboardPageV2(),
            ),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AppNotificationsPage()),
          ),
          GoRoute(
            path: AppRoutes.accessDenied,
            pageBuilder: (context, state) => NoTransitionPage(
              child: AccessDeniedPage(
                reason: state.uri.queryParameters['reason'],
                featureKey: state.uri.queryParameters['key'],
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.mySchedule,
            pageBuilder: (_, __) => const NoTransitionPage(child: MySchedulePage()),
          ),
          GoRoute(
            path: AppRoutes.myAttendance,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: MyAttendancePage()),
          ),
          GoRoute(
            path: AppRoutes.myAdvanceRequest,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: MyAdvanceRequestPage()),
          ),
          GoRoute(
            path: AppRoutes.myLocationPunch,
            pageBuilder: (_, __) => NoTransitionPage(
              child: isNativeMobile
                  ? const MobilePunchPage()
                  : const LocationPunchPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.hrAdvanceRequests,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AdvanceRequestsQueuePage()),
          ),
          GoRoute(
            path: AppRoutes.orgChart,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: OrgChartPage()),
          ),
          GoRoute(
            path: '/hr/org-chart',
            redirect: (_, __) => AppRoutes.orgChart,
          ),
          GoRoute(
            path: AppRoutes.requests,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: RequestsPage()),
          ),
          GoRoute(
            path: AppRoutes.myPayroll,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: MyPayrollPage()),
          ),
          GoRoute(
            path: AppRoutes.hrDashboard,
            pageBuilder: (_, __) => NoTransitionPage(
              child: isNativeMobile
                  ? const MobileHomePage()
                  : const HrDashboardPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.hrAbsentEmployees,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AbsentEmployeesPage()),
          ),
          GoRoute(
            path: AppRoutes.hrEmployees,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: EmployeesPage()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return NoTransitionPage(
                    child: EmployeeDetailPage(employeeId: id),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.hrShifts,
            pageBuilder: (_, __) => const NoTransitionPage(child: ShiftsPage()),
          ),
          GoRoute(
            path: AppRoutes.hrShiftGrid,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: ShiftGridListPage()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return NoTransitionPage(
                    child: ShiftGridDetailPage(gridId: id),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.hrAttendance,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: HrAttendancePage()),
          ),
          GoRoute(
            path: AppRoutes.hrOvertime,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: OvertimePage()),
          ),
          GoRoute(
            path: AppRoutes.hrShiftAssignments,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: ShiftAssignmentsPage()),
          ),
          GoRoute(
            path: AppRoutes.hrDeductions,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: DeductionsPage()),
          ),
          GoRoute(
            path: AppRoutes.hrAdvances,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AdvancesPage()),
          ),
          GoRoute(
            path: AppRoutes.hrAdvanceLoanImport,
            pageBuilder: (_, state) => NoTransitionPage(
              child: AdvanceLoanImportPage(
                initialImportId:
                    state.uri.queryParameters['importId'],
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.hrTips,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: TipsPage()),
          ),
          GoRoute(
            path: AppRoutes.hrTipImport,
            pageBuilder: (_, state) => NoTransitionPage(
              child: AdvanceLoanImportPage(
                kind: 'tip',
                initialImportId: state.uri.queryParameters['importId'],
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.hrPayroll,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: PayrollListPage()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
                  return NoTransitionPage(
                    child: PayrollDetailPage(payrollId: id),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.hrSettings,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: SettingsPage()),
          ),
          GoRoute(
            path: AppRoutes.hrHealthCertificates,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: HealthCertificatesPage()),
          ),
          GoRoute(
            path: AppRoutes.hrReports,
            pageBuilder: (_, __) => const NoTransitionPage(child: ReportsPage()),
          ),
          GoRoute(
            path: AppRoutes.hrAudit,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AuditLogPage()),
          ),
          GoRoute(
            path: AppRoutes.hrHiringAppointments,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: HiringAppointmentsPage()),
            routes: [
              GoRoute(
                path: 'create',
                pageBuilder: (_, __) => const NoTransitionPage(
                  child: HiringAppointmentCreatePage(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._auth) {
    _auth.stream.listen((_) => notifyListeners());
  }
  final AuthCubit _auth;
}
