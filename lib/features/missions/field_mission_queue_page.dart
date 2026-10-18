import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/utils/payroll_month.dart';
import '../../core/widgets/api_error_view.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/l10n_extension.dart';
import '../auth/auth_cubit.dart';
import 'field_mission_common.dart';

/// «طلبات المأمورية» — branch manager queue: approve or reject pending missions.
class FieldMissionQueuePage extends StatefulWidget {
  const FieldMissionQueuePage({super.key});

  @override
  State<FieldMissionQueuePage> createState() => _FieldMissionQueuePageState();
}

class _FieldMissionQueuePageState extends State<FieldMissionQueuePage> {
  List<Map<String, dynamic>> _requests = const [];
  bool _loading = true;
  bool _showAll = false;
  Object? _error;

  bool get _isHrStaff {
    final auth = context.read<AuthCubit>().state;
    return auth.roles.isHrUser || auth.roles.isHrManager || auth.isPlatformAdmin;
  }

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
      final rows = await api.fieldMissionRequestList(
        state: _showAll ? 'all' : null,
      );
      if (mounted) setState(() { _requests = rows; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e; });
    }
  }

  Future<void> _run(Future<void> Function() action, String successKey) async {
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t(successKey))),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(context, e))),
        );
      }
    }
  }

  Future<void> _reject(Map<String, dynamic> request) async {
    final reason = await askMissionReason(context, context.t('mission.rejectReason'));
    if (reason == null || reason.isEmpty) return;
    await _run(
      () => api
          .fieldMissionRequestReject(id: request['id'], reason: reason)
          .then((_) {}),
      'mission.rejected',
    );
  }

  Future<void> _createForEmployee() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _OnBehalfDialog(),
    );
    if (created == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ApiErrorView(error: _error!, onRetry: _load);

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      children: [
        PageHeader(
          title: context.t('mission.queueTitle'),
          subtitle: _isHrStaff
              ? context.t('mission.queueSubtitleHr')
              : context.t('mission.queueSubtitleBranch'),
          icon: Icons.flight_takeoff_outlined,
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            if (!_isHrStaff)
              FilledButton.icon(
                onPressed: _createForEmployee,
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.t('mission.forEmployee')),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceSm),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text(context.t('mission.filter.pending')),
            ),
            ButtonSegment(
              value: true,
              label: Text(context.t('mission.filter.all')),
            ),
          ],
          selected: {_showAll},
          onSelectionChanged: (s) {
            setState(() => _showAll = s.first);
            _load();
          },
        ),
        const SizedBox(height: AppDimensions.spaceMd),
        if (_requests.isEmpty)
          SellixCard(child: Text(context.t('mission.noQueue')))
        else
          ..._requests.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
              child: FieldMissionRequestCard(
                request: r,
                showEmployee: true,
                actions: _actionsFor(r),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _actionsFor(Map<String, dynamic> request) {
    final state = request['state']?.toString();
    if (!isMissionPendingState(state)) return const [];

    return [
      TextButton(
        onPressed: () => _reject(request),
        child: Text(context.t('mission.reject')),
      ),
      FilledButton(
        onPressed: () => _run(
          () => api
              .fieldMissionRequestBranchApprove(request['id'])
              .then((_) {}),
          'mission.branchApproved',
        ),
        child: Text(context.t('mission.branchApprove')),
      ),
    ];
  }
}

/// Filing a mission for staff who can't use the app themselves.
class _OnBehalfDialog extends StatefulWidget {
  const _OnBehalfDialog();

  @override
  State<_OnBehalfDialog> createState() => _OnBehalfDialogState();
}

class _OnBehalfDialogState extends State<_OnBehalfDialog> {
  final _searchCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();

  List<Map<String, dynamic>> _employees = const [];
  Map<String, dynamic>? _selected;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  Timer? _debounce;
  bool _searching = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String value) async {
    setState(() => _searching = true);
    try {
      final page = await api.employeesList(
        search: value.trim().isEmpty ? null : value.trim(),
        limit: 20,
      );
      if (mounted) setState(() { _employees = page.items; _searching = false; });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now();
    final initial = (from ? _dateFrom : _dateTo) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _dateFrom = picked;
        if (_dateTo != null && _dateTo!.isBefore(picked)) _dateTo = picked;
      } else {
        _dateTo = picked;
        if (_dateFrom != null && _dateFrom!.isAfter(picked)) _dateFrom = picked;
      }
    });
  }

  Future<void> _submit() async {
    final details = _detailsCtrl.text.trim();
    if (_selected == null ||
        details.isEmpty ||
        _dateFrom == null ||
        _dateTo == null) {
      return;
    }

    setState(() => _submitting = true);
    try {
      await api.fieldMissionRequestCreate(
        employeeId: _selected!['id'],
        details: details,
        dateFrom: formatIsoDate(_dateFrom!),
        dateTo: formatIsoDate(_dateTo!),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(context, e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('mission.forEmployee')),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  labelText: context.t('mission.pickEmployee'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: AppDimensions.spaceSm),
              if (_selected == null)
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    itemCount: _employees.length,
                    itemBuilder: (_, i) {
                      final e = _employees[i];
                      return ListTile(
                        dense: true,
                        title: Text(e['name']?.toString() ?? ''),
                        subtitle: Text(e['code']?.toString() ?? ''),
                        onTap: () => setState(() => _selected = e),
                      );
                    },
                  ),
                )
              else ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_selected!['name']?.toString() ?? ''),
                  subtitle: Text(_selected!['code']?.toString() ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _selected = null),
                  ),
                ),
                TextField(
                  controller: _detailsCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.t('mission.details'),
                    hintText: context.t('mission.detailsHint'),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate(from: true),
                        child: Text(
                          _dateFrom == null
                              ? context.t('mission.dateFrom')
                              : formatIsoDate(_dateFrom!),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate(from: false),
                        child: Text(
                          _dateTo == null
                              ? context.t('mission.dateTo')
                              : formatIsoDate(_dateTo!),
                        ),
                      ),
                    ),
                  ],
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
          onPressed: _selected == null || _submitting ? null : _submit,
          child: Text(context.t('mission.submit')),
        ),
      ],
    );
  }
}
