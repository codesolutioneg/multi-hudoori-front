import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/layout/app_tab_bar_v2.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money_format.dart';
import '../../core/utils/payroll_month.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';
import '../../l10n/l10n_extension.dart';

import '../mobile/hudoori_loader.dart';
import '../mobile/mobile_tabbed_page.dart';
import '../mobile/mobile_ui.dart';
import '../../core/platform/mobile_platform.dart';
String _money(num? value) => formatMoney(value ?? 0);

const _fawryCommissionRate = 0.0015;

double _roundMoney(double value) => (value * 100).roundToDouble() / 100;

({double approved, double commission, double total}) _fawryTotalsFromItem(
  Map<String, dynamic> item,
) {
  final approved =
      (item['fawryApprovedAmount'] as num?)?.toDouble() ??
      (item['fawryAmount'] as num?)?.toDouble() ??
      0;
  final commission =
      (item['fawryCommissionAmount'] as num?)?.toDouble() ??
      _roundMoney(approved * _fawryCommissionRate);
  final total =
      (item['fawryAmount'] as num?)?.toDouble() ??
      _roundMoney(approved + commission);
  return (approved: approved, commission: commission, total: total);
}

String _fawryBreakdownLine(
  BuildContext context, {
  required double approved,
  required double commission,
  required double total,
}) =>
    '${context.t('fawryLine.noCommission', {'amount': _money(approved)})}'
    ' • ${context.t('fawryLine.commission', {'amount': _money(commission)})}'
    ' • ${context.t('fawryLine.total', {'amount': _money(total)})}';

String _cashPlusFawryApprovedLine(
  BuildContext context, {
  required double cash,
  required double fawryApproved,
}) => context.t('fawryLine.cashPlus', {
  'amount': _money(_roundMoney(cash + fawryApproved)),
});

const _moneyToneSequence = <Color>[
  Color(0xFF1E293B),
  Color(0xFF1E3A5F),
  Color(0xFF3F3F46),
  Color(0xFF164E63),
  Color(0xFF312E81),
  Color(0xFF3F2E1E),
  Color(0xFF14532D),
];

