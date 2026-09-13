import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_format.dart';
import '../../../l10n/l10n_extension.dart';

/// Shared eligibility preview + period picker for short/long advance forms.
class AdvanceEligibilitySection extends StatefulWidget {
  const AdvanceEligibilitySection({
    super.key,
    required this.employeeId,
    required this.percentController,
    required this.onEligibilityChanged,
    this.limitOverride = false,
    this.onLimitOverrideChanged,
    this.overrideReasonController,
  });

  final String? employeeId;
  final TextEditingController percentController;
  final void Function(Map<String, dynamic>? eligibility) onEligibilityChanged;
  final bool limitOverride;
  final ValueChanged<bool>? onLimitOverrideChanged;
  final TextEditingController? overrideReasonController;

  @override
  State<AdvanceEligibilitySection> createState() => AdvanceEligibilitySectionState();
}

class AdvanceEligibilitySectionState extends State<AdvanceEligibilitySection> {
  List<Map<String, dynamic>> _grids = [];
  String? _shiftGridId;
  final _dateFrom = TextEditingController();
  final _dateTo = TextEditingController();
  bool _useCustomPeriod = false;
  bool _loadingGrids = true;
  bool _loadingPreview = false;
  Map<String, dynamic>? _eligibility;
  String? _previewError;

  @override
  void initState() {
    super.initState();
    widget.percentController.addListener(_schedulePreview);
    _loadGrids();
  }

