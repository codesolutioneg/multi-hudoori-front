import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/utils/app_log.dart';
import '../../l10n/l10n_extension.dart';

class BioTimeApiException implements Exception {
  BioTimeApiException(this.message, {this.code, this.data = const {}});
  final String message;
  final String? code;
  final Map<String, dynamic> data;
  @override
  String toString() => message;
}

class EmployeesPageResult {
  const EmployeesPageResult({
    required this.items,
    required this.total,
    required this.hasMore,
    required this.offset,
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final bool hasMore;
  final int offset;
}

class AttendancePageResult {
  const AttendancePageResult({
    required this.items,
    required this.total,
    required this.hasMore,
    required this.offset,
    required this.dateFrom,
    required this.dateTo,
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final bool hasMore;
  final int offset;
  final String dateFrom;
  final String dateTo;
}

class BioTimeApiClient {
  BioTimeApiClient({String? baseUrl})
    : _baseUrl = _normalize(baseUrl ?? ApiConfig.baseUrl);

  String _baseUrl;
  String? _token;
  /// Super Admin selected company (sent as X-Company-Id + activeCompanyId).
  String? _activeCompanyId;

  String get baseUrl => _baseUrl;
  String? get activeCompanyId => _activeCompanyId;

  void configure({String? baseUrl, String? token, String? activeCompanyId}) {
    if (baseUrl != null) _baseUrl = _normalize(baseUrl);
    if (token != null) _token = token;
    if (activeCompanyId != null) {
      _activeCompanyId = activeCompanyId.isEmpty ? null : activeCompanyId;
    }
  }

  void setActiveCompanyId(String? companyId) {
    _activeCompanyId = (companyId == null || companyId.isEmpty) ? null : companyId;
  }

  static String _normalize(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  Future<Map<String, dynamic>> login({
    required String login,
    required String password,
    String? db,
    String? companyCode,
  }) async {
    final result = await _call('/api/auth/login', {
      'login': login,
      'password': password,
      if (db != null && db.isNotEmpty) 'db': db,
      if (companyCode != null && companyCode.trim().isNotEmpty)
        'companyCode': companyCode.trim().toLowerCase(),
      'device_info': 'Hudoori Multi App',
    }, auth: false);
    if (result['success'] != true) {
      throw BioTimeApiException(
        result['message']?.toString() ?? tr('api.loginFailed'),
        code: result['error_code']?.toString(),
      );
    }
    final data = result['data'] as Map<String, dynamic>? ?? {};
    _token = data['token']?.toString();
    return data;
  }

  Future<Map<String, dynamic>> forgotPassword({
    required String loginOrEmail,
  }) async {
    return _unwrap(
      await _call('/api/auth/forgot-password', {
        'loginOrEmail': loginOrEmail,
      }, auth: false),
    );
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    return _unwrap(
      await _call('/api/auth/reset-password', {
        'token': token,
        'password': password,
        'confirmPassword': confirmPassword,
      }, auth: false),
    );
  }

  Future<void> logout() async {
    if (_token == null) return;
    try {
      await _call('/api/auth/logout', {'token': _token}, auth: false);
    } finally {
      _token = null;
    }
  }

  Future<bool> validateToken() async {
    if (_token == null) return false;
    final result = await _call('/api/auth/validate', {
      'token': _token,
    }, auth: false);
    return result['valid'] == true || result['success'] == true;
  }

  Future<Map<String, dynamic>> me() async {
    return _unwrap(await _call('/api/biotime/me', {}));
  }

  Future<Map<String, dynamic>> dashboardStats() async {
    return _unwrap(await _call('/api/biotime/dashboard/stats', {}));
  }

  Future<Map<String, dynamic>> dashboardNotifications() async {
    return _unwrap(await _call('/api/biotime/dashboard/notifications', {}));
  }

  Future<Map<String, dynamic>> dashboardNotificationsReadAll() async {
    return _unwrap(
      await _call('/api/biotime/dashboard/notifications/read-all', {}),
    );
  }

  Future<Map<String, dynamic>> absencesList() async {
    return _unwrap(await _call('/api/biotime/absences/list', {}));
  }

  Future<Map<String, dynamic>> absencesMarkRead() async {
    return _unwrap(await _call('/api/biotime/absences/read', {}));
  }

  Future<List<Map<String, dynamic>>> hiringAppointmentsList({
    int limit = 50,
    int offset = 0,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/hiring-appointments/list', {
        'limit': limit,
        'offset': offset,
      }),
    );
    return _listFrom(data['appointments']);
  }

  Future<int> hiringAppointmentsUnreadCount() async {
    final data = _unwrap(
      await _call('/api/biotime/hiring-appointments/unread-count', {}),
    );
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> hiringAppointmentsMarkSeen() async {
    _unwrap(await _call('/api/biotime/hiring-appointments/mark-seen', {}));
  }

  Future<Map<String, dynamic>> hiringAppointmentCreate(
    Map<String, dynamic> body,
  ) async {
    return _unwrap(
      await _call('/api/biotime/hiring-appointments/create', body),
    );
  }

  Future<Map<String, dynamic>> hiringAppointmentPdf(Object id) async {
    return _unwrap(
      await _call('/api/biotime/hiring-appointments/pdf', {
        'appointmentId': id,
      }),
    );
  }

  Future<Map<String, dynamic>> hiringAppointmentUpdate(
    Map<String, dynamic> body,
  ) async {
    return _unwrap(
      await _call('/api/biotime/hiring-appointments/update', body),
    );
  }

  Future<Map<String, dynamic>> dashboardCharts() async {
    return _unwrap(await _call('/api/biotime/dashboard/charts', {}));
  }

  Future<List<Map<String, dynamic>>> myAttendance({
    String? dateFrom,
    String? dateTo,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/attendance/my', {
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
      }),
    );
    return _listFromData(data);
  }

  // --- Shift grid ---

  Future<List<Map<String, dynamic>>> shiftGridList({
    String? state,
    Object? deviceId,
    int limit = 30,
    int offset = 0,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/shift-grid/list', {
        if (state != null) 'state': state,
        if (deviceId != null) 'deviceId': deviceId,
        'limit': limit,
        'offset': offset,
      }),
    );
    return _listFromData(data);
  }

