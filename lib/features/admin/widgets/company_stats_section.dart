import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_v2.dart';
import '../../../core/utils/company_quota.dart';
import '../../../l10n/l10n_extension.dart';
import '../../dashboard/widgets/dashboard_stat_card_v2.dart';

class CompanyStatsGroup {
  const CompanyStatsGroup({required this.name, required this.count});

  /// Empty name = employees with no branch / department.
  final String name;
  final int count;

  static List<CompanyStatsGroup> listFrom(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((m) {
      final count = m['count'];
      return CompanyStatsGroup(
        name: m['name']?.toString() ?? '',
        count: count is num ? count.toInt() : int.tryParse('$count') ?? 0,
      );
    }).toList();
  }
}

class CompanyStats {
  const CompanyStats({
    required this.quota,
    required this.active,
    required this.archived,
    required this.locations,
    required this.departments,
  });

  final CompanyQuota quota;
  final int active;
  final int archived;
  final List<CompanyStatsGroup> locations;
  final List<CompanyStatsGroup> departments;

  factory CompanyStats.fromJson(Map<String, dynamic> json) {
    int asInt(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    final emp = json['employees'] is Map ? Map<String, dynamic>.from(json['employees'] as Map) : const {};
    final quota = json['quota'] is Map ? Map<String, dynamic>.from(json['quota'] as Map) : null;
    return CompanyStats(
      quota: CompanyQuota.fromJson(quota),
      active: asInt(emp['active']),
      archived: asInt(emp['archived']),
      locations: CompanyStatsGroup.listFrom(json['locations']),
      departments: CompanyStatsGroup.listFrom(json['departments']),
    );
  }
}

class CompanyStatsSection extends StatelessWidget {
  const CompanyStatsSection({super.key, required this.stats, this.companyName});

  final CompanyStats stats;
  final String? companyName;

  String _ofMax(BuildContext context, int? max) => max == null
      ? context.t('admin.stats.unlimited')
      : context.t('admin.stats.ofMax', {'max': max});

  @override
  Widget build(BuildContext context) {
    final q = stats.quota;
    final name = companyName?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          name.isEmpty ? context.t('admin.stats.title') : context.t('admin.stats.titleFor', {'name': name}),
          style: AppThemeV2.headline.copyWith(fontSize: 18),
        ),
        const Gap(14),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 1000 ? 4 : (c.maxWidth >= 600 ? 2 : 1);
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: cols == 1 ? 2.4 : 1.55,
              children: [
                DashboardStatCardV2(
                  title: context.t('admin.stats.activeEmployees'),
                  subtitle: context.t('admin.stats.archivedN', {'n': stats.archived}),
                  value: stats.active,
                  icon: Icons.groups_outlined,
                  tone: StatToneV2.primary,
                ),
                DashboardStatCardV2(
                  title: context.t('admin.stats.employeeSeats'),
                  subtitle: _ofMax(context, q.employeesMax),
                  value: q.employeesUsed,
                  icon: Icons.event_seat_outlined,
                  tone: q.employeesFull ? StatToneV2.danger : StatToneV2.success,
                ),
                DashboardStatCardV2(
                  title: context.t('admin.stats.userSeats'),
                  subtitle: _ofMax(context, q.usersMax),
                  value: q.usersUsed,
                  icon: Icons.admin_panel_settings_outlined,
                  tone: q.usersFull ? StatToneV2.danger : StatToneV2.info,
                ),
                DashboardStatCardV2(
                  title: context.t('admin.stats.branches'),
                  subtitle: context.t('admin.stats.departmentsN', {
                    'n': stats.departments.where((d) => d.name.isNotEmpty).length,
                  }),
                  value: stats.locations.where((l) => l.name.isNotEmpty).length,
                  icon: Icons.store_mall_directory_outlined,
                  tone: StatToneV2.warning,
                ),
              ],
            );
          },
        ),
        const Gap(14),
        LayoutBuilder(
          builder: (context, c) {
            final byBranch = _GroupPanel(
              title: context.t('admin.stats.byBranch'),
              icon: Icons.store_mall_directory_outlined,
              groups: stats.locations,
              emptyLabel: context.t('admin.stats.noBranch'),
            );
            final byDept = _GroupPanel(
              title: context.t('admin.stats.byDepartment'),
              icon: Icons.account_tree_outlined,
              groups: stats.departments,
              emptyLabel: context.t('admin.stats.noDepartment'),
            );
            if (c.maxWidth < 800) {
              return Column(children: [byBranch, const Gap(14), byDept]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: byBranch),
                const Gap(14),
                Expanded(child: byDept),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _GroupPanel extends StatelessWidget {
  const _GroupPanel({
    required this.title,
    required this.icon,
    required this.groups,
    required this.emptyLabel,
  });

  static const _maxRows = 12;

  final String title;
  final IconData icon;
  final List<CompanyStatsGroup> groups;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final top = groups.fold<int>(0, (m, g) => g.count > m ? g.count : m);
    final shown = groups.take(_maxRows).toList();
    final hidden = groups.length - shown.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const Gap(8),
              Expanded(child: Text(title, style: AppThemeV2.title.copyWith(fontSize: 15))),
            ],
          ),
          const Gap(12),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(context.t('admin.stats.noData'), style: AppThemeV2.caption),
            )
          else
            for (final g in shown) ...[
              _GroupRow(label: g.name.isEmpty ? emptyLabel : g.name, count: g.count, top: top),
              const Gap(10),
            ],
          if (hidden > 0)
            Text(context.t('admin.stats.moreN', {'n': hidden}), style: AppThemeV2.caption),
        ],
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.label, required this.count, required this.top});

  final String label;
  final int count;
  final int top;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppThemeV2.body),
            ),
            const Gap(8),
            Text('$count', style: AppThemeV2.body.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const Gap(4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: top == 0 ? 0 : count / top,
            minHeight: 6,
            backgroundColor: AppColors.muted,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
