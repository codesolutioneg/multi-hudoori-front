import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/api_config.dart';
import '../../core/di/injection.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/department_name.dart';
import '../../core/utils/entity_id.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_extension.dart';
import '../../core/utils/egyptian_national_id.dart';
import '../../core/utils/iban.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/file_pick.dart';
import '../../core/utils/money_format.dart';
import '../../core/layout/app_tab_bar_v2.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/employee_search_field.dart';
import '../auth/auth_cubit.dart';
import 'employee_detail_tabs.dart';
import 'job_title_suggestions.dart';


Future<void> _hrPopup(
  BuildContext context,
  String message, {
  String? title,
}) async {
  final heading = title ?? context.t('common.notice');
  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => AlertDialog(
      title: Text(heading),
      content: Text(message, style: const TextStyle(height: 1.45)),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('common.ok'))),
      ],
    ),
  );
}

class EmployeeDetailPage extends StatefulWidget {
  const EmployeeDetailPage({super.key, required this.employeeId});
  final String employeeId;

  @override
  State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> _emp = {};
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _insuranceCompanies = [];
  List<Map<String, dynamic>> _custodyTypes = [];
  List<Map<String, dynamic>> _jobTitles = [];
  final Map<String, bool> _custodyProvided = {};
  Map<String, dynamic> _leaveSummary = {};
  bool _loading = true;
  bool _saving = false;
  bool _archiving = false;
  bool _fetchingPunches = false;
  String? _uploadingDocumentType;
  late final TabController _tabs;

  final _name = TextEditingController();
  final _code = TextEditingController();
  final _email = TextEditingController();
  final _workEmailPassword = TextEditingController();
  final _phone = TextEditingController();
  final _nationalIdConfirm = TextEditingController();
  final _jobTitle = TextEditingController();
  final _address = TextEditingController();
  final _hiringDate = TextEditingController();
  final _basicSalary = TextEditingController();
  final _healthIssueDate = TextEditingController();
  final _healthExpiryDate = TextEditingController();
  final _insuranceNumber = TextEditingController();
  final _insuranceSalary = TextEditingController();
  final _medicalInsuranceSalary = TextEditingController();
  final _fawryPhone = TextEditingController();
  final _bankIban = TextEditingController();
  final _mobileLinePhone = TextEditingController();
  final _leaveStartingBalance = TextEditingController();
  final _personalPhotoCount = TextEditingController();

  String? _locationId;
  String? _departmentId;
  String? _deviceId;
  String? _insuranceCompanyId;
  String? _medicalInsuranceCompanyId;
  String? _managerId;
  String _managerName = '';

  String _qualificationDocStatus = 'none';
  String _militaryDocStatus = 'none';
  String _birthCertificateDocStatus = 'none';