  Future<EmployeesPageResult> shiftGridListPage({
    String? state,
    Object? deviceId,
    int limit = 30,
    int offset = 0,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/shift-grid/list', {
        if (state != null) 'state': state,
        if (deviceId != null) 'deviceId': deviceId,
        'limit': limit,
        'offset': offset,
      }),
    );
    return EmployeesPageResult(
      items: _listFromData(data),
      total: (data['total'] as num?)?.toInt() ?? 0,
      hasMore: data['hasMore'] == true,
      offset: (data['offset'] as num?)?.toInt() ?? offset,
    );
  }

  Future<Map<String, dynamic>> shiftGridGet(
    Object gridId, {
    bool includeData = true,
    bool metaOnly = false,
    int? employeeLimit,
    int? employeeOffset,
    String? grouping,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/get', {
        'gridId': gridId,
        if (!includeData) 'includeData': false,
        if (metaOnly) 'metaOnly': true,
        if (employeeLimit != null) 'employeeLimit': employeeLimit,
        if (employeeOffset != null) 'employeeOffset': employeeOffset,
        if (grouping != null) 'grouping': grouping,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridCreate({
    required String dateFrom,
    required String dateTo,
    String selectionMethod = 'department',
    List<Object>? departmentIds,
    List<Object>? employeeIds,
    Object? deviceId,
    Object? locationId,
    String? gridLocation,
    bool generate = true,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/create', {
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        'selectionMethod': selectionMethod,
        if (departmentIds != null) 'departmentIds': departmentIds,
        if (employeeIds != null) 'employeeIds': employeeIds,
        if (deviceId != null) 'deviceId': deviceId,
        if (locationId != null) 'locationId': locationId,
        if (gridLocation != null && gridLocation.isNotEmpty)
          'gridLocation': gridLocation,
        'generate': generate,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridCreateAllLocations({
    required String dateFrom,
    required String dateTo,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/create-all-locations', {
        'dateFrom': dateFrom,
        'dateTo': dateTo,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridGenerate(
    Object gridId, {
    String? dateFrom,
    String? dateTo,
    String? conflictAction,
    List<Object>? employeeIds,
    List<Object>? departmentIds,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/generate', {
        'gridId': gridId,
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
        if (conflictAction != null) 'conflictAction': conflictAction,
        if (employeeIds != null) 'employeeIds': employeeIds,
        if (departmentIds != null) 'departmentIds': departmentIds,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridUpdate(
    Object gridId, {
    String? dateFrom,
    String? dateTo,
    String? selectionMethod,
    String? conflictAction,
    Object? deviceId,
    Object? locationId,
    List<Object>? employeeIds,
    List<Object>? departmentIds,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/update', {
        'gridId': gridId,
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
        if (selectionMethod != null) 'selectionMethod': selectionMethod,
        if (conflictAction != null) 'conflictAction': conflictAction,
        if (deviceId != null) 'deviceId': deviceId,
        if (locationId != null) 'locationId': locationId,
        if (employeeIds != null) 'employeeIds': employeeIds,
        if (departmentIds != null) 'departmentIds': departmentIds,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridBackToSetup(Object gridId) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/back-to-setup', {'gridId': gridId}),
    );
  }

  Future<Map<String, dynamic>> shiftGridUpdateCell({
    required Object gridId,
    Object? lineId,
    Object? employeeId,
    String? date,
    required String cellValue,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/cell/update', {
        'gridId': gridId,
        if (lineId != null && '$lineId'.trim().isNotEmpty) 'lineId': lineId,
        if (employeeId != null && '$employeeId'.trim().isNotEmpty)
          'employeeId': employeeId,
        if (date != null && date.trim().isNotEmpty) 'date': date.trim(),
        'cellValue': cellValue,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridBulkRow({
    required Object gridId,
    required Object employeeId,
    required String cellValue,
    String? dateFrom,
    String? dateTo,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/bulk/row', {
        'gridId': gridId,
        'employeeId': employeeId,
        'cellValue': cellValue,
        if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridBulkColumn({
    required Object gridId,
    required String date,
    required String cellValue,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/bulk/column', {
        'gridId': gridId,
        'date': date,
        'cellValue': cellValue,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridAddEmployee({
    required Object gridId,
    String? employeeId,
    String? employeeCode,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/add-employee', {
        'gridId': gridId,
        if (employeeId != null && employeeId.isNotEmpty)
          'employeeId': employeeId,
        if (employeeCode != null && employeeCode.isNotEmpty)
          'employeeCode': employeeCode,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridAddEmployees({
    required Object gridId,
    required List<String> employeeIds,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/add-employees', {
        'gridId': gridId,
        'employeeIds': employeeIds,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridRemoveEmployee({
    required Object gridId,
    required Object employeeId,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/remove-employee', {
        'gridId': gridId,
        'employeeId': employeeId,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridTransferEmployee({
    required Object gridId,
    required Object targetGridId,
    required Object employeeId,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/transfer-employee', {
        'gridId': gridId,
        'targetGridId': targetGridId,
        'employeeId': employeeId,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridDayPunches(Object lineId) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/punches', {'lineId': lineId}),
    );
  }

  Future<Map<String, dynamic>> shiftGridSyncStart(Object gridId) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/sync/start', {'gridId': gridId}),
    );
  }

  Future<Map<String, dynamic>> shiftGridSyncStatus(Object gridId) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/sync/status', {'gridId': gridId}),
    );
  }

  Future<void> shiftGridSyncReset(Object gridId) async {
    _unwrap(
      await _call('/api/biotime/shift-grid/sync/reset', {'gridId': gridId}),
    );
  }

  Future<void> shiftGridSyncCancel(Object gridId) async {
    _unwrap(
      await _call('/api/biotime/shift-grid/sync/cancel', {'gridId': gridId}),
    );
  }

  Future<Map<String, dynamic>> shiftGridClose(Object gridId) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/close', {'gridId': gridId}),
    );
  }

  Future<Map<String, dynamic>> shiftGridReopen(Object gridId) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/reopen', {'gridId': gridId}),
    );
  }

  Future<Map<String, dynamic>> shiftGridConfirm(Object gridId) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/confirm-assignments', {
        'gridId': gridId,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridClearAssignments(Object gridId) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/clear-assignments', {
        'gridId': gridId,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridWipeEmployees(Object gridId) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/wipe-employees', {'gridId': gridId}),
    );
  }

  Future<Map<String, dynamic>> shiftGridDelete(Object gridId) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/delete', {'gridId': gridId}),
    );
  }

  Future<Map<String, dynamic>> shiftGridResyncDates(Object gridId) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/resync-dates', {'gridId': gridId}),
    );
  }

  Future<List<Map<String, dynamic>>> shiftsList() async {
    final data = _unwrap(await _call('/api/biotime/shifts/list', {}));
    return _listFromData(data);
  }

  Future<Map<String, dynamic>> shiftsExportXlsx() async {
    return _unwrap(await _call('/api/biotime/shifts/export-xlsx', {}));
  }

  Future<Map<String, dynamic>> shiftsImportXlsx(String base64) async {
    return _unwrap(
      await _call('/api/biotime/shifts/import-xlsx', {'base64': base64}),
    );
  }

  Future<List<Map<String, dynamic>>> devicesList() async {
    final data = _unwrap(await _call('/api/biotime/devices/list', {}));
    return _listFromData(data);
  }

  Future<Map<String, dynamic>> deviceUpdate(
    Object id, {
    String? locationId,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/devices/update', {
        'deviceId': id,
        if (locationId != null) 'locationId': locationId,
      }),
    );
    return Map<String, dynamic>.from(data['device'] as Map? ?? {});
  }

  Future<List<Map<String, dynamic>>> departmentsList({
    bool activeOnly = true,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/departments/list', {
        if (!activeOnly) 'activeOnly': false,
      }),
    );
    return _listFromData(data);
  }

  Future<Map<String, dynamic>> departmentCreate(
    Map<String, dynamic> body,
  ) async {
    final data = _unwrap(await _call('/api/biotime/departments/create', body));
    return Map<String, dynamic>.from(data['department'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> departmentUpdate(
    Object id,
    Map<String, dynamic> body,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/departments/update', {
        'departmentId': id,
        ...body,
      }),
    );
    return Map<String, dynamic>.from(data['department'] as Map? ?? {});
  }

  Future<void> departmentDelete(Object id) async {
    _unwrap(
      await _call('/api/biotime/departments/delete', {'departmentId': id}),
    );
  }

  // --- Locations ---

  Future<List<Map<String, dynamic>>> locationsList({
    bool activeOnly = true,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/locations/list', {
        if (!activeOnly) 'activeOnly': false,
      }),
    );
    return _listFromData(data);
  }

  Future<Map<String, dynamic>> locationCreate(Map<String, dynamic> body) async {
    final data = _unwrap(await _call('/api/biotime/locations/create', body));
    return Map<String, dynamic>.from(data['location'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> locationUpdate(
    Object id,
    Map<String, dynamic> body,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/locations/update', {'locationId': id, ...body}),
    );
    return Map<String, dynamic>.from(data['location'] as Map? ?? {});
  }

  Future<void> locationDelete(Object id) async {
    _unwrap(await _call('/api/biotime/locations/delete', {'locationId': id}));
  }

  Future<Map<String, dynamic>> mobilePunchContext() async {
    final data = _unwrap(await _call('/api/biotime/mobile-punch/context', {}));
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> mobilePunchCheckIn({
    required double latitude,
    required double longitude,
    String? clientPunchAt,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/mobile-punch/check-in', {
        'latitude': latitude,
        'longitude': longitude,
        if (clientPunchAt != null) 'clientPunchAt': clientPunchAt,
      }),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> mobilePunchCheckOut({
    required double latitude,
    required double longitude,
    String? clientPunchAt,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/mobile-punch/check-out', {
        'latitude': latitude,
        'longitude': longitude,
        if (clientPunchAt != null) 'clientPunchAt': clientPunchAt,
      }),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> locationEmployees(
    Object locationId,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/locations/employees', {
        'locationId': locationId,
      }),
    );
    return _listFromData(data);
  }

  Future<Map<String, dynamic>> locationsExportXlsx() async {
    return _unwrap(await _call('/api/biotime/locations/export-xlsx', {}));
  }

  Future<Map<String, dynamic>> locationsImportXlsx(String base64) async {
    return _unwrap(
      await _call('/api/biotime/locations/import-xlsx', {'base64': base64}),
    );
  }

  // --- Shifts CRUD ---

  Future<Map<String, dynamic>> shiftGet(Object shiftId) async {
    final data = _unwrap(
      await _call('/api/biotime/shifts/get', {'shiftId': shiftId}),
    );
    return Map<String, dynamic>.from(data['shift'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> shiftCreate(Map<String, dynamic> body) async {
    final data = _unwrap(await _call('/api/biotime/shifts/create', body));
    return Map<String, dynamic>.from(data['shift'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> shiftUpdate(
    Object shiftId,
    Map<String, dynamic> body,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/shifts/update', {'shiftId': shiftId, ...body}),
    );
    return Map<String, dynamic>.from(data['shift'] as Map? ?? {});
  }

  Future<void> shiftDelete(Object shiftId) async {
    _unwrap(
      await _call('/api/biotime/shifts/delete', {
        'shiftId': shiftId,
        'id': shiftId,
      }),
    );
  }

  // --- Shift assignments ---

  Future<List<Map<String, dynamic>>> shiftAssignmentsList({
    Object? employeeId,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/shift-assignments/list', {
        if (employeeId != null) 'employeeId': employeeId,
      }),
    );
    return _listFromData(data);
  }

  Future<Map<String, dynamic>> shiftAssignmentGet(Object id) async {
    final data = _unwrap(
      await _call('/api/biotime/shift-assignments/get', {'assignmentId': id}),
    );
    return Map<String, dynamic>.from(data['assignment'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> shiftAssignmentCreate(
    Map<String, dynamic> body,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/shift-assignments/create', body),
    );
    return Map<String, dynamic>.from(data['assignment'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> shiftAssignmentUpdate(
    Object id,
    Map<String, dynamic> body,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/shift-assignments/update', {
        'assignmentId': id,
        ...body,
      }),
    );
    return Map<String, dynamic>.from(data['assignment'] as Map? ?? {});
  }

  Future<void> shiftAssignmentDelete(Object id) async {
    _unwrap(
      await _call('/api/biotime/shift-assignments/delete', {
        'assignmentId': id,
      }),
    );
  }

  Future<EmployeesPageResult> employeesList({
    String? search,
    Object? departmentId,
    Object? locationId,
    Object? biotimeDeviceId,
    Object? excludeGridId,
    bool? biotimeSynced,
    bool active = true,
    bool includeInactive = false,
    int limit = 30,
    int offset = 0,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/employees/list', {
        if (search != null && search.isNotEmpty) 'search': search,
        if (departmentId != null) 'departmentId': departmentId,
        if (locationId != null) 'locationId': locationId,
        if (biotimeDeviceId != null) 'biotimeDeviceId': biotimeDeviceId,
        if (excludeGridId != null) 'excludeGridId': excludeGridId,
        if (biotimeSynced != null) 'biotimeSynced': biotimeSynced,
        if (includeInactive) 'includeInactive': true,
        'active': active,
        'limit': limit,
        'offset': offset,
      }),
    );
    final items = _listFrom(data['employees']);
    return EmployeesPageResult(
      items: items,
      total: (data['total'] as num?)?.toInt() ?? items.length,
      hasMore: data['hasMore'] == true,
      offset: (data['offset'] as num?)?.toInt() ?? offset,
    );
  }

  Future<Map<String, dynamic>> employeesExportXlsx({
    String? search,
    Object? departmentId,
    Object? locationId,
    Object? biotimeDeviceId,
    bool? biotimeSynced,
    List<String>? employeeIds,
    bool templateOnly = false,
  }) async {
    return _unwrap(
      await _call('/api/biotime/employees/export-xlsx', {
        if (search != null && search.isNotEmpty) 'search': search,
        if (departmentId != null) 'departmentId': departmentId,
        if (locationId != null) 'locationId': locationId,
        if (biotimeDeviceId != null) 'biotimeDeviceId': biotimeDeviceId,
        if (biotimeSynced != null) 'biotimeSynced': biotimeSynced,
        if (employeeIds != null && employeeIds.isNotEmpty)
          'employeeIds': employeeIds,
        if (templateOnly) 'templateOnly': true,
      }),
    );
  }

  Future<Map<String, dynamic>> employeesImportXlsx(String base64) async {
    return _unwrap(
      await _call('/api/biotime/employees/import-xlsx', {'base64': base64}),
    );
  }

  Future<Map<String, dynamic>> employeesPunchReportExportXlsx({
    required String dateFrom,
    required String dateTo,
    String? search,
    Object? departmentId,
    bool? biotimeSynced,
    List<String>? employeeIds,
    bool includeAllBiotimeCodes = false,
  }) async {
    return _unwrap(
      await _call('/api/biotime/employees/punch-report-export-xlsx', {
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        if (search != null && search.isNotEmpty) 'search': search,
        if (departmentId != null) 'departmentId': departmentId,
        if (biotimeSynced != null) 'biotimeSynced': biotimeSynced,
        if (employeeIds != null && employeeIds.isNotEmpty)
          'employeeIds': employeeIds,
        if (includeAllBiotimeCodes) 'includeAllBiotimeCodes': true,
      }),
    );
  }

  /// Background punch-report export (sync + Excel). Polls until done, then downloads.
  Future<Map<String, dynamic>> employeesPunchReportExportJob({
    required String dateFrom,
    required String dateTo,
    List<String>? employeeIds,
    bool includeAllBiotimeCodes = false,
    bool syncFirst = true,
    void Function(String message, {int? progress})? onProgress,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/employees/punch-report-export/start', {
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        'syncFirst': syncFirst,
        if (includeAllBiotimeCodes) 'includeAllBiotimeCodes': true,
        if (!includeAllBiotimeCodes &&
            employeeIds != null &&
            employeeIds.isNotEmpty)
          'employeeIds': employeeIds,
      }),
    );
    final jobId = data['jobId']?.toString();
    if (jobId == null || jobId.isEmpty) {
      throw BioTimeApiException(tr('api.noJobId'));
    }
    await _waitForJob(jobId, onProgress: onProgress, maxSeconds: 1800);
    return _unwrap(
      await _call('/api/biotime/employees/punch-report-export/download', {
        'jobId': jobId,
      }),
    );
  }

  Future<Map<String, dynamic>> employeeGet(Object employeeId) async {
    final data = _unwrap(
      await _call('/api/biotime/employees/get', {'employeeId': employeeId}),
    );
    return Map<String, dynamic>.from(data['employee'] as Map? ?? {});
  }

  Future<({Map<String, dynamic> employee, Map<String, dynamic> leaveSummary})>
  employeeGetDetail(Object employeeId) async {
    final data = _unwrap(
      await _call('/api/biotime/employees/get', {'employeeId': employeeId}),
    );
    return (
      employee: Map<String, dynamic>.from(data['employee'] as Map? ?? {}),
      leaveSummary: Map<String, dynamic>.from(
        data['leaveSummary'] as Map? ?? {},
      ),
    );
  }

  Future<Map<String, dynamic>> employeeInsurancePrintUpload(
    Object employeeId, {
    required String base64,
    String? mimeType,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/employees/insurance-print/upload', {
        'employeeId': employeeId,
        'base64': base64,
        if (mimeType != null) 'mimeType': mimeType,
      }),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> employeeInsurancePrintGet(
    Object employeeId,
  ) async {
    return _unwrap(
      await _call('/api/biotime/employees/insurance-print/get', {
        'employeeId': employeeId,
      }),
    );
  }

  Future<Map<String, dynamic>> employeeDocumentUpload(
    Object employeeId, {
    required String documentType,
    required String base64,
    String? mimeType,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/employees/document/upload', {
        'employeeId': employeeId,
        'documentType': documentType,
        'base64': base64,
        if (mimeType != null) 'mimeType': mimeType,
      }),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> employeeDocumentGet(
    Object employeeId, {
    required String documentType,
  }) async {
    return _unwrap(
      await _call('/api/biotime/employees/document/get', {
        'employeeId': employeeId,
        'documentType': documentType,
      }),
    );
  }

  Future<List<Map<String, dynamic>>> healthCertificateAlerts() async {
    final data = _unwrap(
      await _call('/api/biotime/health-certificates/alerts', {}),
    );
    return _listFrom(data['alerts']);
  }

  Future<List<Map<String, dynamic>>> insuranceCompaniesList({
    bool activeOnly = true,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/insurance-companies/list', {
        if (!activeOnly) 'activeOnly': false,
      }),
    );
    return _listFrom(data['companies']);
  }

  Future<Map<String, dynamic>> insuranceCompanyCreate(
    Map<String, dynamic> body,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/insurance-companies/create', body),
    );
    return Map<String, dynamic>.from(data['company'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> insuranceCompanyUpdate(
    Object id,
    Map<String, dynamic> body,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/insurance-companies/update', {
        'companyId': id,
        ...body,
      }),
    );
    return Map<String, dynamic>.from(data['company'] as Map? ?? {});
  }

  Future<void> insuranceCompanyDelete(Object id) async {
    _unwrap(
      await _call('/api/biotime/insurance-companies/delete', {'companyId': id}),
    );
  }

  Future<List<Map<String, dynamic>>> custodyTypesList({
    bool activeOnly = true,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/custody-types/list', {
        if (!activeOnly) 'activeOnly': false,
      }),
    );
    return _listFrom(data['types']);
  }

  Future<Map<String, dynamic>> custodyTypeCreate(
    Map<String, dynamic> body,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/custody-types/create', body),
    );
    return Map<String, dynamic>.from(data['type'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> custodyTypeUpdate(
    Object id,
    Map<String, dynamic> body,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/custody-types/update', {'typeId': id, ...body}),
    );
    return Map<String, dynamic>.from(data['type'] as Map? ?? {});
  }

  Future<void> custodyTypeDelete(Object id) async {
    _unwrap(await _call('/api/biotime/custody-types/delete', {'typeId': id}));
  }

  Future<List<Map<String, dynamic>>> jobTitlesList({
    bool activeOnly = true,
    bool syncFromEmployees = false,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/job-titles/list', {
        if (!activeOnly) 'activeOnly': false,
        if (syncFromEmployees) 'syncFromEmployees': true,
      }),
    );
    return _listFrom(data['titles']);
  }

  Future<Map<String, dynamic>> orgChartTree({
    String scope = 'company',
    Object? locationId,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/org-chart/tree', {
        'scope': scope,
        if (locationId != null) 'locationId': locationId,
      }),
    );
    return Map<String, dynamic>.from(data);
  }

  /// Managers this employee may be moved under — the server already drops anyone
  /// that would close a cycle.
  Future<List<Map<String, dynamic>>> orgChartManagerOptions({
    required Object employeeId,
    String search = '',
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/org-chart/manager-options', {
        'employeeId': employeeId,
        if (search.trim().isNotEmpty) 'search': search.trim(),
      }),
    );
    return _listFrom(data['managers']);
  }

  /// Pass a null [managerId] to detach the employee and let derivation take over.
  Future<void> orgChartSetManager({
    required Object employeeId,
    Object? managerId,
  }) async {
    _unwrap(
      await _call('/api/biotime/org-chart/set-manager', {
        'employeeId': employeeId,
        'managerId': managerId,
      }),
    );
  }

  // ---- Advance requests («طلب سلفة») ----

  /// Entitlement for the request form. Employees always get their own figure
  /// regardless of [employeeId]; approvers pass [excludeRequestId] so the request
  /// under review does not count against itself.
  Future<Map<String, dynamic>> advanceRequestEligibility({
    Object? employeeId,
    Object? excludeRequestId,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/advance-requests/eligibility', {
        if (employeeId != null) 'employeeId': employeeId,
        if (excludeRequestId != null) 'excludeRequestId': excludeRequestId,
      }),
    );
    return Map<String, dynamic>.from(data);
  }

  /// Omit [employeeId] to request for yourself; managers pass it to file on
  /// behalf of one of their staff.
  Future<Map<String, dynamic>> advanceRequestCreate({
    Object? employeeId,
    required num amount,
    required String reason,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/advance-requests/create', {
        if (employeeId != null) 'employeeId': employeeId,
        'amount': amount,
        'reason': reason,
      }),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> advanceRequestMine() async {
    final data = _unwrap(await _call('/api/biotime/advance-requests/my', {}));
    return _listFrom(data['requests']);
  }

  /// The approval queue. The server scopes it: branch managers see their own
  /// branch, HR sees everything. Pass `all` for [state] to include closed rows.
  Future<List<Map<String, dynamic>>> advanceRequestList({
    String? state,
    Object? locationId,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/advance-requests/list', {
        if (state != null && state.isNotEmpty) 'state': state,
        if (locationId != null) 'locationId': locationId,
      }),
    );
    return _listFrom(data['requests']);
  }

  Future<Map<String, dynamic>> advanceRequestBranchApprove(Object id) async {
    final data = _unwrap(
      await _call('/api/biotime/advance-requests/branch-approve', {'id': id}),
    );
    return Map<String, dynamic>.from(data);
  }

  /// HR approval — this is what creates the advance payroll will deduct.
  /// [amount] may trim the requested figure; going above the entitlement needs
  /// [limitOverride] together with an [overrideReason].
  Future<Map<String, dynamic>> advanceRequestApprove({
    required Object id,
    num? amount,
    bool limitOverride = false,
    String? overrideReason,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/advance-requests/approve', {
        'id': id,
        if (amount != null) 'amount': amount,
        if (limitOverride) 'limitOverride': true,
        if (overrideReason != null && overrideReason.trim().isNotEmpty)
          'overrideReason': overrideReason.trim(),
      }),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> advanceRequestReject({
    required Object id,
    required String reason,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/advance-requests/reject', {
        'id': id,
        'reason': reason,
      }),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> advanceRequestCancel(Object id) async {
    final data = _unwrap(
      await _call('/api/biotime/advance-requests/cancel', {'id': id}),
    );
    return Map<String, dynamic>.from(data);
  }

  // ---- Branch managers («مدير الفرع») ----

  /// Every active branch with whoever signs off its advance requests — either the
  /// employee HR picked or the head the org chart derives.
  Future<List<Map<String, dynamic>>> branchManagersList() async {
    final data = _unwrap(await _call('/api/biotime/branch-managers/list', {}));
    return _listFrom(data['branches']);
  }

  /// Pass a null [employeeId] to clear the choice and fall back to the org chart.
  Future<Map<String, dynamic>> branchManagerSet({
    required Object locationId,
    Object? employeeId,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/branch-managers/set', {
        'locationId': locationId,
        'employeeId': employeeId,
      }),
    );
    return Map<String, dynamic>.from(data);
  }

  // ---- Job ladder («تدرج الوظائف») ----

  Future<Map<String, dynamic>> jobLevelsList() async {
    final data = _unwrap(await _call('/api/biotime/job-levels/list', {}));
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> jobLevelCreate({
    required String name,
    String? nameEn,
    String? code,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/job-levels/create', {
        'name': name,
        if (nameEn != null) 'nameEn': nameEn,
        if (code != null) 'code': code,
      }),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> jobLevelUpdate({
    required Object id,
    String? name,
    String? nameEn,
    String? code,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/job-levels/update', {
        'id': id,
        if (name != null) 'name': name,
        if (nameEn != null) 'nameEn': nameEn,
        if (code != null) 'code': code,
      }),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> jobLevelDelete(Object id) async {
    final data = _unwrap(
      await _call('/api/biotime/job-levels/delete', {'id': id}),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> jobLevelsReorder(List<String> orderedIds) async {
    final data = _unwrap(
      await _call('/api/biotime/job-levels/reorder', {
        'orderedIds': orderedIds,
      }),
    );
    return Map<String, dynamic>.from(data);
  }

  /// [levelId] null takes the title off the ladder (back to the built-in guess).
  Future<Map<String, dynamic>> jobLevelAssignTitle({
    required Object jobTitleId,
    Object? levelId,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/job-levels/assign-title', {
        'jobTitleId': jobTitleId,
        'levelId': levelId,
      }),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> jobTitlesSyncFromEmployees() async {
    final data = _unwrap(
      await _call('/api/biotime/job-titles/sync-from-employees', {}),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> jobTitleCreate(Map<String, dynamic> body) async {
    final data = _unwrap(await _call('/api/biotime/job-titles/create', body));
    return Map<String, dynamic>.from(data['title'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> jobTitleUpdate(
    Object id,
    Map<String, dynamic> body,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/job-titles/update', {'id': id, ...body}),
    );
    return Map<String, dynamic>.from(data['title'] as Map? ?? {});
  }

  Future<void> jobTitleDelete(Object id) async {
    _unwrap(await _call('/api/biotime/job-titles/delete', {'id': id}));
  }

  Future<List<Map<String, dynamic>>> archiveReasonsList({
    bool activeOnly = true,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/archive-reasons/list', {
        if (!activeOnly) 'activeOnly': false,
      }),
    );
    return _listFrom(data['reasons']);
  }

  Future<Map<String, dynamic>> archiveReasonCreate(
    Map<String, dynamic> body,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/archive-reasons/create', body),
    );
    return Map<String, dynamic>.from(data['reason'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> archiveReasonUpdate(
    Object id,
    Map<String, dynamic> body,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/archive-reasons/update', {'id': id, ...body}),
    );
    return Map<String, dynamic>.from(data['reason'] as Map? ?? {});
  }

  Future<void> archiveReasonDelete(Object id) async {
    _unwrap(await _call('/api/biotime/archive-reasons/delete', {'id': id}));
  }

  Future<Map<String, dynamic>> employeeCreate(
    Map<String, dynamic> fields, {
    bool pushToBiotime = false,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/employees/create', {
        'pushToBiotime': pushToBiotime,
        ...fields,
      }),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> employeeUpdate(
    Object employeeId,
    Map<String, dynamic> fields, {
    bool pushToBiotime = false,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/employees/update', {
        'employeeId': employeeId,
        'pushToBiotime': pushToBiotime,
        ...fields,
      }),
    );
    return Map<String, dynamic>.from(data['employee'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> employeeDelete(Object employeeId) async {
    return _unwrap(
      await _call('/api/biotime/employees/delete', {'employeeId': employeeId}),
    );
  }

  Future<Map<String, dynamic>> employeeArchive(
    Object employeeId,
    String reason, {
    DateTime? archivedAt,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/employees/archive', {
        'employeeId': employeeId,
        'reason': reason,
        if (archivedAt != null)
          'archivedAt': archivedAt.toUtc().toIso8601String(),
      }),
    );
    return Map<String, dynamic>.from(data['employee'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> employeeRestore(Object employeeId) async {
    final data = _unwrap(
      await _call('/api/biotime/employees/restore', {'employeeId': employeeId}),
    );
    return Map<String, dynamic>.from(data['employee'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> employeePushBiotime(Object employeeId) async {
    final data = _unwrap(
      await _call('/api/biotime/employees/push-biotime', {
        'employeeId': employeeId,
      }),
    );
    return Map<String, dynamic>.from(data['employee'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> employeeSyncDevice(
    Object employeeId, {
    bool syncFromBioTime = false,
  }) async {
    return _unwrap(
      await _call('/api/biotime/employees/sync-device', {
        'employeeId': employeeId,
        if (syncFromBioTime) 'sync': 'full',
      }),
    );
  }

  /// Starts a background sync of employee punches from BioTime and
  /// polls until it completes. Runs as a job so it never hits the proxy's
  /// request-time limit (Cloudflare ~100s), unlike a synchronous sync.
  /// Pass either [employeeId] or [employeeIds] (batch).
  Future<Map<String, dynamic>> employeePunchSyncStart(
    Object? employeeId, {
    List<String>? employeeIds,
    String? dateFrom,
    String? dateTo,
    bool includeAllBiotimeCodes = false,
    void Function(String message, {int? progress})? onProgress,
  }) async {
    final ids =
        employeeIds?.map((e) => e.trim()).where((e) => e.isNotEmpty).toList() ??
        [];
    final data = _unwrap(
      await _call('/api/biotime/employees/punch-report/sync-start', {
        if (includeAllBiotimeCodes) 'includeAllBiotimeCodes': true,
        if (!includeAllBiotimeCodes && ids.isNotEmpty) 'employeeIds': ids,
        if (!includeAllBiotimeCodes && ids.isEmpty && employeeId != null)
          'employeeId': employeeId,
        if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
      }),
    );
    final jobId = data['jobId']?.toString();
    if (jobId != null && data['queued'] == true) {
      return _waitForJob(jobId, onProgress: onProgress);
    }
    return data;
  }

  Future<Map<String, dynamic>> employeePunchReportExportXlsx(
    Object employeeId, {
    bool sync = false,
    String? dateFrom,
    String? dateTo,
  }) async {
    return _unwrap(
      await _call(
        '/api/biotime/employees/punch-report/export-xlsx',
        {
          'employeeId': employeeId,
          'sync': sync,
          if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
          if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
        },
        // Sync-before-export pulls from BioTime, which can take a while.
        timeout: Duration(seconds: sync ? 240 : 90),
      ),
    );
  }

  Future<Map<String, dynamic>> configGet() async {
    final data = _unwrap(await _call('/api/biotime/config/get', {}));
    return Map<String, dynamic>.from(data['config'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> companyLogoUpload({
    required String base64,
    String? mimeType,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/company/logo/upload', {
        'base64': base64,
        if (mimeType != null) 'mimeType': mimeType,
      }),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> companyLogoGet() async {
    return _unwrap(await _call('/api/biotime/company/logo/get', {}));
  }

  Future<Map<String, dynamic>> companyLogoDelete() async {
    return _unwrap(await _call('/api/biotime/company/logo/delete', {}));
  }

  Future<Map<String, dynamic>> configUpdate(Map<String, dynamic> fields) async {
    appLog('ApiClient', 'configUpdate →', fields);
    final data = _unwrap(await _call('/api/biotime/config/update', fields));
    final config = Map<String, dynamic>.from(data['config'] as Map? ?? {});
    // Server may omit keys when running an older build — keep requested values.
    for (final entry in fields.entries) {
      final key = entry.key;
      final sent = entry.value;
      if (sent is bool && (config[key] == null || !config.containsKey(key))) {
        config[key] = sent;
        appLog('ApiClient', 'configUpdate patched missing key', {key: sent});
      }
    }
    appLog('ApiClient', 'configUpdate ←', {
      for (final k in fields.keys) k: config[k],
    });
    return config;
  }

  Future<Map<String, dynamic>> configAction(String path) async {
    return _unwrap(await _call(path, {}));
  }

  Future<Map<String, dynamic>> syncStatus() async {
    return _unwrap(await _call('/api/biotime/config/sync-status', {}));
  }

  Future<Map<String, dynamic>> odooConfigGet() async {
    return _unwrap(await _call('/api/biotime/odoo/config/get', {}));
  }

  Future<Map<String, dynamic>> odooConfigUpdate(
    Map<String, dynamic> fields,
  ) async {
    return _unwrap(await _call('/api/biotime/odoo/config/update', fields));
  }

  Future<Map<String, dynamic>> odooTestConnection() async {
    return _unwrap(await _call('/api/biotime/odoo/config/test-connection', {}));
  }

  Future<List<Map<String, dynamic>>> odooJournalsList() async {
    final data = _unwrap(await _call('/api/biotime/odoo/journals/list', {}));
    return ((data['journals'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> odooAccountsList({String? search}) async {
    final data = _unwrap(
      await _call('/api/biotime/odoo/accounts/list', {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      }),
    );
    return ((data['accounts'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> odooLoanReviewUpload({
    required String fileBase64,
    required String filename,
  }) async {
    return _unwrap(
      await _call('/api/biotime/odoo/loan-review/upload', {
        'fileBase64': fileBase64,
        'filename': filename,
      }),
    );
  }

  Future<Map<String, dynamic>> odooPushAll({
    void Function(String message, {int? progress})? onProgress,
  }) async {
    final data = _unwrap(await _call('/api/biotime/odoo/push-all', {}));
    final jobId = data['jobId']?.toString();
    if (jobId != null && data['queued'] == true) {
      return _waitForJob(jobId, onProgress: onProgress);
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> syncJobsList() async {
    final data = _unwrap(await _call('/api/biotime/config/sync-jobs/list', {}));
    return _listFromData(data);
  }

  Future<Map<String, dynamic>> syncAll() async {
    return _unwrap(await _call('/api/biotime/config/sync-all', {}));
  }

  Future<Map<String, dynamic>> syncPullFromBioTime() async {
    return _unwrap(await _call('/api/biotime/config/sync-pull', {}));
  }

  Future<Map<String, dynamic>> syncTransactions({
    String? dateFrom,
    String? dateTo,
  }) async {
    return _unwrap(
      await _call('/api/biotime/config/sync-transactions', {
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
      }),
    );
  }

  Future<AttendancePageResult> attendanceList({
    String? dateFrom,
    String? dateTo,
    Object? employeeId,
    String? search,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/attendance/list', {
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
        if (employeeId != null) 'employeeId': employeeId,
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status.isNotEmpty) 'status': status,
        'limit': limit,
        'offset': offset,
      }),
    );
    final items = _listFrom(data['records']);
    return AttendancePageResult(
      items: items,
      total: (data['total'] as num?)?.toInt() ?? items.length,
      hasMore: data['hasMore'] == true,
      offset: (data['offset'] as num?)?.toInt() ?? offset,
      dateFrom: data['dateFrom']?.toString() ?? dateFrom ?? '',
      dateTo: data['dateTo']?.toString() ?? dateTo ?? '',
    );
  }

  Future<Map<String, dynamic>> attendanceGenerate({
    required String dateFrom,
    required String dateTo,
    Object? shiftGridId,
    bool skipExisting = false,
    void Function(String message, {int? progress})? onProgress,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/attendance/generate', {
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        if (shiftGridId != null) 'shiftGridId': shiftGridId,
        'skipExisting': skipExisting,
      }),
    );
    final jobId = data['jobId']?.toString();
    if (jobId != null && data['queued'] == true) {
      return _waitForJob(jobId, onProgress: onProgress);
    }
    return data;
  }

  Future<Map<String, dynamic>> jobStatus(String jobId) async {
    return _unwrap(await _call('/api/biotime/jobs/status', {'jobId': jobId}));
  }

  Future<Map<String, dynamic>> _waitForJob(
    String jobId, {
    void Function(String message, {int? progress})? onProgress,
    int maxSeconds = 900,
  }) async {
    for (var i = 0; i < maxSeconds; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final st = await jobStatus(jobId);
      final status = st['status']?.toString() ?? '';
      final message = st['message']?.toString() ?? '';
      final progress = (st['progress'] as num?)?.toInt();
      onProgress?.call(
        message.isNotEmpty ? message : status,
        progress: progress,
      );
      if (status == 'done') return st;
      if (status == 'failed' || status == 'cancelled') {
        throw BioTimeApiException(
          message.isNotEmpty ? message : tr('api.opFailed'),
        );
      }
    }
    throw BioTimeApiException(tr('api.opTimeout'));
  }

  Future<Map<String, dynamic>> requestsMy() async {
    return _unwrap(await _call('/api/biotime/requests/my', {}));
  }

  Future<Map<String, dynamic>> requestsPending() async {
    return _unwrap(await _call('/api/biotime/requests/pending', {}));
  }

  Future<void> _requestAction(String path, Object id, {String? reason}) async {
    await _call(path, {'id': id, if (reason != null) 'reason': reason});
  }

  Future<void> leaveRequestApprove(Object id) =>
      _requestAction('/api/biotime/requests/leave/approve', id);
  Future<void> leaveRequestReject(Object id, String reason) =>
      _requestAction('/api/biotime/requests/leave/reject', id, reason: reason);
  Future<void> loanRequestApprove(Object id) =>
      _requestAction('/api/biotime/requests/loan/approve', id);
  Future<void> loanRequestReject(Object id, String reason) =>
      _requestAction('/api/biotime/requests/loan/reject', id, reason: reason);
  Future<void> shiftChangeRequestApprove(Object id) =>
      _requestAction('/api/biotime/requests/shift-change/approve', id);
  Future<void> shiftChangeRequestReject(Object id, String reason) =>
      _requestAction(
        '/api/biotime/requests/shift-change/reject',
        id,
        reason: reason,
      );
  Future<void> salaryRequestApprove(Object id) =>
      _requestAction('/api/biotime/requests/salary/approve', id);
  Future<void> salaryRequestReject(Object id, String reason) =>
      _requestAction('/api/biotime/requests/salary/reject', id, reason: reason);
  Future<void> certificateRequestApprove(Object id) =>
      _requestAction('/api/biotime/requests/certificate/approve', id);
  Future<void> certificateRequestReject(Object id, String reason) =>
      _requestAction(
        '/api/biotime/requests/certificate/reject',
        id,
        reason: reason,
      );
  Future<void> attendanceEditRequestApprove(Object id) =>
      _requestAction('/api/biotime/requests/attendance-edit/approve', id);
  Future<void> attendanceEditRequestReject(Object id, String reason) =>
      _requestAction(
        '/api/biotime/requests/attendance-edit/reject',
        id,
        reason: reason,
      );

  Future<Map<String, dynamic>> leaveRequestCreate({
    required String leaveType,
    required String dateFrom,
    required String dateTo,
    required String reason,
  }) async {
    return _unwrap(
      await _call('/api/biotime/requests/leave/create', {
        'leaveType': leaveType,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        'reason': reason,
      }),
    );
  }

  Future<Map<String, dynamic>> loanRequestCreate({
    required double amount,
    required int repaymentMonths,
    required String reason,
  }) async {
    return _unwrap(
      await _call('/api/biotime/requests/loan/create', {
        'amount': amount,
        'repaymentMonths': repaymentMonths,
        'reason': reason,
      }),
    );
  }

  // --- Payroll ---

  Future<List<Map<String, dynamic>>> payrollList({
    String? state,
    int limit = 100,
    int offset = 0,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/payroll/list', {
        if (state != null) 'state': state,
        'limit': limit,
        'offset': offset,
      }),
    );
    return _listFromData(data);
  }

  Future<EmployeesPageResult> payrollListPage({
    String? state,
    int limit = 30,
    int offset = 0,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/payroll/list', {
        if (state != null) 'state': state,
        'limit': limit,
        'offset': offset,
      }),
    );
    return EmployeesPageResult(
      items: _listFromData(data),
      total: (data['total'] as num?)?.toInt() ?? 0,
      hasMore: data['hasMore'] == true,
      offset: (data['offset'] as num?)?.toInt() ?? offset,
    );
  }

  Future<Map<String, dynamic>> payrollGet(
    Object payrollId, {
    int? lineLimit,
    int? lineOffset,
    String? lineSearch,
    bool includeLines = true,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/payroll/get', {
        'payrollId': payrollId,
        if (lineLimit != null) 'lineLimit': lineLimit,
        if (lineOffset != null) 'lineOffset': lineOffset,
        if (lineSearch != null && lineSearch.isNotEmpty)
          'lineSearch': lineSearch,
        if (!includeLines) 'includeLines': false,
      }),
    );
    final payroll = Map<String, dynamic>.from(data['payroll'] as Map? ?? {});
    if (data['linePagination'] is Map) {
      payroll['_linePagination'] = Map<String, dynamic>.from(
        data['linePagination'] as Map,
      );
    }
    if (data['overDeducted'] is List) {
      payroll['overDeducted'] = data['overDeducted'];
    }
    if (data['overDeductedCount'] != null) {
      payroll['overDeductedCount'] = data['overDeductedCount'];
    }
    return payroll;
  }

  Future<Map<String, dynamic>> payrollCreate({
    String? dateFrom,
    String? dateTo,
    Object? deviceId,
    Object? shiftGridId,
    String? name,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/payroll/create', {
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
        if (deviceId != null) 'deviceId': deviceId,
        if (shiftGridId != null) 'shiftGridId': shiftGridId,
        if (name != null && name.isNotEmpty) 'name': name,
      }),
    );
    return Map<String, dynamic>.from(data['payroll'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> payrollCalculate(Object payrollId) async {
    final data = _unwrap(
      await _call('/api/biotime/payroll/calculate', {'payrollId': payrollId}),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> payrollConfirm(Object payrollId) async {
    final data = _unwrap(
      await _call('/api/biotime/payroll/confirm', {'payrollId': payrollId}),
    );
    return Map<String, dynamic>.from(data['payroll'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> payrollLinkDeductions(Object payrollId) async {
    final data = _unwrap(
      await _call('/api/biotime/payroll/link-deductions', {
        'payrollId': payrollId,
      }),
    );
    return Map<String, dynamic>.from(data['payroll'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> payrollLinkDeductionsConfirmed(
    Object payrollId,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/payroll/link-deductions-confirmed', {
        'payrollId': payrollId,
      }),
    );
    return Map<String, dynamic>.from(data['payroll'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> payrollBackToDraft(Object payrollId) async {
    final data = _unwrap(
      await _call('/api/biotime/payroll/back-to-draft', {
        'payrollId': payrollId,
      }),
    );
    return Map<String, dynamic>.from(data['payroll'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> payrollSyncEmployeeInfo(Object payrollId) async {
    return Map<String, dynamic>.from(
      _unwrap(
            await _call('/api/biotime/payroll/sync-employee-info', {
              'payrollId': payrollId,
            }),
          )
          as Map,
    );
  }

  Future<Map<String, dynamic>> payrollRecalculateBasicSalary(
    Object payrollId,
  ) async {
    return Map<String, dynamic>.from(
      _unwrap(
            await _call('/api/biotime/payroll/recalculate-basic-salary', {
              'payrollId': payrollId,
            }),
          )
          as Map,
    );
  }

  Future<Map<String, dynamic>> payrollRecalculateAdvances(
    Object payrollId,
  ) async {
    return Map<String, dynamic>.from(
      _unwrap(
            await _call('/api/biotime/payroll/recalculate-advances', {
              'payrollId': payrollId,
            }),
          )
          as Map,
    );
  }

  Future<Map<String, dynamic>> payrollLinkLongAdvances(Object payrollId) async {
    final data = _unwrap(
      await _call('/api/biotime/payroll/link-long-advances', {
        'payrollId': payrollId,
      }),
    );
    return Map<String, dynamic>.from(data['payroll'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> payrollImportXlsx(
    Object payrollId,
    String base64,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/payroll/import-xlsx', {
        'payrollId': payrollId,
        'base64': base64,
      }),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> payrollResetEditComparison(
    Object payrollId,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/payroll/reset-edit-comparison', {
        'payrollId': payrollId,
      }),
    );
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> payrollDuplicatesList(
    Object payrollId,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/payroll/duplicates/list', {
        'payrollId': payrollId,
      }),
    );
    return _listFromData(data);
  }

  Future<Map<String, dynamic>> payrollDuplicateMoveLine({
    required Object lineId,
    Object? targetPayrollId,
    String action = 'move',
  }) async {
    return Map<String, dynamic>.from(
      _unwrap(
            await _call('/api/biotime/payroll/duplicates/move-line', {
              'lineId': lineId,
              if (targetPayrollId != null) 'targetPayrollId': targetPayrollId,
              'action': action,
            }),
          )
          as Map,
    );
  }

  Future<Map<String, dynamic>> payrollDuplicatesExportXlsx(
    Object payrollId,
  ) async {
    return _unwrap(
      await _call('/api/biotime/payroll/duplicates/export-xlsx', {
        'payrollId': payrollId,
      }),
    );
  }

  Future<Map<String, dynamic>> payrollPeriodZeroBasicList({
    required String dateFrom,
    required String dateTo,
  }) async {
    return Map<String, dynamic>.from(
      _unwrap(
            await _call('/api/biotime/payroll/period/zero-basic/list', {
              'dateFrom': dateFrom,
              'dateTo': dateTo,
            }),
          )
          as Map,
    );
  }

  Future<Map<String, dynamic>> payrollPeriodZeroBasicExportXlsx({
    required String dateFrom,
    required String dateTo,
  }) async {
    return _unwrap(
      await _call('/api/biotime/payroll/period/zero-basic/export-xlsx', {
        'dateFrom': dateFrom,
        'dateTo': dateTo,
      }),
    );
  }

  Future<Map<String, dynamic>> payrollPeriodDuplicatesList({
    required String dateFrom,
    required String dateTo,
  }) async {
    return Map<String, dynamic>.from(
      _unwrap(
            await _call('/api/biotime/payroll/period/duplicates/list', {
              'dateFrom': dateFrom,
              'dateTo': dateTo,
            }),
          )
          as Map,
    );
  }

  Future<Map<String, dynamic>> payrollPeriodDuplicatesExportXlsx({
    required String dateFrom,
    required String dateTo,
  }) async {
    return _unwrap(
      await _call('/api/biotime/payroll/period/duplicates/export-xlsx', {
        'dateFrom': dateFrom,
        'dateTo': dateTo,
      }),
    );
  }

  Future<Map<String, dynamic>> payrollPeriodNegativeNetList({
    required String dateFrom,
    required String dateTo,
  }) async {
    return Map<String, dynamic>.from(
      _unwrap(
            await _call('/api/biotime/payroll/period/negative-net/list', {
              'dateFrom': dateFrom,
              'dateTo': dateTo,
            }),
          )
          as Map,
    );
  }

  Future<Map<String, dynamic>> payrollPeriodNegativeNetExportXlsx({
    required String dateFrom,
    required String dateTo,
  }) async {
    return _unwrap(
      await _call('/api/biotime/payroll/period/negative-net/export-xlsx', {
        'dateFrom': dateFrom,
        'dateTo': dateTo,
      }),
    );
  }

  Future<Map<String, dynamic>> payrollPeriodCashFawryExportZip({
    required String dateFrom,
    required String dateTo,
  }) async {
    return _unwrap(
      await _call('/api/biotime/payroll/period/cash-fawry/export-zip', {
        'dateFrom': dateFrom,
        'dateTo': dateTo,
      }),
    );
  }

  Future<Map<String, dynamic>> payrollPeriodSummaryExportXlsx({
    required String dateFrom,
    required String dateTo,
  }) async {
    return _unwrap(
      await _call('/api/biotime/payroll/period/summary/export-xlsx', {
        'dateFrom': dateFrom,
        'dateTo': dateTo,
      }),
    );
  }

  Future<Map<String, dynamic>> payrollEditTemplateExportXlsx(
    Object payrollId,
  ) async {
    return _unwrap(
      await _call('/api/biotime/payroll/edit-template/export-xlsx', {
        'payrollId': payrollId,
      }),
    );
  }

  Future<Map<String, dynamic>> payrollEditTemplateImportXlsx(
    Object payrollId,
    String base64,
  ) async {
    return Map<String, dynamic>.from(
      _unwrap(
            await _call('/api/biotime/payroll/edit-template/import-xlsx', {
              'payrollId': payrollId,
              'base64': base64,
            }),
          )
          as Map,
    );
  }

  Future<Map<String, dynamic>> payrollCalculateSingleEmployee({
    required Object payrollId,
    required Object employeeId,
  }) async {
    return Map<String, dynamic>.from(
      _unwrap(
            await _call('/api/biotime/payroll/calculate-single-employee', {
              'payrollId': payrollId,
              'employeeId': employeeId,
            }),
          )
          as Map,
    );
  }

  Future<List<Map<String, dynamic>>> payrollLocationTransferList({
    required Object payrollId,
    required String targetLocation,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/payroll/location-transfer/list', {
        'payrollId': payrollId,
        'targetLocation': targetLocation,
      }),
    );
    return _listFromData(data);
  }

  Future<Map<String, dynamic>> payrollLocationTransferApply({
    required Object payrollId,
    required String targetLocation,
    required List<String> lineIds,
  }) async {
    return Map<String, dynamic>.from(
      _unwrap(
            await _call('/api/biotime/payroll/location-transfer/apply', {
              'payrollId': payrollId,
              'targetLocation': targetLocation,
              'lineIds': lineIds,
            }),
          )
          as Map,
    );
  }

  Future<Map<String, dynamic>> payrollLineFixBasicSalary(Object lineId) async {
    return Map<String, dynamic>.from(
      _unwrap(
            await _call('/api/biotime/payroll/line/fix-basic-salary', {
              'lineId': lineId,
            }),
          )
          as Map,
    );
  }

  Future<Map<String, dynamic>> payrollPayslipDetail(Object lineId) async {
    final data = _unwrap(
      await _call('/api/biotime/payroll/payslip/detail', {'lineId': lineId}),
    );
    return Map<String, dynamic>.from(data['detail'] as Map? ?? data);
  }

  Future<Map<String, dynamic>> payrollPayslipPdf(Object lineId) async {
    return _unwrap(
      await _call('/api/biotime/payroll/payslip/pdf', {'lineId': lineId}),
    );
  }

  Future<Map<String, dynamic>> payrollPayslipPdfAll(Object payrollId) async {
    return _unwrap(
      await _call('/api/biotime/payroll/payslip/pdf-all', {
        'payrollId': payrollId,
      }),
    );
  }

  Future<Map<String, dynamic>> payrollFixPenaltyValues(Object payrollId) async {
    return Map<String, dynamic>.from(
      _unwrap(
            await _call('/api/biotime/payroll/fix-penalty-values', {
              'payrollId': payrollId,
            }),
          )
          as Map,
    );
  }

  Future<Map<String, dynamic>> payrollCheckDuplicates(Object payrollId) async {
    return Map<String, dynamic>.from(
      _unwrap(
            await _call('/api/biotime/payroll/check-duplicates', {
              'payrollId': payrollId,
            }),
          )
          as Map,
    );
  }

  Future<Map<String, dynamic>> payrollLineUpdate(
    Object lineId,
    Map<String, dynamic> fields,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/payroll/line/update', {
        'lineId': lineId,
        ...fields,
      }),
    );
    return Map<String, dynamic>.from(data['line'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> payrollOdooJournalPreview(
    Object payrollId,
  ) async {
    return _unwrap(
      await _call('/api/biotime/payroll/odoo-journal/preview', {
        'payrollId': payrollId,
      }),
    );
  }

  Future<Map<String, dynamic>> payrollSendToOdoo(Object payrollId) async {
    return _unwrap(
      await _call('/api/biotime/payroll/send-to-odoo', {
        'payrollId': payrollId,
      }, timeout: const Duration(seconds: 180)),
    );
  }

  Future<Map<String, dynamic>> payrollExportFawry(Object payrollId) async {
    return _unwrap(
      await _call(
        '/api/biotime/payroll/export-fawry',
        {'payrollId': payrollId},
        // Large payrolls can queue behind BioTime sync on the API process.
        timeout: const Duration(seconds: 240),
      ),
    );
  }

  Future<Map<String, dynamic>> payrollExportPunchImportReference(
    Object payrollId,
  ) async {
    return _unwrap(
      await _call(
        '/api/biotime/payroll/export-punch-import-reference',
        {'payrollId': payrollId},
        timeout: const Duration(seconds: 120),
      ),
    );
  }

  Future<Map<String, dynamic>> payrollReimportPunchReport(
    Object payrollId,
    String base64, {
    String? filename,
  }) async {
    return _unwrap(
      await _call(
        '/api/biotime/payroll/reimport-punch-report',
        {
          'payrollId': payrollId,
          'file': base64,
          if (filename != null && filename.isNotEmpty) 'filename': filename,
        },
        timeout: const Duration(seconds: 240),
      ),
    );
  }

  Future<Map<String, dynamic>> payrollExportXlsx(Object payrollId) async {
    return _unwrap(
      await _call('/api/biotime/payroll/export-xlsx', {
        'payrollId': payrollId,
      }, timeout: const Duration(seconds: 240)),
    );
  }

  Future<Map<String, dynamic>> payrollExportPayslipsXlsx(
    Object payrollId,
  ) async {
    return _unwrap(
      await _call(
        '/api/biotime/payroll/export-payslips-xlsx',
        {'payrollId': payrollId},
        timeout: const Duration(seconds: 240),
      ),
    );
  }

  Future<Map<String, dynamic>> payrollExportCashFawry(Object payrollId) async {
    return _unwrap(
      await _call(
        '/api/biotime/payroll/export-cash-fawry',
        {'payrollId': payrollId},
        timeout: const Duration(seconds: 240),
      ),
    );
  }

  Future<Map<String, dynamic>> shiftGridExportXlsx(
    Object gridId, {
    String? dateFrom,
    String? dateTo,
    String? grouping,
    bool sheetPerGroup = false,
    List<String>? groupKeys,
    List<String>? departmentNames,
    List<String>? employeeIds,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/export-xlsx', {
        'gridId': gridId,
        if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
        if (grouping != null) 'grouping': grouping,
        if (sheetPerGroup) 'sheetPerGroup': true,
        if (groupKeys != null && groupKeys.isNotEmpty) 'groupKeys': groupKeys,
        if (departmentNames != null && departmentNames.isNotEmpty)
          'departmentNames': departmentNames,
        if (employeeIds != null && employeeIds.isNotEmpty)
          'employeeIds': employeeIds,
      }),
    );
  }

  /// One Excel per department for each grid, returned as a ZIP.
  Future<Map<String, dynamic>> shiftGridExportXlsxByDepartmentBulk({
    List<String>? gridIds,
    String? dateFrom,
    String? dateTo,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/export-xlsx-by-department-bulk', {
        if (gridIds != null && gridIds.isNotEmpty) 'gridIds': gridIds,
        if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
      }),
    );
  }

  /// One full Excel workbook per grid, returned as a ZIP.
  Future<Map<String, dynamic>> shiftGridExportXlsxBulk({
    List<String>? gridIds,
    String? dateFrom,
    String? dateTo,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/export-xlsx-bulk', {
        if (gridIds != null && gridIds.isNotEmpty) 'gridIds': gridIds,
        if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridPunchReportExportXlsx(
    Object gridId,
  ) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/punch-report-export-xlsx', {
        'gridId': gridId,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridPunchReportImport(
    Object gridId,
    String base64, {
    String? filename,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/punch-report-import', {
        'gridId': gridId,
        'file': base64,
        if (filename != null && filename.isNotEmpty) 'filename': filename,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridPayrollFromPunchImport(
    Object gridId, {
    String? importId,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/payroll-from-punch-import', {
        'gridId': gridId,
        if (importId != null && importId.isNotEmpty) 'importId': importId,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridManualOtList(Object gridId) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/manual-ot/list', {'gridId': gridId}),
    );
  }

  Future<Map<String, dynamic>> shiftGridManualOtAdd(
    Object gridId, {
    required String employeeId,
    required String date,
    String? note,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/manual-ot/add', {
        'gridId': gridId,
        'employeeId': employeeId,
        'date': date,
        if (note != null) 'note': note,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridManualOtUpdate(
    Object gridId, {
    required String id,
    String? date,
    String? note,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/manual-ot/update', {
        'gridId': gridId,
        'id': id,
        if (date != null) 'date': date,
        if (note != null) 'note': note,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridManualOtDelete(
    Object gridId,
    String id,
  ) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/manual-ot/delete', {
        'gridId': gridId,
        'id': id,
      }),
    );
  }

  Future<Map<String, dynamic>> employeesPunchesExportUnlocatedXlsx({
    String? dateFrom,
    String? dateTo,
  }) async {
    return _unwrap(
      await _call('/api/biotime/employees/punches/export-unlocated-xlsx', {
        if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
      }),
    );
  }

  Future<Map<String, dynamic>> employeesPunchesExportSelectedXlsx(
    Object gridId,
    List<String> employeeIds, {
    String? dateFrom,
    String? dateTo,
  }) async {
    return _unwrap(
      await _call('/api/biotime/employees/punches/export-selected-xlsx', {
        'gridId': gridId,
        'employeeIds': employeeIds,
        if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridImportXlsx(
    Object gridId,
    String base64, {
    String? dateFrom,
    String? dateTo,
    List<String>? createEmployeeCodes,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/import-xlsx', {
        'gridId': gridId,
        'base64': base64,
        if (dateFrom != null && dateFrom.isNotEmpty) 'dateFrom': dateFrom,
        if (dateTo != null && dateTo.isNotEmpty) 'dateTo': dateTo,
        if (createEmployeeCodes != null && createEmployeeCodes.isNotEmpty)
          'createEmployeeCodes': createEmployeeCodes,
      }),
    );
  }

  Future<List<Map<String, dynamic>>> overtimeList({String? state}) async {
    final data = _unwrap(
      await _call('/api/biotime/overtime/list', {
        if (state != null) 'state': state,
      }),
    );
    return _listFromData(data);
  }

  Future<Map<String, dynamic>> overtimeGenerate({
    required String dateFrom,
    required String dateTo,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/overtime/generate', {
        'dateFrom': dateFrom,
        'dateTo': dateTo,
      }),
    );
    final jobId = data['jobId']?.toString();
    if (jobId != null && data['queued'] == true) {
      return _waitForJob(jobId);
    }
    return data;
  }

  Future<void> overtimeApprove(Object id) async {
    _unwrap(await _call('/api/biotime/overtime/approve', {'id': id}));
  }

  Future<void> overtimeReject(Object id, String reason) async {
    _unwrap(
      await _call('/api/biotime/overtime/reject', {'id': id, 'reason': reason}),
    );
  }

  Future<Map<String, dynamic>> salaryRequestCreate({
    required double amount,
    required String reason,
  }) async {
    return _unwrap(
      await _call('/api/biotime/requests/salary/create', {
        'amount': amount,
        'reason': reason,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftChangeRequestCreate({
    required String newShiftId,
    required String dateFrom,
    required String dateTo,
    String? currentShiftId,
    required String reason,
  }) async {
    return _unwrap(
      await _call('/api/biotime/requests/shift-change/create', {
        'newShiftId': newShiftId,
        if (currentShiftId != null) 'currentShiftId': currentShiftId,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        'reason': reason,
      }),
    );
  }

  Future<Map<String, dynamic>> certificateRequestCreate({
    required String certificateType,
    required String reason,
  }) async {
    return _unwrap(
      await _call('/api/biotime/requests/certificate/create', {
        'certificateType': certificateType,
        'reason': reason,
      }),
    );
  }

  Future<Map<String, dynamic>> attendanceEditRequestCreate({
    required String date,
    String? requestedCheckIn,
    String? requestedCheckOut,
    required String reason,
  }) async {
    return _unwrap(
      await _call('/api/biotime/requests/attendance-edit/create', {
        'date': date,
        if (requestedCheckIn != null) 'requestedCheckIn': requestedCheckIn,
        if (requestedCheckOut != null) 'requestedCheckOut': requestedCheckOut,
        'reason': reason,
      }),
    );
  }

  Future<List<Map<String, dynamic>>> myPayroll() async {
    final data = _unwrap(await _call('/api/biotime/payroll/my', {}));
    return _listFromData(data);
  }

  // --- Deductions ---

  Future<List<Map<String, dynamic>>> deductionTypes() async {
    final data = _unwrap(await _call('/api/biotime/deductions/types', {}));
    final types = _listFrom(data['types']);
    if (types.isNotEmpty) return types;
    return _listFromData(data);
  }

  Future<List<Map<String, dynamic>>> deductionsList({String? state}) async {
    final page = await deductionsListPage(state: state);
    return page.items;
  }

  Future<EmployeesPageResult> deductionsListPage({
    String? state,
    String? deviceId,
    String? locationId,
    String? type,
    int limit = 40,
    int offset = 0,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/deductions/list', {
        if (state != null) 'state': state,
        if (deviceId != null) 'deviceId': deviceId,
        if (locationId != null) 'locationId': locationId,
        if (type != null) 'type': type,
        'limit': limit,
        'offset': offset,
      }),
    );
    return EmployeesPageResult(
      items: _listFromData(data),
      total: (data['total'] as num?)?.toInt() ?? 0,
      hasMore: data['hasMore'] == true,
      offset: (data['offset'] as num?)?.toInt() ?? offset,
    );
  }

  Future<Map<String, dynamic>> deductionCreate(
    Map<String, dynamic> body,
  ) async {
    final data = _unwrap(await _call('/api/biotime/deductions/create', body));
    return Map<String, dynamic>.from(data['deduction'] as Map? ?? {});
  }

  Future<void> deductionCancel(Object id) async {
    _unwrap(await _call('/api/biotime/deductions/cancel', {'deductionId': id}));
  }

  Future<Map<String, dynamic>> deductionExportTemplate({
    required String deductionType,
    String? deviceId,
    String? date,
  }) async {
    return _unwrap(
      await _call('/api/biotime/deductions/export-template', {
        'deductionType': deductionType,
        if (deviceId != null) 'deviceId': deviceId,
        if (date != null) 'date': date,
      }),
    );
  }

  Future<Map<String, dynamic>> deductionImportXlsx({
    required String base64,
    required String deductionType,
    String? deviceId,
    String? date,
  }) async {
    return _unwrap(
      await _call('/api/biotime/deductions/import-xlsx', {
        'base64': base64,
        'deductionType': deductionType,
        if (deviceId != null) 'deviceId': deviceId,
        if (date != null) 'date': date,
      }),
    );
  }

  Future<Map<String, dynamic>> deductionExportMultiTemplate({
    String? deviceId,
    String? date,
  }) async {
    return _unwrap(
      await _call('/api/biotime/deductions/export-multi-template', {
        if (deviceId != null) 'deviceId': deviceId,
        if (date != null) 'date': date,
      }),
    );
  }

  Future<Map<String, dynamic>> deductionExportBranchTemplate({
    List<String>? locationIds,
    String? locationId,
    String? date,
    String? deductionType,
    String? dateFrom,
    String? dateTo,
    String? jobTitle,
    List<String>? jobTitles,
  }) async {
    final ids = <String>{
      if (locationIds != null)
        ...locationIds.map((e) => e.trim()).where((e) => e.isNotEmpty),
      if (locationId != null && locationId.trim().isNotEmpty) locationId.trim(),
    }.toList();
    final titles = <String>[
      if (jobTitles != null)
        ...jobTitles.map((e) => e.trim()).where((e) => e.isNotEmpty),
      if (jobTitle != null && jobTitle.trim().isNotEmpty) jobTitle.trim(),
    ];
    final uniqueTitles = titles.toSet().toList();
    return _unwrap(
      await _call('/api/biotime/deductions/export-branch-template', {
        if (ids.isNotEmpty) 'locationIds': ids,
        if (ids.length == 1) 'locationId': ids.first,
        if (date != null) 'date': date,
        if (deductionType != null) 'deductionType': deductionType,
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
        if (uniqueTitles.isNotEmpty) 'jobTitles': uniqueTitles,
      }),
    );
  }

  Future<Map<String, dynamic>> deductionScopeCount({
    List<String>? locationIds,
    String? locationId,
    String? dateFrom,
    String? dateTo,
    String? jobTitle,
    List<String>? jobTitles,
  }) async {
    final ids = <String>{
      if (locationIds != null)
        ...locationIds.map((e) => e.trim()).where((e) => e.isNotEmpty),
      if (locationId != null && locationId.trim().isNotEmpty) locationId.trim(),
    }.toList();
    final titles = <String>[
      if (jobTitles != null)
        ...jobTitles.map((e) => e.trim()).where((e) => e.isNotEmpty),
      if (jobTitle != null && jobTitle.trim().isNotEmpty) jobTitle.trim(),
    ];
    final uniqueTitles = titles.toSet().toList();
    return _unwrap(
      await _call('/api/biotime/deductions/scope-count', {
        if (ids.isNotEmpty) 'locationIds': ids,
        if (ids.length == 1) 'locationId': ids.first,
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
        if (uniqueTitles.isNotEmpty) 'jobTitles': uniqueTitles,
      }),
    );
  }

  Future<List<String>> deductionJobTitles({
    List<String>? locationIds,
    String? locationId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final ids = <String>{
      if (locationIds != null)
        ...locationIds.map((e) => e.trim()).where((e) => e.isNotEmpty),
      if (locationId != null && locationId.trim().isNotEmpty) locationId.trim(),
    }.toList();
    final data = _unwrap(
      await _call('/api/biotime/deductions/job-titles', {
        if (ids.isNotEmpty) 'locationIds': ids,
        if (ids.length == 1) 'locationId': ids.first,
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
      }),
    );
    return (data['jobTitles'] as List? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>> deductionPreviewBranchXlsx(
    String base64, {
    List<String>? locationIds,
    String? locationId,
    String? dateFrom,
    String? dateTo,
    String? deductionType,
  }) async {
    final ids = <String>{
      if (locationIds != null)
        ...locationIds.map((e) => e.trim()).where((e) => e.isNotEmpty),
      if (locationId != null && locationId.trim().isNotEmpty) locationId.trim(),
    }.toList();
    return _unwrap(
      await _call('/api/biotime/deductions/preview-branch-xlsx', {
        'base64': base64,
        if (ids.isNotEmpty) 'locationIds': ids,
        if (ids.length == 1) 'locationId': ids.first,
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
        if (deductionType != null) 'deductionType': deductionType,
      }),
    );
  }

  Future<Map<String, dynamic>> deductionConfirmBranchImport({
    required List<Map<String, dynamic>> lines,
    String? date,
    String? deviceId,
  }) async {
    return _unwrap(
      await _call('/api/biotime/deductions/confirm-branch-import', {
        'lines': lines,
        if (date != null) 'date': date,
        if (deviceId != null) 'deviceId': deviceId,
      }),
    );
  }

  Future<Map<String, dynamic>> deductionDistributePreview({
    List<String>? locationIds,
    String? locationId,
    required String dateFrom,
    required String dateTo,
    required String deductionType,
    required double totalAmount,
    String? date,
    String? jobTitle,
    List<String>? jobTitles,
  }) async {
    final ids = <String>{
      if (locationIds != null)
        ...locationIds.map((e) => e.trim()).where((e) => e.isNotEmpty),
      if (locationId != null && locationId.trim().isNotEmpty) locationId.trim(),
    }.toList();
    final titles = <String>[
      if (jobTitles != null)
        ...jobTitles.map((e) => e.trim()).where((e) => e.isNotEmpty),
      if (jobTitle != null && jobTitle.trim().isNotEmpty) jobTitle.trim(),
    ];
    final uniqueTitles = titles.toSet().toList();
    return _unwrap(
      await _call('/api/biotime/deductions/distribute/preview', {
        if (ids.isNotEmpty) 'locationIds': ids,
        if (ids.length == 1) 'locationId': ids.first,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        'deductionType': deductionType,
        'totalAmount': totalAmount,
        if (date != null) 'date': date,
        if (uniqueTitles.isNotEmpty) 'jobTitles': uniqueTitles,
      }),
    );
  }

  Future<Map<String, dynamic>> deductionDistributeRecalc({
    required List<String> employeeIds,
    required double totalAmount,
    String? note,
  }) async {
    return _unwrap(
      await _call('/api/biotime/deductions/distribute/recalc', {
        'employeeIds': employeeIds,
        'totalAmount': totalAmount,
        if (note != null) 'note': note,
      }),
    );
  }

  Future<Map<String, dynamic>> deductionDistributeConfirm({
    List<String>? locationIds,
    String? locationId,
    required String dateFrom,
    required String dateTo,
    required String deductionType,
    required double totalAmount,
    required List<Map<String, dynamic>> lines,
    String? date,
    String? jobTitle,
    List<String>? jobTitles,
    String? deviceId,
  }) async {
    final ids = <String>{
      if (locationIds != null)
        ...locationIds.map((e) => e.trim()).where((e) => e.isNotEmpty),
      if (locationId != null && locationId.trim().isNotEmpty) locationId.trim(),
    }.toList();
    final titles = <String>[
      if (jobTitles != null)
        ...jobTitles.map((e) => e.trim()).where((e) => e.isNotEmpty),
      if (jobTitle != null && jobTitle.trim().isNotEmpty) jobTitle.trim(),
    ];
    final uniqueTitles = titles.toSet().toList();
    return _unwrap(
      await _call('/api/biotime/deductions/distribute/confirm', {
        if (ids.isNotEmpty) 'locationIds': ids,
        if (ids.length == 1) 'locationId': ids.first,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        'deductionType': deductionType,
        'totalAmount': totalAmount,
        'lines': lines,
        if (date != null) 'date': date,
        if (uniqueTitles.isNotEmpty) 'jobTitles': uniqueTitles,
        if (deviceId != null) 'deviceId': deviceId,
      }),
    );
  }

  Future<Map<String, dynamic>> deductionImportMultiXlsx({
    required String base64,
    String? deviceId,
    String? date,
  }) async {
    return _unwrap(
      await _call('/api/biotime/deductions/import-multi-xlsx', {
        'base64': base64,
        if (deviceId != null) 'deviceId': deviceId,
        if (date != null) 'date': date,
      }),
    );
  }

  // --- Advance loan import ---

  Future<List<Map<String, dynamic>>> advanceLoanImportList({
    String state = 'draft',
    String kind = 'loan',
  }) async {
    final data = await advanceLoanImportListPayload(state: state, kind: kind);
    return _listFrom(data['items']);
  }

  Future<Map<String, dynamic>> advanceLoanImportListPayload({
    String state = 'draft',
    String kind = 'loan',
  }) async {
    return _unwrap(
      await _call('/api/biotime/advances/loan-import/list', {
        'state': state,
        'kind': kind,
      }),
    );
  }

  Future<Map<String, dynamic>> advanceLoanImportCreate(
    Map<String, dynamic> body,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/advances/loan-import/create', body),
    );
    return Map<String, dynamic>.from(data['import'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> advanceLoanImportGet(Object importId) async {
    final data = _unwrap(
      await _call('/api/biotime/advances/loan-import/get', {
        'importId': importId,
      }),
    );
    return Map<String, dynamic>.from(data['import'] as Map? ?? {});
  }

  Future<void> advanceLoanImportDeleteDraft(Object importId) async {
    _unwrap(
      await _call('/api/biotime/advances/loan-import/delete-draft', {
        'importId': importId,
      }),
    );
  }

  Future<Map<String, dynamic>> advanceLoanImportApplyEligibility({
    required Object importId,
    required String eligibilityFileBase64,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/advances/loan-import/apply-eligibility', {
        'importId': importId,
        'eligibilityFile': eligibilityFileBase64,
      }),
    );
    return Map<String, dynamic>.from(data['import'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> advanceLoanImportPreview({
    required Object importId,
    required String loanFileBase64,
    String? eligibilityFileBase64,
    String? dateFrom,
    String? dateTo,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/advances/loan-import/preview', {
        'importId': importId,
        'base64': loanFileBase64,
        if (eligibilityFileBase64 != null)
          'eligibilityBase64': eligibilityFileBase64,
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
      }),
    );
    return Map<String, dynamic>.from(data['import'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> advanceLoanImportMergeLoan({
    required Object importId,
    required String loanFileBase64,
    String? dateFrom,
    String? dateTo,
  }) async {
    return _unwrap(
      await _call('/api/biotime/advances/loan-import/merge-loan', {
        'importId': importId,
        'base64': loanFileBase64,
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
      }),
    );
  }

  Future<Map<String, dynamic>> advanceLoanImportLineUpdate({
    required Object lineId,
    double? approvedAmount,
    bool? toApprove,
    String? rowReason,
    String? employeeId,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/advances/loan-import/lines/update', {
        'lineId': lineId,
        if (approvedAmount != null) 'approvedAmount': approvedAmount,
        if (toApprove != null) 'toApprove': toApprove,
        if (rowReason != null) 'rowReason': rowReason,
        if (employeeId != null) 'employeeId': employeeId,
      }),
    );
    return Map<String, dynamic>.from(data['line'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> advanceLoanImportLineAddManual({
    required Object importId,
    required String employeeId,
    required double requestedAmount,
    String? dateFrom,
    String? dateTo,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/advances/loan-import/lines/add-manual', {
        'importId': importId,
        'employeeId': employeeId,
        'requestedAmount': requestedAmount,
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
      }),
    );
    return Map<String, dynamic>.from(data['line'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> advanceLoanImportApprove(Object importId) async {
    return _unwrap(
      await _call('/api/biotime/advances/loan-import/approve', {
        'importId': importId,
      }),
    );
  }

  Future<Map<String, dynamic>> advanceLoanImportSendToOdooAccounts(
    Object importId,
  ) async {
    return _unwrap(
      await _call('/api/biotime/advances/loan-import/send-to-odoo-accounts', {
        'importId': importId,
      }),
    );
  }

  Future<Map<String, dynamic>> advanceLoanImportResendNotificationEmail(
    Object importId,
  ) async {
    return _unwrap(
      await _call(
        '/api/biotime/advances/loan-import/resend-notification-email',
        {'importId': importId},
      ),
    );
  }

  Future<Map<String, dynamic>> advanceLoanImportExportReview(
    Object importId,
  ) async {
    return _unwrap(
      await _call('/api/biotime/advances/loan-import/export-review', {
        'importId': importId,
      }),
    );
  }

  Future<Map<String, dynamic>> advanceLoanImportEligibilityFromLoan(
    String loanFileBase64, {
    String? sourceGridId,
  }) async {
    return _unwrap(
      await _call('/api/biotime/advances/loan-import/eligibility-from-loan', {
        'loanFile': loanFileBase64,
        if (sourceGridId != null) 'sourceGridId': sourceGridId,
      }),
    );
  }

  /// كاش/فوري accounts sheet (same schema Odoo's DLW export produces).
  Future<Map<String, dynamic>> advanceLoanImportExportAccountsSheet(
    Object importId,
  ) async {
    return _unwrap(
      await _call('/api/biotime/advances/loan-import/export-accounts-sheet', {
        'importId': importId,
      }),
    );
  }

  Future<Map<String, dynamic>> advanceLoanImportExportAccountsPeriod({
    required String dateFrom,
    required String dateTo,
  }) async {
    return _unwrap(
      await _call('/api/biotime/advances/loan-import/export-accounts-period', {
        'dateFrom': dateFrom,
        'dateTo': dateTo,
      }),
    );
  }

  Future<Map<String, dynamic>> advanceLoanImportExportEligibility(
    Object importId,
  ) async {
    return _unwrap(
      await _call('/api/biotime/advances/loan-import/export-eligibility', {
        'importId': importId,
      }),
    );
  }

  Future<Map<String, dynamic>> advancesExportImportTemplate({
    String? locationId,
    List<String>? locationIds,
    bool blank = false,
    String kind = 'loan',
    String? dateFrom,
    String? dateTo,
  }) async {
    if (blank) {
      return _unwrap(
        await _call('/api/biotime/advances/export/import-template', {
          'blank': true,
          'template': 'multiple',
          'kind': kind,
          if (dateFrom != null) 'dateFrom': dateFrom,
          if (dateTo != null) 'dateTo': dateTo,
        }),
      );
    }
    final ids = <String>[
      if (locationIds != null)
        ...locationIds.map((e) => e.trim()).where((e) => e.isNotEmpty),
      if (locationId != null && locationId.trim().isNotEmpty) locationId.trim(),
    ];
    final unique = ids.toSet().toList();
    return _unwrap(
      await _call('/api/biotime/advances/export/import-template', {
        if (unique.length == 1) 'locationId': unique.first,
        if (unique.isNotEmpty) 'locationIds': unique,
        'kind': kind,
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
      }),
    );
  }

  Future<Map<String, dynamic>> advancesExportEligibilityTemplate() async {
    return _unwrap(
      await _call('/api/biotime/advances/export/eligibility-template', {}),
    );
  }

  Future<Map<String, dynamic>> advancesExportShort() async {
    return _unwrap(await _call('/api/biotime/advances/export/short', {}));
  }

  Future<Map<String, dynamic>> advancesExportLong() async {
    return _unwrap(await _call('/api/biotime/advances/export/long', {}));
  }

  // --- Advances ---

  Future<Map<String, dynamic>> advanceEligibilityPreview(
    Map<String, dynamic> body,
  ) async {
    return Map<String, dynamic>.from(
      _unwrap(await _call('/api/biotime/advances/eligibility/preview', body))
          as Map,
    );
  }

  Future<List<Map<String, dynamic>>> advancesShortList({String? state}) async {
    final data = _unwrap(
      await _call('/api/biotime/advances/short/list', {
        if (state != null) 'state': state,
      }),
    );
    return _listFromData(data);
  }

  Future<Map<String, dynamic>> advanceShortCreate(
    Map<String, dynamic> body,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/advances/short/create', body),
    );
    return Map<String, dynamic>.from(data['advance'] as Map? ?? {});
  }

  Future<void> advanceShortCancel(Object id) async {
    _unwrap(
      await _call('/api/biotime/advances/short/cancel', {'advanceId': id}),
    );
  }

  Future<List<Map<String, dynamic>>> advancesLongList({String? state}) async {
    final data = _unwrap(
      await _call('/api/biotime/advances/long/list', {
        if (state != null) 'state': state,
      }),
    );
    return _listFromData(data);
  }

  Future<Map<String, dynamic>> advanceLongCreate(
    Map<String, dynamic> body,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/advances/long/create', body),
    );
    return Map<String, dynamic>.from(data['advance'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> advanceLongConfirm(Object id) async {
    final data = _unwrap(
      await _call('/api/biotime/advances/long/confirm', {'advanceId': id}),
    );
    return Map<String, dynamic>.from(data['advance'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> advanceLongSendToOdoo(Object id) async {
    final data = _unwrap(
      await _call('/api/biotime/advances/long/send-to-odoo', {'advanceId': id}),
    );
    return Map<String, dynamic>.from(data['advance'] as Map? ?? {});
  }

  Future<void> advanceLongCancel(Object id) async {
    _unwrap(
      await _call('/api/biotime/advances/long/cancel', {'advanceId': id}),
    );
  }

  Future<Map<String, dynamic>> advanceLongStop(Object id) async {
    final data = _unwrap(
      await _call('/api/biotime/advances/long/stop', {'advanceId': id}),
    );
    return Map<String, dynamic>.from(data['advance'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> advanceLongAdjustRemaining(
    Object id, {
    required double remainingAmount,
    required int remainingInstallments,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/advances/long/adjust-remaining', {
        'advanceId': id,
        'remainingAmount': remainingAmount,
        'remainingInstallments': remainingInstallments,
      }),
    );
    return Map<String, dynamic>.from(data['advance'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> advanceLongUpdate(
    Object id,
    Map<String, dynamic> body,
  ) async {
    final data = _unwrap(
      await _call('/api/biotime/advances/long/update', {
        'advanceId': id,
        ...body,
      }),
    );
    return Map<String, dynamic>.from(data['advance'] as Map? ?? {});
  }

  Future<List<Map<String, dynamic>>> adminUsersList() async {
    final data = _unwrap(await _call('/api/admin/users/list', {}));
    return _listFrom(data['users']);
  }

  Future<Map<String, dynamic>> adminUserCreate({
    required String name,
    required String login,
    required String password,
    String role = 'EMPLOYEE',
    String? locationId,
  }) async {
    return _unwrap(
      await _call('/api/admin/users', {
        'name': name,
        'login': login,
        'password': password,
        'role': role,
        if (locationId != null && locationId.isNotEmpty)
          'locationId': locationId,
      }),
    );
  }

  Future<void> adminUserDeactivate(Object userId) async {
    _unwrap(await _call('/api/admin/users/deactivate', {'userId': userId}));
  }

  Future<Map<String, dynamic>> adminUserResetPassword(
    Object userId, {
    String? password,
  }) async {
    return _unwrap(
      await _call('/api/admin/users/reset-password', {
        'userId': userId,
        if (password != null && password.isNotEmpty) 'password': password,
      }),
    );
  }

  List<Map<String, dynamic>> _listFrom(dynamic items) {
    if (items is List) {
      return items
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  List<Map<String, dynamic>> _listFromData(Map<String, dynamic> data) {
    for (final key in [
      'items',
      'records',
      'employees',
      'grids',
      'payrolls',
      'shifts',
      'assignments',
      'deductions',
      'advances',
      'devices',
      'departments',
      'locations',
      'users',
      'types',
      'companies',
      'alerts',
    ]) {
      final list = _listFrom(data[key]);
      if (list.isNotEmpty) return list;
    }
    return [];
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic> result) {
    if (result['success'] != true) {
      final extra = result['data'];
      throw BioTimeApiException(
        result['message']?.toString() ?? tr('api.serverError'),
        code: result['error_code']?.toString(),
        data: extra is Map ? Map<String, dynamic>.from(extra) : const {},
      );
    }
    final data = result['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> _call(
    String path,
    Map<String, dynamic> params, {
    bool auth = true,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': 'call',
      'params': {
        if (auth && _token != null) 'token': _token,
        if (auth && _activeCompanyId != null) 'activeCompanyId': _activeCompanyId,
        ...params,
      },
      'id': DateTime.now().millisecondsSinceEpoch,
    });
    final headers = {
      'Content-Type': 'application/json',
      if (auth && _token != null) 'Authorization': 'Bearer $_token',
      if (auth && _activeCompanyId != null) 'X-Company-Id': _activeCompanyId!,
    };
    try {
      final response = await http
          .post(uri, headers: headers, body: body)
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BioTimeApiException(
          'HTTP ${response.statusCode}',
          code: 'HTTP_${response.statusCode}',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['result'] is Map) {
        return Map<String, dynamic>.from(decoded['result'] as Map);
      }
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw BioTimeApiException(tr('api.unexpected'), code: 'BAD_RESPONSE');
    } on BioTimeApiException {
      rethrow;
    } on TimeoutException {
      appLog('API', 'timeout $path');
      throw BioTimeApiException(tr('api.timeout'), code: 'TIMEOUT');
    } on http.ClientException {
      appLog('API', 'network error $path');
      throw BioTimeApiException(tr('api.unreachable'), code: 'NETWORK_ERROR');
    } catch (e) {
      if (_isNetworkError(e)) {
        appLog('API', 'network error $path', e);
        throw BioTimeApiException(tr('api.unreachable'), code: 'NETWORK_ERROR');
      }
      rethrow;
    }
  }

  /// The signed-in employee's weekly schedule. With no range the server picks
  /// the current week using the configured start weekday.
  Future<Map<String, dynamic>> mySchedule({
    String? dateFrom,
    String? dateTo,
  }) async {
    return _unwrap(
      await _call('/api/biotime/my-schedule', {
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
      }),
    );
  }

  // --- Shift grid merge ---

  Future<Map<String, dynamic>> shiftGridMergeCandidates({
    String? reference,
    int? monthStartDay,
    String? locationId,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/merge/candidates', {
        if (reference != null) 'reference': reference,
        if (monthStartDay != null) 'monthStartDay': monthStartDay,
        if (locationId != null) 'locationId': locationId,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridMergePreview(
    List<String> sourceGridIds, {
    String? targetGridId,
    String? periodFrom,
    String? periodTo,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/merge/preview', {
        'sourceGridIds': sourceGridIds,
        if (targetGridId != null) 'targetGridId': targetGridId,
        if (periodFrom != null) 'periodFrom': periodFrom,
        if (periodTo != null) 'periodTo': periodTo,
      }),
    );
  }

  Future<Map<String, dynamic>> shiftGridMerge(
    List<String> sourceGridIds, {
    String? targetGridId,
    String? name,
    String conflictStrategy = 'latest_grid',
    bool confirm = false,
    String? periodFrom,
    String? periodTo,
  }) async {
    return _unwrap(
      await _call('/api/biotime/shift-grid/merge', {
        'sourceGridIds': sourceGridIds,
        if (targetGridId != null) 'targetGridId': targetGridId,
        if (name != null) 'name': name,
        'conflictStrategy': conflictStrategy,
        if (confirm) 'confirm': true,
        if (periodFrom != null) 'periodFrom': periodFrom,
        if (periodTo != null) 'periodTo': periodTo,
      }),
    );
  }

  // --- HR compliance reports ---

  /// Options shared by every report. Nulls are dropped so the server keeps its
  /// own defaults rather than receiving an explicit null.
  Map<String, dynamic> _reportScope({
    String? locationId,
    String? departmentId,
    bool? requireNationalId,
    bool? includeArchived,
    bool? includeInactive,
  }) {
    return <String, dynamic>{
      if (locationId != null) 'locationId': locationId,
      if (departmentId != null) 'departmentId': departmentId,
      if (requireNationalId != null) 'requireNationalId': requireNationalId,
      if (includeArchived != null) 'includeArchived': includeArchived,
      if (includeInactive != null) 'includeInactive': includeInactive,
    };
  }

  Future<Map<String, dynamic>> reportNoPunches({
    required String dateFrom,
    required String dateTo,
    bool? includeNeverScheduled,
    String? locationId,
    String? departmentId,
    List<String>? employeeIds,
    bool? requireNationalId,
    bool? includeArchived,
    bool? includeInactive,
    bool export = false,
  }) async {
    final path = export
        ? '/api/biotime/reports/no-punches/export-xlsx'
        : '/api/biotime/reports/no-punches';
    return _unwrap(
      await _call(path, {
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        if (includeNeverScheduled != null)
          'includeNeverScheduled': includeNeverScheduled,
        if (employeeIds != null && employeeIds.isNotEmpty)
          'employeeIds': employeeIds,
        ..._reportScope(
          locationId: locationId,
          departmentId: departmentId,
          requireNationalId: requireNationalId,
          includeArchived: includeArchived,
          includeInactive: includeInactive,
        ),
      }),
    );
  }

  Future<Map<String, dynamic>> reportLocationMismatch({
    required String dateFrom,
    required String dateTo,
    bool? includeUnmappedDevices,
    String? locationId,
    String? departmentId,
    bool? requireNationalId,
    bool? includeArchived,
    bool export = false,
  }) async {
    final path = export
        ? '/api/biotime/reports/location-mismatch/export-xlsx'
        : '/api/biotime/reports/location-mismatch';
    return _unwrap(
      await _call(path, {
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        if (includeUnmappedDevices != null)
          'includeUnmappedDevices': includeUnmappedDevices,
        ..._reportScope(
          locationId: locationId,
          departmentId: departmentId,
          requireNationalId: requireNationalId,
          includeArchived: includeArchived,
        ),
      }),
    );
  }

  /// Starts pulling the period from BioTime for the selected branch unless a
  /// recent sync already covered it, and returns the job to wait on. Branch-only
  /// pulls finish in about a minute; company-wide ones take many minutes.
  Future<String?> reportPunchSyncStart({
    required String dateFrom,
    required String dateTo,
    required String locationId,
  }) async {
    final data = _unwrap(
      await _call('/api/biotime/reports/punch-report/sync-start', {
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        'locationId': locationId,
      }),
    );
    if (data['queued'] != true) return null;
    return data['jobId']?.toString();
  }

  Future<Map<String, dynamic>> reportPunchSyncWait(
    String jobId, {
    void Function(String message, {int? progress})? onProgress,
  }) {
    return _waitForJob(jobId, onProgress: onProgress);
  }

  Future<Map<String, dynamic>> reportPunchSummary({
    required String dateFrom,
    required String dateTo,
    String? locationId,
    String? departmentId,
    bool? requireNationalId,
    bool? includeArchived,
    bool export = false,
  }) async {
    final path = export
        ? '/api/biotime/reports/punch-summary/export-xlsx'
        : '/api/biotime/reports/punch-summary';
    return _unwrap(
      await _call(path, {
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        ..._reportScope(
          locationId: locationId,
          departmentId: departmentId,
          requireNationalId: requireNationalId,
          includeArchived: includeArchived,
        ),
      }),
    );
  }

  Future<Map<String, dynamic>> reportFawry({
    String filter = 'all',
    String? locationId,
    String? departmentId,
    bool? requireNationalId,
    bool export = false,
  }) async {
    final path = export
        ? '/api/biotime/reports/fawry/export-xlsx'
        : '/api/biotime/reports/fawry';
    return _unwrap(
      await _call(path, {
        'filter': filter,
        ..._reportScope(
          locationId: locationId,
          departmentId: departmentId,
          requireNationalId: requireNationalId,
        ),
      }),
    );
  }

  Future<Map<String, dynamic>> reportInsurance({
    String kind = 'both',
    String filter = 'all',
    String? locationId,
    String? departmentId,
    bool? requireNationalId,
    bool export = false,
  }) async {
    final path = export
        ? '/api/biotime/reports/insurance/export-xlsx'
        : '/api/biotime/reports/insurance';
    return _unwrap(
      await _call(path, {
        'kind': kind,
        'filter': filter,
        ..._reportScope(
          locationId: locationId,
          departmentId: departmentId,
          requireNationalId: requireNationalId,
        ),
      }),
    );
  }

  Future<Map<String, dynamic>> reportDocumentTypes() async {
    return _unwrap(await _call('/api/biotime/reports/documents/types', {}));
  }

  Future<Map<String, dynamic>> reportDocuments({
    List<String> requiredDocuments = const [],
    String filter = 'incomplete',
    String matchMode = 'any',
    bool? acceptCopies,
    String? locationId,
    String? departmentId,
    bool? requireNationalId,
    bool export = false,
  }) async {
    final path = export
        ? '/api/biotime/reports/documents/export-xlsx'
        : '/api/biotime/reports/documents';
    return _unwrap(
      await _call(path, {
        'requiredDocuments': requiredDocuments,
        'filter': filter,
        'matchMode': matchMode,
        if (acceptCopies != null) 'acceptCopies': acceptCopies,
        ..._reportScope(
          locationId: locationId,
          departmentId: departmentId,
          requireNationalId: requireNationalId,
        ),
      }),
    );
  }

  Future<Map<String, dynamic>> reportEmployeeMovements({
    required String dateFrom,
    required String dateTo,
    String mode = 'hirings',
    String? locationId,
    String? departmentId,
    bool? requireNationalId,
    bool export = false,
  }) async {
    final path = export
        ? '/api/biotime/reports/employee-movements/export-xlsx'
        : '/api/biotime/reports/employee-movements';
    return _unwrap(
      await _call(path, {
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        'mode': mode,
        ..._reportScope(
          locationId: locationId,
          departmentId: departmentId,
          requireNationalId: requireNationalId,
        ),
      }),
    );
  }

  Future<Map<String, dynamic>> reportEmployeeEmails({
    String? locationId,
    String? departmentId,
    bool? requireNationalId,
    bool? includeArchived,
    bool export = false,
  }) async {
    final path = export
        ? '/api/biotime/reports/employee-emails/export-xlsx'
        : '/api/biotime/reports/employee-emails';
    return _unwrap(
      await _call(path, {
        ..._reportScope(
          locationId: locationId,
          departmentId: departmentId,
          requireNationalId: requireNationalId,
          includeArchived: includeArchived,
        ),
      }),
    );
  }

  Future<Map<String, dynamic>> reportHealthCertificates({
    String mode = 'expired_or_expiring',
    int? warningDays,
    String? locationId,
    String? departmentId,
    bool? requireNationalId,
    bool export = false,
  }) async {
    final path = export
        ? '/api/biotime/reports/health-certificates/export-xlsx'
        : '/api/biotime/reports/health-certificates';
    return _unwrap(
      await _call(path, {
        'mode': mode,
        if (warningDays != null) 'warningDays': warningDays,
        ..._reportScope(
          locationId: locationId,
          departmentId: departmentId,
          requireNationalId: requireNationalId,
        ),
      }),
    );
  }

  // --- Audit log ---

  Future<Map<String, dynamic>> assistantChat({
    required String message,
    List<Map<String, String>> history = const [],
    String? page,
  }) async {
    return _unwrap(
      await _call('/api/biotime/assistant/chat', {
        'message': message,
        if (page != null && page.isNotEmpty) 'page': page,
        if (history.isNotEmpty) 'history': history,
      }, timeout: const Duration(seconds: 60)),
    );
  }

  Future<Map<String, dynamic>> auditList({
    String? dateFrom,
    String? dateTo,
    String? module,
    String? action,
    String? actorId,
    String? search,
    int limit = 40,
    int offset = 0,
  }) async {
    return _unwrap(
      await _call('/api/biotime/audit/list', {
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
        if (module != null && module.isNotEmpty) 'module': module,
        if (action != null && action.isNotEmpty) 'action': action,
        if (actorId != null && actorId.isNotEmpty) 'actorId': actorId,
        if (search != null && search.isNotEmpty) 'search': search,
        'limit': limit,
        'offset': offset,
      }),
    );
  }

  Future<Map<String, dynamic>> auditGet(String id) async {
    return _unwrap(await _call('/api/biotime/audit/get', {'id': id}));
  }

  Future<Map<String, dynamic>> auditExportXlsx(String id) async {
    return _unwrap(await _call('/api/biotime/audit/export-xlsx', {'id': id}));
  }

  Future<Map<String, dynamic>> adminFeatureGrantsList({
    String feature = 'audit_log',
  }) async {
    return _unwrap(
      await _call('/api/admin/feature-grants/list', {'feature': feature}),
    );
  }

  Future<Map<String, dynamic>> adminFeatureGrantSet({
    required String userId,
    required bool enabled,
    String feature = 'audit_log',
  }) async {
    return _unwrap(
      await _call('/api/admin/feature-grants/set', {
        'userId': userId,
        'enabled': enabled,
        'feature': feature,
      }),
    );
  }

  // --- Companies (Super Admin) ---

  Future<Map<String, dynamic>> adminCompaniesList() async {
    return _unwrap(await _call('/api/admin/companies/list', {}));
  }

  Future<Map<String, dynamic>> adminCompaniesCreate({
    required String code,
    required String name,
    String? hrManagerName,
    String? hrManagerLogin,
    String? hrManagerPassword,
  }) async {
    return _unwrap(
      await _call('/api/admin/companies/create', {
        'code': code,
        'name': name,
        if (hrManagerName != null) 'hrManagerName': hrManagerName,
        if (hrManagerLogin != null) 'hrManagerLogin': hrManagerLogin,
        if (hrManagerPassword != null) 'hrManagerPassword': hrManagerPassword,
      }),
    );
  }

  Future<Map<String, dynamic>> adminCompaniesUpdate({
    required String id,
    String? name,
    bool? active,
  }) async {
    return _unwrap(
      await _call('/api/admin/companies/update', {
        'id': id,
        if (name != null) 'name': name,
        if (active != null) 'active': active,
      }),
    );
  }

  bool _isNetworkError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('connection refused');
  }
}
