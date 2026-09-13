import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/layout/app_tab_bar_v2.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';
import '../../l10n/l10n_extension.dart';

String _money(num? value) => formatMoney(value ?? 0);

const _fawryCommissionRate = 0.0015;

double _roundMoney(double value) => (value * 100).roundToDouble() / 100;

({double approved, double commission, double total}) _fawryTotalsFromItem(
  Map<String, dynamic> item,
) {
  final approved = (item['fawryApprovedAmount'] as num?)?.toDouble() ??
      (item['fawryAmount'] as num?)?.toDouble() ??
      0;
  final commission = (item['fawryCommissionAmount'] as num?)?.toDouble() ??
      _roundMoney(approved * _fawryCommissionRate);
  final total = (item['fawryAmount'] as num?)?.toDouble() ??
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
}) =>
    context.t('fawryLine.cashPlus', {
      'amount': _money(_roundMoney(cash + fawryApproved)),
    });

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
      final drafts = await api.advanceLoanImportList(kind: 'tip');
      final locked = await api.advanceLoanImportList(
        state: 'locked',
        kind: 'tip',
      );
      if (!mounted) return;
      setState(() {
        _drafts = drafts;
        _locked = locked;
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

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
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
          ),
          const SizedBox(height: 16),
          AppTabBarV2(
            controller: _tabs,
            tabs: [
              Tab(text: context.t('tips.tab.drafts')),
              Tab(text: context.t('tips.tab.locked')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _TipImportList(
                        items: _drafts,
                        emptyLabel: context.t('tips.emptyDrafts'),
                        onOpen: (id) => _openImport(importId: id),
                        onRefresh: _load,
                      ),
                      _TipImportList(
                        items: _locked,
                        emptyLabel: context.t('tips.emptyLocked'),
                        onOpen: (id) => _openImport(importId: id),
                        onRefresh: _load,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TipImportList extends StatelessWidget {
  const _TipImportList({
    required this.items,
    required this.emptyLabel,
    required this.onOpen,
    required this.onRefresh,
  });

  final List<Map<String, dynamic>> items;
  final String emptyLabel;
  final Future<void> Function(String id) onOpen;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SellixCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(emptyLabel),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final item = items[index];
          final id = item['id']?.toString() ?? '';
          final primary =
              item['primaryLocationName']?.toString() ??
              item['locationName']?.toString() ??
              context.t('tips.noBranch');
          final headline = '${item['reference'] ?? id} — $primary';
          final cash = (item['cashAmount'] as num?)?.toDouble() ?? 0;
          final fawry = _fawryTotalsFromItem(item);
          return SellixCard(
            padding: EdgeInsets.zero,
            child: ListTile(
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
            ),
          );
        },
      ),
    );
  }
}
