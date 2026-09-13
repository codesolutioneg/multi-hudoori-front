import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/layout/app_tab_bar_v2.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/money_format.dart';
import '../../core/utils/payroll_month.dart';
import '../../core/widgets/hr_local_data_info.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';
import 'advance_request_common.dart';
import 'widgets/advance_create_dialogs.dart';
import 'widgets/long_advance_flow_dialog.dart';
import '../../l10n/l10n_extension.dart';

String _money(num? value) => formatMoney(value ?? 0);

class AdvancesPage extends StatefulWidget {
  const AdvancesPage({super.key});

  @override
  State<AdvancesPage> createState() => _AdvancesPageState();
}

class _AdvancesPageState extends State<AdvancesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>> _short = [];
  List<Map<String, dynamic>> _long = [];
  List<Map<String, dynamic>> _approvedImports = [];
  int _payrollMonthStartDay = 26;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final short = await api.advancesShortList();
      final long = await api.advancesLongList();
      final locked = await api.advanceLoanImportListPayload(state: 'locked');
      if (mounted) {
        setState(() {
          _short = short;
          _long = long;
          _approvedImports = (locked['items'] as List? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _payrollMonthStartDay =
              (locked['payrollMonthStartDay'] as num?)?.toInt() ?? 26;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportPeriodSheets(DateTime from, DateTime to) async {
    try {
      final r = await api.advanceLoanImportExportAccountsPeriod(
        dateFrom: formatIsoDate(from),
        dateTo: formatIsoDate(to),
      );
      final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
      final filename = r['filename']?.toString() ?? 'loan_accounts.zip';
      if (base64.isEmpty) throw Exception(context.t('adv.emptyFile'));
      downloadBase64File(
        base64,
        filename,
        r['mimeType']?.toString() ?? 'application/zip',
      );
      if (mounted) {
        final n = (r['fileCount'] as num?)?.toInt() ?? 0;
        _snack(context.t('adv.downloadedSheets', {'count': n}));
      }
    } catch (e) {
      if (mounted) _snack(e.toString());
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _openCreateShort() async {
    final ok = await showShortAdvanceCreateDialog(context);
    if (ok == true) {
      _snack(context.t('adv.shortCreated'));
      await _load();
    }
  }

  Future<void> _openCreateLong() async {
    final ok = await showLongAdvanceCreateDialog(
      context,
      onSaved: () async {
        _snack(context.t('adv.longCreated'));
        await _load();
        if (mounted) _tabs.animateTo(1);
      },
    );
    if (ok == true && mounted) await _load();
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
      ),
    );
  }

  Future<void> _exportKind(String kind) async {
    try {
      if (kind == 'template') {
        await _exportImportTemplateForBranch();
        return;
      }
      final Map<String, dynamic> r;
      switch (kind) {
        case 'short':
          r = await api.advancesExportShort();
          break;
        case 'long':
          r = await api.advancesExportLong();
          break;
        default:
          return;
      }
      final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
      final filename = r['filename']?.toString() ?? 'advances.xlsx';
      if (base64.isEmpty) throw Exception(context.t('adv.emptyFile'));
      downloadBase64File(
        base64,
        filename,
        r['mimeType']?.toString() ??
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (mounted) _snack(context.t('adv.downloaded', {'name': filename}));
    } catch (e) {
      if (mounted) _snack(e.toString());
    }
  }

  Future<void> _exportImportTemplateForBranch() async {
    final locations = await api.locationsList();
    if (!mounted) return;

    final selected = await showDialog<List<String>>(
      context: context,
      builder: (ctx) {
        final selectedIds = <String>{};
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final allIds = locations
                .map((loc) => loc['id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toList();
            return AlertDialog(
              title: Text(ctx.t('adv.pickBranches')),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      ctx.t('adv.pickBranchesHint'),
                      style: const TextStyle(fontSize: 13, height: 1.35),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pop(ctx, <String>['_blank_multiple_']),
                      icon: const Icon(Icons.note_add_outlined),
                      label: Text(ctx.t('adv.blankTemplate')),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setLocal(() {
                            selectedIds
                              ..clear()
                              ..addAll(allIds);
                          }),
                          child: Text(ctx.t('adv.selectAll')),
                        ),
                        TextButton(
                          onPressed: selectedIds.isEmpty
                              ? null
                              : () => setLocal(() => selectedIds.clear()),
                          child: Text(ctx.t('adv.clearSelection')),
                        ),
                        const Spacer(),
                        Text(
                          ctx.t('adv.selectedCount', {
                            'count': selectedIds.length,
                          }),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: locations.length,
                        itemBuilder: (_, i) {
                          final loc = locations[i];
                          final id = loc['id']?.toString() ?? '';
                          if (id.isEmpty) return const SizedBox.shrink();
                          final name = loc['name']?.toString() ?? id;
                          final checked = selectedIds.contains(id);
                          return CheckboxListTile(
                            dense: true,
                            value: checked,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(name, overflow: TextOverflow.ellipsis),
                            onChanged: (v) => setLocal(() {
                              if (v == true) {
                                selectedIds.add(id);
                              } else {
                                selectedIds.remove(id);
                              }
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(ctx.t('common.cancel')),
                ),
                FilledButton(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () => Navigator.pop(ctx, selectedIds.toList()),
                  child: Text(ctx.t('adv.downloadTemplate')),
                ),
              ],
            );
          },
        );
      },
    );
    if (selected == null || selected.isEmpty) return;

    final blank = selected.length == 1 && selected.first == '_blank_multiple_';
    final r = await api.advancesExportImportTemplate(
      locationIds: blank ? null : selected,
      blank: blank,
    );
    final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
    final filename = r['filename']?.toString() ?? 'advances_import.xlsx';
    if (base64.isEmpty) throw Exception(context.t('adv.emptyFile'));
    downloadBase64File(
      base64,
      filename,
      r['mimeType']?.toString() ??
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    if (mounted) {
      final count = r['count'];
      final fileCount = r['fileCount'];
      final skipped = r['skipped'];
      final skipN = skipped is List ? skipped.length : 0;
      var msg = context.t('adv.downloaded', {'name': filename});
      if (fileCount is num && fileCount > 1) {
        msg = context.t('adv.downloadedFiles', {
          'name': filename,
          'count': fileCount,
        });
        if (count != null)
          msg += context.t('adv.employeesSuffix', {'count': count});
        msg += ')';
      } else if (count != null) {
        msg = context.t('adv.downloadedEmployees', {
          'name': filename,
          'count': count,
        });
      }
      if (skipN > 0) msg += context.t('adv.skippedBranches', {'count': skipN});
      _snack(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.t('advances.title'),
            subtitle: context.t('advances.subtitle'),
            icon: Icons.account_balance_wallet_outlined,
            // Granting an advance is what people come here to do; importing,
            // exporting and the lifecycle reference are occasional. Six buttons
            // wrapped onto a second row and cost the list a third of the fold.
            actions: [
              OutlinedButton.icon(
                onPressed: _openCreateShort,
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: Text(context.t('adv.shortBtn')),
              ),
              FilledButton.icon(
                onPressed: _openCreateLong,
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(context.t('adv.longBtn')),
              ),
              PopupMenuButton<String>(
                tooltip: context.t('common.more'),
                offset: const Offset(0, 40),
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  switch (value) {
                    case 'import':
                      context.push(AppRoutes.hrAdvanceLoanImport);
                    case 'flow':
                      showLongAdvanceFlowDialog(context);
                    case 'refresh':
                      _load();
                    default:
                      _exportKind(value);
                  }
                },
                itemBuilder: (ctx) => [
                  _menuItem(
                    'import',
                    Icons.upload_file_outlined,
                    ctx.t('adv.importFromSheet'),
                  ),
                  _menuItem(
                    'flow',
                    Icons.route_outlined,
                    ctx.t('adv.longFlowBtn'),
                  ),
                  const PopupMenuDivider(),
                  _menuItem(
                    'template',
                    Icons.description_outlined,
                    ctx.t('adv.importTemplate'),
                  ),
                  _menuItem(
                    'long',
                    Icons.calendar_month_outlined,
                    ctx.t('adv.exportLong'),
                  ),
                  _menuItem(
                    'short',
                    Icons.payments_outlined,
                    ctx.t('adv.exportShort'),
                  ),
                  const PopupMenuDivider(),
                  _menuItem('refresh', Icons.refresh, ctx.t('common.refresh')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppTabBarV2(
            controller: _tabs,
            tabs: [
              Tab(text: context.t('advances.tab.short')),
              Tab(text: context.t('advances.tab.long')),
              Tab(text: context.t('adv.tabApprovedImports')),
              // Requests the branches have vouched for. Granting one here is what
              // creates the advance, so it sits with the sheet it lands on.
              Tab(text: context.t('advances.tab.requests')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _ShortAdvanceGroupedList(
                        items: _short,
                        importSummaries: _approvedImports,
                        payrollMonthStartDay: _payrollMonthStartDay,
                        onRefresh: _load,
                        onExportPeriod: _exportPeriodSheets,
                      ),
                      _LongAdvanceList(
                        items: _long,
                        onRefresh: _load,
                        onCreateLong: _openCreateLong,
                      ),
                      _ApprovedLoanImportList(
                        items: _approvedImports,
                        payrollMonthStartDay: _payrollMonthStartDay,
                        onRefresh: _load,
                        onExportPeriod: _exportPeriodSheets,
                      ),
                      // Approving here creates a short advance, so reload the
                      // sheet behind this tab once one goes through.
                      HrAdvanceRequestsReview(onApproved: _load),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

String _advanceStateLabel(
  BuildContext context,
  String state, {
  required bool isLong,
}) {
  if (isLong) {
    switch (state) {
      case 'draft':
        return context.t('adv.stateDraft');
      case 'running':
        return context.t('adv.stateRunning');
      case 'done':
        return context.t('adv.stateDone');
      case 'stopped':
        return context.t('adv.stateStopped');
      case 'cancelled':
        return context.t('adv.stateCancelled');
      default:
        return state;
    }
  }
  switch (state) {
    case 'pending':
    case 'confirmed': // legacy, predates Odoo parity
      return context.t('adv.statePending');
    case 'applied':
    case 'paid': // legacy
      return context.t('adv.stateApplied');
    case 'cancelled':
      return context.t('adv.stateCancelled');
    default:
      return state;
  }
}

String _advanceStateRaw(Map<String, dynamic> a) => a['state']?.toString() ?? '';

int _advanceInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

bool _isShortPending(Map<String, dynamic> a) {
  final state = _advanceStateRaw(a);
  return state == 'pending' || state == 'confirmed';
}

StatusTagType _advanceStateTag(String state) {
  switch (state) {
    case 'pending':
    case 'draft':
      return StatusTagType.warning;
    case 'running':
    case 'applied':
      return StatusTagType.success;
    case 'done':
      return StatusTagType.info;
    case 'stopped':
    case 'cancelled':
      return StatusTagType.danger;
    default:
      return StatusTagType.info;
  }
}

const _fawryCommissionRate = 0.0015;

double _roundMoney(double value) => (value * 100).roundToDouble() / 100;

({double approved, double commission, double total}) _fawryTotalsFromMeta(
  Map<String, dynamic> meta,
) {
  final approved =
      (meta['fawryApprovedAmount'] as num?)?.toDouble() ??
      (meta['fawryAmount'] as num?)?.toDouble() ??
      0;
  final commission =
      (meta['fawryCommissionAmount'] as num?)?.toDouble() ??
      _roundMoney(approved * _fawryCommissionRate);
  final total =
      (meta['fawryAmount'] as num?)?.toDouble() ??
      _roundMoney(approved + commission);
  return (approved: approved, commission: commission, total: total);
}

String _cashPlusFawryApprovedLine(
  BuildContext context, {
  required double cash,
  required double fawryApproved,
}) => context.t('fawryLine.cashPlus', {
  'amount': _money(_roundMoney(cash + fawryApproved)),
});

/// Dark-tone sequence for cash / Fawry / total chips so the money line stays
/// readable without looking like a traffic-light legend.
const _moneyToneSequence = <Color>[
  Color(0xFF1E293B), // slate-800
  Color(0xFF1E3A5F), // navy
  Color(0xFF3F3F46), // zinc-700
  Color(0xFF164E63), // cyan-900
  Color(0xFF312E81), // indigo-900
  Color(0xFF3F2E1E), // warm brown
  Color(0xFF14532D), // green-900
];

List<String> _moneyBreakdownParts(
  BuildContext context, {
  required double cash,
  required double fawryApproved,
  required double fawryCommission,
  required double fawryTotal,
  required double total,
}) => [
  context.t('adv.cashAmount', {'amount': _money(cash)}),
  context.t('fawryLine.noCommission', {'amount': _money(fawryApproved)}),
  context.t('fawryLine.commission', {'amount': _money(fawryCommission)}),
  context.t('fawryLine.total', {'amount': _money(fawryTotal)}),
  _cashPlusFawryApprovedLine(context, cash: cash, fawryApproved: fawryApproved),
  context.t('adv.totalAmount', {'amount': _money(total)}),
];

Widget _moneyBreakdownText(
  BuildContext context, {
  required double cash,
  required double fawryApproved,
  required double fawryCommission,
  required double fawryTotal,
  required double total,
  double fontSize = 12,
}) {
  final parts = _moneyBreakdownParts(
    context,
    cash: cash,
    fawryApproved: fawryApproved,
    fawryCommission: fawryCommission,
    fawryTotal: fawryTotal,
    total: total,
  );
  return Text.rich(
    TextSpan(
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0)
            TextSpan(
              text: ' • ',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          TextSpan(
            text: parts[i],
            style: TextStyle(
              color: _moneyToneSequence[i % _moneyToneSequence.length],
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ],
    ),
  );
}

String _sheetHeadline(
  String reference, {
  required String primary,
  required int locationCount,
}) {
  final loc = locationCount > 1 ? 'multiple' : primary;
  if (loc.trim().isEmpty) return reference;
  return '$reference — $loc';
}

int _locationCountOf(Map<String, dynamic> item) {
  final n = item['locationCount'];
  if (n is num) return n.toInt();
  if (item['mixedLocations'] == true) return 2;
  return 1;
}

Map<String, List<T>> _groupByPayrollPeriod<T>(
  List<T> items,
  DateTime? Function(T item) dateOf,
  int monthStartDay,
) {
  final groups = <String, List<T>>{};
  final order = <String>[];
  for (final item in items) {
    final date = dateOf(item) ?? DateTime.now();
    final range = payrollMonthRange(date, monthStartDay);
    final key =
        '${formatIsoDate(range.dateFrom)}|${formatIsoDate(range.dateTo)}';
    if (!groups.containsKey(key)) {
      groups[key] = [];
      order.add(key);
    }
    groups[key]!.add(item);
  }
  order.sort((a, b) => b.compareTo(a));
  return {for (final key in order) key: groups[key]!};
}

void _showOutsiderEmployees(
  BuildContext context,
  List<Map<String, dynamic>> lines,
  String primaryLocation,
) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.t('adv.outsidersTitle', {'branch': primaryLocation})),
      content: SizedBox(
        width: 640,
        height: 420,
        child: lines.isEmpty
            ? Center(child: Text(ctx.t('adv.allOnPrimary')))
            : ListView.separated(
                itemCount: lines.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final line = lines[index];
                  return ListTile(
                    title: Text(
                      '${line['employeeName'] ?? ''} • ${line['employeeCode'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${ctx.t('adv.lineBranch', {'value': line['locationName'] ?? '—'})}\n'
                      '${ctx.t('adv.lineJob', {'value': line['jobTitle'] ?? '—'})}\n'
                      '${ctx.t('adv.lineRequested', {'amount': _money(line['requestedAmount'] as num?)})}'
                      ' • ${ctx.t('adv.lineApproved', {'amount': _money(line['approvedAmount'] as num?)})}'
                      ' • ${ctx.t('adv.lineTotal', {'amount': _money(line['totalAmount'] as num?)})}'
                      ' • ${ctx.t(line['isFawry'] == true ? 'adv.fawry' : 'adv.cash')}',
                    ),
                    isThreeLine: true,
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(ctx.t('common.close')),
        ),
      ],
    ),
  );
}

Widget _cashFawryFooter(
  BuildContext context, {
  required double cash,
  required double fawryApproved,
  required double fawryCommission,
  required double total,
  int? sheetCount,
}) {
  final fawryTotal = _roundMoney(fawryApproved + fawryCommission);
  return SellixCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sheetCount != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              context.t('adv.rollupMany', {
                'count': sheetCount,
                'amount': _money(cash),
              }),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              context.t('adv.rollupOne', {'amount': _money(cash)}),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        _moneyBreakdownText(
          context,
          cash: cash,
          fawryApproved: fawryApproved,
          fawryCommission: fawryCommission,
          fawryTotal: fawryTotal,
          total: total,
          fontSize: 12.5,
        ),
      ],
    ),
  );
}

class _ApprovedLoanImportList extends StatelessWidget {
  const _ApprovedLoanImportList({
    required this.items,
    required this.payrollMonthStartDay,
    required this.onRefresh,
    required this.onExportPeriod,
  });

  final List<Map<String, dynamic>> items;
  final int payrollMonthStartDay;
  final VoidCallback onRefresh;
  final Future<void> Function(DateTime from, DateTime to) onExportPeriod;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SellixCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(context.t('adv.noApprovedImports')),
          ),
        ),
      );
    }

    final periods = _groupByPayrollPeriod<Map<String, dynamic>>(
      items,
      (item) => parseIsoDate(item['date']?.toString()),
      payrollMonthStartDay,
    );
    final allCash = items.fold<double>(
      0,
      (s, i) => s + ((i['cashAmount'] as num?)?.toDouble() ?? 0),
    );
    final allFawryApproved = items.fold<double>(
      0,
      (s, i) => s + ((i['fawryApprovedAmount'] as num?)?.toDouble() ?? 0),
    );
    final allFawryCommission = items.fold<double>(
      0,
      (s, i) => s + ((i['fawryCommissionAmount'] as num?)?.toDouble() ?? 0),
    );
    final allTotal = items.fold<double>(
      0,
      (s, i) => s + ((i['totalAmount'] as num?)?.toDouble() ?? 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => onRefresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                for (final entry in periods.entries) ...[
                  _PayrollPeriodBlock(
                    periodKey: entry.key,
                    sheetCount: entry.value.length,
                    children: [
                      for (final item in entry.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _LoanImportSummaryTile(
                            item: item,
                            onOpen: () async {
                              final id = item['id']?.toString() ?? '';
                              if (id.isEmpty) return;
                              await context.push(
                                '${AppRoutes.hrAdvanceLoanImport}'
                                '?importId=${Uri.encodeQueryComponent(id)}',
                              );
                              onRefresh();
                            },
                          ),
                        ),
                    ],
                    cash: entry.value.fold<double>(
                      0,
                      (s, i) =>
                          s + ((i['cashAmount'] as num?)?.toDouble() ?? 0),
                    ),
                    fawryApproved: entry.value.fold<double>(
                      0,
                      (s, i) =>
                          s +
                          ((i['fawryApprovedAmount'] as num?)?.toDouble() ?? 0),
                    ),
                    fawryCommission: entry.value.fold<double>(
                      0,
                      (s, i) =>
                          s +
                          ((i['fawryCommissionAmount'] as num?)?.toDouble() ??
                              0),
                    ),
                    total: entry.value.fold<double>(
                      0,
                      (s, i) =>
                          s + ((i['totalAmount'] as num?)?.toDouble() ?? 0),
                    ),
                    onExportPeriod: onExportPeriod,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _cashFawryFooter(
          context,
          cash: allCash,
          fawryApproved: allFawryApproved,
          fawryCommission: allFawryCommission,
          total: allTotal,
          sheetCount: items.length,
        ),
      ],
    );
  }
}

class _PayrollPeriodBlock extends StatelessWidget {
  const _PayrollPeriodBlock({
    required this.periodKey,
    required this.children,
    required this.cash,
    required this.fawryApproved,
    required this.fawryCommission,
    required this.total,
    required this.onExportPeriod,
    this.sheetCount,
  });

  final String periodKey;
  final List<Widget> children;
  final double cash;
  final double fawryApproved;
  final double fawryCommission;
  final double total;
  final Future<void> Function(DateTime from, DateTime to) onExportPeriod;
  final int? sheetCount;

  @override
  Widget build(BuildContext context) {
    final parts = periodKey.split('|');
    final from = parseIsoDate(parts.first) ?? DateTime.now();
    final to = parseIsoDate(parts.length > 1 ? parts[1] : parts.first) ?? from;
    final fawryTotal = _roundMoney(fawryApproved + fawryCommission);
    return SellixCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: context.t('adv.cycle', {
                  'from': formatIsoDate(from),
                  'to': formatIsoDate(to),
                }),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              if (sheetCount != null) ...[
                const TextSpan(
                  text: '  ·  ',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                TextSpan(
                  text: context.t('adv.sheetCount', {'count': sheetCount}),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: _moneyBreakdownText(
          context,
          cash: cash,
          fawryApproved: fawryApproved,
          fawryCommission: fawryCommission,
          fawryTotal: fawryTotal,
          total: total,
          fontSize: 11.5,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => onExportPeriod(from, to),
                icon: const Icon(Icons.folder_zip_outlined, size: 18),
                label: Text(context.t('adv.downloadAllSheets')),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _LoanImportSummaryTile extends StatelessWidget {
  const _LoanImportSummaryTile({required this.item, this.onOpen});

  final Map<String, dynamic> item;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final sent = item['odooAccountsSendId'] != null;
    final outsiders = (item['outsiderLines'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final primary =
        item['primaryLocationName']?.toString() ??
        item['locationName']?.toString() ??
        context.t('adv.noBranch');
    final fawry = _fawryTotalsFromMeta(item);
    final cash = (item['cashAmount'] as num?)?.toDouble() ?? 0;
    final total = (item['totalAmount'] as num?)?.toDouble() ?? 0;
    final headline = _sheetHeadline(
      item['reference']?.toString() ?? item['id']?.toString() ?? '',
      primary: primary,
      locationCount: _locationCountOf(item),
    );
    final metaBits = [
      context.t('adv.primaryLocation', {'name': primary}),
      '${context.t('adv.employeeCount', {'count': item['lineCount'] ?? 0})}'
          '${item['date'] != null && item['date'].toString().isNotEmpty ? ' • ${item['date']}' : ''}',
    ];

    return SellixCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: onOpen,
        leading: const Icon(
          Icons.fact_check_outlined,
          color: AppColors.primary,
        ),
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: headline,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  color: AppColors.textPrimary,
                ),
              ),
              for (final bit in metaBits) ...[
                const TextSpan(
                  text: '  ·  ',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
                TextSpan(
                  text: bit,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _moneyBreakdownText(
            context,
            cash: cash,
            fawryApproved: fawry.approved,
            fawryCommission: fawry.commission,
            fawryTotal: fawry.total,
            total: total,
          ),
        ),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (sent)
              StatusTag(
                label: context.t('adv.sentToOdoo'),
                type: StatusTagType.success,
              )
            else
              StatusTag(
                label: context.t('adv.approved'),
                type: StatusTagType.success,
              ),
            OutlinedButton(
              onPressed: () =>
                  _showOutsiderEmployees(context, outsiders, primary),
              child: Text(
                context.t('adv.outsideBranch', {
                  'count': item['outsiderCount'] ?? outsiders.length,
                }),
              ),
            ),
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(context.t('adv.openSheet')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortAdvanceGroupedList extends StatefulWidget {
  const _ShortAdvanceGroupedList({
    required this.items,
    required this.importSummaries,
    required this.payrollMonthStartDay,
    required this.onRefresh,
    required this.onExportPeriod,
  });

  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> importSummaries;
  final int payrollMonthStartDay;
  final VoidCallback onRefresh;
  final Future<void> Function(DateTime from, DateTime to) onExportPeriod;

  @override
  State<_ShortAdvanceGroupedList> createState() =>
      _ShortAdvanceGroupedListState();
}

class _ShortAdvanceGroupedListState extends State<_ShortAdvanceGroupedList> {
  final _searchController = TextEditingController();
  String? _locationFilter;
  String? _stateFilter;
  String? _importFilter;
  bool _duplicatesOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String _employeeKey(Map<String, dynamic> item) {
    final id = item['employeeId']?.toString().trim() ?? '';
    if (id.isNotEmpty) return id;
    return item['employeeCode']?.toString().trim() ?? '';
  }

  /// Employees carried by more than one imported loan sheet. Manual advances
  /// have no import reference, so they never make an employee a duplicate.
  Set<String> get _duplicateEmployees {
    final importsByEmployee = <String, Set<String>>{};
    for (final item in widget.items) {
      final importId = item['importId']?.toString().trim() ?? '';
      if (importId.isEmpty) continue;
      final key = _employeeKey(item);
      if (key.isEmpty) continue;
      importsByEmployee.putIfAbsent(key, () => <String>{}).add(importId);
    }
    return importsByEmployee.entries
        .where((entry) => entry.value.length > 1)
        .map((entry) => entry.key)
        .toSet();
  }

  List<String> _options(String key) {
    final values =
        widget.items
            .map((item) => item[key]?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<Map<String, dynamic>> _filtered(Set<String> duplicates) {
    final query = _searchController.text.trim().toLowerCase();
    return widget.items.where((item) {
      if (_duplicatesOnly && !duplicates.contains(_employeeKey(item))) {
        return false;
      }
      if (query.isNotEmpty) {
        final text = [
          item['employeeCode'],
          item['employeeName'],
          item['employeeJobTitle'],
        ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');
        if (!text.contains(query)) return false;
      }
      if (_locationFilter != null &&
          item['locationName']?.toString() != _locationFilter) {
        return false;
      }
      if (_stateFilter != null && _advanceStateRaw(item) != _stateFilter) {
        return false;
      }
      if (_importFilter != null &&
          item['importId']?.toString() != _importFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> _groups(
    List<Map<String, dynamic>> items,
  ) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final importId = item['importId']?.toString();
      final key = (importId == null || importId.isEmpty)
          ? '__manual__'
          : importId;
      groups.putIfAbsent(key, () => []).add(item);
    }
    return groups;
  }

  Map<String, Map<String, dynamic>> get _importsById {
    final map = <String, Map<String, dynamic>>{};
    for (final item in widget.importSummaries) {
      final id = item['id']?.toString() ?? '';
      if (id.isNotEmpty) map[id] = item;
    }
    return map;
  }

  Map<String, dynamic> _sheetMeta(
    String key,
    List<Map<String, dynamic>> items,
  ) {
    if (key != '__manual__' && _importsById[key] != null) {
      return _importsById[key]!;
    }
    final locationCounts = <String, int>{};
    for (final item in items) {
      final name = item['locationName']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      locationCounts[name] = (locationCounts[name] ?? 0) + 1;
    }
    final ranked = locationCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final primary = ranked.isEmpty
        ? context.t('adv.noBranch')
        : ranked.first.key;
    final outsiders = items
        .where(
          (item) => (item['locationName']?.toString().trim() ?? '') != primary,
        )
        .map(
          (item) => {
            'employeeName': item['employeeName'],
            'employeeCode': item['employeeCode'],
            'jobTitle': item['employeeJobTitle'],
            'locationName': item['locationName'],
            'requestedAmount': item['amount'],
            'approvedAmount': item['amount'],
            'totalAmount': item['amount'],
            'isFawry': item['hasFawryAccount'] == true,
          },
        )
        .toList();
    var cash = 0.0;
    var fawryApproved = 0.0;
    var fawryCommission = 0.0;
    for (final item in items) {
      if (_advanceStateRaw(item) == 'cancelled') continue;
      final amount = (item['amount'] as num?)?.toDouble() ?? 0;
      if (item['hasFawryAccount'] == true) {
        fawryApproved += amount;
        fawryCommission += _roundMoney(amount * _fawryCommissionRate);
      } else {
        cash += amount;
      }
    }
    fawryApproved = _roundMoney(fawryApproved);
    fawryCommission = _roundMoney(fawryCommission);
    final fawryTotal = _roundMoney(fawryApproved + fawryCommission);
    return {
      'primaryLocationName': primary,
      'locationCount': ranked.length,
      'outsiderCount': outsiders.length,
      'outsiderLines': outsiders,
      'cashAmount': cash,
      'fawryApprovedAmount': fawryApproved,
      'fawryCommissionAmount': fawryCommission,
      'fawryAmount': fawryTotal,
      'totalAmount': cash + fawryTotal,
    };
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 210,
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem(value: null, child: Text(context.t('adv.all'))),
          ...items,
        ],
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return HrEmptyListCard(message: context.t('adv.noShortAdvances'));
    }

    final locations = _options('locationName');
    final states =
        widget.items
            .map(_advanceStateRaw)
            .where((state) => state.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final imports = <String, String>{};
    for (final item in widget.items) {
      final id = item['importId']?.toString() ?? '';
      final reference = item['importReference']?.toString() ?? '';
      if (id.isNotEmpty && reference.isNotEmpty) imports[id] = reference;
    }
    final importEntries = imports.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final duplicates = _duplicateEmployees;
    final filtered = _filtered(duplicates);
    final groups = _groups(filtered);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SellixCard(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: context.t('adv.searchCodeNameJob'),
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
              _dropdown(
                label: context.t('adv.branch'),
                value: _locationFilter,
                items: [
                  for (final location in locations)
                    DropdownMenuItem(value: location, child: Text(location)),
                ],
                onChanged: (value) => setState(() => _locationFilter = value),
              ),
              _dropdown(
                label: context.t('adv.state'),
                value: _stateFilter,
                items: [
                  for (final state in states)
                    DropdownMenuItem(
                      value: state,
                      child: Text(
                        _advanceStateLabel(context, state, isLong: false),
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _stateFilter = value),
              ),
              _dropdown(
                label: context.t('adv.importSheet'),
                value: _importFilter,
                items: [
                  for (final entry in importEntries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) => setState(() => _importFilter = value),
              ),
              FilterChip(
                selected: _duplicatesOnly,
                onSelected: (value) => setState(() => _duplicatesOnly = value),
                avatar: Icon(
                  Icons.copy_all_outlined,
                  size: 18,
                  color: _duplicatesOnly ? AppColors.danger : null,
                ),
                label: Text(
                  context.t('adv.duplicatesOnly', {'count': duplicates.length}),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _locationFilter = null;
                    _stateFilter = null;
                    _importFilter = null;
                    _duplicatesOnly = false;
                  });
                },
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: Text(context.t('adv.clearFilters')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: groups.isEmpty
              ? Center(child: Text(context.t('adv.noMatches')))
              : Builder(
                  builder: (context) {
                    final periodBuckets =
                        _groupByPayrollPeriod<
                          MapEntry<String, List<Map<String, dynamic>>>
                        >(groups.entries.toList(), (entry) {
                          final first = entry.value.first;
                          return parseIsoDate(
                                first['importDate']?.toString(),
                              ) ??
                              parseIsoDate(first['date']?.toString()) ??
                              parseIsoDate(
                                first['deductionStartDate']?.toString(),
                              );
                        }, widget.payrollMonthStartDay);
                    var allCash = 0.0;
                    var allFawryApproved = 0.0;
                    var allFawryCommission = 0.0;
                    var allTotal = 0.0;
                    for (final entry in groups.entries) {
                      final meta = _sheetMeta(entry.key, entry.value);
                      allCash += (meta['cashAmount'] as num?)?.toDouble() ?? 0;
                      allFawryApproved +=
                          (meta['fawryApprovedAmount'] as num?)?.toDouble() ??
                          0;
                      allFawryCommission +=
                          (meta['fawryCommissionAmount'] as num?)?.toDouble() ??
                          0;
                      allTotal +=
                          (meta['totalAmount'] as num?)?.toDouble() ?? 0;
                    }
                    return Column(
                      children: [
                        Expanded(
                          child: ListView(
                            children: [
                              for (final period in periodBuckets.entries)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _PayrollPeriodBlock(
                                    periodKey: period.key,
                                    cash: period.value.fold<double>(0, (
                                      sum,
                                      e,
                                    ) {
                                      final meta = _sheetMeta(e.key, e.value);
                                      return sum +
                                          ((meta['cashAmount'] as num?)
                                                  ?.toDouble() ??
                                              0);
                                    }),
                                    fawryApproved: period.value.fold<double>(
                                      0,
                                      (sum, e) {
                                        final meta = _sheetMeta(e.key, e.value);
                                        return sum +
                                            ((meta['fawryApprovedAmount']
                                                        as num?)
                                                    ?.toDouble() ??
                                                0);
                                      },
                                    ),
                                    fawryCommission: period.value.fold<double>(
                                      0,
                                      (sum, e) {
                                        final meta = _sheetMeta(e.key, e.value);
                                        return sum +
                                            ((meta['fawryCommissionAmount']
                                                        as num?)
                                                    ?.toDouble() ??
                                                0);
                                      },
                                    ),
                                    total: period.value.fold<double>(0, (
                                      sum,
                                      e,
                                    ) {
                                      final meta = _sheetMeta(e.key, e.value);
                                      return sum +
                                          ((meta['totalAmount'] as num?)
                                                  ?.toDouble() ??
                                              0);
                                    }),
                                    onExportPeriod: widget.onExportPeriod,
                                    sheetCount: period.value.length,
                                    children: [
                                      for (final entry in period.value)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: Builder(
                                            builder: (context) {
                                              final first = entry.value.first;
                                              final manual =
                                                  entry.key == '__manual__';
                                              final meta = _sheetMeta(
                                                entry.key,
                                                entry.value,
                                              );
                                              final primary =
                                                  meta['primaryLocationName']
                                                      ?.toString() ??
                                                  context.t('adv.noBranch');
                                              final title = manual
                                                  ? context.t(
                                                      'adv.manualAdvances',
                                                    )
                                                  : _sheetHeadline(
                                                      first['importReference']
                                                              ?.toString() ??
                                                          context.t(
                                                            'adv.advanceSheet',
                                                          ),
                                                      primary: primary,
                                                      locationCount:
                                                          _locationCountOf(
                                                            meta,
                                                          ),
                                                    );
                                              final outsiders =
                                                  (meta['outsiderLines']
                                                              as List? ??
                                                          [])
                                                      .whereType<Map>()
                                                      .map(
                                                        (e) =>
                                                            Map<
                                                              String,
                                                              dynamic
                                                            >.from(e),
                                                      )
                                                      .toList();
                                              final fawry =
                                                  _fawryTotalsFromMeta(meta);
                                              return SellixCard(
                                                padding: EdgeInsets.zero,
                                                child: ExpansionTile(
                                                  initiallyExpanded: false,
                                                  title: Text.rich(
                                                    TextSpan(
                                                      children: [
                                                        TextSpan(
                                                          text: title,
                                                          style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 14.5,
                                                            color: AppColors
                                                                .textPrimary,
                                                          ),
                                                        ),
                                                        const TextSpan(
                                                          text: '  ·  ',
                                                          style: TextStyle(
                                                            color: AppColors
                                                                .textMuted,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontSize: 12.5,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text: context.t(
                                                            'adv.primaryLocation',
                                                            {'name': primary},
                                                          ),
                                                          style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontSize: 12.5,
                                                            color: AppColors
                                                                .textSecondary,
                                                          ),
                                                        ),
                                                        const TextSpan(
                                                          text: '  ·  ',
                                                          style: TextStyle(
                                                            color: AppColors
                                                                .textMuted,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontSize: 12.5,
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text:
                                                              '${context.t('adv.employeeCount', {'count': entry.value.length})}'
                                                              '${manual ? '' : ' • ${first['importDate'] ?? ''}'}',
                                                          style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontSize: 12.5,
                                                            color: AppColors
                                                                .textSecondary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  subtitle: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                        ),
                                                    child: _moneyBreakdownText(
                                                      context,
                                                      cash:
                                                          (meta['cashAmount']
                                                                  as num?)
                                                              ?.toDouble() ??
                                                          0,
                                                      fawryApproved:
                                                          fawry.approved,
                                                      fawryCommission:
                                                          fawry.commission,
                                                      fawryTotal: fawry.total,
                                                      total:
                                                          (meta['totalAmount']
                                                                  as num?)
                                                              ?.toDouble() ??
                                                          0,
                                                    ),
                                                  ),
                                                  children: [
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.fromLTRB(
                                                            12,
                                                            0,
                                                            12,
                                                            8,
                                                          ),
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerRight,
                                                        child: OutlinedButton(
                                                          onPressed: () =>
                                                              _showOutsiderEmployees(
                                                                context,
                                                                outsiders,
                                                                primary,
                                                              ),
                                                          child: Text(
                                                            context.t(
                                                              'adv.outsideBranchEmployees',
                                                              {
                                                                'count':
                                                                    meta['outsiderCount'] ??
                                                                    outsiders
                                                                        .length,
                                                              },
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const Divider(height: 1),
                                                    _AdvanceList(
                                                      items: entry.value,
                                                      isLong: false,
                                                      onRefresh:
                                                          widget.onRefresh,
                                                      embedded: true,
                                                      duplicateEmployees:
                                                          duplicates,
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _cashFawryFooter(
                          context,
                          cash: allCash,
                          fawryApproved: allFawryApproved,
                          fawryCommission: allFawryCommission,
                          total: allTotal,
                          sheetCount: groups.length,
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _LongAdvanceList extends StatefulWidget {
  const _LongAdvanceList({
    required this.items,
    required this.onRefresh,
    this.onCreateLong,
  });

  final List<Map<String, dynamic>> items;
  final VoidCallback onRefresh;
  final VoidCallback? onCreateLong;

  @override
  State<_LongAdvanceList> createState() => _LongAdvanceListState();
}

class _LongAdvanceListState extends State<_LongAdvanceList> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items.where((a) {
      final code = a['employeeCode']?.toString().toLowerCase() ?? '';
      final name = a['employeeName']?.toString().toLowerCase() ?? '';
      return code.contains(q) || name.contains(q);
    }).toList();
  }

  bool _canCancel(Map<String, dynamic> a) {
    final state = _advanceStateRaw(a);
    return (state == 'draft' || state == 'running') &&
        _advanceInt(a['paidInstallments']) == 0;
  }

  bool _canConfirmLong(Map<String, dynamic> a) =>
      _advanceStateRaw(a) == 'draft';

  bool _canEditLong(Map<String, dynamic> a) => a['canEdit'] == true;

  bool _canStopLong(Map<String, dynamic> a) => a['canStop'] == true;

  bool _canAdjustRemaining(Map<String, dynamic> a) =>
      a['canAdjustRemaining'] == true;

  bool _canRetryOdoo(Map<String, dynamic> a) {
    final state = _advanceStateRaw(a);
    return (state == 'running' || state == 'done') && a['odooMoveId'] == null;
  }

  Future<void> _editLongAdvance(Map<String, dynamic> a) async {
    final ok = await showLongAdvanceEditDialog(context, a);
    if (ok == true) {
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t('adv.edited'))));
      }
    }
  }

  Future<void> _adjustRemaining(Map<String, dynamic> a) async {
    final ok = await showLongAdvanceAdjustRemainingDialog(context, a);
    if (ok == true) {
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t('adv.adjusted'))));
      }
    }
  }

  Future<void> _confirmStop(Map<String, dynamic> a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('adv.stopConfirmTitle')),
        content: Text(ctx.t('adv.stopConfirmBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('adv.no')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('adv.stop')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.advanceLongStop(a['id']);
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t('adv.stopped'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _confirmCancel(Map<String, dynamic> a) async {
    final name = a['employeeName']?.toString() ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('adv.cancelAdvance')),
        content: Text(
          ctx.t('adv.cancelConfirm', {
            'name': name,
            'amount': _money(a['totalAmount'] as num?),
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('adv.no')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('adv.cancelAdvance')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.advanceLongCancel(a['id']);
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t('adv.cancelled'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _confirmLongAdvance(Map<String, dynamic> a) async {
    try {
      final activated = await api.advanceLongConfirm(a['id']);
      widget.onRefresh();
      if (mounted) {
        final sent = activated['odooMoveId'] != null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t(
                sent ? 'adv.activatedOdooSent' : 'adv.activatedOdooFailed',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _retryOdoo(Map<String, dynamic> a) async {
    try {
      await api.advanceLongSendToOdoo(a['id']);
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t('adv.odooRetryDone'))));
      }
    } catch (e) {
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('adv.codeCopied', {'code': code}))),
      );
    }
  }

  Widget _detailCell(String label, String value, {bool bold = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> a) {
    final state = _advanceStateRaw(a);
    final stateLabel = _advanceStateLabel(context, state, isLong: true);
    final code = a['employeeCode']?.toString() ?? '';
    final startDate =
        a['startDate']?.toString() ?? a['date']?.toString() ?? '—';
    final notes = a['notes']?.toString().trim() ?? '';
    final odooSent = a['odooMoveId'] != null;
    final odooError = a['odooSyncError']?.toString().trim() ?? '';
    final odooMoveName = a['odooMoveName']?.toString().trim() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SellixCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a['employeeName']?.toString() ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.2,
                        ),
                      ),
                      if (code.isNotEmpty)
                        InkWell(
                          onTap: () => _copyCode(code),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  context.t('adv.code', {'code': code}),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(
                                  Icons.copy_outlined,
                                  size: 12,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                StatusTag(label: stateLabel, type: _advanceStateTag(state)),
                if (state != 'draft') ...[
                  const SizedBox(width: 6),
                  StatusTag(
                    label: context.t(
                      odooSent ? 'adv.odooSent' : 'adv.odooPending',
                    ),
                    type: odooSent ? StatusTagType.info : StatusTagType.warning,
                  ),
                ],
                if (_canConfirmLong(a) ||
                    _canEditLong(a) ||
                    _canAdjustRemaining(a) ||
                    _canStopLong(a) ||
                    _canCancel(a) ||
                    _canRetryOdoo(a))
                  PopupMenuButton<String>(
                    tooltip: context.t('adv.actions'),
                    padding: EdgeInsets.zero,
                    onSelected: (action) async {
                      switch (action) {
                        case 'confirm':
                          await _confirmLongAdvance(a);
                        case 'edit':
                          await _editLongAdvance(a);
                        case 'adjust':
                          await _adjustRemaining(a);
                        case 'stop':
                          await _confirmStop(a);
                        case 'cancel':
                          await _confirmCancel(a);
                        case 'retryOdoo':
                          await _retryOdoo(a);
                      }
                    },
                    itemBuilder: (_) => [
                      if (_canConfirmLong(a))
                        PopupMenuItem(
                          value: 'confirm',
                          child: Text(context.t('adv.activateRunning')),
                        ),
                      if (_canEditLong(a))
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(context.t('adv.edit')),
                        ),
                      if (_canAdjustRemaining(a))
                        PopupMenuItem(
                          value: 'adjust',
                          child: Text(context.t('adv.adjustRemaining')),
                        ),
                      if (_canStopLong(a))
                        PopupMenuItem(
                          value: 'stop',
                          child: Text(context.t('adv.stop')),
                        ),
                      if (_canCancel(a))
                        PopupMenuItem(
                          value: 'cancel',
                          child: Text(context.t('adv.cancel')),
                        ),
                      if (_canRetryOdoo(a))
                        PopupMenuItem(
                          value: 'retryOdoo',
                          child: Text(context.t('adv.odooRetry')),
                        ),
                    ],
                    icon: const Icon(Icons.more_vert, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _detailCell(
                  context.t('adv.total'),
                  _money(a['totalAmount'] as num?),
                  bold: true,
                ),
                _detailCell(
                  context.t('adv.installments'),
                  '${a['installments'] ?? 0}',
                ),
                _detailCell(
                  context.t('adv.installmentAmount'),
                  _money(a['installmentAmount'] as num?),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _detailCell(
                  context.t('adv.paid'),
                  _money(a['paidAmount'] as num?),
                ),
                _detailCell(
                  context.t('adv.remaining'),
                  _money(a['remainingAmount'] as num?),
                  bold: true,
                ),
                _detailCell(
                  context.t('adv.remainingInstallments'),
                  '${a['remainingInstallments'] ?? 0}',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _detailCell(context.t('adv.deductionStart'), startDate),
                _detailCell(
                  context.t('adv.date'),
                  a['date']?.toString() ?? '—',
                ),
                _detailCell(
                  context.t('adv.paidInstallments'),
                  '${a['paidInstallments'] ?? 0}',
                ),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                context.t('adv.notesLine', {'value': notes}),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.25,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (odooSent && odooMoveName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                context.t('adv.odooMove', {'name': odooMoveName}),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ] else if (odooError.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                context.t('adv.odooError', {'error': odooError}),
                style: const TextStyle(fontSize: 11, color: AppColors.danger),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return HrEmptyListCard(
        message: context.t('adv.noLongAdvances'),
        actionLabel: widget.onCreateLong != null
            ? context.t('adv.createLong')
            : null,
        onAction: widget.onCreateLong,
      );
    }

    final filtered = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: context.t('adv.searchCodeName'),
            prefixIcon: const Icon(Icons.search, size: 20),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                context.t('adv.noSearchResults'),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) => _buildCard(filtered[i]),
            ),
          ),
      ],
    );
  }
}

class _AdvanceList extends StatelessWidget {
  const _AdvanceList({
    required this.items,
    required this.isLong,
    required this.onRefresh,
    this.embedded = false,
    this.duplicateEmployees = const <String>{},
    this.onCreateLong,
  });
  final List<Map<String, dynamic>> items;
  final bool isLong;
  final VoidCallback onRefresh;
  final bool embedded;
  final Set<String> duplicateEmployees;
  final VoidCallback? onCreateLong;

  bool _canCancel(Map<String, dynamic> a) {
    final state = _advanceStateRaw(a);
    if (!isLong) {
      return _isShortPending(a) &&
          a['payrollId'] == null &&
          a['isDeducted'] != true;
    }
    return (state == 'draft' || state == 'running') &&
        _advanceInt(a['paidInstallments']) == 0;
  }

  bool _canConfirmLong(Map<String, dynamic> a) {
    return isLong && _advanceStateRaw(a) == 'draft';
  }

  bool _canEditLong(Map<String, dynamic> a) {
    return isLong && a['canEdit'] == true;
  }

  Future<void> _editLongAdvance(
    BuildContext context,
    Map<String, dynamic> a,
  ) async {
    final ok = await showLongAdvanceEditDialog(context, a);
    if (ok == true) {
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t('adv.edited'))));
      }
    }
  }

  Future<void> _confirmCancel(
    BuildContext context,
    Map<String, dynamic> a,
  ) async {
    final name = a['employeeName']?.toString() ?? '';
    final amount = isLong ? a['totalAmount'] : a['amount'];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('adv.cancelAdvance')),
        content: Text(
          ctx.t('adv.cancelConfirm', {
            'name': name,
            'amount': _money(amount as num?),
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('adv.no')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('adv.cancelAdvance')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (isLong) {
        await api.advanceLongCancel(a['id']);
      } else {
        await api.advanceShortCancel(a['id']);
      }
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t('adv.cancelled'))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _confirmLongAdvance(
    BuildContext context,
    Map<String, dynamic> a,
  ) async {
    try {
      await api.advanceLongConfirm(a['id']);
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t('adv.activated'))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showDetail(BuildContext context, Map<String, dynamic> a) {
    final state = _advanceStateRaw(a);
    final stateLabel = _advanceStateLabel(context, state, isLong: isLong);
    final payrollId = a['payrollId']?.toString();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t(isLong ? 'adv.longAdvance' : 'adv.shortAdvance'),
              style: Theme.of(
                ctx,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (!isLong && _isShortPending(a) && payrollId == null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  context.t('adv.pendingNote'),
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
            ],
            _detailRow(
              context.t('adv.employee'),
              a['employeeName']?.toString() ?? '',
            ),
            if ((a['employeeCode']?.toString() ?? '').isNotEmpty)
              _detailRow(
                context.t('adv.employeeCode'),
                a['employeeCode']?.toString() ?? '',
              ),
            _detailRow(context.t('adv.state'), stateLabel),
            _detailRow(context.t('adv.date'), a['date']?.toString() ?? ''),
            _detailRow(
              context.t('adv.deductionStart'),
              a['deductionStartDate']?.toString() ??
                  a['startDate']?.toString() ??
                  '—',
            ),
            if (isLong) ...[
              _detailRow(
                context.t('adv.total'),
                _money(a['totalAmount'] as num?),
              ),
              _detailRow(
                context.t('adv.installments'),
                '${a['installments'] ?? 0}',
              ),
              _detailRow(
                context.t('adv.installmentAmount'),
                _money(a['installmentAmount'] as num?),
              ),
              _detailRow(
                context.t('adv.paid'),
                _money(a['paidAmount'] as num?),
              ),
              _detailRow(
                context.t('adv.remaining'),
                _money(a['remainingAmount'] as num?),
              ),
              _detailRow(
                context.t('adv.remainingInstallments'),
                '${a['remainingInstallments'] ?? 0}',
              ),
            ] else ...[
              _detailRow(context.t('adv.amount'), _money(a['amount'] as num?)),
              if (a['isDeducted'] == true)
                _detailRow(context.t('adv.deducted'), context.t('adv.yes')),
            ],
            if (a['notes'] != null && a['notes'].toString().isNotEmpty)
              _detailRow(context.t('adv.notes'), a['notes'].toString()),
            if (payrollId != null && payrollId.isNotEmpty)
              _detailRow(context.t('adv.payroll'), payrollId),
            const SizedBox(height: 16),
            if (payrollId != null && payrollId.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('${AppRoutes.hrPayroll}/$payrollId');
                },
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: Text(context.t('adv.openPayroll')),
              )
            else if (!isLong && _isShortPending(a))
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go(AppRoutes.hrPayroll);
                },
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: Text(context.t('adv.openPayrolls')),
              ),
            if (_canConfirmLong(a)) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _confirmLongAdvance(context, a);
                },
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text(context.t('adv.activateRunning')),
              ),
            ],
            if (_canEditLong(a)) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _editLongAdvance(context, a);
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(context.t('adv.edit')),
              ),
            ],
            if (_canCancel(a)) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _confirmCancel(context, a);
                },
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: Text(context.t('adv.cancelAdvance')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return HrEmptyListCard(
        message: isLong
            ? context.t('adv.noLongAdvances')
            : context.t('adv.noShortAdvances'),
        actionLabel: isLong && onCreateLong != null
            ? context.t('adv.createLong')
            : null,
        onAction: isLong ? onCreateLong : null,
      );
    }

    final list = ListView.builder(
      shrinkWrap: embedded,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      itemCount: items.length,
      itemBuilder: (_, i) {
        final a = items[i];
        final state = _advanceStateRaw(a);
        final stateLabel = _advanceStateLabel(context, state, isLong: isLong);
        final title = isLong
            ? context.t('adv.longSummary', {
                'name': a['employeeName'],
                'amount': _money(a['totalAmount'] as num?),
                'count': a['remainingInstallments'] ?? '?',
              })
            : '${a['employeeName']} — ${_money(a['amount'] as num?)}';
        final subtitle = isLong
            ? context.t('adv.longSubline', {
                'start': a['startDate'] ?? a['date'],
                'remaining': _money(a['remainingAmount'] as num?),
                'installment': _money(a['installmentAmount'] as num?),
              })
            : context.t('adv.shortSubline', {
                'start': a['deductionStartDate'] ?? a['date'],
                'notes': a['notes'] ?? '',
              });
        final employeeKey = _ShortAdvanceGroupedListState._employeeKey(a);
        final isDuplicate =
            employeeKey.isNotEmpty && duplicateEmployees.contains(employeeKey);
        return ListTile(
          title: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (isDuplicate) ...[
                const SizedBox(width: 8),
                StatusTag(
                  label: context.t('adv.duplicateAcrossSheets'),
                  type: StatusTagType.danger,
                ),
              ],
            ],
          ),
          subtitle: Text(subtitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusTag(
                label: stateLabel,
                type: _advanceStateTag(
                  state == 'confirmed' ? 'pending' : state,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: context.t('adv.actions'),
                onSelected: (action) async {
                  switch (action) {
                    case 'confirm':
                      await _confirmLongAdvance(context, a);
                    case 'edit':
                      await _editLongAdvance(context, a);
                    case 'cancel':
                      await _confirmCancel(context, a);
                    case 'detail':
                      _showDetail(context, a);
                  }
                },
                itemBuilder: (ctx) => [
                  if (_canConfirmLong(a))
                    PopupMenuItem(
                      value: 'confirm',
                      child: ListTile(
                        leading: const Icon(
                          Icons.check_circle_outline,
                          color: AppColors.primary,
                        ),
                        title: Text(context.t('adv.activateRunning')),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (_canEditLong(a))
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: Text(context.t('adv.edit')),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (_canCancel(a))
                    PopupMenuItem(
                      value: 'cancel',
                      child: ListTile(
                        leading: const Icon(
                          Icons.cancel_outlined,
                          color: AppColors.danger,
                        ),
                        title: Text(context.t('adv.cancelAdvance')),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  PopupMenuItem(
                    value: 'detail',
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(context.t('adv.details')),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert, size: 20),
              ),
            ],
          ),
          onTap: () => _showDetail(context, a),
        );
      },
    );
    if (embedded) return list;
    return SellixCard(padding: EdgeInsets.zero, child: list);
  }
}
