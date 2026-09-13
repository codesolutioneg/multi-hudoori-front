import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';
import '../../l10n/l10n_extension.dart';

class OvertimePage extends StatefulWidget {
  const OvertimePage({super.key});

  @override
  State<OvertimePage> createState() => _OvertimePageState();
}

class _OvertimePageState extends State<OvertimePage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _stateFilter = 'pending';
  DateTime _genFrom = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _genTo = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await api.overtimeList(state: _stateFilter.isEmpty ? null : _stateFilter);
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      await api.overtimeGenerate(
        dateFrom: _genFrom.toIso8601String().slice(0, 10),
        dateTo: _genTo.toIso8601String().slice(0, 10),
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('ot.generated'))));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _approve(String id) async {
    await api.overtimeApprove(id);
    _load();
  }

  Future<void> _reject(String id) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => const _RejectReasonDialog(),
    );
    if (reason == null || reason.isEmpty) return;
    await api.overtimeReject(id, reason);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(AppDimensions.spaceMd),
          child: PageHeader(
            title: context.t('ot.title'),
            subtitle: context.t('ot.subtitle'),
            icon: Icons.more_time_outlined,
            actions: [
              IconButton(onPressed: _load, icon: Icon(Icons.refresh)),
              OutlinedButton.icon(
                onPressed: _loading ? null : () async {
                  final from = await showDatePicker(
                    context: context,
                    initialDate: _genFrom,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (from == null || !mounted) return;
                  final to = await showDatePicker(
                    context: context,
                    initialDate: _genTo,
                    firstDate: from,
                    lastDate: DateTime(2035),
                  );
                  if (to != null) setState(() { _genFrom = from; _genTo = to; });
                },
                icon: const Icon(Icons.date_range, size: 18),
                label: Text('${_genFrom.toIso8601String().slice(0, 10)} → ${_genTo.toIso8601String().slice(0, 10)}'),
              ),
              FilledButton.icon(
                onPressed: _loading ? null : _generate,
                icon: const Icon(Icons.analytics_outlined, size: 18),
                label: Text(context.t('ot.generateFromPunches')),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd),
          child: DropdownButtonFormField<String>(
            value: _stateFilter,
            decoration: InputDecoration(labelText: context.t('ot.recordState'), isDense: true),
            items: [
              DropdownMenuItem(value: '', child: Text(context.t('common.all'))),
              DropdownMenuItem(value: 'pending', child: Text(context.t('ot.pending'))),
              DropdownMenuItem(value: 'approved', child: Text(context.t('ot.approved'))),
              DropdownMenuItem(value: 'rejected', child: Text(context.t('ot.rejected'))),
            ],
            onChanged: (v) {
              setState(() => _stateFilter = v ?? '');
              _load();
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? Center(child: Text(context.t('ot.noPending')))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd),
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final o = _items[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SellixCard(
                            child: ListTile(
                              title: Text('${o['employeeName']} — ${o['date']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(context.t('ot.line', {'ot': o['overtimeHours'], 'late': o['lateMinutes'], 'status': o['attendanceStatus']})),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  StatusTag(label: o['state']?.toString() ?? '', type: StatusTagType.info),
                                  IconButton(
                                    icon: Icon(Icons.check, color: AppColors.success),
                                    onPressed: () => _approve(o['id'].toString()),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: AppColors.danger),
                                    onPressed: () => _reject(o['id'].toString()),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog();

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('ot.rejectReason')),
      content: TextField(
        controller: _reason,
        decoration: InputDecoration(labelText: context.t('ot.reason')),
        maxLines: 2,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t('common.cancel'))),
        FilledButton(
          onPressed: () => Navigator.pop(context, _reason.text.trim()),
          child: Text(context.t('hire.reject')),
        ),
      ],
    );
  }
}

extension _DateSlice on String {
  String slice(int start, int end) => substring(start, end.clamp(0, length));
}
