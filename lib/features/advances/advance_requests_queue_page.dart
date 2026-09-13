import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/widgets/api_error_view.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/l10n_extension.dart';
import '../auth/auth_cubit.dart';
import 'advance_request_common.dart';

/// «طلبات السلف» — the branch manager's queue: their own branch's requests, to
/// vouch for or turn down. HR does not work here; granting the advance is their
/// step and it lives in «السلف», next to the sheet the advance lands on.
class AdvanceRequestsQueuePage extends StatefulWidget {
  const AdvanceRequestsQueuePage({super.key});

  @override
  State<AdvanceRequestsQueuePage> createState() => _AdvanceRequestsQueuePageState();
}

class _AdvanceRequestsQueuePageState extends State<AdvanceRequestsQueuePage> {
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
      final rows = await api.advanceRequestList(state: _showAll ? 'all' : null);
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
    final reason = await askAdvanceReason(context, context.t('advReq.rejectReason'));
    if (reason == null || reason.isEmpty) return;
    await _run(
      () => api.advanceRequestReject(id: request['id'], reason: reason).then((_) {}),
      'advReq.rejected',
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
          title: context.t('advReq.queueTitle'),
          subtitle: _isHrStaff
              ? context.t('advReq.queueSubtitleHr')
              : context.t('advReq.queueSubtitleBranch'),
          icon: Icons.request_quote_outlined,
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            // HR already creates advances outright from «السلف», so raising a
            // request they would then approve themselves is just a longer road.
            if (!_isHrStaff)
              FilledButton.icon(
                onPressed: _createForEmployee,
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.t('advReq.forEmployee')),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceSm),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(context.t('advReq.filter.pending'))),
            ButtonSegment(value: true, label: Text(context.t('advReq.filter.all'))),
          ],
          selected: {_showAll},
          onSelectionChanged: (s) {
            setState(() => _showAll = s.first);
            _load();
          },
        ),
        const SizedBox(height: AppDimensions.spaceMd),
        if (_requests.isEmpty)
          SellixCard(child: Text(context.t('advReq.noQueue')))
        else
          ..._requests.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
              child: AdvanceRequestCard(
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
    if (!isPendingState(state)) return const [];

    final actions = <Widget>[
      TextButton(onPressed: () => _reject(request), child: Text(context.t('advReq.reject'))),
    ];

    if (state == 'pending_branch') {
      actions.add(
        FilledButton(
          onPressed: () => _run(
            () => api.advanceRequestBranchApprove(request['id']).then((_) {}),
            'advReq.branchApproved',
          ),
          child: Text(context.t('advReq.branchApprove')),
        ),
      );
    }
    // A request that has moved on is HR's to grant, from «السلف».
    return actions;
  }
}

/// Filing for staff who can't use the app themselves. The employee list is
/// already branch-scoped server-side for branch managers.
class _OnBehalfDialog extends StatefulWidget {
  const _OnBehalfDialog();

  @override
  State<_OnBehalfDialog> createState() => _OnBehalfDialogState();
}

class _OnBehalfDialogState extends State<_OnBehalfDialog> {
  final _searchCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  List<Map<String, dynamic>> _employees = const [];
  Map<String, dynamic>? _selected;
  Map<String, dynamic>? _eligibility;
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
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
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

  Future<void> _select(Map<String, dynamic> employee) async {
    setState(() {
      _selected = employee;
      _eligibility = null;
    });
    try {
      final data = await api.advanceRequestEligibility(employeeId: employee['id']);
      if (mounted) setState(() => _eligibility = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(context, e))),
        );
      }
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim().replaceAll(',', ''));
    final reason = _reasonCtrl.text.trim();
    if (_selected == null || amount == null || amount <= 0 || reason.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await api.advanceRequestCreate(
        employeeId: _selected!['id'],
        amount: amount,
        reason: reason,
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
      title: Text(context.t('advReq.forEmployee')),
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
                  labelText: context.t('advReq.pickEmployee'),
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
                        onTap: () => _select(e),
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
                    onPressed: () => setState(() { _selected = null; _eligibility = null; }),
                  ),
                ),
                if (_eligibility == null)
                  const Padding(
                    padding: EdgeInsets.all(AppDimensions.spaceMd),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  EligibilityCard(eligibility: _eligibility!, compact: true),
                const SizedBox(height: AppDimensions.spaceSm),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: context.t('advReq.amount')),
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                TextField(
                  controller: _reasonCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.t('advReq.reason'),
                    hintText: context.t('advReq.reasonHint'),
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
          onPressed: _selected == null || _submitting ? null : _submit,
          child: Text(context.t('advReq.submit')),
        ),
      ],
    );
  }
}
