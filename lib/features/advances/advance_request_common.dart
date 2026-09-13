import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/widgets/api_error_view.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';
import '../../l10n/l10n_extension.dart';

num asNum(Object? value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

String money(Object? value) => asNum(value).toStringAsFixed(2);

/// A request nobody has approved or rejected yet.
bool isPendingState(String? state) =>
    state == 'pending_branch' || state == 'pending_hr';

StatusTagType advanceStateTag(String? state) {
  switch (state) {
    case 'approved':
      return StatusTagType.success;
    case 'rejected':
    case 'cancelled':
      return StatusTagType.danger;
    case 'pending_hr':
      return StatusTagType.info;
    default:
      return StatusTagType.warning;
  }
}

String advanceStateLabel(BuildContext context, String? state) =>
    state == null || state.isEmpty ? '' : context.t('advReq.state.$state');

/// The entitlement breakdown shown above the request form and inside the
/// approval dialog, so requester and approver read the same numbers.
class EligibilityCard extends StatelessWidget {
  const EligibilityCard({super.key, required this.eligibility, this.compact = false});

  final Map<String, dynamic> eligibility;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final eligible = eligibility['isEligible'] == true;
    final theme = Theme.of(context);

    final rows = <Widget>[
      _row(context, context.t('advReq.available'), money(eligibility['availableAmount']), bold: true),
      _row(context, context.t('advReq.maxEligible'), money(eligibility['maxEligibleAmount'])),
      if (!compact) ...[
        _row(context, context.t('advReq.basicSalary'), money(eligibility['basicSalary'])),
        _row(context, context.t('advReq.workingDays'), '${asNum(eligibility['actualWorkingDays'])}'),
        _row(context, context.t('advReq.minimumDays'), '${asNum(eligibility['minimumWorkingDays'])}'),
      ],
      if (asNum(eligibility['pendingShortTotal']) +
              asNum(eligibility['runningLongRemaining']) +
              asNum(eligibility['draftLongTotal']) >
          0)
        _row(
          context,
          context.t('advReq.committed'),
          money(asNum(eligibility['pendingShortTotal']) +
              asNum(eligibility['runningLongRemaining']) +
              asNum(eligibility['draftLongTotal'])),
        ),
      if (asNum(eligibility['pendingRequestTotal']) > 0)
        _row(context, context.t('advReq.pendingRequests'), money(eligibility['pendingRequestTotal'])),
      if (!compact && (eligibility['periodLabel']?.toString().isNotEmpty ?? false))
        _row(context, context.t('advReq.period'), eligibility['periodLabel'].toString()),
    ];

    return SellixCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(context.t('advReq.eligibility'), style: theme.textTheme.titleMedium),
              ),
              if (!eligible)
                StatusTag(
                  label: context.t('advReq.notEligible'),
                  type: StatusTagType.danger,
                ),
            ],
          ),
          if (!eligible)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.spaceXs),
              child: Text(
                context.t('advReq.notEligibleHint', {
                  'days': '${asNum(eligibility['actualWorkingDays'])}',
                  'min': '${asNum(eligibility['minimumWorkingDays'])}',
                }),
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: AppDimensions.spaceSm),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool bold = false}) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            value,
            style: bold ? style?.copyWith(fontWeight: FontWeight.w700) : style,
          ),
        ],
      ),
    );
  }
}

