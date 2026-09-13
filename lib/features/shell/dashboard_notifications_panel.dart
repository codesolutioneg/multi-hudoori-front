import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../l10n/l10n_extension.dart';

class DashboardNotificationItem {
  const DashboardNotificationItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.routeKey,
  });

  final String id;
  final String kind;
  final String title;
  final String subtitle;
  final String routeKey;

  factory DashboardNotificationItem.fromJson(Map<String, dynamic> json) {
    return DashboardNotificationItem(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      routeKey: json['routeKey']?.toString() ?? '',
    );
  }
}

class DashboardNotificationSection {
  const DashboardNotificationSection({
    required this.key,
    required this.label,
    required this.routeKey,
    required this.count,
    required this.items,
  });

  final String key;
  final String label;
  final String routeKey;
  final int count;
  final List<DashboardNotificationItem> items;

  factory DashboardNotificationSection.fromJson(Map<String, dynamic> json) {
    return DashboardNotificationSection(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      routeKey: json['routeKey']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      items: ((json['items'] as List?) ?? [])
          .whereType<Map>()
          .map(
            (e) => DashboardNotificationItem.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
  }
}

String dashboardNotificationRoute(String routeKey) {
  return switch (routeKey) {
    'requests' => AppRoutes.requests,
    'health_certificates' => AppRoutes.hrHealthCertificates,
    'hiring' => AppRoutes.hrHiringAppointments,
    'employees' => AppRoutes.hrEmployees,
    'absent_employees' => AppRoutes.hrAbsentEmployees,
    _ => AppRoutes.dashboard,
  };
}

Future<void> showDashboardNotificationsPanel(
  BuildContext context, {
  required List<DashboardNotificationSection> sections,
  required int totalCount,
  required Future<void> Function() onReadAll,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dashboard-notifications',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, _, __) => const SizedBox.shrink(),
    transitionBuilder: (ctx, animation, _, __) {
      final slide = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: SlideTransition(
          position: slide,
          child: _DashboardNotificationsSidePanel(
            sections: sections,
            totalCount: totalCount,
            onClose: () => Navigator.of(ctx).pop(),
            onReadAll: onReadAll,
          ),
        ),
      );
    },
  );
}

class _SectionStyle {
  const _SectionStyle({
    required this.bg,
    required this.fg,
    required this.accent,
  });
  final Color bg;
  final Color fg;
  final Color accent;
}

_SectionStyle _styleForSection(String key) {
  return switch (key) {
    'requests' => const _SectionStyle(
      bg: Color(0xFFE0F2FE),
      fg: Color(0xFF0369A1),
      accent: Color(0xFF0284C7),
    ),
    'health_certificates' => const _SectionStyle(
      bg: Color(0xFFFEF3C7),
      fg: Color(0xFFB45309),
      accent: Color(0xFFD97706),
    ),
    'hiring' => const _SectionStyle(
      bg: Color(0xFFEDE9FE),
      fg: Color(0xFF6D28D9),
      accent: Color(0xFF7C3AED),
    ),
    'no_punch' => const _SectionStyle(
      bg: Color(0xFFFEE2E2),
      fg: Color(0xFFB91C1C),
      accent: Color(0xFFDC2626),
    ),
    _ => _SectionStyle(
      bg: AppThemeV2.primarySoft,
      fg: AppThemeV2.primary,
      accent: AppThemeV2.primary,
    ),
  };
}

IconData _iconForSection(String key) {
  return switch (key) {
    'requests' => Icons.pending_actions_outlined,
    'health_certificates' => Icons.health_and_safety_outlined,
    'hiring' => Icons.assignment_ind_outlined,
    'no_punch' => Icons.fingerprint_outlined,
    _ => Icons.notifications_outlined,
  };
}

IconData _iconForItemKind(String kind) {
  return switch (kind) {
    'leave' => Icons.beach_access_outlined,
    'loan' => Icons.payments_outlined,
    'shift_change' => Icons.swap_horiz_rounded,
    'salary' => Icons.account_balance_wallet_outlined,
    'certificate' => Icons.description_outlined,
    'attendance_edit' => Icons.edit_calendar_outlined,
    'health_cert' => Icons.medical_services_outlined,
    'hiring_pending' => Icons.person_add_alt_1_outlined,
    'hiring_update' => Icons.update_outlined,
    'no_punch' => Icons.fingerprint_outlined,
    _ => Icons.circle_notifications_outlined,
  };
}

class _DashboardNotificationsSidePanel extends StatelessWidget {
  const _DashboardNotificationsSidePanel({
    required this.sections,
    required this.totalCount,
    required this.onClose,
    required this.onReadAll,
  });

