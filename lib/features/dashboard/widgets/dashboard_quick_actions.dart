import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme_v2.dart';
import '../../../l10n/l10n_extension.dart';

class DashboardQuickAction {
  const DashboardQuickAction({
    required this.label,
    required this.description,
    required this.icon,
    required this.route,
    this.tone = QuickActionTone.primary,
    this.badge,
  });

  final String label;
  final String description;
  final IconData icon;
  final String route;
  final QuickActionTone tone;
  final String? badge;
}

enum QuickActionTone { primary, success, warning, info }

class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({super.key, required this.actions});

  final List<DashboardQuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 640
            ? 2
            : 1;

        // A single column is a list, not a grid. Sizing it by aspect ratio ties
        // the tile's height to the phone's width, so a long description either
        // gets clipped or leaves a band of empty card under a short one. Laid
        // out as a column each tile is exactly as tall as its own text.
        if (crossCount == 1) {
          return Column(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const Gap(12),
                _QuickActionTile(action: actions[i], compact: true),
              ],
            ],
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.1,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) =>
              _QuickActionTile(action: actions[index]),
        );
      },
    );
  }

  static List<DashboardQuickAction> branchManagerActions(
    BuildContext context, {
    int hiringUnread = 0,
  }) => [
    DashboardQuickAction(
      label: context.t('qa.hiring'),
      description: context.t('qa.hiringBranchDesc'),
      icon: Icons.assignment_ind_outlined,
      route: AppRoutes.hrHiringAppointments,
      tone: QuickActionTone.primary,
      badge: hiringUnread > 0 ? '$hiringUnread' : null,
    ),
    DashboardQuickAction(
      label: context.t('qa.shifts'),
      description: context.t('qa.shiftsDesc'),
      icon: Icons.access_time_outlined,
      route: AppRoutes.hrShifts,
      tone: QuickActionTone.info,
    ),
    DashboardQuickAction(
      label: context.t('qa.shiftGrid'),
      description: context.t('qa.shiftGridDesc'),
      icon: Icons.grid_on_outlined,
      route: AppRoutes.hrShiftGrid,
      tone: QuickActionTone.success,
    ),
  ];

  static List<DashboardQuickAction> hrActions(
    BuildContext context, {
    int pendingRequests = 0,
    int healthCertAlerts = 0,
    int hiringUnread = 0,
    int unreadAbsences = 0,
  }) => [
    DashboardQuickAction(
      label: context.t('qa.addHiring'),
      description: context.t('qa.addHiringDesc'),
      icon: Icons.person_add_alt_1_outlined,
      route: AppRoutes.hrHiringAppointmentCreate,
      tone: QuickActionTone.info,
    ),
    DashboardQuickAction(
      label: context.t('qa.hiring'),
      description: context.t('qa.hiringDesc'),
      icon: Icons.assignment_ind_outlined,
      route: AppRoutes.hrHiringAppointments,
      tone: QuickActionTone.primary,
      badge: hiringUnread > 0 ? '$hiringUnread' : null,
    ),
    DashboardQuickAction(
      label: context.t('qa.employees'),
      description: context.t('qa.employeesDesc'),
      icon: Icons.people_outline_rounded,
      route: AppRoutes.hrEmployees,
      tone: QuickActionTone.primary,
    ),
    DashboardQuickAction(
      label: context.t('qa.absentEmployees'),
      description: context.t('qa.absentEmployeesDesc'),
      icon: Icons.person_off_outlined,
      route: AppRoutes.hrAbsentEmployees,
      tone: QuickActionTone.warning,
      badge: unreadAbsences > 0 ? '$unreadAbsences' : null,
    ),
    DashboardQuickAction(
      label: context.t('qa.healthCerts'),
      description: context.t('qa.healthCertsDesc'),
      icon: Icons.health_and_safety_outlined,
      route: AppRoutes.hrHealthCertificates,
      tone: QuickActionTone.warning,
      badge: healthCertAlerts > 0 ? '$healthCertAlerts' : null,
    ),
    DashboardQuickAction(
      label: context.t('qa.reports'),
      description: context.t('qa.reportsDesc'),
      icon: Icons.assessment_outlined,
      route: AppRoutes.hrReports,
      tone: QuickActionTone.info,
    ),
    DashboardQuickAction(
      label: context.t('qa.attendance'),
      description: context.t('qa.attendanceDesc'),
      icon: Icons.fact_check_outlined,
      route: AppRoutes.hrAttendance,
      tone: QuickActionTone.success,
    ),
    DashboardQuickAction(
      label: context.t('qa.payroll'),
      description: context.t('qa.payrollDesc'),
      icon: Icons.payments_outlined,
      route: AppRoutes.hrPayroll,
      tone: QuickActionTone.warning,
    ),
    DashboardQuickAction(
      label: context.t('qa.requests'),
      description: context.t('qa.requestsDesc'),
      icon: Icons.pending_actions_outlined,
      route: AppRoutes.requests,
      tone: QuickActionTone.info,
      badge: pendingRequests > 0 ? '$pendingRequests' : null,
    ),
  ];

  static List<DashboardQuickAction> employeeActions(BuildContext context) => [
    DashboardQuickAction(
      label: context.t('qa.myAttendance'),
      description: context.t('qa.myAttendanceDesc'),
      icon: Icons.schedule_outlined,
      route: AppRoutes.myAttendance,
      tone: QuickActionTone.primary,
    ),
    DashboardQuickAction(
      label: context.t('qa.mySchedule'),
      description: context.t('qa.myScheduleDesc'),
      icon: Icons.calendar_month_outlined,
      route: AppRoutes.mySchedule,
      tone: QuickActionTone.info,
    ),
  ];
}

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({required this.action, this.compact = false});

  final DashboardQuickAction action;

  /// Phone layout: the tile sizes itself to its text instead of a grid cell.
  final bool compact;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _hovered = false;

  (Color bg, Color fg) get _colors => switch (widget.action.tone) {
    QuickActionTone.success => (const Color(0xFFD1FAE5), AppThemeV2.success),
    QuickActionTone.warning => (const Color(0xFFFEF3C7), AppThemeV2.warning),
    QuickActionTone.info => (const Color(0xFFCFFAFE), AppThemeV2.info),
    QuickActionTone.primary => (AppThemeV2.primarySoft, AppThemeV2.primary),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(widget.action.route),
          borderRadius: BorderRadius.circular(AppThemeV2.cardRadius),
          child: AnimatedContainer(
            duration: AppThemeV2.normal,
            curve: Curves.easeOutQuart,
            padding: EdgeInsets.all(widget.compact ? 14 : 16),
            decoration: BoxDecoration(
              color: AppThemeV2.surface,
              borderRadius: BorderRadius.circular(AppThemeV2.cardRadius),
              border: Border.all(
                color: _hovered
                    ? fg.withValues(alpha: 0.35)
                    : AppThemeV2.border,
              ),
              boxShadow: _hovered
                  ? AppThemeV2.glowShadow
                  : AppThemeV2.cardShadow,
            ),
            child: Row(
              mainAxisSize: widget.compact
                  ? MainAxisSize.min
                  : MainAxisSize.max,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: widget.compact ? 40 : 44,
                      height: widget.compact ? 40 : 44,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.action.icon,
                        color: fg,
                        size: widget.compact ? 20 : 22,
                      ),
                    ),
                    if (widget.action.badge != null)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppThemeV2.danger,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            widget.action.badge!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: AppThemeV2.headline.fontFamily,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Gap(widget.compact ? 12 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: widget.compact
                        ? MainAxisSize.min
                        : MainAxisSize.max,
                    children: [
                      Text(
                        widget.action.label,
                        style: AppThemeV2.title.copyWith(
                          fontSize: widget.compact ? 15.5 : 17,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(2),
                      Text(
                        widget.action.description,
                        style: AppThemeV2.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Gap(widget.compact ? 6 : 0),
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 14,
                  color: _hovered ? fg : AppThemeV2.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
