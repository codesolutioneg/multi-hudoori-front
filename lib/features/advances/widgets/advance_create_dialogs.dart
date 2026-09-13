import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/employee_search_field.dart';
import '../../../l10n/l10n_extension.dart';
import 'advance_eligibility_section.dart';

String fmtAdvanceDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime firstOfNextMonth([DateTime? from]) {
  final base = from ?? DateTime.now();
  return DateTime(base.year, base.month + 1, 1);
}

Future<void> pickDateInto(BuildContext context, TextEditingController controller) async {
  final initial = DateTime.tryParse(controller.text.trim()) ?? DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
  if (picked != null) controller.text = fmtAdvanceDate(picked);
}

/// Opens long-advance create dialog. Returns true if at least one advance was saved.
Future<bool?> showLongAdvanceCreateDialog(
  BuildContext context, {
  String? initialDeductionStart,
  Object? payrollId,
  bool linkPayrollAfterSave = false,
  Future<void> Function()? onSaved,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => LongAdvanceFormDialog(
      initialDeductionStart: initialDeductionStart,
      payrollId: payrollId,
      linkPayrollAfterSave: linkPayrollAfterSave,
      onSaved: onSaved,
    ),
  );
}

Future<bool?> showShortAdvanceCreateDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const ShortAdvanceFormDialog(),
  );
}

class LongAdvanceFormDialog extends StatefulWidget {
  const LongAdvanceFormDialog({
    super.key,
    this.initialDeductionStart,
    this.payrollId,
    this.linkPayrollAfterSave = false,
    this.onSaved,
  });

  final String? initialDeductionStart;
  final Object? payrollId;
  final bool linkPayrollAfterSave;
  final Future<void> Function()? onSaved;

  @override
  State<LongAdvanceFormDialog> createState() => _LongAdvanceFormDialogState();
}

class _LongAdvanceFormDialogState extends State<LongAdvanceFormDialog> {
  String? _employeeId;
  String? _employeeLabel;
  final _total = TextEditingController();
  final _installments = TextEditingController(text: '6');
  final _deductionStart = TextEditingController();
  bool _saving = false;
  bool _savedAny = false;
  int _employeeSearchKey = 0;

  @override
  void initState() {
    super.initState();
    _deductionStart.text =
        widget.initialDeductionStart?.trim().isNotEmpty == true
            ? widget.initialDeductionStart!.trim()
            : fmtAdvanceDate(firstOfNextMonth());
  }

  @override
  void dispose() {
    _total.dispose();
    _installments.dispose();
    _deductionStart.dispose();
    super.dispose();
  }

  void _resetForNext() {
    _total.clear();
    _installments.text = '6';
    setState(() {
      _employeeId = null;
      _employeeLabel = null;
      _employeeSearchKey++;
    });
  }

  Future<void> _save({required bool activate}) async {
    if (_employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('advDlg.pickFromSearch'))),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final advance = await api.advanceLongCreate({
        'employeeId': _employeeId,
        'totalAmount': double.tryParse(_total.text) ?? 0,
        'installments': int.tryParse(_installments.text) ?? 1,
        'deductionStartDate': _deductionStart.text.trim(),
      });
      if (activate) {
        final id = advance['id'];
        if (id != null) await api.advanceLongConfirm(id);
      }
      if (widget.linkPayrollAfterSave &&
          widget.payrollId != null &&
          activate) {
        await api.payrollLinkLongAdvances(widget.payrollId!);
      }
      _savedAny = true;
      await widget.onSaved?.call();
      if (!mounted) return;
      setState(() => _saving = false);
      _resetForNext();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activate
                ? context.t('advDlg.savedActive')
                : context.t('advDlg.savedDraft'),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _close() => Navigator.pop(context, _savedAny ? true : null);

