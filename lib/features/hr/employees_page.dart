import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/layout/keyboard_stable_layout.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/utils/department_name.dart';
import '../../core/utils/egyptian_national_id.dart';
import '../../core/utils/money_format.dart';
import '../../core/utils/entity_id.dart';
import '../../l10n/l10n_extension.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/file_pick.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/searchable_select_field.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/skeleton_box.dart';
import '../../core/widgets/status_tag.dart';
import '../../data/api/biotime_api_client.dart';
import '../auth/auth_cubit.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  static const _pageSize = 30;
  static const _loadMoreSkeletonCount = 3;

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'employees-search');
  final _scrollCtrl = ScrollController();
  Timer? _searchDebounce;

  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _exportingExcel = false;
  bool _exportingTemplate = false;
  bool _importingExcel = false;
  String? _departmentFilter;
  String? _locationFilter;
  bool? _biotimeFilter;
  bool _showArchived = false;
  int _total = 0;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadDepartments();
    _loadLocations();
    _reload(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _showMessage(String message, {String? title}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text(title ?? context.t('common.notice')),
        content: Text(message, style: const TextStyle(height: 1.45)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('common.ok')),
          ),
        ],
      ),
    );
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _loadingMore || _loading) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 280) {
      _loadMore();
    }
  }

  Future<void> _loadDepartments() async {
    try {
      final depts = await api.departmentsList();
      if (mounted) setState(() => _departments = depts);
    } catch (_) {}
  }

  Future<void> _loadLocations() async {
    try {
      final list = await api.locationsList();
      if (!mounted) return;
      final auth = context.read<AuthCubit>().state;
      final scoped = auth.scopedLocationId;
      setState(() {
        _locations = list;
        if (scoped != null && scoped.isNotEmpty) {
          _locationFilter = scoped;
        }
      });
    } catch (_) {}
  }

  Future<void> _reload({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _offset = 0;
        _items.clear();
      });
    }
    try {
      final auth = context.read<AuthCubit>().state;
      final locationId = auth.scopedLocationId ?? _locationFilter;
      final page = await api.employeesList(
        search: _searchCtrl.text.trim(),
        departmentId: _departmentFilter,
        locationId: locationId,
        biotimeSynced: _biotimeFilter,
        active: !_showArchived,
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _total = page.total;
        _offset = page.items.length;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        await _showMessage(e.toString(), title: context.t('common.error'));
      }
    }
  }

  Future<void> _loadMore() async {
    if (_offset >= _total || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final auth = context.read<AuthCubit>().state;
      final locationId = auth.scopedLocationId ?? _locationFilter;
      final page = await api.employeesList(
        search: _searchCtrl.text.trim(),
        departmentId: _departmentFilter,
        locationId: locationId,
        biotimeSynced: _biotimeFilter,
        active: !_showArchived,
        limit: _pageSize,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _offset += page.items.length;
        _total = page.total;
        _loadingMore = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMore = false);
        await _showMessage(e.toString(), title: context.t('common.error'));
      }
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _reload(reset: true),
    );
  }

  Future<void> _openCreateForm() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EmployeeFormDialog(departments: _departments),
    );
    if (saved == true && mounted) _reload(reset: true);
  }

  Future<void> _exportExcel() async {
    if (_exportingExcel) return;
    setState(() => _exportingExcel = true);
    try {
      final r = await api.employeesExportXlsx();
      final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
      final filename = r['filename']?.toString() ?? 'employees.xlsx';
      if (base64.isEmpty) throw Exception(context.t('set.emptyFile'));
      downloadBase64File(
        base64,
        filename,
        r['mimeType']?.toString() ??
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (!mounted) return;
      await _showMessage(
        context.t('emp.downloaded', {'file': filename}),
        title: context.t('common.done'),
      );
    } catch (e) {
      if (!mounted) return;
      await _showMessage(e.toString(), title: context.t('common.error'));
    } finally {
      if (mounted) setState(() => _exportingExcel = false);
    }
  }

  Future<void> _exportTemplate() async {
    if (_exportingTemplate) return;
    setState(() => _exportingTemplate = true);
    try {
      final r = await api.employeesExportXlsx(templateOnly: true);
      final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
      final filename =
          r['filename']?.toString() ?? 'employees_new_template.xlsx';
      if (base64.isEmpty) throw Exception(context.t('set.emptyFile'));
      downloadBase64File(
        base64,
        filename,
        r['mimeType']?.toString() ??
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (!mounted) return;
      await _showMessage(
        context.t('emp.templateDownloaded', {'file': filename}),
        title: context.t('common.done'),
      );
    } catch (e) {
      if (!mounted) return;
      await _showMessage(e.toString(), title: context.t('common.error'));
    } finally {
      if (mounted) setState(() => _exportingTemplate = false);
    }
  }

  Future<void> _importExcel() async {
    if (_importingExcel) return;
    try {
      final base64 = await pickExcelBase64();
      if (base64 == null || base64.isEmpty) return;
      setState(() => _importingExcel = true);
      final r = await api.employeesImportXlsx(base64);
      if (!mounted) return;
      await _reload(reset: true);
      if (!mounted) return;
      final errors = (r['errors'] as List?) ?? [];
      final msg = r['message']?.toString() ?? context.t('emp.imported');
      final warningLines = errors
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final detail = warningLines.isEmpty
          ? msg
          : context.t('emp.importWarnings', {
              'msg': msg,
              'count': warningLines.length,
              'lines': warningLines.take(12).join('\n'),
              'more': warningLines.length > 12
                  ? context.t('emp.moreWarnings', {
                      'count': warningLines.length - 12,
                    })
                  : '',
            });
      await _showMessage(
        detail,
        title: warningLines.isEmpty
            ? context.t('emp.imported')
            : context.t('emp.importedWithWarnings'),
      );
    } catch (e) {
      if (!mounted) return;
      await _showMessage(e.toString(), title: context.t('common.error'));
    } finally {
      if (mounted) setState(() => _importingExcel = false);
    }
  }

  (DateTime, DateTime) _defaultPunchReportPeriod() {
    final now = DateTime.now();
    if (now.day >= 26) {
      final from = DateTime(now.year, now.month, 26);
      final toMonth = now.month == 12 ? 1 : now.month + 1;
      final toYear = now.month == 12 ? now.year + 1 : now.year;
      return (from, DateTime(toYear, toMonth, 25));
    }
    final fromMonth = now.month == 1 ? 12 : now.month - 1;
    final fromYear = now.month == 1 ? now.year - 1 : now.year;
    return (
      DateTime(fromYear, fromMonth, 26),
      DateTime(now.year, now.month, 25),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _deleteEmployee(Map<String, dynamic> employee) async {
    final id = employee['id']?.toString();
    if (id == null || id.isEmpty) return;
    final name = employee['displayName']?.toString().trim().isNotEmpty == true
        ? employee['displayName'].toString()
        : employee['name']?.toString() ?? context.t('emp.employee');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('emp.deleteTitle')),
        content: Text(context.t('emp.deleteBody', {'name': name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final r = await api.employeeDelete(id);
      if (!mounted) return;
      await _reload(reset: true);
      if (!mounted) return;
      await _showMessage(
        r['message']?.toString() ?? context.t('emp.deleted'),
        title: context.t('common.done'),
      );
    } catch (e) {
      if (!mounted) return;
      await _showMessage(e.toString(), title: context.t('common.error'));
    }
  }

  Future<void> _exportPunchReport() async {
    final defaults = _defaultPunchReportPeriod();
    final config = await showDialog<_PunchReportExportConfig>(
      context: context,
      builder: (ctx) => _PunchReportExportDialog(
        initialFrom: defaults.$1,
        initialTo: defaults.$2,
        matchingFiltersCount: _total,
      ),
    );
    if (config == null || !mounted) return;

    try {
      final dateFrom = _fmtDate(config.dateFrom);
      final dateTo = _fmtDate(config.dateTo);

      if (config.mode == _PunchReportExportMode.all) {
        await _runPunchReportExportJob(
          dateFrom: dateFrom,
          dateTo: dateTo,
          includeAllBiotimeCodes: true,
          headline: context.t('emp.punchAllHeadline', {
            'from': dateFrom,
            'to': dateTo,
          }),
        );
        return;
      }

      final employeeIds = config.employeeIds;
      if (employeeIds == null || employeeIds.isEmpty) {
        if (!mounted) return;
        await _showMessage(
          context.t('emp.noneToExport'),
          title: context.t('common.notice'),
        );
        return;
      }

      await _runPunchReportExportJob(
        dateFrom: dateFrom,
        dateTo: dateTo,
        employeeIds: employeeIds,
        headline: context.t('emp.punchSomeHeadline', {
          'count': employeeIds.length,
          'from': dateFrom,
          'to': dateTo,
        }),
      );
    } catch (e) {
      if (!mounted) return;
      await _showMessage(e.toString(), title: context.t('common.error'));
    }
  }

  Future<void> _runPunchReportExportJob({
    required String dateFrom,
    required String dateTo,
    required String headline,
    List<String>? employeeIds,
    bool includeAllBiotimeCodes = false,
  }) async {
    if (!mounted) return;
    final jobProgress = ValueNotifier<(int pct, String message)>((
      0,
      context.t('emp.startingJob'),
    ));
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: ValueListenableBuilder<(int, String)>(
          valueListenable: jobProgress,
          builder: (ctx, value, _) {
            final pct = value.$1.clamp(0, 100);
            final hasPct = pct > 0;
            return AlertDialog(
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(headline, style: const TextStyle(height: 1.35)),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: hasPct ? pct / 100 : null,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          hasPct ? '$pct%' : '…',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            value.$2,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    try {
      final r = await api.employeesPunchReportExportJob(
        dateFrom: dateFrom,
        dateTo: dateTo,
        employeeIds: employeeIds,
        includeAllBiotimeCodes: includeAllBiotimeCodes,
        onProgress: (message, {int? progress}) {
          final next = (progress ?? jobProgress.value.$1).clamp(0, 100);
          jobProgress.value = (
            next,
            message.isNotEmpty ? message : jobProgress.value.$2,
          );
        },
      );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
      final filename = r['filename']?.toString() ?? 'punch_report.xlsx';
      if (base64.isEmpty) throw Exception(context.t('set.emptyFile'));
      downloadBase64File(
        base64,
        filename,
        r['mimeType']?.toString() ??
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (!mounted) return;
      await _showMessage(
        context.t('emp.downloaded', {'file': filename}),
        title: context.t('common.done'),
      );
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      rethrow;
    } finally {
      jobProgress.dispose();
    }
  }

  Future<void> _syncPunchesWithProgress({
    required List<String> employeeIds,
    required String dateFrom,
    required String dateTo,
    required String headline,
    bool includeAllBiotimeCodes = false,
  }) async {
    if (!mounted) return;
    if (!includeAllBiotimeCodes && employeeIds.isEmpty) return;
    final syncProgress = ValueNotifier<(int pct, String message)>((
      0,
      context.t('emp.startingSync'),
    ));
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: ValueListenableBuilder<(int, String)>(
          valueListenable: syncProgress,
          builder: (ctx, value, _) {
            final pct = value.$1.clamp(0, 100);
            final hasPct = pct > 0;
            return AlertDialog(
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(headline, style: const TextStyle(height: 1.35)),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: hasPct ? pct / 100 : null,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          hasPct ? '$pct%' : '…',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            value.$2,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    try {
      await api.employeePunchSyncStart(
        null,
        employeeIds: includeAllBiotimeCodes ? null : employeeIds,
        includeAllBiotimeCodes: includeAllBiotimeCodes,
        dateFrom: dateFrom,
        dateTo: dateTo,
        onProgress: (message, {int? progress}) {
          final next = (progress ?? syncProgress.value.$1).clamp(0, 100);
          syncProgress.value = (
            next,
            message.isNotEmpty ? message : syncProgress.value.$2,
          );
        },
      );
      syncProgress.value = (100, context.t('emp.syncComplete'));
      await Future<void>.delayed(const Duration(milliseconds: 350));
    } finally {
      syncProgress.dispose();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<List<String>> _collectFilteredEmployeeIds() async {
    final ids = <String>[];
    var offset = 0;
    const pageSize = 100;
    while (true) {
      final page = await api.employeesList(
        search: _searchCtrl.text.trim().isEmpty
            ? null
            : _searchCtrl.text.trim(),
        departmentId: _departmentFilter,
        locationId:
            context.read<AuthCubit>().state.scopedLocationId ?? _locationFilter,
        biotimeSynced: _biotimeFilter,
        active: !_showArchived,
        limit: pageSize,
        offset: offset,
      );
      for (final emp in page.items) {
        final id = EntityId.parse(emp['id']);
        if (id != null && id.isNotEmpty) ids.add(id);
      }
      if (!page.hasMore || page.items.isEmpty) break;
      offset = page.offset + page.items.length;
      if (ids.length >= 5000) break;
    }
    return ids;
  }

  List<Widget> _headerActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () => _reload(reset: true),
        icon: const Icon(Icons.refresh),
        tooltip: context.t('common.refresh'),
      ),
      OutlinedButton.icon(
        onPressed: _loading ? null : _exportPunchReport,
        icon: const Icon(Icons.fingerprint, size: 18),
        label: Text(context.t('employees.punchReport')),
      ),
      OutlinedButton.icon(
        onPressed: _loading || _exportingTemplate ? null : _exportTemplate,
        icon: _exportingTemplate
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.note_add_outlined, size: 18),
        label: Text(
          _exportingTemplate
              ? context.t('emp.downloadingTemplate')
              : context.t('emp.newEmployeeTemplate'),
        ),
      ),
      OutlinedButton.icon(
        onPressed: _loading || _importingExcel ? null : _importExcel,
        icon: _importingExcel
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload_file, size: 18),
        label: Text(
          _importingExcel
              ? context.t('employees.importing')
              : context.t('employees.importExcel'),
        ),
      ),
      OutlinedButton.icon(
        onPressed: _loading || _exportingExcel ? null : _exportExcel,
        icon: _exportingExcel
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download, size: 18),
        label: Text(
          _exportingExcel
              ? context.t('employees.exporting')
              : context.t('employees.exportExcel'),
        ),
      ),
      FilledButton.icon(
        onPressed: _openCreateForm,
        icon: const Icon(Icons.person_add, size: 18),
        label: Text(context.t('employees.newEmployee')),
      ),
    ];
  }

  Widget _filtersCard(BuildContext context) {
    return SellixCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            autofillHints: const <String>[],
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: context.t('emp.searchHint'),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        _reload(reset: true);
                      },
                    )
                  : null,
            ),
            onChanged: _onSearchChanged,
            onSubmitted: (_) => _reload(reset: true),
          ),
          const SizedBox(height: 12),
          SearchableSelectField<String>(
            label: context.t('employees.field.location'),
            allLabel: context.t('employees.allLocations'),
            value:
                context.read<AuthCubit>().state.scopedLocationId ??
                _locationFilter,
            options: [
              for (final l in _locations)
                SearchableSelectOption(
                  value: EntityId.parse(l['id']) ?? '',
                  label: (l['actualName'] ?? l['name'])?.toString() ?? '',
                ),
            ],
            onChanged: context.read<AuthCubit>().state.isLocationScoped
                ? (_) {}
                : (v) {
                    setState(() => _locationFilter = v);
                    _reload(reset: true);
                  },
          ),
          const SizedBox(height: 12),
          SearchableSelectField<String>(
            label: context.t('employees.department'),
            allLabel: context.t('employees.allDepartments'),
            value: _departmentFilter,
            options: [
              for (final d in _departments)
                SearchableSelectOption(
                  value: d['id']?.toString() ?? '',
                  label: departmentDisplayName(d, isArabic: context.l10n.isAr),
                ),
            ],
            onChanged: (v) {
              setState(() => _departmentFilter = v);
              _reload(reset: true);
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                label: Text(context.t('common.all')),
                selected: _biotimeFilter == null && !_showArchived,
                onSelected: (_) {
                  setState(() {
                    _biotimeFilter = null;
                    _showArchived = false;
                  });
                  _reload(reset: true);
                },
              ),
              FilterChip(
                label: Text(context.t('emp.linkedBio')),
                selected: _biotimeFilter == true && !_showArchived,
                onSelected: (_) {
                  setState(() {
                    _biotimeFilter = true;
                    _showArchived = false;
                  });
                  _reload(reset: true);
                },
              ),
              FilterChip(
                label: Text(context.t('emp.notLinked')),
                selected: _biotimeFilter == false && !_showArchived,
                onSelected: (_) {
                  setState(() {
                    _biotimeFilter = false;
                    _showArchived = false;
                  });
                  _reload(reset: true);
                },
              ),
              FilterChip(
                avatar: const Icon(Icons.archive_outlined, size: 18),
                label: Text(context.t('emp.archived')),
                selected: _showArchived,
                onSelected: (_) {
                  setState(() {
                    _showArchived = true;
                    _biotimeFilter = null;
                  });
                  _reload(reset: true);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _employeesList(BuildContext context) {
    if (_loading) return const _EmployeesListSkeleton();
    if (_items.isEmpty) {
      return SellixCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(context.t('emp.noMatches')),
          ),
        ),
      );
    }
    return SellixCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        controller: _scrollCtrl,
        itemCount: _items.length + (_loadingMore ? _loadMoreSkeletonCount : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i >= _items.length) return const _EmployeeTileSkeleton();
          return _EmployeeTile(
            employee: _items[i],
            onTap: () async {
              await context.push('${AppRoutes.hrEmployees}/${_items[i]['id']}');
              if (mounted) _reload(reset: true);
            },
            onDelete: context.watch<AuthCubit>().state.canDeleteEmployee
                ? () => _deleteEmployee(_items[i])
                : null,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = isMobile(context) || isTablet(context);
    final pagePadding = EdgeInsets.fromLTRB(
      compact ? 12 : 24,
      compact ? 12 : 20,
      compact ? 12 : 24,
      compact ? 16 : 24,
    );

    return Stack(
      children: [
        Padding(
          padding: pagePadding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Short viewports: scroll the whole page so filters never push
              // the list off-screen / into a zero-height Expanded. Android's
              // keyboard temporarily removes its inset from maxHeight, so use
              // the pre-keyboard height to avoid remounting the search field.
              final shortViewport = useShortEmployeesViewport(
                layoutHeight: constraints.maxHeight,
                keyboardInset: MediaQuery.viewInsetsOf(context).bottom,
              );
              final header = PageHeader(
                title: context.t('employees.title'),
                subtitle: _total > 0
                    ? context.t('employees.totalBioTime', {'n': _total})
                    : context.t('employees.emptyBioTime'),
                icon: Icons.people_outline_rounded,
                actions: _headerActions(context),
              );
              final filters = _filtersCard(context);
              final list = _employeesList(context);

              if (shortViewport) {
                return ListView(
                  children: [
                    header,
                    const SizedBox(height: 16),
                    filters,
                    const SizedBox(height: 16),
                    SizedBox(height: 420, child: list),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const SizedBox(height: 16),
                  filters,
                  const SizedBox(height: 16),
                  Expanded(child: list),
                ],
              );
            },
          ),
        ),
        if (_exportingExcel || _exportingTemplate || _importingExcel)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black26,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 22,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 14),
                        Text(
                          _exportingExcel
                              ? context.t('emp.exportingExcel')
                              : _exportingTemplate
                              ? context.t('emp.downloadingEmpTemplate')
                              : context.t('emp.importingExcel'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmployeesListSkeleton extends StatelessWidget {
  const _EmployeesListSkeleton();

  @override
  Widget build(BuildContext context) {
    return SellixCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: 8,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, __) => const _EmployeeTileSkeleton(),
      ),
    );
  }
}

class _EmployeeTileSkeleton extends StatelessWidget {
  const _EmployeeTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(
            height: 40,
            width: 40,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 15, width: 190),
                SizedBox(height: 10),
                Row(
                  children: [
                    SkeletonBox(
                      height: 22,
                      width: 76,
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    SizedBox(width: 8),
                    SkeletonBox(height: 12, width: 110),
                  ],
                ),
                SizedBox(height: 8),
                SkeletonBox(height: 11, width: 210),
              ],
            ),
          ),
          SizedBox(width: 12),
          SkeletonBox(
            height: 26,
            width: 78,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ],
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({
    required this.employee,
    required this.onTap,
    this.onDelete,
  });

  final Map<String, dynamic> employee;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  String get _displayName =>
      employee['displayName']?.toString().trim().isNotEmpty == true
      ? employee['displayName'].toString()
      : employee['name']?.toString() ?? '—';

  String get _initials {
    final parts = _displayName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return s.length >= 2 ? s.substring(0, 2) : s;
    }
    return '${parts.first[0]}${parts.last[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final code = employee['code']?.toString() ?? '';
    final dept = employeeDepartmentName(employee, context);
    final job = employee['jobTitle']?.toString().trim() ?? '';
    final branch =
        employee['locationName']?.toString().trim().isNotEmpty == true
        ? employee['locationName'].toString().trim()
        : employee['location']?.toString().trim() ?? '';
    final email = employee['workEmail']?.toString() ?? '';
    final phone = employee['mobilePhone']?.toString() ?? '';
    final synced = employee['biotimeSynced'] == true;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: AppThemeV2.primarySoft,
        foregroundColor: AppThemeV2.primary,
        child: Text(
          _initials,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      title: Text(_displayName, style: AppThemeV2.title.copyWith(fontSize: 15)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (code.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppThemeV2.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppThemeV2.border),
                  ),
                  child: Text(
                    context.t('emp.codeLabel', {'code': code}),
                    style: AppThemeV2.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (dept.isNotEmpty) Text(dept, style: AppThemeV2.caption),
              if (job.isNotEmpty) Text(job, style: AppThemeV2.caption),
              if (branch.isNotEmpty) Text(branch, style: AppThemeV2.caption),
            ],
          ),
          if (email.isNotEmpty || phone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  if (email.isNotEmpty) email,
                  if (phone.isNotEmpty) phone,
                ].join('  •  '),
                style: AppThemeV2.caption.copyWith(
                  color: AppThemeV2.textMuted,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusTag(
            label: synced
                ? 'BioTime'
                : (code.isNotEmpty
                      ? context.t('emp.awaitingUpload')
                      : context.t('emp.notLinked')),
            type: synced ? StatusTagType.success : StatusTagType.warning,
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: AppThemeV2.danger,
              ),
              tooltip: context.t('emp.deleteEmployee'),
              onPressed: onDelete,
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _EmployeeFormDialog extends StatefulWidget {
  const _EmployeeFormDialog({required this.departments});

  final List<Map<String, dynamic>> departments;

  @override
  State<_EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends State<_EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nationalId = TextEditingController();
  final _code = TextEditingController();
  final _phone = TextEditingController();
  final _salary = TextEditingController();
  String? _departmentId;
  String? _locationId;
  String? _jobTitle;
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _jobTitles = [];
  bool _locationsLoading = true;
  bool _jobTitlesLoading = true;
  bool _pushToBiotime = false;
  bool _isForeigner = false;
  bool _saving = false;
  String? _nationalIdServerError;

  static final _codePattern = RegExp(r'^[A-Za-z0-9_-]+$');

  @override
  void initState() {
    super.initState();
    final scoped = context.read<AuthCubit>().state.scopedLocationId;
    if (scoped != null) _locationId = scoped;
    _loadLocations();
    _loadJobTitles();
  }

  Future<void> _loadLocations() async {
    try {
      final list = await api.locationsList();
      if (!mounted) return;
      setState(() {
        _locations = list;
        _locationsLoading = false;
        final scoped = context.read<AuthCubit>().state.scopedLocationId;
        if (scoped != null) {
          _locationId = scoped;
        } else if (_locationId == null && list.length == 1) {
          _locationId = EntityId.parse(list.first['id']);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _locationsLoading = false);
    }
  }

  Future<void> _loadJobTitles() async {
    try {
      final list = await api.jobTitlesList(
        activeOnly: true,
        syncFromEmployees: true,
      );
      if (!mounted) return;
      setState(() {
        _jobTitles = list;
        _jobTitlesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _jobTitlesLoading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _nationalId.dispose();
    _code.dispose();
    _phone.dispose();
    _salary.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    final t = v?.trim() ?? '';
    if (t.length < 2) return context.t('emp.nameRequired');
    return null;
  }

  String? _validateNationalId(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    if (_isForeigner) return _nationalIdServerError;
    final formatError = validateEgyptianNationalId(context, t);
    if (formatError != null) return formatError;
    return _nationalIdServerError;
  }

  String? _validateCode(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    if (!_codePattern.hasMatch(t)) return context.t('emp.codeCharset');
    return null;
  }

  String? _validatePhone(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    if (t.length < 8) return context.t('emp.phoneShort');
    return null;
  }

  String? _validateSalary(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final n = parseMoney(t);
    if (n == null || n < 0) return context.t('emp.salaryInvalid');
    return null;
  }

  Future<void> _save() async {
    setState(() => _nationalIdServerError = null);
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => AlertDialog(
          title: Text(context.t('common.notice')),
          content: Text(
            context.t('emp.formInvalid'),
            style: TextStyle(height: 1.45),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.t('common.ok')),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final salaryText = _salary.text.trim();
      final auth = context.read<AuthCubit>().state;
      final locationId = auth.scopedLocationId ?? _locationId;
      final nid = _nationalId.text.trim();
      final result = await api.employeeCreate({
        'name': _name.text.trim(),
        'isForeigner': _isForeigner,
        if (nid.isNotEmpty) 'nationalIdConfirm': nid,
        if (_code.text.trim().isNotEmpty) 'identificationId': _code.text.trim(),
        if (_departmentId != null) 'departmentId': _departmentId,
        if (_jobTitle != null && _jobTitle!.isNotEmpty) 'jobTitle': _jobTitle,
        if (locationId != null) 'locationId': locationId,
        if (_phone.text.trim().isNotEmpty) 'workPhone': _phone.text.trim(),
        if (salaryText.isNotEmpty) 'basicSalary': parseMoney(salaryText) ?? 0,
      }, pushToBiotime: _pushToBiotime);
      if (!mounted) return;
      final msg = result['message']?.toString() ?? context.t('emp.created');
      Navigator.pop(context, true);
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => AlertDialog(
          title: Text(context.t('common.done')),
          content: Text(msg, style: const TextStyle(height: 1.45)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.t('common.ok')),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = friendlyApiError(context, e);
      final isDuplicateNid =
          msg.contains('الرقم القومي') ||
          (e is BioTimeApiException &&
              e.code == 'DUPLICATE' &&
              msg.contains('قومي'));
      setState(() {
        _saving = false;
        if (isDuplicateNid) {
          _nationalIdServerError = context.t('emp.nidTaken');
        }
      });
      if (isDuplicateNid) {
        _formKey.currentState?.validate();
      }
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => AlertDialog(
          title: Text(context.t('emp.createFailed')),
          content: Text(
            isDuplicateNid ? context.t('emp.nidTakenLong') : msg,
            style: const TextStyle(height: 1.45),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.t('common.ok')),
            ),
          ],
        ),
      );
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    String? helper,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      prefixIcon: icon != null
          ? Icon(icon, size: 20, color: AppColors.textSecondary)
          : null,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.72;
    final nidInfo = parseEgyptianNationalId(_nationalId.text);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 460, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('emp.newEmployee'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          context.t('emp.newEmployeeHint'),
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionTitle(
                        context.t('emp.personalData'),
                        Icons.badge_outlined,
                      ),
                      TextFormField(
                        controller: _name,
                        decoration: _fieldDecoration(
                          label: context.t('emp.nameField'),
                          icon: Icons.person_outline,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: _validateName,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nationalId,
                        decoration: _fieldDecoration(
                          label: _isForeigner
                              ? context.t('emp.idOrPassport')
                              : context.t('emp.nationalIdOpt'),
                          hint: _isForeigner
                              ? context.t('emp.blankForForeign')
                              : context.t('emp.nid14'),
                          icon: Icons.credit_card_outlined,
                        ),
                        keyboardType: _isForeigner
                            ? TextInputType.text
                            : TextInputType.number,
                        maxLength: _isForeigner ? 40 : 14,
                        inputFormatters: _isForeigner
                            ? const []
                            : [FilteringTextInputFormatter.digitsOnly],
                        textInputAction: TextInputAction.next,
                        validator: _validateNationalId,
                        onChanged: (_) {
                          if (_nationalIdServerError != null) {
                            setState(() => _nationalIdServerError = null);
                          } else {
                            setState(() {});
                          }
                        },
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.t('emp.foreigner')),
                        subtitle: Text(
                          context.t('emp.foreignerHint'),
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _isForeigner,
                        onChanged: (v) =>
                            setState(() => _isForeigner = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      if (!_isForeigner && nidInfo.birthDate != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          context.t('emp.birthAndAge', {
                            'date': formatBirthDateIso(nidInfo.birthDate!),
                            'age': nidInfo.age ?? '—',
                          }),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        decoration: _fieldDecoration(
                          label: context.t('emp.phone'),
                          icon: Icons.phone_outlined,
                        ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        validator: _validatePhone,
                      ),
                      const SizedBox(height: 18),
                      _sectionTitle(
                        context.t('emp.workData'),
                        Icons.work_outline,
                      ),
                      TextFormField(
                        controller: _code,
                        decoration: _fieldDecoration(
                          label: context.t('emp.fingerprintCodeOpt'),
                          hint: context.t('emp.codeExample'),
                          helper: context.t('emp.codeAutoHint'),
                          icon: Icons.fingerprint,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: _validateCode,
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final auth = context.watch<AuthCubit>().state;
                          final scopedLocationId = auth.scopedLocationId;
                          final locationLocked = auth.isLocationScoped;
                          final locationItems = locationLocked
                              ? _locations
                                    .where(
                                      (l) =>
                                          EntityId.parse(l['id']) ==
                                          scopedLocationId,
                                    )
                                    .toList()
                              : _locations;
                          return DropdownButtonFormField<String?>(
                            value: locationLocked
                                ? scopedLocationId
                                : _locationId,
                            decoration: _fieldDecoration(
                              label: context.t('employees.field.location'),
                              icon: Icons.storefront_outlined,
                              helper: _locationsLoading
                                  ? context.t('emp.loadingBranches')
                                  : null,
                            ),
                            items: [
                              if (!locationLocked)
                                DropdownMenuItem(
                                  value: null,
                                  child: Text(context.t('emp.noLocation')),
                                ),
                              for (final l in locationItems)
                                DropdownMenuItem(
                                  value: EntityId.parse(l['id']),
                                  child: Text(l['name']?.toString() ?? ''),
                                ),
                            ],
                            onChanged: locationLocked || _locationsLoading
                                ? null
                                : (v) => setState(() => _locationId = v),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        value: _departmentId,
                        decoration: _fieldDecoration(
                          label: context.t('emp.department'),
                          icon: Icons.apartment_outlined,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(context.t('emp.noDepartment')),
                          ),
                          for (final d in widget.departments)
                            DropdownMenuItem(
                              value: EntityId.parse(d['id']),
                              child: Text(
                                departmentDisplayName(
                                  d,
                                  isArabic: context.l10n.isAr,
                                ),
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => _departmentId = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        value: _jobTitle,
                        decoration: _fieldDecoration(
                          label: context.t('employees.field.jobTitle'),
                          icon: Icons.badge_outlined,
                          helper: _jobTitlesLoading
                              ? context.t('emp.loadingJobs')
                              : context.t('employees.field.jobTitleHint'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(context.t('emp.noJobTitle')),
                          ),
                          for (final j in _jobTitles)
                            DropdownMenuItem(
                              value: j['name']?.toString(),
                              child: Text(j['name']?.toString() ?? ''),
                            ),
                        ],
                        onChanged: _jobTitlesLoading
                            ? null
                            : (v) => setState(() => _jobTitle = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _salary,
                        decoration: _fieldDecoration(
                          label: context.t('emp.baseSalary'),
                          hint: '0.00',
                          icon: Icons.payments_outlined,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _validateSalary,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.muted,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: CheckboxListTile(
                          value: _pushToBiotime,
                          onChanged: _saving
                              ? null
                              : (v) =>
                                    setState(() => _pushToBiotime = v ?? false),
                          title: Text(
                            context.t('emp.pushToBio'),
                            style: TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            context.t('emp.pushToBioHint'),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
                color: AppColors.background,
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: Text(context.t('common.cancel')),
                  ),
                  const Spacer(),
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
                        : const Icon(Icons.save_rounded, size: 18),
                    label: Text(
                      _saving
                          ? context.t('common.saving')
                          : context.t('common.save'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PunchReportExportMode { all, selected }

class _PunchReportExportConfig {
  const _PunchReportExportConfig({
    required this.dateFrom,
    required this.dateTo,
    required this.mode,
    this.employeeIds,
  });

  final DateTime dateFrom;
  final DateTime dateTo;
  final _PunchReportExportMode mode;
  final List<String>? employeeIds;
}

enum _MissingPunchesAction { cancel, exportAnyway, pullThenExport }

class _PunchReportExportDialog extends StatefulWidget {
  const _PunchReportExportDialog({
    required this.initialFrom,
    required this.initialTo,
    required this.matchingFiltersCount,
  });

  final DateTime initialFrom;
  final DateTime initialTo;
  final int matchingFiltersCount;

  @override
  State<_PunchReportExportDialog> createState() =>
      _PunchReportExportDialogState();
}

class _PunchReportExportDialogState extends State<_PunchReportExportDialog> {
  late DateTime _dateFrom = widget.initialFrom;
  late DateTime _dateTo = widget.initialTo;
  _PunchReportExportMode _mode = _PunchReportExportMode.all;

  final Set<String> _selectedIds = {};
  final Map<String, Map<String, dynamic>> _selectedMeta = {};
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(bool from) async {
    final initial = from ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _dateFrom = picked;
        if (_dateTo.isBefore(_dateFrom)) _dateTo = _dateFrom;
      } else {
        _dateTo = picked;
        if (_dateFrom.isAfter(_dateTo)) _dateFrom = _dateTo;
      }
    });
  }

  void _onSearchChanged(String raw) {
    _debounce?.cancel();
    final q = raw.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final page = await api.employeesList(
          search: q,
          active: true,
          limit: 40,
          offset: 0,
        );
        if (!mounted) return;
        setState(() {
          _results = page.items;
          _searching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _results = [];
          _searching = false;
        });
      }
    });
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final canExport =
        _mode == _PunchReportExportMode.all || _selectedIds.isNotEmpty;
    return AlertDialog(
      title: Text(context.t('emp.exportPunchExcel')),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.t('emp.dateFrom')),
                subtitle: Text(_fmt(_dateFrom)),
                trailing: const Icon(Icons.calendar_today, size: 20),
                onTap: () => _pick(true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.t('emp.dateTo')),
                subtitle: Text(_fmt(_dateTo)),
                trailing: const Icon(Icons.calendar_today, size: 20),
                onTap: () => _pick(false),
              ),
              const SizedBox(height: 8),
              RadioListTile<_PunchReportExportMode>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _PunchReportExportMode.all,
                groupValue: _mode,
                onChanged: (v) => setState(() => _mode = v!),
                title: Text(context.t('emp.allBioCodes')),
                subtitle: Text(
                  context.t('emp.allBioCodesHint'),
                  style: TextStyle(fontSize: 12),
                ),
              ),
              RadioListTile<_PunchReportExportMode>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _PunchReportExportMode.selected,
                groupValue: _mode,
                onChanged: (v) => setState(() => _mode = v!),
                title: Text(context.t('emp.pickEmployees')),
                subtitle: Text(
                  context.t('emp.pickEmployeesHint'),
                  style: TextStyle(fontSize: 12),
                ),
              ),
              if (_mode == _PunchReportExportMode.selected) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: context.t('search.byNameOrCode'),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: _onSearchChanged,
                ),
                if (_selectedIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final id in _selectedIds)
                        Chip(
                          label: Text(() {
                            final m = _selectedMeta[id];
                            final code = m?['code']?.toString() ?? '';
                            final name =
                                m?['name']?.toString() ??
                                m?['displayName']?.toString() ??
                                id;
                            return code.isNotEmpty ? '$code — $name' : name;
                          }(), style: const TextStyle(fontSize: 12)),
                          onDeleted: () => setState(() {
                            _selectedIds.remove(id);
                            _selectedMeta.remove(id);
                          }),
                        ),
                    ],
                  ),
                ],
                if (_results.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      itemBuilder: (ctx, i) {
                        final emp = _results[i];
                        final id = EntityId.parse(emp['id']);
                        if (id == null) return const SizedBox.shrink();
                        final selected = _selectedIds.contains(id);
                        final code = emp['code']?.toString() ?? '';
                        final name =
                            emp['name']?.toString() ??
                            emp['displayName']?.toString() ??
                            '';
                        return CheckboxListTile(
                          dense: true,
                          value: selected,
                          title: Text(
                            code.isNotEmpty ? '$code — $name' : name,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedIds.add(id);
                                _selectedMeta[id] = emp;
                              } else {
                                _selectedIds.remove(id);
                                _selectedMeta.remove(id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton(
          onPressed: !canExport
              ? null
              : () => Navigator.pop(
                  context,
                  _PunchReportExportConfig(
                    dateFrom: _dateFrom,
                    dateTo: _dateTo,
                    mode: _mode,
                    employeeIds: _mode == _PunchReportExportMode.selected
                        ? _selectedIds.toList()
                        : null,
                  ),
                ),
          child: Text(context.t('emp.continue')),
        ),
      ],
    );
  }
}

class _MissingPunchesDialog extends StatelessWidget {
  const _MissingPunchesDialog({
    required this.rows,
    required this.dateFrom,
    required this.dateTo,
  });

  final List<Map<String, dynamic>> rows;
  final String dateFrom;
  final String dateTo;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('emp.missingPunches')),
      content: SizedBox(
        width: 560,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t('emp.missingPunchesBody', {
                'count': rows.length,
                'from': dateFrom,
                'to': dateTo,
              }),
              style: TextStyle(height: 1.4, fontSize: 13),
            ),
            SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(context.t('common.code'))),
                    DataColumn(label: Text(context.t('common.name'))),
                    DataColumn(label: Text(context.t('emp.department'))),
                  ],
                  rows: [
                    for (final r in rows.take(200))
                      DataRow(
                        cells: [
                          DataCell(Text(r['code']?.toString() ?? '')),
                          DataCell(Text(r['name']?.toString() ?? '')),
                          DataCell(Text(r['departmentName']?.toString() ?? '')),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (rows.length > 200)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  context.t('emp.andMore', {'count': rows.length - 200}),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _MissingPunchesAction.cancel),
          child: Text(context.t('common.cancel')),
        ),
        OutlinedButton(
          onPressed: () =>
              Navigator.pop(context, _MissingPunchesAction.exportAnyway),
          child: Text(context.t('emp.exportWithoutPull')),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, _MissingPunchesAction.pullThenExport),
          child: Text(context.t('emp.pullThenExport')),
        ),
      ],
    );
  }
}
