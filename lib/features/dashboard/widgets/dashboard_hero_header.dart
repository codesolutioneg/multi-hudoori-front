import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme_v2.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/auth_state.dart';

class DashboardHeroHeader extends StatelessWidget {
  const DashboardHeroHeader({
    super.key,
    required this.auth,
    required this.onRefresh,
    this.isRefreshing = false,
    this.lastUpdated,
  });

  final AuthState auth;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final DateTime? lastUpdated;

  String get _displayName {
    if (auth.employeeName.isNotEmpty) return auth.employeeName;
    return auth.user?.name ?? '';
  }

  String _initials(AppLocalizations l10n) {
    final parts = _displayName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return l10n.isAr ? 'ح' : 'H';
    return parts.take(2).map((p) => p[0]).join();
  }

  String _roleLabel(AppLocalizations l10n) {
    if (auth.roles.isHrManager) return l10n.t('role.hrManager');
    if (auth.roles.isHrSupervisor) return l10n.t('role.hrSupervisor');
    if (auth.roles.isHrUser) return l10n.t('role.hrUser');
    if (auth.roles.isBranchManager) return l10n.t('role.branchManager');
    if (auth.roles.isEmployee) return l10n.t('role.employee');
    return auth.user?.role ?? l10n.t('role.user');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final localeCode = l10n.isAr ? 'ar' : 'en';
    final dateLabel = DateFormat('EEEE, d MMMM yyyy', localeCode).format(now);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Two thresholds, because they answer different questions. `stacked` is
        // whether the refresh button still fits beside the identity; `compact`
        // is whether this is phone-sized type and spacing. A 700px tablet wants
        // the first and not the second.
        final stacked = constraints.maxWidth < 720;
        final compact = constraints.maxWidth < 480;
        final greeting = l10n.greetingForHour(now.hour);

        final identity = Row(
          children: [
            _AvatarRing(initials: _initials(l10n), diameter: compact ? 52 : 64),
            Gap(compact ? 12 : 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting, style: AppThemeV2.caption),
                  const Gap(4),
                  Text(
                    _displayName.isEmpty ? l10n.t('common.welcome') : _displayName,
                    // 35.4 is a desktop headline. A four-part Arabic name at
                    // that size takes three lines on a phone, pushing the rest
                    // of the card off the first screen.
                    style: AppThemeV2.headline.copyWith(
                      fontSize: compact ? 22 : 30 * 1.18,
                      height: compact ? 1.25 : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Gap(compact ? 8 : 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusBadge(label: _roleLabel(l10n), tone: BadgeTone.info),
                      if (auth.employeeCode.isNotEmpty)
                        _MetaChip(
                          icon: Icons.badge_outlined,
                          label: '${l10n.t('common.code')} ${auth.employeeCode}',
                        ),
                      _MetaChip(
                        icon: Icons.calendar_today_outlined,
                        label: dateLabel,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );

        final actions = _HeaderActions(
          l10n: l10n,
          lastUpdated: lastUpdated,
          isRefreshing: isRefreshing,
          onRefresh: onRefresh,
        );

        return GlassCard(
          animated: false,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 24,
            vertical: compact ? 18 : 22,
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [identity, Gap(compact ? 14 : 16), actions],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: identity), const Gap(16), actions],
                ),
        );
      },
    );
  }
}

class _AvatarRing extends StatelessWidget {
  const _AvatarRing({required this.initials, this.diameter = 64});

  final String initials;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppThemeV2.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppThemeV2.primary.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2.5),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppThemeV2.surface,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
              fontFamily: AppThemeV2.headline.fontFamily,
              fontSize: diameter * 0.34,
              fontWeight: FontWeight.w700,
              color: AppThemeV2.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppThemeV2.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppThemeV2.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppThemeV2.textMuted),
          const Gap(6),
          Text(
            label,
            style: AppThemeV2.caption.copyWith(
              color: AppThemeV2.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.l10n,
    required this.onRefresh,
    required this.isRefreshing,
    this.lastUpdated,
  });

  final AppLocalizations l10n;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FilledButton.icon(
          onPressed: isRefreshing ? null : onRefresh,
          icon: isRefreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.refresh_rounded, size: 18),
          label: Text(isRefreshing ? l10n.t('common.refreshing') : l10n.t('common.refreshData')),
          style: FilledButton.styleFrom(
            backgroundColor: AppThemeV2.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (lastUpdated != null) ...[
          const Gap(8),
          Text(
            l10n.t('common.lastUpdate', {'time': l10n.formatTimeAgo(lastUpdated!)}),
            style: AppThemeV2.caption.copyWith(fontSize: 12),
          ),
        ],
      ],
    );
  }
}