  @override
  Widget build(BuildContext context) {
    final total = double.tryParse(_total.text) ?? 0;
    final n = int.tryParse(_installments.text) ?? 1;
    final installmentPreview =
        (total > 0 && n > 0) ? formatMoneyField(total / n) : null;

    return AdvanceFormShell(
      title: context.t('advDlg.longTitle'),
      subtitle: widget.linkPayrollAfterSave
          ? context.t('advDlg.longSubtitleLink')
          : context.t('advDlg.longSubtitle'),
      icon: Icons.calendar_month_outlined,
      saving: _saving,
      onCancel: _close,
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => _save(activate: false),
          child: Text(context.t('advDlg.saveDraft')),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _save(activate: true),
          child: Text(context.t(widget.linkPayrollAfterSave ? 'advDlg.saveActivateLink' : 'advDlg.saveActivate')),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdvanceFormSection(
            title: context.t('advDlg.employeeSearch'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EmployeeSearchField(
                  key: ValueKey(_employeeSearchKey),
                  onSelected: (id, label) => setState(() {
                    _employeeId = id;
                    _employeeLabel = label;
                  }),
                ),
                if (_employeeLabel != null && _employeeLabel!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _employeeLabel!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          AdvanceFormSection(
            title: context.t('advDlg.instalmentsSection'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _total,
                  decoration: InputDecoration(labelText: context.t('advDlg.totalAmount')),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _installments,
                  decoration: InputDecoration(labelText: context.t('advDlg.instalmentCount')),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                if (installmentPreview != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.payments_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.t('advDlg.monthlyInstalment', {'amount': installmentPreview}),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: _deductionStart,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: context.t('advDlg.deductionStart'),
                    helperText: context.t('advDlg.deductionStartHintLong'),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.event_outlined, size: 18),
                      onPressed: () => pickDateInto(context, _deductionStart),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Edit long advance while no instalment is on a confirmed payroll sheet.
Future<bool?> showLongAdvanceEditDialog(
  BuildContext context,
  Map<String, dynamic> advance,
) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => LongAdvanceEditDialog(advance: advance),
  );
}

class LongAdvanceEditDialog extends StatefulWidget {
  const LongAdvanceEditDialog({super.key, required this.advance});

  final Map<String, dynamic> advance;

  @override
  State<LongAdvanceEditDialog> createState() => _LongAdvanceEditDialogState();
}

class _LongAdvanceEditDialogState extends State<LongAdvanceEditDialog> {
  late final TextEditingController _total;
  late final TextEditingController _installments;
  late final TextEditingController _deductionStart;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.advance;
    _total = TextEditingController(
      text: a['totalAmount'] is num ? formatMoneyField(a['totalAmount'] as num) : '',
    );
    _installments = TextEditingController(text: '${a['installments'] ?? 6}');
    _deductionStart = TextEditingController(
      text: (a['startDate'] ?? a['date'] ?? '').toString(),
    );
  }

  @override
  void dispose() {
    _total.dispose();
    _installments.dispose();
    _deductionStart.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await api.advanceLongUpdate(widget.advance['id'], {
        'totalAmount': double.tryParse(_total.text) ?? 0,
        'installments': int.tryParse(_installments.text) ?? 1,
        'deductionStartDate': _deductionStart.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.advance;
    final total = double.tryParse(_total.text) ?? 0;
    final n = int.tryParse(_installments.text) ?? 1;
    final installmentPreview =
        (total > 0 && n > 0) ? formatMoneyField(total / n) : null;
    final paid = a['paidAmount'];
    final paidInstallments = a['paidInstallments'];

    return AdvanceFormShell(
      title: context.t('advDlg.editLongTitle'),
      subtitle: context.t('advDlg.editLongSubtitle'),
      icon: Icons.edit_outlined,
      saving: _saving,
      onCancel: () => Navigator.pop(context),
      actions: [
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(context.t('advDlg.saveEdits')),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdvanceFormSection(
            title: context.t('advDlg.employee'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a['employeeName']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if ((a['employeeCode']?.toString() ?? '').isNotEmpty)
                  Text(
                    context.t('advDlg.code', {'code': a['employeeCode']}),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (paid is num && paid > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                context.t('advDlg.paidSoFar', {'amount': formatMoneyField(paid), 'count': paidInstallments}),
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ),
          ],
          const SizedBox(height: 12),
          AdvanceFormSection(
            title: context.t('advDlg.instalmentsSection'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _total,
                  decoration: InputDecoration(labelText: context.t('advDlg.totalAmount')),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _installments,
                  decoration: InputDecoration(labelText: context.t('advDlg.instalmentCount')),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                if (installmentPreview != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.t('advDlg.monthlyInstalment', {'amount': installmentPreview}),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: _deductionStart,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: context.t('advDlg.deductionStart'),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.event_outlined, size: 18),
                      onPressed: () => pickDateInto(context, _deductionStart),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool?> showLongAdvanceAdjustRemainingDialog(
  BuildContext context,
  Map<String, dynamic> advance,
) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => LongAdvanceAdjustRemainingDialog(advance: advance),
  );
}

class LongAdvanceAdjustRemainingDialog extends StatefulWidget {
  const LongAdvanceAdjustRemainingDialog({super.key, required this.advance});

  final Map<String, dynamic> advance;

  @override
  State<LongAdvanceAdjustRemainingDialog> createState() =>
      _LongAdvanceAdjustRemainingDialogState();
}

class _LongAdvanceAdjustRemainingDialogState
    extends State<LongAdvanceAdjustRemainingDialog> {
  late final TextEditingController _remaining;
  late final TextEditingController _remainingInstallments;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.advance;
    _remaining = TextEditingController(
      text: a['remainingAmount'] is num
          ? formatMoneyField(a['remainingAmount'] as num)
          : '',
    );
    _remainingInstallments = TextEditingController(
      text: '${a['remainingInstallments'] ?? 1}',
    );
  }

  @override
  void dispose() {
    _remaining.dispose();
    _remainingInstallments.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await api.advanceLongAdjustRemaining(
        widget.advance['id'],
        remainingAmount: double.tryParse(_remaining.text) ?? 0,
        remainingInstallments: int.tryParse(_remainingInstallments.text) ?? 0,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.advance;
    final remaining = double.tryParse(_remaining.text) ?? 0;
    final n = int.tryParse(_remainingInstallments.text) ?? 0;
    final installmentPreview =
        (remaining > 0 && n > 0) ? formatMoneyField(remaining / n) : null;
    final paid = a['paidAmount'];
    final paidInstallments = a['paidInstallments'];

    return AdvanceFormShell(
      title: context.t('advDlg.adjustRemainingTitle'),
      subtitle: context.t('advDlg.adjustRemainingSubtitle'),
      icon: Icons.tune_outlined,
      saving: _saving,
      onCancel: () => Navigator.pop(context),
      actions: [
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(context.t('advDlg.saveEdits')),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdvanceFormSection(
            title: context.t('advDlg.employee'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a['employeeName']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if ((a['employeeCode']?.toString() ?? '').isNotEmpty)
                  Text(
                    context.t('advDlg.code', {'code': a['employeeCode']}),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (paid is num) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                context.t('advDlg.paidLocked', {
                  'amount': formatMoneyField(paid),
                  'count': paidInstallments,
                }),
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ),
          ],
          const SizedBox(height: 12),
          AdvanceFormSection(
            title: context.t('advDlg.instalmentsSection'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _remaining,
                  decoration: InputDecoration(
                    labelText: context.t('advDlg.remainingAmount'),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _remainingInstallments,
                  decoration: InputDecoration(
                    labelText: context.t('advDlg.remainingInstallments'),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
                if (installmentPreview != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.t('advDlg.monthlyInstalment', {
                      'amount': installmentPreview,
                    }),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShortAdvanceFormDialog extends StatefulWidget {
  const ShortAdvanceFormDialog({super.key});

  @override
  State<ShortAdvanceFormDialog> createState() => _ShortAdvanceFormDialogState();
}

class _ShortAdvanceFormDialogState extends State<ShortAdvanceFormDialog> {
  String? _employeeId;
  String? _employeeLabel;
  final _amount = TextEditingController();
  final _grantDate = TextEditingController();
  final _deductionStart = TextEditingController();
  final _percent = TextEditingController(text: '25');
  final _overrideReason = TextEditingController();
  final _eligibilityKey = GlobalKey<AdvanceEligibilitySectionState>();
  bool _limitOverride = false;
  bool _saving = false;
  Map<String, dynamic>? _eligibility;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _grantDate.text = fmtAdvanceDate(today);
    _deductionStart.text = fmtAdvanceDate(firstOfNextMonth(today));
    _loadDefaultPercent();
  }

  Future<void> _loadDefaultPercent() async {
    try {
      final config = await api.configGet();
      final p = config['advanceDefaultPercent'];
      if (p != null && mounted) _percent.text = '$p';
    } catch (_) {}
  }

  @override
  void dispose() {
    _amount.dispose();
    _grantDate.dispose();
    _deductionStart.dispose();
    _percent.dispose();
    _overrideReason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('advDlg.pickFromSearchShort'))),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await api.advanceShortCreate({
        'employeeId': _employeeId,
        'amount': double.tryParse(_amount.text) ?? 0,
        'date': _grantDate.text.trim(),
        'deductionStartDate': _deductionStart.text.trim(),
        ...?_eligibilityKey.currentState?.eligibilityPayload(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _fillAvailableAmount() {
    final available = _eligibility?['availableAmount'];
    if (available is num && available > 0) {
      _amount.text = formatMoneyField(available);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdvanceFormShell(
      title: context.t('advDlg.shortTitle'),
      subtitle: context.t('advDlg.shortSubtitle'),
      icon: Icons.payments_outlined,
      saving: _saving,
      onCancel: () => Navigator.pop(context),
      actions: [
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(context.t('advDlg.savePending')),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdvanceFormSection(
            title: context.t('advDlg.employeeSearch'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EmployeeSearchField(
                  onSelected: (id, label) => setState(() {
                    _employeeId = id;
                    _employeeLabel = label;
                  }),
                ),
                if (_employeeLabel != null && _employeeLabel!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _employeeLabel!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_employeeId != null) ...[
            const SizedBox(height: 12),
            AdvanceFormSection(
              title: context.t('advDlg.eligibilitySection'),
              child: AdvanceEligibilitySection(
                key: _eligibilityKey,
                employeeId: _employeeId,
                percentController: _percent,
                limitOverride: _limitOverride,
                overrideReasonController: _overrideReason,
                onLimitOverrideChanged: (v) => setState(() => _limitOverride = v),
                onEligibilityChanged: (e) => setState(() => _eligibility = e),
              ),
            ),
          ],
          const SizedBox(height: 12),
          AdvanceFormSection(
            title: context.t('advDlg.amountDatesSection'),
            child: Column(
              children: [
                AmountWithAvailableField(
                  controller: _amount,
                  label: context.t('advDlg.amount'),
                  available: _eligibility?['availableAmount'],
                  onUseAvailable: _employeeId == null ? null : _fillAvailableAmount,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _grantDate,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: context.t('advDlg.advanceDate'),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      onPressed: () => pickDateInto(context, _grantDate),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _deductionStart,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: context.t('advDlg.deductionStart'),
                    helperText: context.t('advDlg.deductionStartHintShort'),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.event_outlined, size: 18),
                      onPressed: () => pickDateInto(context, _deductionStart),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdvanceFormShell extends StatelessWidget {
  const AdvanceFormShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.body,
    required this.actions,
    required this.onCancel,
    required this.saving,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget body;
  final List<Widget> actions;
  final VoidCallback onCancel;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: saving ? null : onCancel,
                    icon: const Icon(Icons.close),
                    tooltip: context.t('common.close'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: body,
              ),
            ),
            if (saving) const LinearProgressIndicator(minHeight: 2),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: saving ? null : onCancel,
                    child: Text(context.t('common.cancel')),
                  ),
                  const Spacer(),
                  ...[
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      actions[i],
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdvanceFormSection extends StatelessWidget {
  const AdvanceFormSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class AmountWithAvailableField extends StatelessWidget {
  const AmountWithAvailableField({
    super.key,
    required this.controller,
    required this.label,
    this.available,
    this.onUseAvailable,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final dynamic available;
  final VoidCallback? onUseAvailable;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final avail = available is num ? available as num : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => onChanged?.call(),
        ),
        if (avail != null && avail > 0 && onUseAvailable != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onUseAvailable,
              icon: const Icon(Icons.auto_fix_high, size: 16),
              label: Text(context.t('advDlg.useAvailable', {'amount': formatMoneyField(avail)})),
            ),
          ),
        ],
      ],
    );
  }
}
