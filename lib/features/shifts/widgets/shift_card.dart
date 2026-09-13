import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/shift_calculations.dart';
import '../../../core/widgets/sellix_card.dart';
import '../../../core/widgets/status_tag.dart';
import '../../../l10n/l10n_extension.dart';

class ShiftCard extends StatefulWidget {
  const ShiftCard({
    super.key,
    required this.shift,
    this.onTap,
    this.onDelete,
  });

  final Map<String, dynamic> shift;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  State<ShiftCard> createState() => _ShiftCardState();
}

class _ShiftCardState extends State<ShiftCard> {
  bool _hovering = false;

  String get _startDisplay =>
      widget.shift['startTimeDisplay']?.toString() ??
      ShiftCalculations.floatToDisplay((widget.shift['startTime'] as num?)?.toDouble() ?? 8);

  String get _endDisplay =>
      widget.shift['endTimeDisplay']?.toString() ??
      ShiftCalculations.floatToDisplay((widget.shift['endTime'] as num?)?.toDouble() ?? 17);

  bool get _overnight => widget.shift['isOvernight'] == true;

  double get _totalHours => (widget.shift['totalHours'] as num?)?.toDouble() ??
      ShiftCalculations.computeTotalHours(
        (widget.shift['startTime'] as num?)?.toDouble() ?? 8,
        (widget.shift['endTime'] as num?)?.toDouble() ?? 17,
        breakHours: (widget.shift['breakDuration'] as num?)?.toDouble() ?? 0,
      );

  int get _graceIn => int.tryParse('${widget.shift['gracePeriodIn'] ?? widget.shift['checkInGrace'] ?? 0}') ?? 0;
  int get _graceOut => int.tryParse('${widget.shift['gracePeriodOut'] ?? widget.shift['checkOutGrace'] ?? 0}') ?? 0;

  @override
  Widget build(BuildContext context) {
    final name = widget.shift['name']?.toString() ?? '';
    final code = widget.shift['code']?.toString() ?? '';
    final active = widget.shift['active'] != false;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: SellixCard(
        hover: true,
        onTap: widget.onTap,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _overnight ? Icons.nightlight_round : Icons.wb_sunny_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.muted,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              code,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (!active)
                            StatusTag(
                              label: context.t('shifts.inactive'),
                              type: StatusTagType.neutral,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.onDelete != null)
                  AnimatedOpacity(
                    opacity: _hovering ? 1 : 0.35,
                    duration: const Duration(milliseconds: 150),
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onDelete,
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                      tooltip: context.t('common.delete'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.muted.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    '$_startDisplay ← $_endDisplay',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      context.t('shifts.hoursShort', {'n': _totalHours}),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                StatusTag(
                  label: context.t('shifts.graceIn', {'n': _graceIn}),
                  type: StatusTagType.info,
                  dot: true,
                ),
                StatusTag(
                  label: context.t('shifts.graceOut', {'n': _graceOut}),
                  type: StatusTagType.info,
                  dot: true,
                ),
                if (_overnight)
                  StatusTag(
                    label: context.t('shifts.overnight'),
                    type: StatusTagType.warning,
                    dot: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