/// One request row, shared by the employee's history and the approval queue.
class AdvanceRequestCard extends StatelessWidget {
  const AdvanceRequestCard({
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
                      : money(request['amount']),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              StatusTag(label: advanceStateLabel(context, state), type: advanceStateTag(state)),
            ],
          ),
          if (showEmployee)
            Text(
              '${context.t('advReq.requestedAmount')}: ${money(request['amount'])}',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: AppDimensions.spaceXs),
          Text(request['reason']?.toString() ?? '', style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppDimensions.spaceXs),
          Wrap(
            spacing: AppDimensions.spaceMd,
            runSpacing: AppDimensions.spaceXs,
            children: [
              if (createdAt.length >= 10)
                Text(
                  '${context.t('advReq.requestedAt')}: ${createdAt.substring(0, 10)}',
                  style: theme.textTheme.bodySmall,
                ),
              if ((request['locationName']?.toString() ?? '').isNotEmpty)
                Text(request['locationName'].toString(), style: theme.textTheme.bodySmall),
              if (asNum(request['availableAtRequest']) > 0)
                Text(
                  '${context.t('advReq.availableAtRequest')}: ${money(request['availableAtRequest'])}',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
          if ((request['rejectionReason']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.spaceXs),
              child: Text(
                '${context.t('advReq.rejectReason')}: ${request['rejectionReason']}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          if ((request['overrideReason']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.spaceXs),
              child: Text(
                '${context.t('advReq.overrideReason')}: ${request['overrideReason']}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (actions.isNotEmpty || onCancel != null) ...[
            const SizedBox(height: AppDimensions.spaceSm),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppDimensions.spaceSm,
              children: [
                if (onCancel != null)
                  TextButton(onPressed: onCancel, child: Text(context.t('advReq.cancel'))),
                ...actions,
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class AdvanceApproveResult {
  const AdvanceApproveResult({required this.amount, required this.limitOverride, this.overrideReason});

  final num amount;
  final bool limitOverride;
  final String? overrideReason;
}

/// HR's grant dialog. It reloads the entitlement excluding this request so the
/// approver sees what is genuinely left, not a figure this request blocks itself.
class AdvanceApproveDialog extends StatefulWidget {
  const AdvanceApproveDialog({super.key, required this.request});

  final Map<String, dynamic> request;

  @override
  State<AdvanceApproveDialog> createState() => AdvanceApproveDialogState();
}

class AdvanceApproveDialogState extends State<AdvanceApproveDialog> {
  late final TextEditingController _amountCtrl =
      TextEditingController(text: money(widget.request['amount']));
  final _overrideCtrl = TextEditingController();

  Map<String, dynamic>? _eligibility;
  bool _loading = true;
  bool _override = false;

  @override
  void initState() {
    super.initState();
    _loadEligibility();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _overrideCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEligibility() async {
    try {
      final data = await api.advanceRequestEligibility(
        employeeId: widget.request['employeeId'],
        excludeRequestId: widget.request['id'],
      );
      if (mounted) setState(() { _eligibility = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = num.tryParse(_amountCtrl.text.trim()) ?? 0;
    final available = asNum(_eligibility?['availableAmount']);
    final exceeds = _eligibility != null && amount > available + 0.009;

    return AlertDialog(
      title: Text(
        context.t('advReq.approveTitle', {
          'name': widget.request['employeeName']?.toString() ?? '',
        }),
      ),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const Center(child: Padding(
                padding: EdgeInsets.all(AppDimensions.spaceLg),
                child: CircularProgressIndicator(),
              ))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_eligibility != null)
                      EligibilityCard(eligibility: _eligibility!, compact: true),
                    const SizedBox(height: AppDimensions.spaceSm),
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: context.t('advReq.approveAmount'),
                        helperText: context.t('advReq.approveHint'),
                      ),
                    ),
                    if (exceeds) ...[
                      const SizedBox(height: AppDimensions.spaceSm),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _override,
                        onChanged: (v) => setState(() => _override = v ?? false),
                        title: Text(context.t('advReq.limitOverride')),
                      ),
                      if (_override)
                        TextField(
                          controller: _overrideCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: context.t('advReq.overrideReason'),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton(
          onPressed: _loading || amount <= 0 || (exceeds && !_override)
              ? null
              : () {
                  if (exceeds && _overrideCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.t('advReq.overrideRequired'))),
                    );
                    return;
                  }
                  Navigator.pop(
                    context,
                    AdvanceApproveResult(
                      amount: amount,
                      limitOverride: exceeds && _override,
                      overrideReason: exceeds ? _overrideCtrl.text.trim() : null,
                    ),
                  );
                },
          child: Text(context.t('advReq.approve')),
        ),
      ],
    );
  }
}

/// Prompt for the written reason a rejection (or an override) needs.
/// Returns null when the approver backs out, an empty string when they confirm
/// without typing anything — the caller decides whether that is acceptable.
Future<String?> askAdvanceReason(BuildContext context, String label) async {
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

/// Requests their branch has vouched for, waiting on HR to grant or refuse.
///
/// This is HR's whole involvement in the flow, and it lives inside «السلف»
/// rather than on its own page: approving is what creates the advance, so the
/// decision belongs next to the sheet the advance lands on.
class HrAdvanceRequestsReview extends StatefulWidget {
  const HrAdvanceRequestsReview({super.key, this.onApproved});

  /// Lets the host refresh its own advance lists once a grant creates one.
  final Future<void> Function()? onApproved;

  @override
  State<HrAdvanceRequestsReview> createState() => _HrAdvanceRequestsReviewState();
}

class _HrAdvanceRequestsReviewState extends State<HrAdvanceRequestsReview> {
  List<Map<String, dynamic>> _requests = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await api.advanceRequestList(state: 'pending_hr');
      if (mounted) setState(() { _requests = rows; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e; });
    }
  }

  Future<void> _run(Future<void> Function() action, String successKey) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t(successKey))),
      );
      await _load();
      await widget.onApproved?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(context, e))),
        );
      }
    }
  }

  Future<void> _approve(Map<String, dynamic> request) async {
    final result = await showDialog<AdvanceApproveResult>(
      context: context,
      builder: (_) => AdvanceApproveDialog(request: request),
    );
    if (result == null) return;
    await _run(
      () => api
          .advanceRequestApprove(
            id: request['id'],
            amount: result.amount,
            limitOverride: result.limitOverride,
            overrideReason: result.overrideReason,
          )
          .then((_) {}),
      'advReq.approved',
    );
  }

  Future<void> _reject(Map<String, dynamic> request) async {
    final reason = await askAdvanceReason(context, context.t('advReq.rejectReason'));
    if (reason == null || reason.isEmpty) return;
    await _run(
      () => api.advanceRequestReject(id: request['id'], reason: reason).then((_) {}),
      'advReq.rejected',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ApiErrorView(error: _error!, onRetry: _load);

    if (_requests.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        children: [SellixCard(child: Text(context.t('advReq.noHrQueue')))],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      itemCount: _requests.length,
      itemBuilder: (_, i) {
        final r = _requests[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
          child: AdvanceRequestCard(
            request: r,
            showEmployee: true,
            actions: [
              TextButton(
                onPressed: () => _reject(r),
                child: Text(context.t('advReq.reject')),
              ),
              FilledButton(
                onPressed: () => _approve(r),
                child: Text(context.t('advReq.approve')),
              ),
            ],
          ),
        );
      },
    );
  }
}
