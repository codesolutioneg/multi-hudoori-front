import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';
import '../../l10n/l10n_extension.dart';

bool isMissionPendingState(String? state) => state == 'pending_branch';

StatusTagType missionStateTag(String? state) {
  switch (state) {
    case 'approved':
      return StatusTagType.success;
    case 'rejected':
    case 'cancelled':
      return StatusTagType.danger;
    default:
      return StatusTagType.warning;
  }
}

String missionStateLabel(BuildContext context, String? state) =>
    state == null || state.isEmpty ? '' : context.t('mission.state.$state');

/// One request row, shared by the employee's history and the BM approval queue.
class FieldMissionRequestCard extends StatelessWidget {
  const FieldMissionRequestCard({
    super.key,
    required this.request,
    this.showEmployee = false,
    this.onCancel,
    this.actions = const [],
  });

  final Map<String, dynamic> request;
  final bool showEmployee;
  final VoidCallback? onCancel;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = request['state']?.toString();
    final createdAt = request['createdAt']?.toString() ?? '';
    final dateFrom = request['dateFrom']?.toString() ?? '';
    final dateTo = request['dateTo']?.toString() ?? '';

    return SellixCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  showEmployee
                      ? [
                          request['employeeName']?.toString() ?? '',
                          if ((request['employeeCode']?.toString() ?? '').isNotEmpty)
                            '(${request['employeeCode']})',
                        ].join(' ')
                      : (request['details']?.toString() ?? ''),
                  style: theme.textTheme.titleMedium,
                  maxLines: showEmployee ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusTag(
                label: missionStateLabel(context, state),
                type: missionStateTag(state),
              ),
            ],
          ),
          if (showEmployee) ...[
            const SizedBox(height: AppDimensions.spaceXs),
            Text(
              request['details']?.toString() ?? '',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: AppDimensions.spaceXs),
          Wrap(
            spacing: AppDimensions.spaceMd,
            runSpacing: AppDimensions.spaceXs,
            children: [
              if (dateFrom.isNotEmpty || dateTo.isNotEmpty)
                Text(
                  '${context.t('mission.dates')}: $dateFrom → $dateTo',
                  style: theme.textTheme.bodySmall,
                ),
              if (createdAt.length >= 10)
                Text(
                  '${context.t('mission.requestedAt')}: ${createdAt.substring(0, 10)}',
                  style: theme.textTheme.bodySmall,
                ),
              if ((request['locationName']?.toString() ?? '').isNotEmpty)
                Text(request['locationName'].toString(), style: theme.textTheme.bodySmall),
            ],
          ),
          if ((request['rejectionReason']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.spaceXs),
              child: Text(
                '${context.t('mission.rejectReason')}: ${request['rejectionReason']}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          if (actions.isNotEmpty || onCancel != null) ...[
            const SizedBox(height: AppDimensions.spaceSm),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppDimensions.spaceSm,
              children: [
                if (onCancel != null)
                  TextButton(
                    onPressed: onCancel,
                    child: Text(context.t('mission.cancel')),
                  ),
                ...actions,
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Prompt for a rejection reason. Returns null when cancelled.
Future<String?> askMissionReason(BuildContext context, String label) async {
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(label),
      content: TextField(
        controller: ctrl,
        maxLines: 2,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.t('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.t('common.confirm')),
        ),
      ],
    ),
  );
  final text = ctrl.text.trim();
  ctrl.dispose();
  return ok == true ? text : null;
}