Widget _moneyBreakdownText(
  BuildContext context, {
  required double cash,
  required double fawryApproved,
  required double fawryCommission,
  required double fawryTotal,
  required double total,
  double fontSize = 11.5,
}) {
  if (isNativeMobile) {
    return MobileMoneySummary(
      total: total,
      cash: cash,
      fawry: fawryApproved,
      commission: fawryCommission,
      format: (v) => _money(v),
    );
  }
  final parts = [
    context.t('tips.cash', {'amount': _money(cash)}),
    context.t('fawryLine.noCommission', {'amount': _money(fawryApproved)}),
    context.t('fawryLine.commission', {'amount': _money(fawryCommission)}),
    context.t('fawryLine.total', {'amount': _money(fawryTotal)}),
    _cashPlusFawryApprovedLine(
      context,
      cash: cash,
      fawryApproved: fawryApproved,
    ),
    context.t('tips.total', {'amount': _money(total)}),
  ];
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

class TipsPage extends StatefulWidget {
  const TipsPage({super.key});

  @override
  State<TipsPage> createState() => _TipsPageState();
}

class _TipsPageState extends State<TipsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>> _drafts = [];
  List<Map<String, dynamic>> _locked = [];
  int _payrollMonthStartDay = 26;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
      final drafts = await api.advanceLoanImportListPayload(kind: 'tip');
      final locked = await api.advanceLoanImportListPayload(
        state: 'locked',
        kind: 'tip',
      );
      if (!mounted) return;
      setState(() {
        _drafts = (drafts['items'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _locked = (locked['items'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _payrollMonthStartDay =
            (locked['payrollMonthStartDay'] as num?)?.toInt() ??
            (drafts['payrollMonthStartDay'] as num?)?.toInt() ??
            26;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openImport({String? importId}) async {
    final q = importId == null
        ? ''
        : '?importId=${Uri.encodeQueryComponent(importId)}';
    await context.push('${AppRoutes.hrTipImport}$q');
    if (mounted) _load();
  }

  Widget _importCardMobile(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openImport(),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: MobileUi.card(r: 20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFB923C), Color(0xFFEA580C)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('tips.importFromSheet'),
                      style: MobileUi.text(14.5, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.t('m.tipsImportHint'),
                      style: MobileUi.text(12, weight: FontWeight.w500, color: MobileUi.muted, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: MobileUi.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_rounded, size: 18, color: MobileUi.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final header = PageHeader(
      title: context.t('tips.title'),
      icon: Icons.card_giftcard_outlined,
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        FilledButton.icon(
          onPressed: () => _openImport(),
          icon: const Icon(Icons.upload_file_outlined, size: 18),
          label: Text(context.t('tips.importFromSheet')),
        ),
      ],
    );
    final tabs = AppTabBarV2(
      controller: _tabs,
      tabs: [
        Tab(text: context.t('tips.tab.drafts')),
        Tab(text: context.t('tips.tab.locked')),
      ],
    );
    final body = _body(context);
    if (isNativeMobile) {
      return MobileTabbedPage(
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: context.t('tips.title'),
              icon: Icons.card_giftcard_outlined,
              actions: [
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
              ],
            ),
            const SizedBox(height: 12),
            _importCardMobile(context),
          ],
        ),
        tabBar: tabs,
        body: body,
      );
    }
    return AppPageScaffold(
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 16),
          tabs,
          const SizedBox(height: 16),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    return _loading
                ? const Center(child: HudooriLoader())
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _TipImportList(
                        items: _drafts,
                        emptyLabel: context.t('tips.emptyDrafts'),
                        onOpen: (id) => _openImport(importId: id),
                        onRefresh: _load,
                        payrollMonthStartDay: _payrollMonthStartDay,
                      ),
                      _TipImportList(
                        items: _locked,
                        emptyLabel: context.t('tips.emptyLocked'),
                        onOpen: (id) => _openImport(importId: id),
                        onRefresh: _load,
                        payrollMonthStartDay: _payrollMonthStartDay,
                      ),
                    ],
                  );
  }
}

class _TipImportList extends StatelessWidget {
  const _TipImportList({
    required this.items,
    required this.emptyLabel,
    required this.onOpen,
    required this.onRefresh,
    required this.payrollMonthStartDay,
  });

  final List<Map<String, dynamic>> items;
  final String emptyLabel;
  final Future<void> Function(String id) onOpen;
  final VoidCallback onRefresh;
  final int payrollMonthStartDay;

  List<MapEntry<String, List<Map<String, dynamic>>>> _groupedByPeriod() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final date = parseIsoDate(item['date']?.toString());
      if (date == null) continue;
      final range = payrollMonthRange(date, payrollMonthStartDay);
      final key =
          '${formatIsoDate(range.dateFrom)}|${formatIsoDate(range.dateTo)}';
      (grouped[key] ??= []).add(item);
    }
    final groups = grouped.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return groups;
  }

  Widget _tipTile(BuildContext context, Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final primary =
        item['primaryLocationName']?.toString() ??
        item['locationName']?.toString() ??
        context.t('tips.noBranch');
    final headline = '${item['reference'] ?? id} — $primary';
    final cash = (item['cashAmount'] as num?)?.toDouble() ?? 0;
    final fawry = _fawryTotalsFromItem(item);
    if (isNativeMobile) {
      final locked = item['state']?.toString() == 'locked';
      final l10n = context.l10n;
      return InkWell(
        onTap: id.isEmpty ? null : () => onOpen(id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const MobileIconBadge(icon: Icons.card_giftcard_rounded, size: 38, color: MobileTone.violet),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['reference'] ?? id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MobileUi.text(14.5, weight: FontWeight.w800, height: 1.3),
                        ),
                        Text(
                          primary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MobileUi.text(12, weight: FontWeight.w500, color: MobileUi.muted),
                        ),
                      ],
                    ),
                  ),
                  MobileChip(
                    label: locked ? context.t('tips.stateLocked') : context.t('tips.stateDraft'),
                    color: locked ? MobileTone.success : MobileTone.warning,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  MobileChip(
                    icon: Icons.people_alt_outlined,
                    label: l10n.t('m.employeesCount', {'n': item['lineCount'] ?? 0}),
                  ),
                  if ((item['date']?.toString() ?? '').isNotEmpty)
                    MobileChip(icon: Icons.event_outlined, label: item['date'].toString()),
                  MobileChip(
                    icon: Icons.payments_outlined,
                    color: MobileTone.success,
                    label: l10n.t('m.cashAmount', {'amount': _money(cash)}),
                  ),
                  MobileChip(
                    icon: Icons.bolt_rounded,
                    color: MobileTone.violet,
                    label: l10n.t('m.fawryAmount', {'amount': _money(fawry.total)}),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t('tips.total', {'amount': _money(item['totalAmount'] as num?)}),
                      style: MobileUi.text(14, weight: FontWeight.w800, color: MobileUi.primaryDeep),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: id.isEmpty ? null : () => onOpen(id),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(l10n.t('m.openSheet')),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return ListTile(
      onTap: id.isEmpty ? null : () => onOpen(id),
      leading: const Icon(
        Icons.card_giftcard_outlined,
        color: AppColors.primary,
      ),
      title: Text(
        headline,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      subtitle: Text(
        '${context.t('tips.primaryLocation', {'name': primary})}\n'
        '${context.t('tips.employeeCount', {'count': item['lineCount'] ?? 0})}'
        ' • ${item['date'] ?? ''}\n'
        '${context.t('tips.cash', {'amount': _money(cash)})}'
        ' • ${_fawryBreakdownLine(context, approved: fawry.approved, commission: fawry.commission, total: fawry.total)}'
        ' • ${_cashPlusFawryApprovedLine(context, cash: cash, fawryApproved: fawry.approved)}'
        ' • ${context.t('tips.total', {'amount': _money(item['totalAmount'] as num?)})}',
      ),
      isThreeLine: true,
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusTag(
            label: item['state']?.toString() == 'locked'
                ? context.t('tips.stateLocked')
                : context.t('tips.stateDraft'),
            type: item['state']?.toString() == 'locked'
                ? StatusTagType.success
                : StatusTagType.warning,
          ),
          FilledButton.icon(
            onPressed: id.isEmpty ? null : () => onOpen(id),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(context.t('tips.openSheet')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      if (isNativeMobile) {
        return ListView(
          children: [
            const SizedBox(height: 8),
            MobileEmptyState(icon: Icons.card_giftcard_rounded, message: emptyLabel),
          ],
        );
      }
      return SellixCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(emptyLabel),
          ),
        ),
      );
    }
    final groups = _groupedByPeriod();
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final group = groups[index];
          final parts = group.key.split('|');
          final from = parseIsoDate(parts.first) ?? DateTime.now();
          final to =
              parseIsoDate(parts.length > 1 ? parts[1] : parts.first) ?? from;
          final monthName = payrollCycleMonthName(
            to,
            Localizations.localeOf(context).languageCode,
          );
          var cash = 0.0;
          var fawryApproved = 0.0;
          var fawryCommission = 0.0;
          var fawryTotal = 0.0;
          var total = 0.0;
          for (final item in group.value) {
            cash += (item['cashAmount'] as num?)?.toDouble() ?? 0;
            final fawry = _fawryTotalsFromItem(item);
            fawryApproved += fawry.approved;
            fawryCommission += fawry.commission;
            fawryTotal += fawry.total;
            total +=
                (item['totalAmount'] as num?)?.toDouble() ??
                _roundMoney(
                  ((item['cashAmount'] as num?)?.toDouble() ?? 0) + fawry.total,
                );
          }
          cash = _roundMoney(cash);
          fawryApproved = _roundMoney(fawryApproved);
          fawryCommission = _roundMoney(fawryCommission);
          fawryTotal = _roundMoney(fawryTotal);
          total = _roundMoney(total);
          return SellixCard(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              initiallyExpanded: false,
              title: isNativeMobile
                  ? Row(
                      children: [
                        const MobileIconBadge(icon: Icons.calendar_month_rounded, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.t('tips.monthCycle', {'month': monthName}),
                                style: MobileUi.text(15.5, weight: FontWeight.w800, height: 1.3),
                              ),
                              Text(
                                context.t('tips.total', {'amount': _money(total)}),
                                style: MobileUi.text(13, weight: FontWeight.w700, color: MobileUi.primaryDeep),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('tips.monthCycle', {'month': monthName}),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _moneyBreakdownText(
                      context,
                      cash: cash,
                      fawryApproved: fawryApproved,
                      fawryCommission: fawryCommission,
                      fawryTotal: fawryTotal,
                      total: total,
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                context.t('tips.cycleSummary', {
                  'from': formatIsoDate(from),
                  'to': formatIsoDate(to),
                  'count': group.value.length,
                }),
              ),
              children: [
                const Divider(height: 1),
                for (var i = 0; i < group.value.length; i++) ...[
                  _tipTile(context, group.value[i]),
                  if (i < group.value.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
