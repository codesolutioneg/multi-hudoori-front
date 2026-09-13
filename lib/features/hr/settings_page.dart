import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/api_config.dart';
import '../../core/router/app_router.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';
import '../../l10n/l10n_extension.dart';
import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/utils/app_log.dart';
import '../../core/utils/file_pick_web.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/alert_banner.dart';
import '../../core/widgets/async_checkbox_tile.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/searchable_select_field.dart';
import '../../core/widgets/status_tag.dart';
import 'widgets/app_settings_section.dart';
import 'widgets/branch_managers_settings_section.dart';
import 'widgets/job_ladder_settings_section.dart';
import 'widgets/company_logo_settings_section.dart';
import 'widgets/settings_accordion_section.dart';
import 'widgets/sync_progress_dialog.dart';
import 'widgets/location_punch_settings_section.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic> _config = {};
  Map<String, dynamic> _syncStatus = {};
  bool _loading = true;
  bool _busy = false;
  String? _togglingKey;
  final _serverIp = TextEditingController();
  final _serverPort = TextEditingController(text: '8090');
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _odooUrl = TextEditingController();
  final _odooDb = TextEditingController();
  final _odooLogin = TextEditingController();
  final _odooPassword = TextEditingController();
  bool _odooIntegrationEnabled = false;
  int? _odooJournalId;
  int? _odooCashDebitId;
  int? _odooCashCreditId;
  int? _odooFawryDebitId;
  int? _odooFawryCreditId;
  List<Map<String, dynamic>> _odooJournals = [];
  List<Map<String, dynamic>> _odooAccounts = [];
  List<Map<String, dynamic>> _locations = [];
  final Map<String, String> _loanNotificationEmailTexts = {};
  bool _odooCatalogLoading = false;
  List<Map<String, dynamic>> _jobTitles = [];
  final Set<String> _tipJobTitleIds = {};
  final _advancePercentCtrl = TextEditingController(text: '25');
  final _advanceMinDaysCtrl = TextEditingController(text: '15');
  Map<String, dynamic> _odooStatus = {};
  bool _advanceEnforceLimit = true;
  String _advanceEligibilitySource = 'punch_report';
  final _lateGraceCtrl = TextEditingController(text: '20');
  final _lateQuarterMaxCtrl = TextEditingController(text: '30');
  final _lateHalfMaxCtrl = TextEditingController(text: '60');
  final _lateForgivenCountCtrl = TextEditingController(text: '2');
  String _lateForgivenSelection = 'oldest';
  String _lateGracePrecedence = 'longest';
  final _latePermissionCapCtrl = TextEditingController(text: '2');
  bool _latePermissionCapEnabled = true;
  final _defaultLateCheckoutHoursCtrl = TextEditingController(text: '4');
  final _defaultEarlyCheckinHoursCtrl = TextEditingController(text: '2');
  final _payrollMonthStartDayCtrl = TextEditingController(text: '26');
  bool _payrollFixedMonthDaysEnabled = false;
  final _payrollFixedMonthDaysCtrl = TextEditingController(text: '30');
  final _absentForgivenDaysCtrl = TextEditingController(text: '4');
  int _gridWeekStartDay = 0;
  String _teamScope = 'department';
  bool _teamShowShiftTimes = true;
  bool _teamShowOffDays = true;
  bool _teamShowLeave = false;
  bool _teamShowSickLeave = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _serverIp.dispose();
    _serverPort.dispose();
    _username.dispose();
    _password.dispose();
    _odooUrl.dispose();
    _odooDb.dispose();
    _odooLogin.dispose();
    _odooPassword.dispose();
    _advancePercentCtrl.dispose();
    _advanceMinDaysCtrl.dispose();
    _lateGraceCtrl.dispose();
    _lateQuarterMaxCtrl.dispose();
    _lateHalfMaxCtrl.dispose();
    _lateForgivenCountCtrl.dispose();
    _latePermissionCapCtrl.dispose();
    _defaultLateCheckoutHoursCtrl.dispose();
    _defaultEarlyCheckinHoursCtrl.dispose();
    _payrollMonthStartDayCtrl.dispose();
    _payrollFixedMonthDaysCtrl.dispose();
    _absentForgivenDaysCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final config = await api.configGet();
      final syncStatus = await api.syncStatus();
      final locations = await api.locationsList(activeOnly: false);
      List<Map<String, dynamic>> jobTitles = [];
      try {
        jobTitles = await api.jobTitlesList(activeOnly: true, syncFromEmployees: true);
      } catch (_) {}
      Map<String, dynamic> odooStatus = {};
      var shouldLoadOdooCatalog = false;
      if (ApiConfig.showOdooUi) {
        try {
          odooStatus = await api.odooConfigGet();
        } catch (_) {
          // Older backend without /odoo/* routes — still show BioTime settings.
        }
        final odooConfig =
            (odooStatus['config'] as Map?)?.cast<String, dynamic>() ?? {};
        _odooUrl.text = odooConfig['baseUrl']?.toString() ?? '';
        _odooDb.text = odooConfig['database']?.toString() ?? '';
        _odooLogin.text = odooConfig['login']?.toString() ?? '';
        _odooIntegrationEnabled = odooConfig['integrationEnabled'] == true;
        _odooJournalId = _parseOdooId(odooConfig['journalOdooId']);
        _odooCashDebitId = _parseOdooId(odooConfig['cashDebitAccountOdooId']);
        _odooCashCreditId = _parseOdooId(odooConfig['cashCreditAccountOdooId']);
        _odooFawryDebitId = _parseOdooId(odooConfig['fawryDebitAccountOdooId']);
        _odooFawryCreditId = _parseOdooId(
          odooConfig['fawryCreditAccountOdooId'],
        );
        shouldLoadOdooCatalog = odooConfig['credentialsConfigured'] == true;
      }
      if (mounted) {
        _serverIp.text = config['serverIp']?.toString() ?? '';
        _serverPort.text = '${config['serverPort'] ?? 80}';
        _username.text = config['username']?.toString() ?? '';
        setState(() {
          _config = config;
          _syncStatus = syncStatus;
          _odooStatus = odooStatus;
          _locations = locations;
          _jobTitles = jobTitles;
          _tipJobTitleIds
            ..clear()
            ..addAll(
              ((config['tipJobTitleIds'] as List?) ?? const [])
                  .map((id) => id.toString())
                  .where((id) => id.isNotEmpty),
            );
          _loanNotificationEmailTexts
            ..clear()
            ..addEntries(
              locations.map((location) {
                final emails =
                    (location['loanNotificationEmails'] as List?)
                        ?.map((email) => email.toString())
                        .toList() ??
                    const <String>[];
                return MapEntry(location['id'].toString(), emails.join(', '));
              }),
            );
          _advancePercentCtrl.text =
              '${(config['advanceDefaultPercent'] as num?)?.toDouble() ?? 25}';
          _advanceMinDaysCtrl.text =
              '${(config['advanceMinimumWorkingDays'] as num?)?.toDouble() ?? 15}';
          _advanceEnforceLimit = config['advanceEnforceLimit'] != false;
          _advanceEligibilitySource =
              config['advanceEligibilitySource']?.toString() == 'shift_grid'
              ? 'shift_grid'
              : 'punch_report';
          _lateGraceCtrl.text =
              '${(config['lateGraceMinutes'] as num?)?.toInt() ?? 20}';
          _lateQuarterMaxCtrl.text =
              '${(config['lateQuarterDayMaxMinutes'] as num?)?.toInt() ?? 30}';
          _lateHalfMaxCtrl.text =
              '${(config['lateHalfDayMaxMinutes'] as num?)?.toInt() ?? 60}';
          _lateForgivenCountCtrl.text =
              '${(config['lateForgivenDaysCount'] as num?)?.toInt() ?? 2}';
          _lateForgivenSelection = _normalizeForgivenSelection(
            config['lateForgivenDaysSelection'],
          );
          _lateGracePrecedence = _normalizeGracePrecedence(
            config['lateGracePrecedence'],
          );
          _latePermissionCapCtrl.text =
              '${(config['latePermissionCap'] as num?)?.toInt() ?? 2}';
          _latePermissionCapEnabled =
              config['latePermissionCapEnabled'] != false;
          _defaultLateCheckoutHoursCtrl.text =
              '${(config['defaultLateCheckoutHours'] as num?)?.toDouble() ?? 4}';
          _defaultEarlyCheckinHoursCtrl.text =
              '${(config['defaultEarlyCheckinHours'] as num?)?.toDouble() ?? 2}';
          _payrollMonthStartDayCtrl.text =
              '${(config['payrollMonthStartDay'] as num?)?.toInt() ?? 26}';
          _payrollFixedMonthDaysEnabled =
              config['payrollFixedMonthDaysEnabled'] == true;
          _payrollFixedMonthDaysCtrl.text =
              '${(config['payrollFixedMonthDays'] as num?)?.toInt() ?? 30}';
          _absentForgivenDaysCtrl.text =
              '${(config['absentForgivenDaysCount'] as num?)?.toInt() ?? 4}';
          final weekStart = (config['gridWeekStartDay'] as num?)?.toInt() ?? 0;
          _gridWeekStartDay = weekStart >= 0 && weekStart <= 6 ? weekStart : 0;
          _teamScope = _normalizeTeamScope(config['employeeTeamScheduleScope']);
          _teamShowShiftTimes = config['employeeTeamShowShiftTimes'] != false;
          _teamShowOffDays = config['employeeTeamShowOffDays'] != false;
          _teamShowLeave = config['employeeTeamShowLeave'] == true;
          _teamShowSickLeave = config['employeeTeamShowSickLeave'] == true;
          _loading = false;
        });
        if (shouldLoadOdooCatalog) {
          await _loadOdooCatalog(silent: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  static int? _parseOdooId(Object? raw) {
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  static const _lateForgivenSelections = {'oldest', 'largest', 'smallest'};

  static String _normalizeForgivenSelection(Object? raw) {
    final value = raw?.toString() ?? '';
    return _lateForgivenSelections.contains(value) ? value : 'oldest';
  }

  static const _teamScopes = {'none', 'department', 'branch', 'all'};

  static String _normalizeTeamScope(Object? raw) {
    final value = raw?.toString() ?? '';
    return _teamScopes.contains(value) ? value : 'department';
  }

  Future<void> _saveTeamVisibility() async {
    setState(() => _busy = true);
    try {
      final config = await api.configUpdate({
        'employeeTeamScheduleScope': _teamScope,
        'employeeTeamShowShiftTimes': _teamShowShiftTimes,
        'employeeTeamShowOffDays': _teamShowOffDays,
        'employeeTeamShowLeave': _teamShowLeave,
        'employeeTeamShowSickLeave': _teamShowSickLeave,
      });
      if (mounted) {
        setState(() {
          _config = config;
          _busy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('settings.teamVisibilitySaved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  static const _lateGracePrecedences = {'longest', 'policy', 'shift'};

  static String _normalizeGracePrecedence(Object? raw) {
    final value = raw?.toString() ?? '';
    return _lateGracePrecedences.contains(value) ? value : 'longest';
  }

  /// Null when the field is blank or not a non-negative whole number.
  int? _positiveIntOrNull(TextEditingController ctrl) {
    final parsed = int.tryParse(ctrl.text.trim());
    if (parsed == null || parsed < 0) return null;
    return parsed;
  }

  Future<void> _saveLatePolicy() async {
    final grace = _positiveIntOrNull(_lateGraceCtrl);
    final quarterMax = _positiveIntOrNull(_lateQuarterMaxCtrl);
    final halfMax = _positiveIntOrNull(_lateHalfMaxCtrl);
    final forgiven = _positiveIntOrNull(_lateForgivenCountCtrl);
    final permissionCap = _positiveIntOrNull(_latePermissionCapCtrl);
    if (grace == null ||
        quarterMax == null ||
        halfMax == null ||
        forgiven == null ||
        permissionCap == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('settings.latePolicyInvalidNumbers'))),
      );
      return;
    }
    if (quarterMax < grace || halfMax < quarterMax) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('settings.latePolicyOutOfOrder'))),
      );
      return;
    }
    final lateCheckoutH = double.tryParse(
      _defaultLateCheckoutHoursCtrl.text.trim(),
    );
    final earlyCheckinH = double.tryParse(
      _defaultEarlyCheckinHoursCtrl.text.trim(),
    );
    if (lateCheckoutH == null ||
        earlyCheckinH == null ||
        lateCheckoutH < 0 ||
        lateCheckoutH > 12 ||
        earlyCheckinH < 0 ||
        earlyCheckinH > 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('settings.overnightWindowInvalid'))),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final config = await api.configUpdate({
        'lateGraceMinutes': grace,
        'lateQuarterDayMaxMinutes': quarterMax,
        'lateHalfDayMaxMinutes': halfMax,
        'lateForgivenDaysCount': forgiven,
        'lateForgivenDaysSelection': _lateForgivenSelection,
        'lateGracePrecedence': _lateGracePrecedence,
        'latePermissionCap': permissionCap,
        'latePermissionCapEnabled': _latePermissionCapEnabled,
        'defaultLateCheckoutHours': lateCheckoutH,
        'defaultEarlyCheckinHours': earlyCheckinH,
      });
      if (mounted) {
        setState(() {
          _config = config;
          _busy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('settings.latePolicySaved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _savePayrollPeriod() async {
    final day = int.tryParse(_payrollMonthStartDayCtrl.text.trim());
    if (day == null || day < 1 || day > 31) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('settings.payrollMonthStartDayInvalid')),
        ),
      );
      return;
    }
    final fixedDays = int.tryParse(_payrollFixedMonthDaysCtrl.text.trim());
    if (fixedDays == null || fixedDays < 1 || fixedDays > 31) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('settings.payrollFixedMonthDaysInvalid')),
        ),
      );
      return;
    }
    final forgiven = int.tryParse(_absentForgivenDaysCtrl.text.trim());
    if (forgiven == null || forgiven < 0 || forgiven > 31) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('settings.absentForgivenDaysInvalid')),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final config = await api.configUpdate({
        'payrollMonthStartDay': day,
        'gridWeekStartDay': _gridWeekStartDay,
        'payrollFixedMonthDaysEnabled': _payrollFixedMonthDaysEnabled,
        'payrollFixedMonthDays': fixedDays,
        'absentForgivenDaysCount': forgiven,
      });
      if (mounted) {
        setState(() {
          _config = config;
          _busy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('settings.payrollPeriodSaved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _saveAdvanceSettings() async {
    setState(() => _busy = true);
    try {
      final config = await api.configUpdate({
        'advanceDefaultPercent':
            double.tryParse(_advancePercentCtrl.text.trim()) ?? 25,
        'advanceMinimumWorkingDays':
            double.tryParse(_advanceMinDaysCtrl.text.trim()) ?? 15,
        'advanceEnforceLimit': _advanceEnforceLimit,
        'advanceEligibilitySource': _advanceEligibilitySource,
      });
      if (mounted) {
        setState(() {
          _config = config;
          _busy = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t('setPg.advSaved'))));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _saveTipSettings() async {
    setState(() => _busy = true);
    try {
      final config = await api.configUpdate({
        'tipJobTitleIds': _tipJobTitleIds.toList(),
      });
      if (mounted) {
        setState(() {
          _config = config;
          _busy = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t('setPg.commSaved'))));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static List<String> _parseEmailList(String raw) {
    return raw
        .split(RegExp(r'[,;\n]+'))
        .map((email) => email.trim().toLowerCase())
        .where((email) => email.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _saveLoanNotificationEmails() async {
    final parsed = <String, List<String>>{};
    for (final location in _locations) {
      final id = location['id'].toString();
      final emails = _parseEmailList(_loanNotificationEmailTexts[id] ?? '');
      final invalid = emails.where((email) => !_emailPattern.hasMatch(email));
      if (invalid.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t('setPg.badEmail', {'branch': location['name'], 'email': invalid.first}),
            ),
          ),
        );
        return;
      }
      parsed[id] = emails;
    }

    setState(() => _busy = true);
    try {
      for (final location in _locations) {
        final id = location['id'].toString();
        await api.locationUpdate(id, {
          'loanNotificationEmails': parsed[id] ?? const <String>[],
        });
      }
      if (!mounted) return;
      setState(() {
        for (final location in _locations) {
          final id = location['id'].toString();
          location['loanNotificationEmails'] = parsed[id] ?? const <String>[];
        }
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('setPg.emailsSaved'))),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _saveServer() async {
    setState(() => _busy = true);
    try {
      final config = await api.configUpdate({
        'serverIp': _serverIp.text.trim(),
        'serverPort': int.tryParse(_serverPort.text.trim()) ?? 80,
        'username': _username.text.trim(),
        if (_password.text.isNotEmpty) 'password': _password.text,
      });
      if (mounted)
        setState(() {
          _config = config;
          _busy = false;
        });
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  bool _configBool(String key) {
    if (key == 'scheduledAutoSyncEnabled') return _config[key] != false;
    return _config[key] == true;
  }

  Future<void> _toggle(String key, bool value) async {
    if (_togglingKey != null) {
      appLog(
        'SettingsToggle',
        'ignored — already toggling $_togglingKey',
        'requested $key=$value',
      );
      return;
    }

    final previous = _config[key];
    final previousBool = _configBool(key);
    appLog('SettingsToggle', 'start', {
      'key': key,
      'requested': value,
      'previousRaw': previous,
      'previousBool': previousBool,
    });

    setState(() {
      _togglingKey = key;
      _config = {..._config, key: value};
    });
    appLog('SettingsToggle', 'optimistic', {
      'key': key,
      'localBool': _configBool(key),
    });

    try {
      final payload = {key: value};
      appLog('SettingsToggle', 'api.configUpdate request', payload);
      final config = await api.configUpdate(payload);
      final serverBool = key == 'scheduledAutoSyncEnabled'
          ? config[key] != false
          : config[key] == true;
      appLog('SettingsToggle', 'api.configUpdate response', {
        'key': key,
        'raw': config[key],
        'parsedBool': serverBool,
        'matchesRequest': serverBool == value,
      });

      if (mounted) {
        setState(() {
          _config = config;
          _togglingKey = null;
        });
        appLog('SettingsToggle', 'done', {
          'key': key,
          'uiBool': _configBool(key),
        });
      }
    } catch (e, st) {
      appLog('SettingsToggle', 'error — reverting', {
        'key': key,
        'error': e,
        'stack': st,
      });
      if (mounted) {
        setState(() {
          _config = {..._config, key: previous};
          _togglingKey = null;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Widget _configSwitchTile({
    required String key,
    required String title,
    String? subtitle,
  }) {
    return AsyncCheckboxTile(
      title: title,
      subtitle: subtitle,
      value: _configBool(key),
      loading: _togglingKey == key,
      disabled: _togglingKey != null && _togglingKey != key,
      onChanged: (v) => _toggle(key, v),
    );
  }

  bool _isSyncPath(String path) => path.contains('/sync');

  Future<void> _pollSyncJob(
    ValueNotifier<SyncDialogState> notifier, {
    String? jobId,
  }) async {
    for (var i = 0; i < 180; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      try {
        final status = await api.syncStatus();
        final jobs = (status['recentJobs'] as List?) ?? [];
        final counts =
            (status['counts'] as Map?)?.cast<String, dynamic>() ?? {};
        Map<String, dynamic>? job;
        for (final j in jobs) {
          if (j is! Map) continue;
          final m = Map<String, dynamic>.from(j);
          if (jobId == null || m['id']?.toString() == jobId) {
            job = m;
            break;
          }
        }
        final jobStatus = job?['status']?.toString() ?? 'running';
        notifier.value = notifier.value.copyWith(
          message: job?['message']?.toString() ?? context.t('setPg.syncing'),
          progress:
              (job?['progress'] as num?)?.toInt() ?? notifier.value.progress,
          employees: (counts['employees'] as num?)?.toInt(),
          departments: (counts['departments'] as num?)?.toInt(),
          devices: (counts['devices'] as num?)?.toInt(),
          transactions: (counts['transactions'] as num?)?.toInt(),
          status: jobStatus,
        );
        if (jobStatus == 'done' ||
            jobStatus == 'failed' ||
            jobStatus == 'cancelled') {
          notifier.value = notifier.value.copyWith(
            done: jobStatus == 'done',
            failed: jobStatus != 'done',
            title: jobStatus == 'done' ? context.t('setPg.syncDone') : context.t('setPg.syncFailed'),
            message: job?['message']?.toString() ?? jobStatus,
            progress: 100,
          );
          return;
        }
      } catch (_) {}
    }
    notifier.value = notifier.value.copyWith(
      failed: true,
      title: context.t('setPg.timedOut'),
      message: context.t('setPg.stillRunning'),
    );
  }

  Future<void> _saveOdoo() async {
    setState(() => _busy = true);
    try {
      final status = await api.odooConfigUpdate({
        'baseUrl': _odooUrl.text.trim(),
        'database': _odooDb.text.trim(),
        'login': _odooLogin.text.trim(),
        if (_odooPassword.text.isNotEmpty) 'password': _odooPassword.text,
        'integrationEnabled': _odooIntegrationEnabled,
        'journalOdooId': _odooJournalId,
        'cashDebitAccountOdooId': _odooCashDebitId,
        'cashCreditAccountOdooId': _odooCashCreditId,
        'fawryDebitAccountOdooId': _odooFawryDebitId,
        'fawryCreditAccountOdooId': _odooFawryCreditId,
      });
      if (mounted) {
        setState(() {
          _odooStatus = status;
          _odooPassword.clear();
          _busy = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t('setPg.odooSaved'))));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _loadOdooCatalog({bool silent = false}) async {
    setState(() {
      _busy = true;
      _odooCatalogLoading = true;
    });
    try {
      final journals = await api.odooJournalsList();
      final accounts = await api.odooAccountsList();
      if (!mounted) return;
      setState(() {
        _odooJournals = journals;
        _odooAccounts = accounts;
        _busy = false;
        _odooCatalogLoading = false;
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t('setPg.odooFetched', {'journals': journals.length, 'accounts': accounts.length}),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _odooCatalogLoading = false;
      });
      if (!silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Widget _odooIdDropdown({
    required String label,
    required int? value,
    required List<Map<String, dynamic>> rows,
    required ValueChanged<int?> onChanged,
  }) {
    final hasCurrent =
        value != null && rows.any((row) => _parseOdooId(row['id']) == value);
    return SearchableSelectField<int>(
      label: label,
      value: value,
      hint: context.t('setPg.searchCodeName'),
      allLabel: context.t('setPg.unset'),
      allowNull: true,
      options: [
        if (value != null && !hasCurrent)
          SearchableSelectOption<int>(
            value: value,
            label: context.t('setPg.odooSavedId', {'id': value}),
          ),
        ...rows.where((row) => _parseOdooId(row['id']) != null).map((row) {
          final name = row['name']?.toString() ?? '#${row['id']}';
          final code = row['code']?.toString().trim() ?? '';
          final label = code.isNotEmpty && !name.startsWith(code)
              ? '$code — $name'
              : name;
          return SearchableSelectOption<int>(
            value: _parseOdooId(row['id'])!,
            label: label,
          );
        }),
      ],
      onChanged: onChanged,
    );
  }

  Future<void> _testOdoo() async {
    setState(() => _busy = true);
    try {
      final status = await api.odooTestConnection();
      if (mounted) {
        setState(() {
          _odooStatus = status;
          _busy = false;
        });
        final ok = (status['config'] as Map?)?['isConnected'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? context.t('setPg.odooConnected')
                  : (status['message']?.toString() ?? context.t('setPg.connFailed')),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _uploadOdooLoanReview() async {
    final file = await pickExcelFile();
    if (file == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('setPg.uploadSheetTitle')),
        content: Text(
          context.t('setPg.uploadSheetBody', {'file': file.filename}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.t('setPg.uploadAndPost')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await api.odooLoanReviewUpload(
        fileBase64: file.base64,
        filename: file.filename,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ??
                context.t('setPg.uploadPosted'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _pushOdoo() async {
    final notifier = ValueNotifier(
      SyncDialogState(title: context.t('setPg.uploadToOdoo'), message: context.t('setPg.uploading')),
    );
    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SyncProgressDialog(stateListenable: notifier),
      );
    }

    setState(() => _busy = true);
    try {
      final result = await api.odooPushAll(
        onProgress: (msg, {int? progress}) {
          notifier.value = notifier.value.copyWith(message: msg);
        },
      );
      notifier.value = notifier.value.copyWith(
        done: true,
        title: context.t('setPg.uploaded'),
        message: result['message']?.toString() ?? context.t('setPg.completed'),
        progress: 100,
      );
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        setState(() => _busy = false);
        await _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? context.t('setPg.uploadedToOdoo')),
          ),
        );
      }
    } catch (e) {
      notifier.value = notifier.value.copyWith(
        failed: true,
        title: context.t('setPg.uploadFailed'),
        message: e.toString(),
      );
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _syncPunchesFull() async {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 90));
    setState(() => _busy = true);
    try {
      final result = await api.syncTransactions(
        dateFrom: from.toIso8601String().slice(0, 10),
        dateTo: now.toIso8601String().slice(0, 10),
      );
      if (mounted) {
        setState(() => _busy = false);
        await _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ?? context.t('setPg.punchesSynced'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _run(String path, String label) async {
    final isSync = _isSyncPath(path);
    final notifier = ValueNotifier(const SyncDialogState());
    if (isSync && mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SyncProgressDialog(stateListenable: notifier),
      );
    }

    setState(() => _busy = true);
    try {
      final result = await api.configAction(path);
      if (!mounted) return;

      if (result['config'] is Map) {
        _config = Map<String, dynamic>.from(result['config'] as Map);
      }

      if (isSync && result['queued'] == true) {
        await _pollSyncJob(notifier, jobId: result['jobId']?.toString());
        await Future.delayed(const Duration(milliseconds: 600));
      } else if (isSync) {
        notifier.value = notifier.value.copyWith(
          done: true,
          title: context.t('setPg.syncDone'),
          message: result['message']?.toString() ?? 'Done: $label',
          progress: 100,
        );
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (isSync && mounted) Navigator.of(context, rootNavigator: true).pop();

      setState(() => _busy = false);
      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['queued'] == true
                  ? (notifier.value.message ?? context.t('setPg.syncing'))
                  : (result['message']?.toString() ?? 'Done: $label'),
            ),
          ),
        );
      }
    } catch (e) {
      if (isSync) {
        notifier.value = notifier.value.copyWith(
          failed: true,
          title: context.t('setPg.syncFailed'),
          message: e.toString(),
        );
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Widget _buildOdooContent() {
    final odooConfig =
        (_odooStatus['config'] as Map?)?.cast<String, dynamic>() ?? {};
    final odooTotals =
        (_odooStatus['totals'] as Map?)?.cast<String, dynamic>() ?? {};
    final odooSynced =
        (_odooStatus['synced'] as Map?)?.cast<String, dynamic>() ?? {};
    final odooConnected = odooConfig['isConnected'] == true;
    final odooCredentialsConfigured =
        odooConfig['credentialsConfigured'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.t('setPg.enableOdoo')),
          subtitle: Text(context.t('setPg.enableOdooHint')),
          value: _odooIntegrationEnabled,
          onChanged: (v) => setState(() => _odooIntegrationEnabled = v),
        ),
        Row(
          children: [
            Icon(
              odooConnected ? Icons.cloud_done : Icons.cloud_off,
              color: odooConnected ? AppColors.success : AppColors.danger,
            ),
            const SizedBox(width: 8),
            Text(
              odooConnected ? context.t('setPg.odooConnected') : context.t('setPg.odooDisconnected'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        if (odooConfig['lastPushAt'] != null) ...[
          const SizedBox(height: 8),
          Text(
            context.t('setPg.lastPush', {'at': odooConfig['lastPushAt']}),
            style: const TextStyle(fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _odooUrl,
          decoration: const InputDecoration(labelText: 'Odoo URL (https://…)'),
          keyboardType: TextInputType.url,
        ),
        TextField(
          controller: _odooDb,
          decoration: const InputDecoration(labelText: 'Database'),
        ),
        TextField(
          controller: _odooLogin,
          decoration: const InputDecoration(labelText: 'Login'),
        ),
        TextField(
          controller: _odooPassword,
          decoration: InputDecoration(
            labelText: 'Password',
            helperText: odooCredentialsConfigured
                ? context.t('setPg.passwordSaved')
                : context.t('setPg.enterOdooPassword'),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _busy ? null : _saveOdoo,
          child: Text(context.t('setPg.saveOdoo')),
        ),
        if (!odooCredentialsConfigured)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              context.t('setPg.odooIncomplete'),
              style: TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: (_busy || !odooCredentialsConfigured)
                  ? null
                  : _testOdoo,
              icon: const Icon(Icons.link, size: 18),
              label: Text(context.t('setPg.testConnection')),
            ),
            OutlinedButton.icon(
              onPressed: (_busy || !odooCredentialsConfigured)
                  ? null
                  : _loadOdooCatalog,
              icon: _odooCatalogLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.account_balance_outlined, size: 18),
              label: Text(context.t('setPg.fetchJournals')),
            ),
            FilledButton.icon(
              onPressed: (_busy || !odooCredentialsConfigured)
                  ? null
                  : _pushOdoo,
              icon: const Icon(Icons.upload, size: 18),
              label: Text(context.t('setPg.pushToOdoo')),
            ),
            FilledButton.tonalIcon(
              onPressed:
                  (_busy ||
                      !odooCredentialsConfigured ||
                      !_odooIntegrationEnabled ||
                      _odooJournalId == null ||
                      _odooCashDebitId == null ||
                      _odooCashCreditId == null)
                  ? null
                  : _uploadOdooLoanReview,
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text(context.t('setPg.uploadAdvSheet')),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            context.t('setPg.sheetFormat'),
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.t('setPg.accountsMoved'),
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _odooIdDropdown(
          label: context.t('setPg.journal'),
          value: _odooJournalId,
          rows: _odooJournals,
          onChanged: (v) => setState(() => _odooJournalId = v),
        ),
        const SizedBox(height: 8),
        _odooIdDropdown(
          label: context.t('setPg.cashDebit'),
          value: _odooCashDebitId,
          rows: _odooAccounts,
          onChanged: (v) => setState(() => _odooCashDebitId = v),
        ),
        const SizedBox(height: 8),
        _odooIdDropdown(
          label: context.t('setPg.cashCredit'),
          value: _odooCashCreditId,
          rows: _odooAccounts,
          onChanged: (v) => setState(() => _odooCashCreditId = v),
        ),
        const SizedBox(height: 8),
        _odooIdDropdown(
          label: context.t('setPg.fawryDebit'),
          value: _odooFawryDebitId,
          rows: _odooAccounts,
          onChanged: (v) => setState(() => _odooFawryDebitId = v),
        ),
        const SizedBox(height: 8),
        _odooIdDropdown(
          label: context.t('setPg.fawryCredit'),
          value: _odooFawryCreditId,
          rows: _odooAccounts,
          onChanged: (v) => setState(() => _odooFawryCreditId = v),
        ),
        const SizedBox(height: 8),
        Text(
          context.t('setPg.localTotals', {'emp': odooTotals['employees'] ?? 0, 'ded': odooTotals['deductions'] ?? 0, 'adv': (odooTotals['advancesShort'] as num? ?? 0) + (odooTotals['advancesLong'] as num? ?? 0), 'pay': odooTotals['payrolls'] ?? 0}),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        Text(
          context.t('setPg.alreadyPushed', {'ded': odooSynced['deduction'] ?? 0, 'pay': odooSynced['payroll'] ?? 0}),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final connected = _config['isConnected'] == true;
    final credentialsConfigured = _config['credentialsConfigured'] == true;
    final counts =
        (_syncStatus['counts'] as Map?)?.cast<String, dynamic>() ?? {};
    final recentJobs = (_syncStatus['recentJobs'] as List?) ?? [];
    final odooConfig =
        (_odooStatus['config'] as Map?)?.cast<String, dynamic>() ?? {};
    final odooConnected = odooConfig['isConnected'] == true;
    final employeeCount = counts['employees'] ?? _config['employeeCount'] ?? 0;

    return AppPageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.t('settings.biotimeTitle'),
            subtitle: context.t('settings.biotimeSubtitle', {
              'name': _config['name'] ?? '',
              'version': ApiConfig.appVersion,
            }),
            icon: Icons.settings_outlined,
            showRefresh: !_busy,
            onRefresh: _load,
          ),
          const SizedBox(height: 20),
          SettingsAccordionSection(
            title: context.t('setPg.connStatus'),
            subtitle: connected
                ? context.t('setPg.bioConnected')
                : context.t('setPg.bioDisconnected'),
            icon: connected
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
            badge: connected ? context.t('setPg.connected') : context.t('setPg.disconnected'),
            badgeType: connected ? StatusTagType.success : StatusTagType.danger,
            initiallyExpanded: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      connected ? Icons.check_circle : Icons.error_outline,
                      color: connected ? AppColors.success : AppColors.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        connected ? context.t('setPg.bioConnected') : context.t('setPg.disconnected'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                if ((_config['connectionMessage']?.toString() ?? '')
                    .isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _config['connectionMessage']?.toString() ?? '',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
                if (!credentialsConfigured) ...[
                  const SizedBox(height: 12),
                  AlertBanner(
                    tone: AlertBannerTone.warning,
                    message:
                        context.t('setPg.completeBio'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          SettingsAccordionSection(
            title: context.t('setPg.companyLogo'),
            subtitle: context.t('setPg.companyLogoHint'),
            icon: Icons.image_outlined,
            child: CompanyLogoSettingsSection(
              hasLogo: _config['hasCompanyLogo'] == true,
              onChanged: () async {
                final config = await api.configGet();
                if (mounted) setState(() => _config = config);
              },
            ),
          ),
          const SizedBox(height: 10),
          SettingsAccordionSection(
            title: context.t('set.title'),
            subtitle: context.t('setPg.settingsHint'),
            icon: Icons.tune_outlined,
            child: const AppSettingsSection(embedded: true),
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 10),
          SettingsAccordionSection(
            title: context.t('setPg.branchManagers'),
            subtitle: context.t('setPg.branchManagersHint'),
            icon: Icons.badge_outlined,
            child: BranchManagersSettingsSection(),
          ),
          const SizedBox(height: 10),
          SettingsAccordionSection(
            title: context.t('setPg.jobLadder'),
            subtitle: context.t('setPg.jobLadderHint'),
            icon: Icons.account_tree_outlined,
            child: JobLadderSettingsSection(),
          ),
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, auth) {
              if (!auth.canViewAudit) return const SizedBox.shrink();
              return Column(
                children: [
                  const SizedBox(height: 10),
                  SettingsAccordionSection(
                    title: context.t('setPg.auditLog'),
                    subtitle: context.t('setPg.auditLogHint'),
                    icon: Icons.history_edu_outlined,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FilledButton.icon(
                        onPressed: () => context.go(AppRoutes.hrAudit),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text(context.t('setPg.openAuditLog')),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          SettingsAccordionSection(
            title: context.t('setPg.bioServer'),
            subtitle: context.t('setPg.bioServerHint'),
            icon: Icons.dns_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'BioTime API credentials (for sync only — not app login)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Node server connects directly to ZKTeco BioTime. App users are created in Admin Dashboard.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _serverIp,
                  decoration: const InputDecoration(labelText: 'Server IP'),
                ),
                TextField(
                  controller: _serverPort,
                  decoration: const InputDecoration(labelText: 'Port'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: _username,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                TextField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _saveServer,
                  child: const Text('Save server settings'),
                ),
              ],
            ),
          ),
          if (ApiConfig.showOdooUi) ...[
            const SizedBox(height: 10),
            SettingsAccordionSection(
              title: 'Odoo Integration',
              subtitle: context.t('setPg.odooHint'),
              icon: Icons.cloud_upload_outlined,
              badge: odooConnected ? context.t('setPg.connected') : null,
              badgeType: odooConnected ? StatusTagType.success : null,
              child: _buildOdooContent(),
            ),
          ],
          const SizedBox(height: 10),
          SettingsAccordionSection(
            title: context.t('setPg.advSettings'),
            subtitle: context.t('setPg.advSettingsHint'),
            icon: Icons.account_balance_wallet_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: context.t('setPg.advPercent'),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  controller: _advancePercentCtrl,
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: context.t('setPg.minWorkDays'),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  controller: _advanceMinDaysCtrl,
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _advanceEligibilitySource,
                  decoration: InputDecoration(
                    labelText: context.t('setPg.workDaysSource'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'punch_report',
                      child: Text(context.t('setPg.punchReportFirst')),
                    ),
                    DropdownMenuItem(
                      value: 'shift_grid',
                      child: Text(context.t('setPg.shiftGridFirst')),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null)
                      setState(() => _advanceEligibilitySource = v);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('setPg.enableCapOnCreate')),
                  value: _advanceEnforceLimit,
                  onChanged: (v) => setState(() => _advanceEnforceLimit = v),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy ? null : _saveAdvanceSettings,
                  child: Text(context.t('setPg.saveAdv')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SettingsAccordionSection(
            title: context.t('setPg.commSettings'),
            subtitle: context.t('setPg.commSettingsHint'),
            icon: Icons.card_giftcard_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.t('setPg.commHint'),
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                if (_jobTitles.isEmpty)
                  Text(context.t('setPg.noJobTitles'))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final job in _jobTitles)
                        FilterChip(
                          label: Text(job['name']?.toString() ?? ''),
                          selected: _tipJobTitleIds.contains(
                            job['id']?.toString() ?? '',
                          ),
                          onSelected: (selected) {
                            final id = job['id']?.toString() ?? '';
                            if (id.isEmpty) return;
                            setState(() {
                              if (selected) {
                                _tipJobTitleIds.add(id);
                              } else {
                                _tipJobTitleIds.remove(id);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _saveTipSettings,
                  child: Text(context.t('setPg.saveComm')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          LocationPunchSettingsSection(
            locations: _locations,
            busy: _busy,
            onChanged: _load,
          ),
          const SizedBox(height: 10),
          SettingsAccordionSection(
            title: context.t('setPg.advEmails'),
            subtitle: context.t('setPg.advEmailsHint'),
            icon: Icons.mark_email_read_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.t('setPg.advEmailsNote'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                if (_locations.isEmpty)
                  Text(context.t('setPg.noBranches'))
                else
                  ..._locations.map((location) {
                    final id = location['id'].toString();
                    final active = location['active'] != false;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        key: ValueKey('loan-notification-emails-$id'),
                        initialValue: _loanNotificationEmailTexts[id] ?? '',
                        onChanged: (value) =>
                            _loanNotificationEmailTexts[id] = value,
                        keyboardType: TextInputType.emailAddress,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText:
                              '${location['name']}${active ? '' : ' (غير نشط)'}',
                          hintText: 'finance@example.com, manager@example.com',
                          prefixIcon: const Icon(Icons.alternate_email),
                        ),
                      ),
                    );
                  }),
                FilledButton.icon(
                  onPressed: _busy || _locations.isEmpty
                      ? null
                      : _saveLoanNotificationEmails,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(context.t('setPg.saveBranchEmails')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SettingsAccordionSection(
            title: context.t('settings.teamVisibilityTitle'),
            subtitle: context.t('settings.teamVisibilitySubtitle'),
            icon: Icons.visibility_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: _teamScope,
                  decoration: InputDecoration(
                    labelText: context.t('settings.teamScope'),
                    helperText: context.t('settings.teamScopeHint'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'none',
                      child: Text(context.t('settings.teamScopeNone')),
                    ),
                    DropdownMenuItem(
                      value: 'department',
                      child: Text(context.t('settings.teamScopeDepartment')),
                    ),
                    DropdownMenuItem(
                      value: 'branch',
                      child: Text(context.t('settings.teamScopeBranch')),
                    ),
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(context.t('settings.teamScopeAll')),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _teamScope = v);
                  },
                ),
                if (_teamScope != 'none') ...[
                  const Divider(height: 24),
                  Text(
                    context.t('settings.teamDetailTitle'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(context.t('settings.teamShowShiftTimes')),
                    value: _teamShowShiftTimes,
                    onChanged: (v) => setState(() => _teamShowShiftTimes = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(context.t('settings.teamShowOffDays')),
                    subtitle: Text(
                      context.t('settings.teamShowOffDaysHint'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    value: _teamShowOffDays,
                    onChanged: (v) => setState(() => _teamShowOffDays = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(context.t('settings.teamShowLeave')),
                    value: _teamShowLeave,
                    onChanged: (v) => setState(() => _teamShowLeave = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(context.t('settings.teamShowSickLeave')),
                    subtitle: Text(
                      context.t('settings.teamShowSickLeaveHint'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    value: _teamShowSickLeave,
                    onChanged: (v) => setState(() => _teamShowSickLeave = v),
                  ),
                ],
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy ? null : _saveTeamVisibility,
                  child: Text(context.t('settings.teamVisibilitySave')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SettingsAccordionSection(
            title: context.t('settings.payrollPeriodTitle'),
            subtitle: context.t('settings.payrollPeriodSubtitle'),
            icon: Icons.date_range_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: context.t('settings.payrollMonthStartDay'),
                    helperText: context.t('settings.payrollMonthStartDayHint'),
                  ),
                  keyboardType: TextInputType.number,
                  controller: _payrollMonthStartDayCtrl,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('settings.payrollFixedMonthDaysEnabled')),
                  subtitle: Text(
                    context.t('settings.payrollFixedMonthDaysEnabledHint'),
                  ),
                  value: _payrollFixedMonthDaysEnabled,
                  onChanged: (v) =>
                      setState(() => _payrollFixedMonthDaysEnabled = v),
                ),
                TextField(
                  enabled: _payrollFixedMonthDaysEnabled,
                  decoration: InputDecoration(
                    labelText: context.t('settings.payrollFixedMonthDays'),
                    helperText: context.t('settings.payrollFixedMonthDaysHint'),
                  ),
                  keyboardType: TextInputType.number,
                  controller: _payrollFixedMonthDaysCtrl,
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: context.t('settings.absentForgivenDays'),
                    helperText: context.t('settings.absentForgivenDaysHint'),
                  ),
                  keyboardType: TextInputType.number,
                  controller: _absentForgivenDaysCtrl,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _gridWeekStartDay,
                  decoration: InputDecoration(
                    labelText: context.t('settings.gridWeekStartDay'),
                    helperText: context.t('settings.gridWeekStartDayHint'),
                  ),
                  items: [
                    for (var day = 0; day < 7; day++)
                      DropdownMenuItem(
                        value: day,
                        child: Text(context.t('settings.weekday.$day')),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _gridWeekStartDay = v);
                  },
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy ? null : _savePayrollPeriod,
                  child: Text(context.t('settings.payrollPeriodSave')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SettingsAccordionSection(
            title: context.t('settings.latePolicyTitle'),
            subtitle: context.t('settings.latePolicySubtitle'),
            icon: Icons.timer_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.t('settings.latePolicyNote'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: context.t('settings.lateGrace'),
                    helperText: context.t('settings.lateGraceHelp'),
                  ),
                  keyboardType: TextInputType.number,
                  controller: _lateGraceCtrl,
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: context.t('settings.defaultLateCheckoutHours'),
                    helperText: context.t(
                      'settings.defaultLateCheckoutHoursHelp',
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  controller: _defaultLateCheckoutHoursCtrl,
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: context.t('settings.defaultEarlyCheckinHours'),
                    helperText: context.t(
                      'settings.defaultEarlyCheckinHoursHelp',
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  controller: _defaultEarlyCheckinHoursCtrl,
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: context.t('settings.lateQuarterMax'),
                    helperText: context.t('settings.lateQuarterMaxHelp'),
                  ),
                  keyboardType: TextInputType.number,
                  controller: _lateQuarterMaxCtrl,
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: context.t('settings.lateHalfMax'),
                    helperText: context.t('settings.lateHalfMaxHelp'),
                  ),
                  keyboardType: TextInputType.number,
                  controller: _lateHalfMaxCtrl,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _lateGracePrecedence,
                  decoration: InputDecoration(
                    labelText: context.t('settings.lateGracePrecedence'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'longest',
                      child: Text(
                        context.t('settings.lateGracePrecedenceLongest'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'policy',
                      child: Text(
                        context.t('settings.lateGracePrecedencePolicy'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'shift',
                      child: Text(
                        context.t('settings.lateGracePrecedenceShift'),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _lateGracePrecedence = v);
                  },
                ),
                const Divider(height: 24),
                TextField(
                  decoration: InputDecoration(
                    labelText: context.t('settings.lateForgivenCount'),
                    helperText: context.t('settings.lateForgivenCountHelp'),
                  ),
                  keyboardType: TextInputType.number,
                  controller: _lateForgivenCountCtrl,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _lateForgivenSelection,
                  decoration: InputDecoration(
                    labelText: context.t('settings.lateForgivenSelection'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'oldest',
                      child: Text(context.t('settings.lateForgivenOldest')),
                    ),
                    DropdownMenuItem(
                      value: 'largest',
                      child: Text(context.t('settings.lateForgivenLargest')),
                    ),
                    DropdownMenuItem(
                      value: 'smallest',
                      child: Text(context.t('settings.lateForgivenSmallest')),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _lateForgivenSelection = v);
                  },
                ),
                const Divider(height: 24),
                TextField(
                  decoration: InputDecoration(
                    labelText: context.t('settings.latePermissionCap'),
                  ),
                  keyboardType: TextInputType.number,
                  controller: _latePermissionCapCtrl,
                  enabled: _latePermissionCapEnabled,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.t('settings.latePermissionCapEnabled')),
                  value: _latePermissionCapEnabled,
                  onChanged: (v) =>
                      setState(() => _latePermissionCapEnabled = v),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy ? null : _saveLatePolicy,
                  child: Text(context.t('settings.latePolicySave')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SettingsAccordionSection(
            title: context.t('setPg.syncGuide'),
            subtitle: context.t('setPg.syncGuideHint'),
            icon: Icons.menu_book_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SellixCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('setPg.fromBio'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.t('setPg.fromBioList'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.t('setPg.localOnly'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.t('setPg.localOnlyList'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SellixCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('setPg.afterSync'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        context.t('setPg.afterSyncList'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SettingsAccordionSection(
            title: context.t('setPg.dbStatus'),
            subtitle:
                context.t('setPg.dbSubtitle', {'emp': employeeCount, 'tx': counts['transactions'] ?? _config['transactionCount'] ?? 0}),
            icon: Icons.storage_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('setPg.dbEmpTx', {'emp': employeeCount, 'tx': counts['transactions'] ?? _config['transactionCount'] ?? 0}),
                ),
                Text(
                  context.t('setPg.dbDepDev', {'dep': counts['departments'] ?? _config['totalDepartmentsSynced'] ?? 0, 'dev': counts['devices'] ?? _config['totalDevicesSynced'] ?? 0}),
                ),
                const SizedBox(height: 8),
                Text(
                  context.t('setPg.lastJobNote'),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (_config['lastTransactionSync'] != null &&
                    _config['lastTransactionSync'] != false) ...[
                  const SizedBox(height: 6),
                  Text(
                    context.t('setPg.lastPunchSync', {'at': _config['lastTransactionSync']}),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                if (recentJobs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.t('setPg.lastJob', {'message': recentJobs.first['message'], 'status': recentJobs.first['status']}),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          SettingsAccordionSection(
            title: context.t('setPg.autoSync'),
            subtitle: context.t('setPg.autoSyncHint'),
            icon: Icons.schedule_outlined,
            child: Column(
              children: [
                _configSwitchTile(
                  key: 'scheduledAutoSyncEnabled',
                  title: context.t('setPg.enableAutoSync'),
                  subtitle:
                      context.t('setPg.autoSyncNote'),
                ),
                const Divider(height: 1),
                _configSwitchTile(
                  key: 'autoPushToBiotime',
                  title: 'Push to BioTime on employee edit',
                  subtitle:
                      context.t('setPg.onSaveNote'),
                ),
                const Divider(height: 1),
                _configSwitchTile(
                  key: 'autoSyncEmployees',
                  title: 'Sync employees',
                ),
                const Divider(height: 1),
                _configSwitchTile(
                  key: 'autoSyncDepartments',
                  title: 'Sync departments',
                ),
                const Divider(height: 1),
                _configSwitchTile(
                  key: 'autoSyncTransactions',
                  title: 'Sync punches',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SettingsAccordionSection(
            title: context.t('setPg.syncActions'),
            subtitle:
                context.t('setPg.syncActionsHint'),
            icon: Icons.sync_outlined,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: (_busy || !credentialsConfigured)
                      ? null
                      : () =>
                            _run('/api/biotime/config/test-connection', 'test'),
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('Test connection'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run('/api/biotime/config/sync-all', 'sync all'),
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Sync all'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () =>
                            _run('/api/biotime/config/sync-pull', 'pull only'),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Pull from BioTime (pull only)'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          '/api/biotime/config/sync-transactions',
                          'punches',
                        ),
                  icon: const Icon(Icons.fingerprint, size: 18),
                  label: Text(context.t('setPg.syncNewPunches')),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _syncPunchesFull,
                  icon: const Icon(Icons.history, size: 18),
                  label: Text(context.t('setPg.punches90')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

extension on String {
  String slice(int start, int end) => substring(start, end.clamp(0, length));
}
