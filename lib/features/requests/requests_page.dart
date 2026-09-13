import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/widgets/api_error_view.dart';
import '../../core/widgets/list_picker_field.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';
import '../../l10n/l10n_extension.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic> _data = {};
  bool _loading = true;
  bool _hrReview = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _hrReview = _isHr(context.read<AuthCubit>().state);
      _load();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool _isHr(AuthState auth) => auth.roles.isHrUser || auth.roles.isHrManager;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = _hrReview ? await api.requestsPending() : await api.requestsMy();
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e; });
    }
  }

  Future<void> _openCreateMenu() async {
    final type = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('req.new')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: Icon(Icons.beach_access), title: Text(context.t('req.leave')), onTap: () => Navigator.pop(ctx, 'leave')),
            // «قرض» is gone from this menu: money on the salary now goes through
            // «طلب سلفة», which checks entitlement and lands in payroll. Existing
            // loan rows still show in their tab so they can be closed out.
            ListTile(leading: Icon(Icons.schedule), title: Text(context.t('req.shiftChange')), onTap: () => Navigator.pop(ctx, 'shift')),
            ListTile(leading: Icon(Icons.payments), title: Text(context.t('req.salaryRequest')), onTap: () => Navigator.pop(ctx, 'salary')),
            ListTile(leading: Icon(Icons.description), title: Text(context.t('req.certificate')), onTap: () => Navigator.pop(ctx, 'certificate')),
            ListTile(leading: Icon(Icons.edit_calendar), title: Text(context.t('req.attendanceEdit')), onTap: () => Navigator.pop(ctx, 'attendance')),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _RequestFormDialog(type: type),
    );
    if (ok == true) await _load();
  }

  Future<void> _approve(String kind, Map<String, dynamic> item) async {
    final id = item['id'];
    try {
      switch (kind) {
        case 'leave':
          await api.leaveRequestApprove(id);
        case 'loan':
          await api.loanRequestApprove(id);
        case 'shiftChange':
          await api.shiftChangeRequestApprove(id);
        case 'salary':
          await api.salaryRequestApprove(id);
        case 'certificate':
          await api.certificateRequestApprove(id);
        case 'attendanceEdit':
          await api.attendanceEditRequestApprove(id);
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('req.approved'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(context, e))),
        );
      }
    }
  }

  Future<void> _reject(String kind, Map<String, dynamic> item) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('req.rejectTitle')),
        content: TextField(
          controller: reasonCtrl,
          decoration: InputDecoration(labelText: context.t('req.rejectReason')),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('common.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.t('req.reject'))),
        ],
      ),
    );
    if (ok != true) {
      reasonCtrl.dispose();
      return;
    }
    final reason = reasonCtrl.text.trim().isEmpty ? context.t('req.rejected') : reasonCtrl.text.trim();
    reasonCtrl.dispose();
    try {
      final id = item['id'];
      switch (kind) {
        case 'leave':
          await api.leaveRequestReject(id, reason);
        case 'loan':
          await api.loanRequestReject(id, reason);
        case 'shiftChange':
          await api.shiftChangeRequestReject(id, reason);
        case 'salary':
          await api.salaryRequestReject(id, reason);
        case 'certificate':
          await api.certificateRequestReject(id, reason);
        case 'attendanceEdit':
          await api.attendanceEditRequestReject(id, reason);
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('req.rejectedDone'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(context, e))),
        );
      }
    }
  }

  String _employeeLabel(Map<String, dynamic> r) {
    final emp = r['employee'];
    if (emp is Map) {
      final name = emp['name']?.toString() ?? '';
      final code = emp['code']?.toString() ?? '';
      if (name.isNotEmpty && code.isNotEmpty) return '$name ($code)';
      if (name.isNotEmpty) return name;
    }
    return '';
  }

  StatusTagType _stateTag(String state) {
    if (state == 'approved') return StatusTagType.success;
    if (state == 'rejected' || state == 'cancelled') return StatusTagType.danger;
    return StatusTagType.warning;
  }

  String _stateAr(String state) {
    switch (state) {
      case 'pending': return context.t('req.state.pending');
      case 'approved': return context.t('req.state.approved');
      case 'rejected': return context.t('req.rejected');
      case 'cancelled': return context.t('req.state.cancelled');
      default: return state;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return ApiErrorView(error: _error!, onRetry: _load);
    }

    final leave = (_data['leave'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final loan = (_data['loan'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final shift = (_data['shiftChange'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final salary = (_data['salary'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final certificate = (_data['certificate'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final attendanceEdit = (_data['attendanceEdit'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          child: PageHeader(
            title: context.t('requests.title'),
            subtitle: _hrReview ? context.t('requests.subtitle') : context.t('requests.mySubtitle'),
            icon: Icons.assignment_outlined,
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              if (!_hrReview)
                FilledButton.icon(
                  onPressed: _openCreateMenu,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.t('requests.newRequest')),
                ),
            ],
          ),
        ),
        TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          isScrollable: true,
          tabs: [
            Tab(text: '${context.t('requests.tab.leave')} (${leave.length})'),
            Tab(text: '${context.t('requests.tab.loan')} (${loan.length})'),
            Tab(text: '${context.t('requests.tab.shift')} (${shift.length})'),
            Tab(text: '${context.t('requests.tab.salary')} (${salary.length})'),
            Tab(text: '${context.t('requests.tab.certificate')} (${certificate.length})'),
            Tab(text: '${context.t('requests.tab.attendance')} (${attendanceEdit.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _list('leave', leave, (r) => '${r['leaveType']} • ${r['dateFrom']} → ${r['dateTo']}'),
              _list('loan', loan, (r) => context.t('req.loanSummary', {'amount': r['amount'], 'months': r['repaymentMonths']})),
              _list('shiftChange', shift, (r) => '${r['dateFrom']} → ${r['dateTo']}'),
              _list('salary', salary, (r) => '${r['amount']}'),
              _list('certificate', certificate, (r) => '${r['certificateType']}'),
              _list('attendanceEdit', attendanceEdit, (r) => '${r['date']}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _list(String kind, List<Map<String, dynamic>> items, String Function(Map<String, dynamic>) subtitle) {
    if (items.isEmpty) {
      return Center(
        child: Text(context.t('requests.empty')),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = items[i];
        final state = r['state']?.toString() ?? '';
        final emp = _employeeLabel(r);
        return SellixCard(
          child: ListTile(
            title: Text(
              emp.isNotEmpty ? emp : subtitle(r),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (emp.isNotEmpty) Text(subtitle(r)),
                if (r['reason'] != null && r['reason'].toString().isNotEmpty)
                  Text(r['reason'].toString(), style: const TextStyle(fontSize: 12)),
              ],
            ),
            trailing: _hrReview && state == 'pending'
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: context.t('req.approve'),
                        icon: const Icon(Icons.check_circle_outline, color: AppColors.primary),
                        onPressed: () => _approve(kind, r),
                      ),
                      IconButton(
                        tooltip: context.t('req.reject'),
                        icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
                        onPressed: () => _reject(kind, r),
                      ),
                    ],
                  )
                : StatusTag(label: _stateAr(state), type: _stateTag(state)),
          ),
        );
      },
    );
  }
}

class _RequestFormDialog extends StatefulWidget {
  const _RequestFormDialog({required this.type});
  final String type;

  @override
  State<_RequestFormDialog> createState() => _RequestFormDialogState();
}

class _RequestFormDialogState extends State<_RequestFormDialog> {
  final _reason = TextEditingController();
  final _amount = TextEditingController(text: '1000');
  final _months = TextEditingController(text: '3');
  String _leaveType = 'annual';
  String? _shiftId;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now().add(const Duration(days: 1));
  List<Map<String, dynamic>> _shifts = [];
  bool _loadingShifts = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == 'shift') _loadShifts();
  }

  @override
  void dispose() {
    _reason.dispose();
    _amount.dispose();
    _months.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadShifts() async {
    setState(() => _loadingShifts = true);
    try {
      final shifts = await api.shiftsList();
      if (mounted) {
        setState(() {
          _shifts = shifts;
          if (shifts.isNotEmpty) _shiftId = shifts.first['id']?.toString();
          _loadingShifts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingShifts = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => isFrom ? _from = picked : _to = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final reason = _reason.text.trim();
    try {
      if (widget.type == 'leave') {
        await api.leaveRequestCreate(
          leaveType: _leaveType,
          dateFrom: _fmt(_from),
          dateTo: _fmt(_to),
          reason: reason.isEmpty ? context.t('req.leaveRequest') : reason,
        );
      } else if (widget.type == 'loan') {
        await api.loanRequestCreate(
          amount: double.tryParse(_amount.text) ?? 0,
          repaymentMonths: int.tryParse(_months.text) ?? 1,
          reason: reason.isEmpty ? context.t('req.loanRequest') : reason,
        );
      } else if (widget.type == 'salary') {
        await api.salaryRequestCreate(
          amount: double.tryParse(_amount.text) ?? 0,
          reason: reason.isEmpty ? context.t('req.salaryRequest') : reason,
        );
      } else if (widget.type == 'certificate') {
        await api.certificateRequestCreate(
          certificateType: 'employment',
          reason: reason.isEmpty ? context.t('req.certificateRequest') : reason,
        );
      } else if (widget.type == 'attendance') {
        await api.attendanceEditRequestCreate(
          date: _fmt(_from),
          reason: reason.isEmpty ? context.t('req.punchFixRequest') : reason,
          requestedCheckIn: '09:00',
          requestedCheckOut: '17:00',
        );
      } else if (widget.type == 'shift') {
        if (_shiftId == null) throw Exception(context.t('req.pickNewShift'));
        await api.shiftChangeRequestCreate(
          newShiftId: _shiftId!,
          dateFrom: _fmt(_from),
          dateTo: _fmt(_to),
          reason: reason.isEmpty ? context.t('req.shiftChangeRequest') : reason,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(context, e))),
        );
      }
    }
  }

  String get _title {
    switch (widget.type) {
      case 'leave': return context.t('req.leaveRequest');
      case 'loan': return context.t('req.loanRequest');
      case 'shift': return context.t('req.shiftChangeRequest');
      case 'salary': return context.t('req.salaryRequest');
      case 'certificate': return context.t('req.certificateTitle');
      case 'attendance': return context.t('req.attendanceEditTitle');
      default: return context.t('req.new');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_title),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.type == 'leave') ...[
                ListPickerField<String>(
                  label: context.t('req.leaveType'),
                  value: _leaveType,
                  options: [
                    (value: 'annual', label: context.t('req.leaveType.annual')),
                    (value: 'sick', label: context.t('req.leaveType.sick')),
                    (value: 'unpaid', label: context.t('req.leaveType.unpaid')),
                  ],
                  onChanged: (v) => setState(() => _leaveType = v),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => _pickDate(true), child: Text(context.t('common.fromDate', {'date': _fmt(_from)})))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: () => _pickDate(false), child: Text(context.t('common.toDate', {'date': _fmt(_to)})))),
                ]),
              ],
              if (widget.type == 'loan') ...[
                TextField(controller: _amount, decoration: InputDecoration(labelText: context.t('req.amount')), keyboardType: TextInputType.number),
                TextField(controller: _months, decoration: InputDecoration(labelText: context.t('req.repaymentMonths')), keyboardType: TextInputType.number),
              ],
              if (widget.type == 'salary')
                TextField(controller: _amount, decoration: InputDecoration(labelText: context.t('req.requestedAmount')), keyboardType: TextInputType.number),
              if (widget.type == 'shift') ...[
                if (_loadingShifts)
                  const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
                else if (_shifts.isEmpty)
                  Text(context.t('req.noShifts'))
                else
                  ListPickerField<String>(
                    label: context.t('req.newShift'),
                    value: _shiftId,
                    options: [
                      for (final s in _shifts)
                        (value: s['id']?.toString() ?? '', label: '${s['code']} - ${s['name']}'),
                    ],
                    onChanged: (v) => setState(() => _shiftId = v),
                  ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => _pickDate(true), child: Text(context.t('common.fromDate', {'date': _fmt(_from)})))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: () => _pickDate(false), child: Text(context.t('common.toDate', {'date': _fmt(_to)})))),
                ]),
              ],
              if (widget.type == 'attendance')
                OutlinedButton(onPressed: () => _pickDate(true), child: Text(context.t('req.dateLabel', {'date': _fmt(_from)}))),
              const SizedBox(height: 8),
              TextField(controller: _reason, decoration: InputDecoration(labelText: context.t('req.reasonNotes'))),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t('common.cancel'))),
        FilledButton(onPressed: _saving ? null : _save, child: Text(context.t('req.send'))),
      ],
    );
  }
}
