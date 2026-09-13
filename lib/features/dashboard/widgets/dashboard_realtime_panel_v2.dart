import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../core/theme/app_theme_v2.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/status_badge.dart';

class DashboardRealtimePanelV2 extends StatelessWidget {
  const DashboardRealtimePanelV2({
    super.key,
    required this.punches,
    this.onRefresh,
  });

  final List<Map<String, dynamic>> punches;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(context.t('panel.realtimeTitle'), style: AppThemeV2.title)),
              const StatusBadge(label: 'LIVE', tone: BadgeTone.online, pulse: true),
              if (onRefresh != null) ...[
                const Gap(8),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: AppThemeV2.textMuted),
                ),
              ],
            ],
          ),
          const Gap(16),
          Expanded(
            child: punches.isEmpty
                ? _buildEmptyState(context)
                : ListView.separated(
                    itemCount: punches.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: AppThemeV2.border,
                    ),
                    itemBuilder: (context, index) => _PunchItem(
                      punch: punches[index],
                      index: index,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fingerprint_outlined, size: 48, color: AppThemeV2.border),
          const Gap(16),
          Text(
            context.t('panel.noPunchesYet'),
            style: AppThemeV2.body.copyWith(color: AppThemeV2.textMuted),
          ),
          const Gap(4),
          Text(context.t('panel.syncHint'), style: AppThemeV2.caption),
        ],
      ),
    );
  }
}

class _PunchItem extends StatelessWidget {
  const _PunchItem({required this.punch, required this.index});

  final Map<String, dynamic> punch;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isIn = punch['punchType']?.toString() == 'Check In';
    final name = punch['employeeName']?.toString() ?? '—';
    final parts = name.split(' ').where((s) => s.isNotEmpty).toList();
    final initials = parts.take(2).map((s) => s[0]).join();

    final avatarBg = isIn ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7);
    final avatarBorder = isIn ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A);
    final accentColor = isIn ? AppThemeV2.success : AppThemeV2.warning;
    final timeBg = isIn ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: avatarBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: avatarBorder),
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppThemeV2.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppThemeV2.textPrimary,
                  ),
                ),
                const Gap(2),
                Text(
                  '${punch['deviceName'] ?? ''}  ·  ${punch['punchType'] ?? ''}',
                  style: AppThemeV2.caption,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: timeBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              punch['punchTime']?.toString() ?? '',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: index * 50))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.1, end: 0, duration: 300.ms);
  }
}