  final List<DashboardNotificationSection> sections;
  final int totalCount;
  final VoidCallback onClose;
  final Future<void> Function() onReadAll;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final panelWidth = width > 900 ? 420.0 : (width * 0.92).clamp(320.0, 420.0);

    return Material(
      elevation: 16,
      shadowColor: Colors.black26,
      color: const Color(0xFFF8FAFC),
      child: SizedBox(
        width: panelWidth,
        height: MediaQuery.sizeOf(context).height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppThemeV2.primary.withValues(alpha: 0.12),
                    AppThemeV2.primarySoft,
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: AppThemeV2.border.withValues(alpha: 0.6),
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppThemeV2.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppThemeV2.primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('notif.panelTitle'),
                          style: AppThemeV2.title.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.t('notif.panelSubtitle', {'n': totalCount}),
                          style: AppThemeV2.caption.copyWith(
                            color: AppThemeV2.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: sections.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppThemeV2.border),
                              ),
                              child: Icon(
                                Icons.notifications_none_rounded,
                                size: 36,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              context.t('notif.empty'),
                              textAlign: TextAlign.center,
                              style: AppThemeV2.body.copyWith(
                                color: AppThemeV2.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      itemCount: sections.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final section = sections[index];
                        return _SectionBlock(
                          section: section,
                          style: _styleForSection(section.key),
                          icon: _iconForSection(section.key),
                          onOpenSection: () {
                            onClose();
                            context.go(
                              dashboardNotificationRoute(section.routeKey),
                            );
                          },
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: AppThemeV2.border.withValues(alpha: 0.7),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed: totalCount == 0
                    ? null
                    : () async {
                        await onReadAll();
                        onClose();
                      },
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: Text(context.t('notif.markAllRead')),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  backgroundColor: AppThemeV2.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.section,
    required this.style,
    required this.icon,
    required this.onOpenSection,
  });

  final DashboardNotificationSection section;
  final _SectionStyle style;
  final IconData icon;
  final VoidCallback onOpenSection;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppThemeV2.cardRadius),
        border: Border.all(color: AppThemeV2.border.withValues(alpha: 0.85)),
        boxShadow: AppThemeV2.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: style.bg.withValues(alpha: 0.55),
              border: Border(right: BorderSide(color: style.accent, width: 4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: style.accent.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(icon, color: style.fg, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: style.fg,
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 28),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppThemeV2.danger,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppThemeV2.danger.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${section.count}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // All items — outer panel ListView scrolls the full list
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Column(
              children: [
                for (var i = 0; i < section.items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: AppThemeV2.border.withValues(alpha: 0.6),
                    ),
                  _NotificationItemTile(
                    item: section.items[i],
                    accent: style.accent,
                    onTap: onOpenSection,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: TextButton.icon(
              onPressed: onOpenSection,
              icon: Icon(Icons.open_in_new_rounded, size: 16, color: style.fg),
              label: Text(
                context.t('notif.openSection'),
                style: TextStyle(color: style.fg, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                backgroundColor: style.bg.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationItemTile extends StatefulWidget {
  const _NotificationItemTile({
    required this.item,
    required this.accent,
    required this.onTap,
  });

  final DashboardNotificationItem item;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_NotificationItemTile> createState() => _NotificationItemTileState();
}

class _NotificationItemTileState extends State<_NotificationItemTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: _hovered
            ? widget.accent.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                // RTL: first child sits on the right — chevron as navigation affordance
                Icon(
                  Icons.chevron_left_rounded,
                  size: 20,
                  color: _hovered ? widget.accent : AppThemeV2.textMuted,
                ),
                const SizedBox(width: 6),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _iconForItemKind(widget.item.kind),
                    size: 16,
                    color: widget.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.item.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.item.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
