import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_download.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';
import '../../l10n/l10n_extension.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  /// Filter chips: module id paired with the key for its label.
  static const _modules = <(String?, String)>[
    (null, 'common.all'),
    ('employees', 'audit.module.employees'),
    ('hiring', 'audit.module.hiring'),
    ('shift_grid', 'audit.module.shiftGrid'),
    ('deductions', 'audit.module.deductions'),
    ('advances', 'audit.module.advances'),
    ('payroll', 'audit.module.payroll'),
  ];

  static const _fieldLabels = <String, String>{
    'name': 'audit.field.name',
    'active': 'audit.field.active',
    'departmentId': 'audit.field.departmentId',
    'locationId': 'audit.field.locationId',
    'jobTitle': 'audit.field.jobTitle',
    'workPhone': 'audit.field.workPhone',
    'mobilePhone': 'audit.field.mobilePhone',
    'workEmail': 'audit.field.workEmail',
    'birthday': 'audit.field.birthday',
    'hiringDate': 'audit.field.hiringDate',
    'firstWorkDay': 'audit.field.firstWorkDay',
    'basicSalary': 'audit.field.basicSalary',
    'bankIban': 'audit.field.bankIban',
    'bankName': 'audit.field.bankName',
    'fawryAccount': 'audit.field.fawryAccount',
    'hasFawryAccount': 'audit.field.hasFawryAccount',
    'insuranceNumber': 'audit.field.insuranceNumber',
    'insuranceStatus': 'audit.field.insuranceStatus',
    'insuranceCompanyId': 'audit.field.insuranceCompanyId',
    'insuranceSalary': 'audit.field.insuranceSalary',
    'medicalInsuranceStatus': 'audit.field.medicalInsuranceStatus',
    'medicalInsuranceCompanyId': 'audit.field.medicalInsuranceCompanyId',
    'medicalInsuranceSalary': 'audit.field.medicalInsuranceSalary',
    'nationalIdConfirm': 'audit.field.nationalIdConfirm',
    'identificationId': 'audit.field.identificationId',
    'mobileLine': 'audit.field.mobileLine',
    'dateFrom': 'audit.field.dateFrom',
    'dateTo': 'audit.field.dateTo',
    'state': 'audit.field.state',
    'amount': 'audit.field.amount',
    'note': 'audit.field.note',
  };

  final _searchCtrl = TextEditingController();
  String? _module;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _offset = 0;
  String? _error;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    return '${_fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _moduleLabel(String? m) {
    switch (m) {
      case 'employees':
        return tr('audit.module.employees');
      case 'hiring':
        return tr('audit.module.hiring');
      case 'shift_grid':
        return tr('audit.module.shiftGrid');
      case 'deductions':
        return tr('audit.module.deductions');
      case 'advances':
        return tr('audit.module.advances');
      case 'payroll':
        return tr('audit.module.payroll');
      default:
        return m ?? '—';
    }
  }

  String _fieldLabel(Map<String, dynamic> d) {
    final labeled = d['fieldLabel']?.toString();
    if (labeled != null && labeled.isNotEmpty) return labeled;
    final field = d['field']?.toString() ?? '';
    final key = _fieldLabels[field];
    return key != null ? tr(key) : (field.isEmpty ? '—' : field);
  }

  String _displayValue(Map<String, dynamic> d, {required bool after}) {
    final key = after ? 'afterDisplay' : 'beforeDisplay';
    final labeled = d[key]?.toString();
    if (labeled != null && labeled.isNotEmpty) return labeled;
    final raw = after ? d['after'] : d['before'];
    if (raw == null) return '—';
    if (raw is bool) return raw ? tr('common.yes') : tr('common.no');
    final s = raw.toString().trim();
    if (s.isEmpty || s == 'null') return '—';
    final m = RegExp(r'^(\d{4}-\d{2}-\d{2})(?:T(\d{2}):(\d{2}))').firstMatch(s);
    if (m != null) {
      if (m.group(2) == '00' && m.group(3) == '00') return m.group(1)!;
      return '${m.group(1)} ${m.group(2)}:${m.group(3)}';
    }
    return s;
  }

  List<Map<String, dynamic>> _diffsOf(Map<String, dynamic> item) {
    final raw = item['diffPreview'] ?? item['changes'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _offset = 0;
      _items.clear();
    });
    await _loadMore(reset: true);
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final data = await api.auditList(
        dateFrom: _dateFrom == null ? null : _fmtDate(_dateFrom!),
        dateTo: _dateTo == null ? null : _fmtDate(_dateTo!),
        module: _module,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        limit: 40,
        offset: reset ? 0 : _offset,
      );
      final rows = ((data['items'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(rows);
        _offset = _items.length;
        _hasMore = data['hasMore'] == true;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _pickRange({required bool from}) async {
    final initial = from ? (_dateFrom ?? DateTime.now()) : (_dateTo ?? DateTime.now());
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
      } else {
        _dateTo = picked;
      }
    });
  }

  Future<void> _showFull(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final data = await api.auditGet(id);
      if (!mounted) return;
      nav.pop();
      final raw = data['item'] ?? data;
      final full = raw is Map
          ? Map<String, dynamic>.from(raw as Map)
          : <String, dynamic>{};
      final diffs = _diffsOf(full);
      final counts = full['countsDisplay'] is Map
          ? Map<String, dynamic>.from(full['countsDisplay'] as Map)
          : full['counts'] is Map
              ? Map<String, dynamic>.from(full['counts'] as Map)
              : <String, dynamic>{};

      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => AlertDialog(
          title: Text(full['summary']?.toString() ?? context.t('audit.fullDetails')),
          content: SizedBox(
            width: 720,
            height: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${_fmtDateTime(full['createdAt']?.toString())} · '
                  '${full['actorName'] ?? full['actorLogin'] ?? '—'} · '
                  '${_moduleLabel(full['module']?.toString())}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  full['actionLabel']?.toString() ??
                      full['action']?.toString() ??
                      '',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                if (counts.isNotEmpty) ...[
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final e in counts.entries)
                        Chip(
                          label: Text('${e.key}: ${e.value}', style: TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
                SizedBox(height: 12),
                Expanded(
                  child: diffs.isEmpty
                      ? Center(
                          child: Text(
                            full['payload'] != null
                                ? context.t('audit.noRowsWithSummary')
                                : context.t('audit.noRows'),
                            style: TextStyle(color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowHeight: 40,
                              dataRowMinHeight: 40,
                              columns: [
                                DataColumn(label: Text(context.t('audit.col.entity'))),
                                DataColumn(label: Text(context.t('audit.col.field'))),
                                DataColumn(label: Text(context.t('audit.col.before'))),
                                DataColumn(label: Text(context.t('audit.col.after'))),
                                DataColumn(label: Text(context.t('audit.col.note'))),
                              ],
                              rows: [
                                for (final d in diffs)
                                  DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          d['entityLabel']?.toString() ??
                                              d['entityId']?.toString() ??
                                              '—',
                                        ),
                                      ),
                                      DataCell(Text(_fieldLabel(d))),
                                      DataCell(Text(_displayValue(d, after: false))),
                                      DataCell(Text(_displayValue(d, after: true))),
                                      DataCell(Text(d['note']?.toString() ?? '—')),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('common.close'))),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        if (nav.canPop()) nav.pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _download(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      final r = await api.auditExportXlsx(id);
      final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
      final filename = r['filename']?.toString() ?? 'audit.xlsx';
      if (base64.isEmpty) throw Exception(context.t('common.emptyFile'));
      downloadBase64File(
        base64,
        filename,
        r['mimeType']?.toString() ??
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('common.downloaded', {'file': filename}))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _diffTable(List<Map<String, dynamic>> diffs) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 40,
        columns: [
          DataColumn(label: Text(context.t('audit.col.entity'))),
          DataColumn(label: Text(context.t('audit.col.field'))),
          DataColumn(label: Text(context.t('audit.col.before'))),
          DataColumn(label: Text(context.t('audit.col.after'))),
          DataColumn(label: Text(context.t('audit.col.note'))),
        ],
        rows: [
          for (final d in diffs.take(50))
            DataRow(
              cells: [
                DataCell(
                  Text(
                    d['entityLabel']?.toString() ??
                        d['entityId']?.toString() ??
                        '—',
                  ),
                ),
                DataCell(Text(_fieldLabel(d))),
                DataCell(Text(_displayValue(d, after: false))),
                DataCell(Text(_displayValue(d, after: true))),
                DataCell(Text(d['note']?.toString() ?? '—')),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, auth) {
        if (!auth.canViewAudit) {
          return Center(child: Text(context.t('audit.noPermission')));
        }
        return AppPageScaffold(
          scrollable: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: context.t('audit.title'),
                subtitle: context.t('audit.subtitle'),
                icon: Icons.history_edu_outlined,
                actions: [
                  IconButton(
                    onPressed: _loading ? null : _reload,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              SellixCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in _modules)
                          ChoiceChip(
                            label: Text(context.t(m.$2)),
                            selected: _module == m.$1,
                            onSelected: (_) {
                              setState(() => _module = m.$1);
                              _reload();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              labelText: context.t('audit.searchHint'),
                              prefixIcon: Icon(Icons.search),
                            ),
                            onSubmitted: (_) => _reload(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _pickRange(from: true),
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(_dateFrom == null ? context.t('common.from') : _fmtDate(_dateFrom!)),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          onPressed: () => _pickRange(from: false),
                          icon: const Icon(Icons.event, size: 16),
                          label: Text(_dateTo == null ? context.t('common.to') : _fmtDate(_dateTo!)),
                        ),
                        const SizedBox(width: 6),
                        FilledButton(onPressed: _reload, child: Text(context.t('common.apply'))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                Expanded(
                  child: Center(
                    child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ),
                )
              else if (_items.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(context.t('audit.noEvents')),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _items.length + (_hasMore ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i >= _items.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: _loadingMore
                                ? const CircularProgressIndicator(strokeWidth: 2)
                                : TextButton(
                                    onPressed: _loadMore,
                                    child: Text(context.t('audit.loadMore')),
                                  ),
                          ),
                        );
                      }
                      final item = _items[i];
                      final id = item['id']?.toString() ?? '$i';
                      final expanded = _expanded.contains(id);
                      final diffs = _diffsOf(item);
                      final counts = item['counts'] is Map
                          ? Map<String, dynamic>.from(item['counts'] as Map)
                          : <String, dynamic>{};
                      final actionLabel =
                          item['actionLabel']?.toString() ?? item['action']?.toString() ?? '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ExpansionTile(
                          initiallyExpanded: expanded,
                          onExpansionChanged: (v) {
                            setState(() {
                              if (v) {
                                _expanded.add(id);
                              } else {
                                _expanded.remove(id);
                              }
                            });
                          },
                          title: Text(
                            item['summary']?.toString() ?? actionLabel,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${_fmtDateTime(item['createdAt']?.toString())} · '
                              '${item['actorName'] ?? item['actorLogin'] ?? '—'} · '
                              '${_moduleLabel(item['module']?.toString())}'
                              '${actionLabel.isEmpty ? '' : ' · $actionLabel'}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                          children: [
                            if (counts.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    for (final e in counts.entries)
                                      Chip(
                                        label: Text(
                                          '${e.key}: ${e.value}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                              ),
                            if (diffs.isEmpty)
                              Padding(
                                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Text(
                                  context.t('audit.noDetailedRows'),
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              )
                            else
                              _diffTable(diffs),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _showFull(item),
                                    icon: const Icon(Icons.visibility_outlined, size: 16),
                                    label: Text(context.t('audit.fullDetails')),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.tonalIcon(
                                    onPressed: () => _download(item),
                                    icon: const Icon(Icons.download_outlined, size: 16),
                                    label: Text(context.t('audit.downloadExcel')),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