  @override
  void didUpdateWidget(covariant AdvanceEligibilitySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employeeId != widget.employeeId) {
      _schedulePreview();
    }
  }

  @override
  void dispose() {
    widget.percentController.removeListener(_schedulePreview);
    _dateFrom.dispose();
    _dateTo.dispose();
    super.dispose();
  }

  Future<void> _loadGrids() async {
    try {
      final grids = await api.shiftGridList(limit: 50);
      if (!mounted) return;
      setState(() {
        _grids = grids;
        _loadingGrids = false;
        if (_shiftGridId == null && grids.isNotEmpty) {
          _shiftGridId = grids.first['id']?.toString();
        }
      });
      _schedulePreview();
    } catch (_) {
      if (mounted) setState(() => _loadingGrids = false);
    }
  }

  void _schedulePreview() {
    if (widget.employeeId == null) {
      setState(() {
        _eligibility = null;
        _previewError = null;
      });
      widget.onEligibilityChanged(null);
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 250), _fetchPreview);
  }

  Future<void> _fetchPreview() async {
    final employeeId = widget.employeeId;
    if (employeeId == null) return;
    setState(() {
      _loadingPreview = true;
      _previewError = null;
    });
    try {
      final body = <String, dynamic>{
        'employeeId': employeeId,
        'percent': double.tryParse(widget.percentController.text.trim()),
      };
      if (_useCustomPeriod) {
        if (_dateFrom.text.trim().isNotEmpty) body['dateFrom'] = _dateFrom.text.trim();
        if (_dateTo.text.trim().isNotEmpty) body['dateTo'] = _dateTo.text.trim();
      } else if (_shiftGridId != null) {
        body['shiftGridId'] = _shiftGridId;
      }
      final data = await api.advanceEligibilityPreview(body);
      final eligibility = Map<String, dynamic>.from(data['eligibility'] as Map? ?? data);
      if (!mounted) return;
      setState(() {
        _eligibility = eligibility;
        _loadingPreview = false;
      });
      widget.onEligibilityChanged(eligibility);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPreview = false;
        _previewError = e.toString();
        _eligibility = null;
      });
      widget.onEligibilityChanged(null);
    }
  }

  Map<String, dynamic> eligibilityPayload() {
    final body = <String, dynamic>{
      if (widget.percentController.text.trim().isNotEmpty)
        'eligibilityPercent': double.tryParse(widget.percentController.text.trim()),
      if (widget.limitOverride) 'limitOverride': true,
      if (widget.overrideReasonController != null && widget.limitOverride)
        'overrideReason': widget.overrideReasonController!.text.trim(),
    };
    if (_useCustomPeriod) {
      if (_dateFrom.text.trim().isNotEmpty) body['eligibilityDateFrom'] = _dateFrom.text.trim();
      if (_dateTo.text.trim().isNotEmpty) body['eligibilityDateTo'] = _dateTo.text.trim();
    } else if (_shiftGridId != null) {
      body['shiftGridId'] = _shiftGridId;
    }
    return body;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.percentController,
                decoration: InputDecoration(
                  labelText: context.t('advElig.percent'),
                  helperText: context.t('advElig.percentHint'),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.t('advElig.customPeriod'), style: const TextStyle(fontSize: 13)),
          subtitle: Text(context.t('advElig.customPeriodHint'), style: const TextStyle(fontSize: 11)),
          value: _useCustomPeriod,
          onChanged: (v) {
            setState(() => _useCustomPeriod = v);
            _schedulePreview();
          },
        ),
        if (_useCustomPeriod) ...[
          TextField(
            controller: _dateFrom,
            readOnly: true,
            decoration: InputDecoration(
              labelText: context.t('advElig.dateFrom'),
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    _dateFrom.text =
                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    _schedulePreview();
                  }
                },
              ),
            ),
          ),
          TextField(
            controller: _dateTo,
            readOnly: true,
            decoration: InputDecoration(
              labelText: context.t('advElig.dateTo'),
              suffixIcon: IconButton(
                icon: const Icon(Icons.event_outlined, size: 18),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    _dateTo.text =
                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    _schedulePreview();
                  }
                },
              ),
            ),
          ),
        ] else if (!_loadingGrids) ...[
          DropdownButtonFormField<String?>(
            isExpanded: true,
            value: _shiftGridId,
            decoration: InputDecoration(labelText: context.t('advElig.shiftGrid')),
            items: [
              for (final g in _grids)
                DropdownMenuItem(
                  value: g['id']?.toString(),
                  child: Text(
                    '${g['name'] ?? g['id']} (${g['dateFrom'] ?? ''} → ${g['dateTo'] ?? ''})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) {
              setState(() => _shiftGridId = v);
              _schedulePreview();
            },
          ),
        ],
        const SizedBox(height: 8),
        if (_loadingPreview)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (_previewError != null)
          Text(_previewError!, style: const TextStyle(color: AppColors.danger, fontSize: 12))
        else if (_eligibility != null)
          _EligibilityCard(eligibility: _eligibility!),
        if (widget.onLimitOverrideChanged != null) ...[
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('advElig.override'), style: const TextStyle(fontSize: 13)),
            subtitle: Text(context.t('advElig.overrideHint'), style: const TextStyle(fontSize: 11)),
            value: widget.limitOverride,
            onChanged: (v) => widget.onLimitOverrideChanged?.call(v ?? false),
          ),
          if (widget.limitOverride && widget.overrideReasonController != null)
            TextField(
              controller: widget.overrideReasonController,
              decoration: InputDecoration(labelText: context.t('advElig.overrideReason')),
              maxLines: 2,
            ),
        ],
      ],
    );
  }
}

class _EligibilityCard extends StatelessWidget {
  const _EligibilityCard({required this.eligibility});
  final Map<String, dynamic> eligibility;

  String _n(dynamic v) => v is num ? formatMoney(v) : (v?.toString() ?? '—');

  @override
  Widget build(BuildContext context) {
    final eligible = eligibility['isEligible'] == true;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: eligible ? AppColors.primarySoft : AppColors.muted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(eligible ? 'advElig.eligible' : 'advElig.notEligible'),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: eligible ? AppColors.primary : AppColors.danger,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(context.t('advElig.period', {'period': eligibility['periodLabel'] ?? ''}), style: const TextStyle(fontSize: 11)),
          Text(context.t('advElig.salaryDays', {'salary': _n(eligibility['basicSalary']), 'days': eligibility['actualWorkingDays'] ?? 0})),
          Text(context.t('advElig.limit', {'percent': eligibility['percentUsed'] ?? 0, 'amount': _n(eligibility['maxEligibleAmount'])})),
          Text(context.t('advElig.outstanding', {'short': _n(eligibility['pendingShortTotal']), 'long': _n(eligibility['runningLongRemaining'])})),
          Text(context.t('advElig.availableNow', {'amount': _n(eligibility['availableAmount'])}), style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
