import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/money_format.dart';
import 'payroll_line_edit_model.dart';
import '../../l10n/l10n_extension.dart';

/// Improved payroll-line editor: grouped sections, search, live net preview.
class PayrollLineEditDialog extends StatefulWidget {
  const PayrollLineEditDialog({
    super.key,
    required this.line,
    this.onFixBasicSalary,
  });

  final Map<String, dynamic> line;

  /// When basic is 0 — optional fix callback (API). Returns true on success.
  final Future<bool> Function()? onFixBasicSalary;

  @override
  State<PayrollLineEditDialog> createState() => _PayrollLineEditDialogState();
}

class _PayrollLineEditDialogState extends State<PayrollLineEditDialog> {
  late final Map<String, TextEditingController> _controllers;
  late final TextEditingController _search;
  late final Map<String, bool> _expanded;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final initial = initialPayrollLineEditValues(widget.line);
    _controllers = {
      for (final e in initial.entries) e.key: TextEditingController(text: e.value),
    };
    for (final c in _controllers.values) {
      c.addListener(_onChanged);
    }
    _search = TextEditingController();
    _expanded = {
      for (final s in kPayrollLineEditSections) s.id: s.initiallyExpanded,
    };
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.removeListener(_onChanged);
      c.dispose();
    }
    _search.dispose();
    super.dispose();
  }

  Map<String, String> get _texts => {
        for (final e in _controllers.entries) e.key: e.value.text,
      };

  Map<String, dynamic> get _payload => buildPayrollLineUpdatePayload(_texts);

  PayrollLineEditPreview get _preview => previewPayrollLineEdit(_payload);

  void _save() => Navigator.pop(context, _payload);

  Future<void> _fixBasic() async {
    final fn = widget.onFixBasicSalary;
    if (fn == null) return;
    final ok = await fn();
    if (ok && mounted) Navigator.pop(context, {'__fixBasic': true});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = widget.line['employeeName']?.toString() ?? '';
    final code = widget.line['employeeCode']?.toString() ?? '';
    final basicZero = (widget.line['basicSalary'] as num? ?? 0) == 0;
    final sections = filterPayrollLineEditSections(_query, label: context.t);
    final preview = _preview;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? context.t('payEd.title') : name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (code.isNotEmpty)
                      Text(
                        context.t('search.code', {'code': code}),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.t('common.close'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              isDense: true,
              hintText: context.t('payEd.searchFields'),
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 520,
        child: Column(
          children: [
            _PreviewBar(preview: preview),
            const SizedBox(height: 8),
            Expanded(
              child: sections.isEmpty
                  ? Center(child: Text(context.t('payEd.noFields')))
                  : ListView(
                      children: [
                        for (final section in sections)
                          _SectionCard(
                            key: ValueKey(
                              '${section.id}_${_query.isNotEmpty}_${_expanded[section.id]}',
                            ),
                            section: section,
                            expanded: _query.isNotEmpty
                                ? true
                                : (_expanded[section.id] ?? false),
                            onExpansionChanged: (open) {
                              setState(() => _expanded[section.id] = open);
                            },
                            controllers: _controllers,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        if (basicZero && widget.onFixBasicSalary != null)
          TextButton(
            onPressed: _fixBasic,
            child: Text(context.t('payEd.fixBasic')),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton(onPressed: _save, child: Text(context.t('common.save'))),
      ],
    );
  }
}

class _PreviewBar extends StatelessWidget {
  const _PreviewBar({required this.preview});
  final PayrollLineEditPreview preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget cell(String label, double value, {bool emphasize = false}) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              formatMoney(value),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                color: emphasize ? theme.colorScheme.primary : null,
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            cell(context.t('pay.earnings'), preview.totalEarnings),
            cell(context.t('pay.deductions'), preview.totalDeductions),
            cell(context.t('payEd.netPreview'), preview.netSalary, emphasize: true),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
    required this.section,
    required this.expanded,
    required this.onExpansionChanged,
    required this.controllers,
  });

  final PayrollLineEditSection section;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final Map<String, TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey('${section.id}_$expanded'),
        initiallyExpanded: expanded,
        onExpansionChanged: onExpansionChanged,
        maintainState: true,
        title: Text(
          context.t(section.titleKey),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(context.t('payEd.fieldCount', {'count': section.fields.length})),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          for (final field in section.fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: field.isNotes
                  ? TextField(
                      controller: controllers[field.key],
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: context.t(field.labelKey),
                        alignLabelWithHint: true,
                        border: const OutlineInputBorder(),
                      ),
                    )
                  : TextField(
                      controller: controllers[field.key],
                      decoration: InputDecoration(
                        labelText: context.t(field.labelKey),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: false,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\- ]')),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}