  bool _criminalRecord = false;
  bool _idCardPhoto = false;
  bool _personalPhoto = false;
  bool _hasSkillLevel = false;
  bool _healthCertificate = false;
  bool _isForeigner = false;
  bool _fawryAccount = false;
  bool _misrAccount = false;
  String _insurancePrintUrl = '';
  String _idCardPhotoUrl = '';
  String _qualificationDocUrl = '';
  String _militaryDocUrl = '';
  String _birthCertificateDocUrl = '';
  String _criminalRecordDocUrl = '';
  String _personalPhotoDocUrl = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _nationalIdConfirm.addListener(_onNationalIdChanged);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _name.dispose();
    _code.dispose();
    _email.dispose();
    _workEmailPassword.dispose();
    _phone.dispose();
    _nationalIdConfirm.removeListener(_onNationalIdChanged);
    _nationalIdConfirm.dispose();
    _jobTitle.dispose();
    _address.dispose();
    _hiringDate.dispose();
    _basicSalary.dispose();
    _healthIssueDate.dispose();
    _healthExpiryDate.dispose();
    _insuranceNumber.dispose();
    _insuranceSalary.dispose();
    _medicalInsuranceSalary.dispose();
    _fawryPhone.dispose();
    _bankIban.dispose();
    _mobileLinePhone.dispose();
    _leaveStartingBalance.dispose();
    _personalPhotoCount.dispose();
    super.dispose();
  }

  void _onNationalIdChanged() {
    if (mounted) setState(() {});
  }

  void _setText(TextEditingController c, dynamic value) {
    c.text = value?.toString() ?? '';
  }

  void _setMoney(TextEditingController c, dynamic value) {
    c.text = formatMoneyField(value);
  }

  void _fillForm(Map<String, dynamic> emp) {
    _name.text = emp['name']?.toString() ?? '';
    _code.text =
        emp['identificationId']?.toString() ?? emp['code']?.toString() ?? '';
    _email.text = emp['workEmail']?.toString() ?? '';
    _workEmailPassword.text = emp['workEmailPassword']?.toString() ?? '';
    // API returns workPhone: '' when null — ?? would skip mobilePhone.
    final workPhone = emp['workPhone']?.toString().trim() ?? '';
    final mobilePhone = emp['mobilePhone']?.toString().trim() ?? '';
    _phone.text = workPhone.isNotEmpty ? workPhone : mobilePhone;
    _locationId = EntityId.parse(emp['locationId']);
    _departmentId = EntityId.parse(emp['departmentId']);
    _deviceId = EntityId.parse(emp['biotimeDeviceId']);
    _managerId = EntityId.parse(emp['managerId']);
    _managerName = emp['managerName']?.toString().trim() ?? '';
    _setText(_jobTitle, emp['jobTitle'] ?? emp['job']);
    _setText(_address, emp['address']);

    _setText(_nationalIdConfirm, emp['nationalIdConfirm']);
    _setText(_hiringDate, emp['hiringDate']);
    _setMoney(_basicSalary, emp['basicSalary']);
    _setText(_healthIssueDate, emp['healthCertificateIssueDate']);
    _setText(_healthExpiryDate, emp['healthCertificateExpiryDate']);
    _setText(_insuranceNumber, emp['insuranceNumber']);
    _setMoney(_insuranceSalary, emp['insuranceSalary']);
    _setMoney(_medicalInsuranceSalary, emp['medicalInsuranceSalary']);
    _setText(_fawryPhone, emp['fawryPhone']);
    _setText(_bankIban, emp['bankIban']);
    _setText(_mobileLinePhone, emp['mobileLinePhone']);
    _setText(_leaveStartingBalance, emp['leaveStartingBalance']);
    _setText(_personalPhotoCount, emp['personalPhotoCount']);

    _insuranceCompanyId = EntityId.parse(emp['insuranceCompanyId']);
    _medicalInsuranceCompanyId = EntityId.parse(
      emp['medicalInsuranceCompanyId'],
    );

    _qualificationDocStatus =
        emp['qualificationDocStatus']?.toString() ?? 'none';
    _militaryDocStatus = emp['militaryDocStatus']?.toString() ?? 'none';
    _birthCertificateDocStatus =
        emp['birthCertificateDocStatus']?.toString() ?? 'none';
    if (!employeeDocumentStatuses.containsKey(_qualificationDocStatus))
      _qualificationDocStatus = 'none';
    if (!employeeDocumentStatuses.containsKey(_militaryDocStatus))
      _militaryDocStatus = 'none';
    if (!employeeDocumentStatuses.containsKey(_birthCertificateDocStatus))
      _birthCertificateDocStatus = 'none';

    _criminalRecord = emp['criminalRecord'] == true;
    _idCardPhoto = emp['idCardPhoto'] == true;
    _isForeigner = emp['isForeigner'] == true;
    _personalPhoto = emp['personalPhoto'] == true;
    _hasSkillLevel = emp['hasSkillLevel'] == true;
    _healthCertificate = emp['healthCertificate'] == true;
    _fawryAccount = emp['fawryAccount'] == true;
    _misrAccount = emp['misrAccount'] == true;
    _applyCustodiesFromEmployee(emp);
    _insurancePrintUrl = emp['insurancePrintUrl']?.toString() ?? '';
    _idCardPhotoUrl = emp['idCardPhotoUrl']?.toString() ?? '';
    _qualificationDocUrl = emp['qualificationDocUrl']?.toString() ?? '';
    _militaryDocUrl = emp['militaryDocUrl']?.toString() ?? '';
    _birthCertificateDocUrl = emp['birthCertificateDocUrl']?.toString() ?? '';
    _criminalRecordDocUrl = emp['criminalRecordDocUrl']?.toString() ?? '';
    _personalPhotoDocUrl = emp['personalPhotoDocUrl']?.toString() ?? '';
  }

  void _applyCustodiesFromEmployee(Map<String, dynamic> emp) {
    _custodyProvided.clear();
    final custodies = emp['custodies'];
    if (custodies is List) {
      for (final row in custodies) {
        if (row is! Map) continue;
        final typeId = EntityId.parse(
          row['custodyTypeId'] ?? row['custodyType']?['id'],
        );
        if (typeId != null) _custodyProvided[typeId] = row['provided'] == true;
      }
    }
    for (final type in _custodyTypes) {
      final typeId = EntityId.parse(type['id']);
      if (typeId == null || _custodyProvided.containsKey(typeId)) continue;
      final code = type['code']?.toString().toUpperCase() ?? '';
      if (code == 'LAPTOP')
        _custodyProvided[typeId] = emp['laptopProvided'] == true;
      if (code == 'MOBILE')
        _custodyProvided[typeId] = emp['mobileProvided'] == true;
      if (code == 'MOBILE_LINE')
        _custodyProvided[typeId] = emp['mobileLine'] == true;
    }
  }

  bool _isMobileLineCustodyType(Map<String, dynamic> type) =>
      type['code']?.toString().toUpperCase() == 'MOBILE_LINE';

  bool _mobileLineProvided() {
    for (final type in _custodyTypes) {
      if (!_isMobileLineCustodyType(type)) continue;
      final typeId = EntityId.parse(type['id']);
      if (typeId != null) return _custodyProvided[typeId] == true;
    }
    return false;
  }

  List<Map<String, dynamic>> _buildCustodiesPayload() {
    final activeTypes = _custodyTypes
        .where((t) => t['active'] != false)
        .toList();
    return [
      for (final type in activeTypes)
        if (EntityId.parse(type['id']) case final typeId?)
          {
            'custodyTypeId': typeId,
            'provided': _custodyProvided[typeId] == true,
          },
    ];
  }

  void _applyLeaveSummary(Map<String, dynamic> summary) {
    _leaveSummary = summary;
  }

  Map<String, dynamic> _buildUpdatePayload() {
    double? numOrNull(String text) {
      final parsed = parseMoney(text);
      if (parsed == null) return 0;
      return parsed;
    }

    String? emptyToNull(String text) {
      final t = text.trim();
      return t.isEmpty ? null : t;
    }

    return {
      'name': _name.text.trim(),
      'identificationId': _code.text.trim(),
      'departmentId': _departmentId,
      'biotimeDeviceId': _deviceId,
      'workEmail': _email.text.trim(),
      'workEmailPassword': _workEmailPassword.text.trim(),
      'workPhone': _phone.text.trim(),
      'mobilePhone': _phone.text.trim(),
      'locationId':
          context.read<AuthCubit>().state.scopedLocationId ?? _locationId,
      'jobTitle': _jobTitle.text.trim(),
      'managerId': _managerId,
      'address': _address.text.trim(),
      'nationalIdConfirm': _nationalIdConfirm.text.trim(),
      'isForeigner': _isForeigner,
      'hiringDate': emptyToNull(_hiringDate.text),
      'basicSalary': numOrNull(_basicSalary.text),
      'idCardPhoto': _idCardPhoto,
      'qualificationDocStatus': _qualificationDocStatus,
      'militaryDocStatus': _militaryDocStatus,
      'criminalRecord': _criminalRecord,
      'birthCertificateDocStatus': _birthCertificateDocStatus,
      'personalPhoto': _personalPhoto,
      'personalPhotoCount': numOrNull(_personalPhotoCount.text)?.toInt() ?? 0,
      'hasSkillLevel': _hasSkillLevel,
      'healthCertificate': _healthCertificate,
      'healthCertificateIssueDate': emptyToNull(_healthIssueDate.text),
      'healthCertificateExpiryDate': emptyToNull(_healthExpiryDate.text),
      'insuranceNumber': _insuranceNumber.text.trim(),
      'insuranceCompanyId': _insuranceCompanyId,
      'insuranceSalary': numOrNull(_insuranceSalary.text),
      'medicalInsuranceCompanyId': _medicalInsuranceCompanyId,
      'medicalInsuranceSalary': numOrNull(_medicalInsuranceSalary.text),
      'mobileLine': _mobileLineProvided(),
      'mobileLinePhone': _mobileLinePhone.text.trim(),
      'fawryAccount': _fawryAccount,
      'fawryPhone': _fawryPhone.text.trim(),
      'misrAccount': _misrAccount,
      'bankIban': normalizeEgyptianIban(_bankIban.text),
      'custodies': _buildCustodiesPayload(),
      'leaveStartingBalance': numOrNull(_leaveStartingBalance.text),
    };
  }


  Future<void> _showMessage(String message, {String? title}) async {
    if (!mounted) return;
    await _hrPopup(context, message, title: title);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final futures = <Future>[
        api.employeeGetDetail(widget.employeeId),
        api.departmentsList(),
        if (ApiConfig.showBiotimeDeviceUi) api.devicesList(),
        api.locationsList(),
        api.insuranceCompaniesList(),
        api.custodyTypesList(),
        api.jobTitlesList(activeOnly: true),
      ];
      final results = await Future.wait(futures);
      if (!mounted) return;
      var i = 0;
      final detail =
          results[i++]
              as ({
                Map<String, dynamic> employee,
                Map<String, dynamic> leaveSummary,
              });
      final emp = detail.employee;
      setState(() {
        _emp = emp;
        _departments = results[i++] as List<Map<String, dynamic>>;
        if (ApiConfig.showBiotimeDeviceUi) {
          _devices = results[i++] as List<Map<String, dynamic>>;
        }
        _locations = results[i++] as List<Map<String, dynamic>>;
        _insuranceCompanies = results[i++] as List<Map<String, dynamic>>;
        _custodyTypes = results[i++] as List<Map<String, dynamic>>;
        _jobTitles = results[i++] as List<Map<String, dynamic>>;
        _fillForm(emp);
        _applyLeaveSummary(detail.leaveSummary);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        await _showMessage(e.toString(), title: context.t('common.error'));
      }
    }
  }

  Future<void> _save() async {
    final nidText = _nationalIdConfirm.text.trim();
    if (!_isForeigner && nidText.isNotEmpty) {
      final nidError = validateEgyptianNationalId(context, nidText);
      if (nidError != null) {
        await _showMessage(nidError, title: context.t('common.notice'));
        return;
      }
    }

    final ibanError = validateEgyptianIban(
      context,
      _bankIban.text,
      required: _misrAccount,
    );
    if (ibanError != null) {
      await _showMessage(ibanError, title: context.t('common.notice'));
      return;
    }
    final mobileLineError = validateEgyptianMobileLine(
      context,
      _mobileLinePhone.text,
      required: _mobileLineProvided(),
    );
    if (mobileLineError != null) {
      await _showMessage(mobileLineError, title: context.t('common.notice'));
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await api.employeeUpdate(
        widget.employeeId,
        _buildUpdatePayload(),
      );
      final detail = await api.employeeGetDetail(widget.employeeId);
      if (mounted) {
        setState(() {
          _emp = updated;
          _fillForm(updated);
          _applyLeaveSummary(detail.leaveSummary);
          _saving = false;
        });
        await _showMessage(context.t('employees.saved'), title: context.t('common.done'));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        await _showMessage(e.toString(), title: context.t('common.error'));
      }
    }
  }

  Future<void> _action(Future<void> Function() fn, String ok) async {
    try {
      await fn();
      await _load();
      if (mounted)
        await _showMessage(ok, title: context.t('common.done'));
    } catch (e) {
      if (mounted)
        await _showMessage(e.toString(), title: context.t('common.error'));
    }
  }

  String _fmtArchiveDateTime(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final mo = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }

  DateTime _initialArchiveDateTime() {
    final raw = _emp['archivedAt'];
    if (raw is String && raw.isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed.toLocal();
    }
    return DateTime.now();
  }

  Future<DateTime?> _pickArchiveDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<({String reason, DateTime archivedAt})?> _showArchiveDialog({
    required String title,
    String? initialReason,
    DateTime? initialArchivedAt,
  }) async {
    List<Map<String, dynamic>> reasons = [];
    try {
      reasons = await api.archiveReasonsList(activeOnly: true);
    } catch (_) {
      // Fall back to seeded defaults if API fails.
    }
    if (reasons.isEmpty) {
      reasons = [
        {'name': context.t('empD.termination')},
        {'name': context.t('empD.resignation')},
        {'name': context.t('empD.clearance')},
      ];
    }
    final reasonNames = reasons
        .map((r) => r['name']?.toString().trim() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    if (!mounted) return null;

    return showDialog<({String reason, DateTime archivedAt})>(
      context: context,
      builder: (ctx) {
        String? selected = initialReason;
        if (selected != null && !reasonNames.contains(selected)) {
          // Keep a legacy free-text reason selectable while editing.
          reasonNames.insert(0, selected);
        }
        if (selected == null && reasonNames.isNotEmpty) {
          selected = reasonNames.first;
        }
        var archivedAt = initialArchivedAt ?? DateTime.now();
        final dateCtrl = TextEditingController(text: _fmtArchiveDateTime(archivedAt));
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (initialReason == null)
                  Text(ctx.t('employees.archive.body')),
                if (initialReason == null) const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(selected),
                  initialValue: selected,
                  decoration: InputDecoration(
                    labelText: ctx.t('employees.archive.reasonLabel'),
                    hintText: ctx.t('employees.archive.reasonHint'),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final name in reasonNames)
                      DropdownMenuItem(value: name, child: Text(name)),
                  ],
                  onChanged: (value) => setDialogState(() => selected = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  readOnly: true,
                  controller: dateCtrl,
                  decoration: InputDecoration(
                    labelText: ctx.t('employees.archive.departureLabel'),
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.event_outlined),
                  ),
                  onTap: () async {
                    final picked = await _pickArchiveDateTime(archivedAt);
                    if (picked == null) return;
                    setDialogState(() {
                      archivedAt = picked;
                      dateCtrl.text = _fmtArchiveDateTime(picked);
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ctx.t('common.cancel')),
              ),
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () => Navigator.pop(
                          ctx,
                          (reason: selected!, archivedAt: archivedAt),
                        ),
                child: Text(
                  initialReason == null
                      ? ctx.t('employees.archive.confirm')
                      : ctx.t('common.save'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleArchive() async {
    final isArchived = _emp['active'] == false;

    ({String reason, DateTime archivedAt})? archivePayload;
    if (isArchived) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.t('employees.restore.title')),
          content: Text(ctx.t('employees.restore.body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('employees.restore.confirm')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    } else {
      archivePayload = await _showArchiveDialog(
        title: context.t('employees.archive.title'),
      );
      if (archivePayload == null || archivePayload.reason.isEmpty) return;
    }
    if (!mounted) return;

    setState(() => _archiving = true);
    try {
      if (isArchived) {
        await api.employeeRestore(widget.employeeId);
      } else {
        await api.employeeArchive(
          widget.employeeId,
          archivePayload!.reason,
          archivedAt: archivePayload.archivedAt,
        );
      }
      if (!mounted) return;
      await _showMessage(
        isArchived
            ? context.t('employees.restore.done')
            : context.t('employees.archive.done'),
        title: context.t('common.done'),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        await _showMessage(e.toString(), title: context.t('common.error'));
      }
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }

  Future<void> _editArchiveReason() async {
    final current = _emp['archiveReason']?.toString();
    final initialReason =
        (current == context.t('empD.termination') || current == context.t('empD.clearance')) ? current : null;
    final picked = await _showArchiveDialog(
      title: context.t('employees.archive.editReason'),
      initialReason: initialReason,
      initialArchivedAt: _initialArchiveDateTime(),
    );
    if (picked == null || picked.reason.isEmpty || !mounted) return;
    setState(() => _archiving = true);
    try {
      await api.employeeArchive(
        widget.employeeId,
        picked.reason,
        archivedAt: picked.archivedAt,
      );
      if (!mounted) return;
      await _showMessage(
        context.t('employees.archive.reasonUpdated'),
        title: context.t('common.done'),
      );
      await _load();
    } catch (e) {
      if (mounted) await _showMessage(e.toString(), title: context.t('common.error'));
    } finally {
      if (mounted) setState(() => _archiving = false);
    }
  }

  Map<String, dynamic>? get _mapping {
    final m = _emp['mapping'];
    return m is Map ? Map<String, dynamic>.from(m) : null;
  }

  Future<void> _fetchDevicePunches() async {
    setState(() => _fetchingPunches = true);
    try {
      final report = await api.employeeSyncDevice(widget.employeeId);
      if (!mounted) return;
      if (report['employee'] is Map) {
        setState(() {
          _emp = Map<String, dynamic>.from(report['employee'] as Map);
          _fillForm(_emp);
        });
      }
      await showDialog<void>(
        context: context,
        builder: (ctx) => _EmployeePunchesDialog(
          report: report,
          employeeId: widget.employeeId,
        ),
      );
      if (mounted && report['message'] != null) {
        await _showMessage(report['message'].toString(), title: context.t('common.done'));
      }
    } catch (e) {
      if (mounted) {
        await _showMessage(e.toString(), title: context.t('common.error'));
      }
    } finally {
      if (mounted) setState(() => _fetchingPunches = false);
    }
  }

  Future<void> _exportPunchesRange() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _PunchExportRangeDialog(employeeId: widget.employeeId),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    ValueChanged<T?>? onChanged,
    bool allowEmpty = true,
  }) {
    final allItems = [
      if (allowEmpty) DropdownMenuItem<T>(value: null, child: const Text('—')),
      ...items,
    ];
    final allowed = allItems
        .map((item) => item.value)
        .where((v) => v != null || allowEmpty)
        .toSet();
    final safeValue = value == null || allowed.contains(value) ? value : null;

    return DropdownButtonFormField<T>(
      value: safeValue,
      decoration: InputDecoration(labelText: label),
      items: allItems,
      onChanged: onChanged,
    );
  }

  int? get _displayAge {
    final fromNationalId = parseEgyptianNationalId(_nationalIdConfirm.text).age;
    if (fromNationalId != null) return fromNationalId;
    final saved = _emp['employeeAge'];
    if (saved is num && saved > 0) return saved.toInt();
    return null;
  }

  String? get _displayBirthDate {
    final fromNationalId = parseEgyptianNationalId(
      _nationalIdConfirm.text,
    ).birthDate;
    if (fromNationalId != null) return formatBirthDateIso(fromNationalId);
    final saved = _emp['birthday']?.toString() ?? '';
    return saved.isNotEmpty ? saved : null;
  }

  Future<void> _pickDateField(TextEditingController controller) async {
    final changed = await pickDate(context, controller);
    if (changed && mounted) setState(() {});
  }

  Future<void> _pickHealthIssueDate() async {
    final changed = await pickDate(context, _healthIssueDate);
    if (!changed || !mounted) return;
    final issue = DateTime.tryParse(_healthIssueDate.text.trim());
    if (issue != null) {
      final expiry = DateTime(issue.year + 1, issue.month, issue.day);
      _healthExpiryDate.text =
          '${expiry.year.toString().padLeft(4, '0')}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}';
    }
    setState(() {});
  }

  Future<void> _uploadDocument(String documentType) async {
    try {
      final picked = await pickDocumentBase64();
      if (picked == null || picked.base64.isEmpty) return;
      setState(() => _uploadingDocumentType = documentType);
      final result = await api.employeeDocumentUpload(
        widget.employeeId,
        documentType: documentType,
        base64: picked.base64,
        mimeType: picked.mimeType,
      );
      if (!mounted) return;
      final emp = result['employee'];
      if (emp is Map) _fillForm(Map<String, dynamic>.from(emp));
      setState(() => _uploadingDocumentType = null);
      await _showMessage(
        result['message']?.toString() ?? context.t('empD.docUploaded'),
        title: context.t('common.done'),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingDocumentType = null);
        await _showMessage(e.toString(), title: context.t('common.error'));
      }
    }
  }

  Future<void> _viewDocument(String documentType, String filename) async {
    try {
      final file = await api.employeeDocumentGet(
        widget.employeeId,
        documentType: documentType,
      );
      final base64 = file['base64']?.toString() ?? '';
      if (base64.isEmpty) throw Exception(context.t('set.emptyFile'));
      downloadBase64File(
        base64,
        file['filename']?.toString() ?? filename,
        file['mimeType']?.toString() ?? 'application/octet-stream',
      );
    } catch (e) {
      if (mounted) {
        await _showMessage(e.toString(), title: context.t('common.error'));
      }
    }
  }

  Future<void> _uploadInsurancePrint() async {
    await _uploadDocument('insurance_print');
  }

  Future<void> _viewInsurancePrint() async {
    await _viewDocument('insurance_print', 'insurance-print');
  }

  List<Map<String, dynamic>> get _leaveDates {
    final dates = _leaveSummary['dates'];
    if (dates is! List) return [];
    return dates
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  double get _usedLeaveDays =>
      (_leaveSummary['usedLeaveDays'] as num?)?.toDouble() ?? 0;
  double get _remainingLeaveDays =>
      (_leaveSummary['remainingLeaveBalance'] as num?)?.toDouble() ?? 0;

  Widget _archivedBanner() {
    final archivedAtRaw = _emp['archivedAt'];
    String archivedDate = '';
    if (archivedAtRaw is String && archivedAtRaw.isNotEmpty) {
      final parsed = DateTime.tryParse(archivedAtRaw);
      archivedDate = parsed != null
          ? _fmtArchiveDateTime(parsed.toLocal())
          : archivedAtRaw;
    }
    final reason = _emp['archiveReason']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.archive_outlined, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  archivedDate.isEmpty
                      ? context.t('employees.archivedBanner')
                      : context.t('employees.archivedSince', {
                          'date': archivedDate,
                        }),
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (reason.isNotEmpty)
                  Text(
                    context.t('employees.archivedReason', {'reason': reason}),
                    style: TextStyle(
                      color: AppColors.danger.withValues(alpha: 0.9),
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: _archiving ? null : _editArchiveReason,
            child: Text(context.t('employees.archive.editReason')),
          ),
        ],
      ),
    );
  }

  Widget _tabScroll(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppThemeV2.primary),
      );
    }

    final mapping = _mapping;
    final displayAge = _displayAge;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile(context) ? 12 : 24,
        isMobile(context) ? 12 : 20,
        isMobile(context) ? 12 : 24,
        isMobile(context) ? 12 : 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title:
                _emp['displayName']?.toString() ??
                _emp['name']?.toString() ??
                context.t('employees.employee'),
            subtitle:
                '${context.t('employees.codeLabel')}: ${_emp['code'] ?? ''}${employeeDepartmentName(_emp, context).isNotEmpty ? '  •  ${employeeDepartmentName(_emp, context)}' : ''}',
            icon: Icons.person_outline_rounded,
            backOnEnd: true,
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.hrEmployees);
              }
            },
          ),
          if (_emp['active'] == false) ...[
            const SizedBox(height: 12),
            _archivedBanner(),
          ],
          const SizedBox(height: 16),
          AppTabBarV2(
            controller: _tabs,
            tabs: [
              Tab(text: context.t('employees.tab.main')),
              Tab(text: context.t('employees.tab.documents')),
              Tab(text: context.t('employees.tab.insurance')),
              Tab(text: context.t('employees.tab.accountsLeave')),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _mainDataTab(mapping, displayAge),
                _documentsTab(),
                _insuranceTab(),
                _accountsLeaveTab(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SellixCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, size: 18),
                  label: Text(context.t('employees.action.save')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _action(
                    () => api.employeePushBiotime(widget.employeeId),
                    context.t('employees.action.pushOk'),
                  ),
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: Text(context.t('employees.action.manualPush')),
                ),
                OutlinedButton.icon(
                  onPressed: _fetchingPunches ? null : _fetchDevicePunches,
                  icon: _fetchingPunches
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fingerprint, size: 18),
                  label: Text(
                    _fetchingPunches
                        ? context.t('employees.action.fetchingPunches')
                        : context.t('employees.action.fetchPunches'),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _exportPunchesRange,
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: Text(context.t('employees.action.exportPunches')),
                ),
                OutlinedButton.icon(
                  onPressed: _archiving ? null : _toggleArchive,
                  icon: _archiving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _emp['active'] == false
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                          size: 18,
                        ),
                  label: Text(
                    _emp['active'] == false
                        ? context.t('employees.action.restore')
                        : context.t('employees.action.archive'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _emp['active'] == false
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mainDataTab(Map<String, dynamic>? mapping, int? displayAge) {
    final displayBirthDate = _displayBirthDate;
    return _tabScroll(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mapping != null) ...[
            SellixCard(
              child: Text(
                'BioTime: ${mapping['biotimeEmpCode'] ?? ''} (id: ${mapping['biotimeEmpId'] ?? ''})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
          ],
          EmployeeTabSection(
            title: context.t('employees.section.personal'),
            children: [
              TextField(
                controller: _code,
                decoration: InputDecoration(
                  labelText: context.t('employees.field.empCode'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: context.t('employees.field.name'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nationalIdConfirm,
                keyboardType: _isForeigner
                    ? TextInputType.text
                    : TextInputType.number,
                maxLength: _isForeigner ? 40 : 14,
                inputFormatters: _isForeigner
                    ? const []
                    : [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: context.t('employees.field.nationalId'),
                  counterText: '',
                  helperText: _isForeigner
                      ? context.t('employees.field.isForeignerHint')
                      : null,
                  errorText: (!_isForeigner &&
                          _nationalIdConfirm.text.trim().isNotEmpty)
                      ? validateEgyptianNationalId(context, _nationalIdConfirm.text)
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.t('employees.field.isForeigner')),
                subtitle: Text(context.t('employees.field.isForeignerHint')),
                value: _isForeigner,
                onChanged: (v) => setState(() => _isForeigner = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: context.t('employees.field.age'),
                  hintText: displayAge == null
                      ? context.t('employees.field.ageHint')
                      : null,
                  suffixText: displayAge != null
                      ? context.t('employees.field.ageYears')
                      : null,
                  border: const OutlineInputBorder(),
                ),
                child: Text(
                  displayAge?.toString() ?? '—',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: context.t('employees.field.birthDate'),
                  hintText: displayBirthDate == null
                      ? context.t('employees.field.birthDateHint')
                      : null,
                  border: const OutlineInputBorder(),
                ),
                child: Text(
                  displayBirthDate ?? '—',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          EmployeeTabSection(
            title: context.t('employees.section.work'),
            children: [
              Builder(
                builder: (context) {
                  final auth = context.read<AuthCubit>().state;
                  final scopedLocationId = auth.scopedLocationId;
                  final locationLocked = auth.isLocationScoped;
                  final locationItems = locationLocked
                      ? _locations
                            .where(
                              (l) =>
                                  EntityId.parse(l['id']) == scopedLocationId,
                            )
                            .toList()
                      : _locations;
                  return _dropdown<String?>(
                    label: context.t('employees.field.location'),
                    value: locationLocked ? scopedLocationId : _locationId,
                    items: [
                      for (final l in locationItems)
                        DropdownMenuItem(
                          value: EntityId.parse(l['id']),
                          child: Text(l['name']?.toString() ?? ''),
                        ),
                    ],
                    onChanged: locationLocked
                        ? null
                        : (v) => setState(() => _locationId = v),
                  );
                },
              ),
              const SizedBox(height: 12),
              _dropdown<String?>(
                label: context.t('employees.department'),
                value: _departmentId,
                items: [
                  for (final d in _departments)
                    DropdownMenuItem(
                      value: EntityId.parse(d['id']),
                      child: Text(
                        departmentDisplayName(
                          d,
                          isArabic: AppLocalizations.of(context).isAr,
                        ),
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _departmentId = v),
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final current = _jobTitle.text.trim();
                  final names = <String>{
                    ...formalJobTitleSuggestions(
                      isArabic: AppLocalizations.of(context).isAr,
                    ),
                    for (final j in _jobTitles)
                      if ((j['name']?.toString() ?? '').trim().isNotEmpty)
                        j['name'].toString().trim(),
                  };
                  if (current.isNotEmpty) names.add(current);
                  final sorted = names.toList()..sort();
                  return Autocomplete<String>(
                    initialValue: TextEditingValue(text: current),
                    optionsBuilder: (textEditingValue) {
                      final q = textEditingValue.text.trim().toLowerCase();
                      if (q.isEmpty) return sorted.take(12);
                      return sorted
                          .where((n) => n.toLowerCase().contains(q))
                          .take(20);
                    },
                    onSelected: (v) => setState(() => _jobTitle.text = v),
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      // Keep local controller in sync with form state.
                      if (controller.text != _jobTitle.text) {
                        controller.text = _jobTitle.text;
                        controller.selection = TextSelection.collapsed(
                          offset: controller.text.length,
                        );
                      }
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: (v) => _jobTitle.text = v,
                        onSubmitted: (_) => onFieldSubmitted(),
                        decoration: InputDecoration(
                          labelText: context.t('employees.field.jobTitle'),
                          helperText: context.t('employees.field.jobTitleHint'),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              EmployeeSearchField(
                key: ValueKey('manager-${_managerId ?? 'none'}-$_managerName'),
                initialId: _managerId,
                initialName: _managerName,
                excludeEmployeeId: widget.employeeId,
                label: context.t('employees.field.manager'),
                onSelected: (id, name) {
                  setState(() {
                    _managerId = id;
                    _managerName = name;
                  });
                },
              ),
              if (ApiConfig.showBiotimeDeviceUi) ...[
                const SizedBox(height: 12),
                _dropdown<String?>(
                  label: context.t('employees.field.device'),
                  value: _deviceId,
                  items: [
                    for (final d in _devices)
                      DropdownMenuItem(
                        value: EntityId.parse(d['id']),
                        child: Text(d['name']?.toString() ?? ''),
                      ),
                  ],
                  onChanged: (v) => setState(() => _deviceId = v),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                decoration: InputDecoration(
                  labelText: context.t('employees.field.email'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _workEmailPassword,
                decoration: InputDecoration(
                  labelText: context.t('employees.field.workEmailPassword'),
                  helperText: context.t('employees.field.workEmailPasswordHint'),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: context.t('common.copy'),
                        icon: const Icon(Icons.copy_outlined, size: 20),
                        onPressed: () async {
                          final text = _workEmailPassword.text.trim();
                          if (text.isEmpty) return;
                          await Clipboard.setData(ClipboardData(text: text));
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.t('employees.field.passwordCopied'),
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: context.t('employees.field.regeneratePassword'),
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: () {
                          const alphabet =
                              'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
                          final rnd = StringBuffer();
                          final now = DateTime.now().microsecondsSinceEpoch;
                          var x = now;
                          for (var i = 0; i < 10; i++) {
                            x = (x * 1103515245 + 12345) & 0x7fffffff;
                            rnd.write(alphabet[x % alphabet.length]);
                          }
                          setState(() => _workEmailPassword.text = rnd.toString());
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                decoration: InputDecoration(
                  labelText: context.t('employees.field.phone'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _address,
                decoration: InputDecoration(
                  labelText: context.t('employees.field.address'),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              EmployeeDateField(
                label: context.t('employees.field.hiringDate'),
                controller: _hiringDate,
                onPick: () => _pickDateField(_hiringDate),
              ),
              const SizedBox(height: 12),
              EmployeeNumberField(
                label: context.t('employees.field.basicSalary'),
                controller: _basicSalary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _documentsTab() {
    bool uploading(String type) => _uploadingDocumentType == type;
    return _tabScroll(
      Column(
        children: [
          employeeTabHint(context.t('employees.docs.hint')),
          EmployeeTabSection(
            title: context.t('employees.section.documents'),
            children: [
              EmployeeDocumentField(
                label: context.t('employees.docs.idCard'),
                useBoolStatus: true,
                boolValue: _idCardPhoto,
                onBoolChanged: (v) => setState(() => _idCardPhoto = v),
                hasFile: _idCardPhotoUrl.isNotEmpty,
                uploading: uploading('id_card'),
                onUpload: () => _uploadDocument('id_card'),
                onView: _idCardPhotoUrl.isNotEmpty
                    ? () => _viewDocument('id_card', 'id-card')
                    : null,
              ),
              const SizedBox(height: 16),
              EmployeeDocumentField(
                label: context.t('employees.docs.qualification'),
                statusValue: _qualificationDocStatus,
                onStatusChanged: (v) =>
                    setState(() => _qualificationDocStatus = v),
                hasFile: _qualificationDocUrl.isNotEmpty,
                uploading: uploading('qualification'),
                onUpload: () => _uploadDocument('qualification'),
                onView: _qualificationDocUrl.isNotEmpty
                    ? () => _viewDocument('qualification', 'qualification')
                    : null,
              ),
              const SizedBox(height: 16),
              EmployeeDocumentField(
                label: context.t('employees.docs.military'),
                statusValue: _militaryDocStatus,
                onStatusChanged: (v) => setState(() => _militaryDocStatus = v),
                hasFile: _militaryDocUrl.isNotEmpty,
                uploading: uploading('military'),
                onUpload: () => _uploadDocument('military'),
                onView: _militaryDocUrl.isNotEmpty
                    ? () => _viewDocument('military', 'military')
                    : null,
              ),
              const SizedBox(height: 16),
              EmployeeDocumentField(
                label: context.t('employees.docs.criminal'),
                useBoolStatus: true,
                boolValue: _criminalRecord,
                onBoolChanged: (v) => setState(() => _criminalRecord = v),
                hasFile: _criminalRecordDocUrl.isNotEmpty,
                uploading: uploading('criminal_record'),
                onUpload: () => _uploadDocument('criminal_record'),
                onView: _criminalRecordDocUrl.isNotEmpty
                    ? () => _viewDocument('criminal_record', 'criminal-record')
                    : null,
              ),
              const SizedBox(height: 16),
              EmployeeDocumentField(
                label: context.t('employees.docs.birthCert'),
                statusValue: _birthCertificateDocStatus,
                onStatusChanged: (v) =>
                    setState(() => _birthCertificateDocStatus = v),
                hasFile: _birthCertificateDocUrl.isNotEmpty,
                uploading: uploading('birth_certificate'),
                onUpload: () => _uploadDocument('birth_certificate'),
                onView: _birthCertificateDocUrl.isNotEmpty
                    ? () => _viewDocument(
                        'birth_certificate',
                        'birth-certificate',
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              EmployeeDocumentField(
                label: context.t('employees.docs.personalPhoto'),
                useBoolStatus: true,
                boolValue: _personalPhoto,
                onBoolChanged: (v) => setState(() => _personalPhoto = v),
                hasFile: _personalPhotoDocUrl.isNotEmpty,
                uploading: uploading('personal_photo'),
                onUpload: () => _uploadDocument('personal_photo'),
                onView: _personalPhotoDocUrl.isNotEmpty
                    ? () => _viewDocument('personal_photo', 'personal-photo')
                    : null,
              ),
              if (_personalPhoto) ...[
                const SizedBox(height: 12),
                EmployeeNumberField(
                  label: context.t('employees.docs.photoCount'),
                  controller: _personalPhotoCount,
                ),
              ],
              const SizedBox(height: 16),
              EmployeeDocumentField(
                label: context.t('employees.docs.insurancePrint'),
                hasFile: _insurancePrintUrl.isNotEmpty,
                uploading: uploading('insurance_print'),
                onUpload: _uploadInsurancePrint,
                onView: _insurancePrintUrl.isNotEmpty
                    ? _viewInsurancePrint
                    : null,
              ),
              const SizedBox(height: 16),
              EmployeeBoolField(
                label: context.t('employees.docs.skillLevel'),
                value: _hasSkillLevel,
                onChanged: (v) => setState(() => _hasSkillLevel = v),
              ),
              const SizedBox(height: 12),
              EmployeeBoolField(
                label: context.t('employees.docs.healthCert'),
                value: _healthCertificate,
                onChanged: (v) => setState(() => _healthCertificate = v),
              ),
              if (_healthCertificate) ...[
                const SizedBox(height: 12),
                EmployeeDateField(
                  label: context.t('employees.docs.healthIssue'),
                  controller: _healthIssueDate,
                  onPick: _pickHealthIssueDate,
                ),
                const SizedBox(height: 12),
                EmployeeDateField(
                  label: context.t('employees.docs.healthExpiry'),
                  controller: _healthExpiryDate,
                  onPick: () => _pickDateField(_healthExpiryDate),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _insuranceTab() {
    return _tabScroll(
      Column(
        children: [
          employeeTabHint(context.t('employees.insurance.hint')),
          EmployeeTabSection(
            title: context.t('employees.section.insurance'),
            children: [
              TextField(
                controller: _insuranceNumber,
                decoration: InputDecoration(
                  labelText: context.t('employees.field.insuranceNumber'),
                ),
              ),
              const SizedBox(height: 12),
              _dropdown<String?>(
                label: context.t('employees.field.insuranceStatus'),
                value: _insuranceCompanyId,
                items: [
                  for (final c in _insuranceCompanies)
                    DropdownMenuItem(
                      value: EntityId.parse(c['id']),
                      child: Text(c['name']?.toString() ?? ''),
                    ),
                ],
                onChanged: (v) => setState(() => _insuranceCompanyId = v),
              ),
              const SizedBox(height: 12),
              EmployeeNumberField(
                label: context.t('employees.field.insuranceSalary'),
                controller: _insuranceSalary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          EmployeeTabSection(
            title: context.t('employees.section.medical'),
            children: [
              _dropdown<String?>(
                label: context.t('employees.field.medicalStatus'),
                value: _medicalInsuranceCompanyId,
                items: [
                  for (final c in _insuranceCompanies)
                    DropdownMenuItem(
                      value: EntityId.parse(c['id']),
                      child: Text(c['name']?.toString() ?? ''),
                    ),
                ],
                onChanged: (v) =>
                    setState(() => _medicalInsuranceCompanyId = v),
              ),
              const SizedBox(height: 12),
              EmployeeNumberField(
                label: context.t('employees.field.insuranceSalary'),
                controller: _medicalInsuranceSalary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accountsLeaveTab() {
    return _tabScroll(
      Column(
        children: [
          EmployeeTabSection(
            title: context.t('employees.section.accounts'),
            children: [
              EmployeeBoolField(
                label: 'Fawry',
                value: _fawryAccount,
                onChanged: (v) => setState(() => _fawryAccount = v),
              ),
              if (_fawryAccount) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _fawryPhone,
                  decoration: InputDecoration(
                    labelText: context.t('employees.field.fawryPhone'),
                  ),
                ),
              ],
              EmployeeBoolField(
                label: 'Bank Account',
                value: _misrAccount,
                onChanged: (v) => setState(() => _misrAccount = v),
              ),
              if (_misrAccount) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _bankIban,
                  decoration: InputDecoration(
                    labelText: context.t('employees.field.iban'),
                    hintText: 'EG000000000000000000000000000',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\s]')),
                    LengthLimitingTextInputFormatter(34),
                  ],
                  onChanged: (_) {
                    final text = _bankIban.text;
                    final upper = text.toUpperCase();
                    if (text != upper) {
                      _bankIban.value = _bankIban.value.copyWith(
                        text: upper,
                        selection: TextSelection.collapsed(
                          offset: upper.length,
                        ),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
          if (_custodyTypes.where((t) => t['active'] != false).isNotEmpty) ...[
            const SizedBox(height: 12),
            EmployeeTabSection(
              title: context.t('employees.section.custody'),
              children: [
                for (final type in _custodyTypes.where(
                  (t) => t['active'] != false,
                )) ...[
                  if (EntityId.parse(type['id']) case final typeId?) ...[
                    EmployeeBoolField(
                      label: type['name']?.toString() ??
                          context.t('employees.field.custodyDefault'),
                      value: _custodyProvided[typeId] == true,
                      onChanged: (v) =>
                          setState(() => _custodyProvided[typeId] = v),
                    ),
                    if (_isMobileLineCustodyType(type) &&
                        _custodyProvided[typeId] == true) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _mobileLinePhone,
                        decoration: InputDecoration(
                          labelText: context.t('employees.field.mobileLine'),
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ],
              ],
            ),
          ],
          const SizedBox(height: 12),
          EmployeeTabSection(
            title: context.t('employees.section.leave'),
            children: [
              EmployeeNumberField(
                label: context.t('employees.field.leaveStart'),
                controller: _leaveStartingBalance,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _leaveStatCard(
                      context.t('employees.field.leaveUsed'),
                      _usedLeaveDays.toStringAsFixed(0),
                      AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _leaveStatCard(
                      context.t('employees.field.leaveRemaining'),
                      _remainingLeaveDays.toStringAsFixed(0),
                      AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.t('employees.leave.usedThisYear', {
                  'year': _leaveSummary['year'] ?? DateTime.now().year,
                }),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              if (_leaveDates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    context.t('employees.leave.emptyYear'),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                SellixCard(
                  padding: EdgeInsets.zero,
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(1),
                    },
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              context.t('employees.leave.date'),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              context.t('employees.leave.source'),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      for (final row in _leaveDates)
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(row['date']?.toString() ?? ''),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                row['source'] == 'shift_grid'
                                    ? context.t('employees.leave.sourceGrid')
                                    : context.t(
                                        'employees.leave.sourceAttendance',
                                      ),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leaveStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeePunchesDialog extends StatefulWidget {
  const _EmployeePunchesDialog({
    required this.report,
    required this.employeeId,
  });

  final Map<String, dynamic> report;
  final String employeeId;

  @override
  State<_EmployeePunchesDialog> createState() => _EmployeePunchesDialogState();
}

class _EmployeePunchesDialogState extends State<_EmployeePunchesDialog> {
  bool _exporting = false;

  List<Map<String, dynamic>> get _items =>
      (widget.report['items'] as List?)
          ?.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList() ??
      [];

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final r = await api.employeePunchReportExportXlsx(
        widget.employeeId,
        sync: false,
      );
      final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
      final filename = r['filename']?.toString() ?? 'punches.xlsx';
      if (base64.isEmpty) throw Exception(context.t('set.emptyFile'));
      downloadBase64File(
        base64,
        filename,
        r['mimeType']?.toString() ??
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (mounted) {
        await _hrPopup(context, context.t('emp.downloaded', {'file': filename}), title: context.t('common.done'));
      }
    } catch (e) {
      if (mounted) {
        await _hrPopup(context, e.toString(), title: context.t('common.error'));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.report['employeeName']?.toString() ?? '';
    final from = widget.report['dateFrom']?.toString() ?? '';
    final to = widget.report['dateTo']?.toString() ?? '';
    final device = widget.report['deviceName']?.toString() ?? '';
    final count = widget.report['count'] ?? _items.length;

    return AlertDialog(
      title: Text(context.t('empD.punchesOf', {'name': name})),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t('empD.punchRange', {'from': from, 'to': to, 'count': count, 'device': device.isNotEmpty ? ' — $device' : ''}),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            if (widget.report['syncedCount'] != null &&
                (widget.report['syncedCount'] as num) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  context.t('empD.syncedNew', {'count': widget.report['syncedCount']}),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (_items.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(context.t('empD.noPunches90')),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = _items[i];
                    final date = p['date']?.toString() ?? '';
                    final time = p['time']?.toString() ?? '';
                    final state =
                        p['punchStateLabel']?.toString() ??
                        p['punchState']?.toString() ??
                        '';
                    final terminal =
                        p['terminalAlias']?.toString() ??
                        p['terminalSn']?.toString() ??
                        '';
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          state.isNotEmpty ? state[0] : '?',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        '$date  $time',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        [
                          state,
                          if (terminal.isNotEmpty) terminal,
                        ].join('  •  '),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('common.close')),
        ),
        if (_items.isNotEmpty)
          FilledButton.icon(
            onPressed: _exporting ? null : _export,
            icon: _exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download, size: 18),
            label: Text(context.t('empD.exportExcel')),
          ),
      ],
    );
  }
}

class _PunchExportRangeDialog extends StatefulWidget {
  const _PunchExportRangeDialog({required this.employeeId});

  final String employeeId;

  @override
  State<_PunchExportRangeDialog> createState() =>
      _PunchExportRangeDialogState();
}

class _PunchExportRangeDialogState extends State<_PunchExportRangeDialog> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  bool _syncFromBioTime = false;
  bool _exporting = false;
  String? _error;
  String? _progress;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromCtrl.text = _fmt(DateTime(now.year, now.month, 1));
    _toCtrl.text = _fmt(now);
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime? _parse(String s) {
    final t = s.trim();
    final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(t);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    final dt = DateTime(y, mo, d);
    if (dt.month != mo || dt.day != d) return null;
    return dt;
  }

  void _applyPreset(DateTime from, DateTime to) {
    setState(() {
      _fromCtrl.text = _fmt(from);
      _toCtrl.text = _fmt(to);
      _error = null;
    });
  }

  Future<void> _pick(TextEditingController ctrl) async {
    final current = _parse(ctrl.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      ctrl.text = _fmt(picked);
      _error = null;
    });
  }

  Future<void> _export() async {
    final from = _parse(_fromCtrl.text);
    final to = _parse(_toCtrl.text);
    if (from == null || to == null) {
      setState(
        () => _error =
            context.t('empD.badDateFormat'),
      );
      return;
    }
    if (from.isAfter(to)) {
      setState(() => _error = context.t('empD.startAfterEnd'));
      return;
    }
    setState(() {
      _error = null;
      _exporting = true;
      _progress = _syncFromBioTime ? context.t('empD.syncingPunches') : null;
    });
    try {
      // Run the BioTime sync as a polled background job first so we never block
      // a single request past the proxy timeout, then export from cache.
      if (_syncFromBioTime) {
        await api.employeePunchSyncStart(
          widget.employeeId,
          dateFrom: _fmt(from),
          dateTo: _fmt(to),
          onProgress: (m, {int? progress}) {
            if (mounted)
              setState(() => _progress = m.isNotEmpty ? m : context.t('empD.syncing'));
          },
        );
        if (mounted) setState(() => _progress = context.t('empD.buildingExcel'));
      }
      final r = await api.employeePunchReportExportXlsx(
        widget.employeeId,
        sync: false,
        dateFrom: _fmt(from),
        dateTo: _fmt(to),
      );
      final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
      final filename = r['filename']?.toString() ?? 'punches.xlsx';
      if (base64.isEmpty) throw Exception(context.t('set.emptyFile'));
      downloadBase64File(
        base64,
        filename,
        r['mimeType']?.toString() ??
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (mounted) {
        Navigator.pop(context);
        await _hrPopup(context, context.t('emp.downloaded', {'file': filename}), title: context.t('common.done'));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _exporting = false;
          _progress = null;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Widget _dateField({
    required String label,
    required TextEditingController ctrl,
  }) {
    return TextField(
      controller: ctrl,
      enabled: !_exporting,
      keyboardType: TextInputType.datetime,
      textDirection: TextDirection.ltr,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
        LengthLimitingTextInputFormatter(10),
      ],
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      decoration: InputDecoration(
        labelText: label,
        hintText: 'YYYY-MM-DD',
        isDense: true,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.event, size: 18),
        suffixIcon: IconButton(
          tooltip: context.t('empD.pickFromCalendar'),
          icon: const Icon(Icons.calendar_month, size: 18),
          onPressed: _exporting ? null : () => _pick(ctrl),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          children: [
            Icon(Icons.file_download_outlined, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              context.t('empD.exportPunchesExcel'),
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t('empD.exportHint'),
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _dateField(label: context.t('emp.dateFrom'), ctrl: _fromCtrl),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dateField(label: context.t('emp.dateTo'), ctrl: _toCtrl),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _presetChip(
                  context.t('empD.thisMonth'),
                  () => _applyPreset(DateTime(now.year, now.month, 1), now),
                ),
                _presetChip(context.t('empD.prevMonth'), () {
                  final firstThis = DateTime(now.year, now.month, 1);
                  final lastPrev = firstThis.subtract(const Duration(days: 1));
                  _applyPreset(
                    DateTime(lastPrev.year, lastPrev.month, 1),
                    lastPrev,
                  );
                }),
                _presetChip(
                  context.t('empD.last7'),
                  () =>
                      _applyPreset(now.subtract(const Duration(days: 6)), now),
                ),
                _presetChip(
                  context.t('empD.last30'),
                  () =>
                      _applyPreset(now.subtract(const Duration(days: 29)), now),
                ),
              ],
            ),
            if (_exporting && _progress != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _progress!,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.danger,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            CheckboxListTile(
              value: _syncFromBioTime,
              onChanged: _exporting
                  ? null
                  : (v) => setState(() => _syncFromBioTime = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                context.t('empD.syncBeforeExport'),
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _exporting ? null : () => Navigator.pop(context),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton.icon(
          onPressed: _exporting ? null : _export,
          icon: _exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.download, size: 18),
          label: Text(context.t('empD.export')),
        ),
      ],
    );
  }

  Widget _presetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: _exporting ? null : onTap,
      backgroundColor: AppColors.primary.withValues(alpha: 0.06),
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
      visualDensity: VisualDensity.compact,
    );
  }
}
