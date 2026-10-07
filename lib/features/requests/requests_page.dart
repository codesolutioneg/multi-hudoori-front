import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/router/app_router.dart';
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

import '../mobile/hudoori_loader.dart';
import '../mobile/mobile_actions.dart';
import '../mobile/mobile_ui.dart';
import '../../core/platform/mobile_platform.dart';

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

  Map<String, dynamic>? get _openCycle {
    final raw = _data['openCycle'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  String? get _openCycleLabel {
    final cycle = _openCycle;
    if (cycle == null) return null;
    final from = cycle['dateFrom']?.toString() ?? '';
    final to = cycle['dateTo']?.toString() ?? '';
    if (from.isEmpty || to.isEmpty) return null;
    return context.t('requests.openCycle', {'from': from, 'to': to});
  }

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

  Future<String?> _pickTypeMobile() {
    // Employee create menu: leave / shift / attendance + advance (money path).
    // Salary/certificate/loan create stay closed on the API (READ_ONLY).
    final types = <(String, String, IconData, Color)>[
      ('leave', context.t('req.leave'), Icons.beach_access_rounded, const Color(0xFF0D9488)),
      ('shift', context.t('req.shiftChange'), Icons.swap_horiz_rounded, MobileTone.violet),
      ('attendance', context.t('req.attendanceEdit'), Icons.edit_calendar_rounded, MobileTone.info),
      ('advance', context.t('req.advance'), Icons.savings_outlined, const Color(0xFF16A34A)),
    ];
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5DCE8),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(context.t('req.new'), style: MobileUi.text(18, weight: FontWeight.w800)),
              ),
              if (_openCycleLabel != null) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    _openCycleLabel!,
                    style: MobileUi.text(12.5, weight: FontWeight.w600, color: MobileUi.muted),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              LayoutBuilder(builder: (context, c) {
                final w = c.maxWidth / 2;
                return Wrap(
                  children: [
                    for (final (id, label, icon, color) in types)
                      SizedBox(
                        width: w,
                        child: MobileActionTile(
                          icon: icon,
                          color: color,
                          label: label,
                          onPressed: () => Navigator.pop(ctx, id),
                        ),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateForm(String type) async {
    if (type == 'advance') {
      if (!mounted) return;
      await context.push(AppRoutes.myAdvanceRequest);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _RequestFormDialog(type: type, openCycle: _openCycle),
    );
    if (ok == true) await _load();
  }

  Future<void> _openCreateMenu() async {
    if (isNativeMobile) {
      final type = await _pickTypeMobile();
      if (type == null || !mounted) return;
      await _openCreateForm(type);
      return;
    }
    final type = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('req.new')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_openCycleLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_openCycleLabel!, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ),
            ListTile(leading: const Icon(Icons.beach_access), title: Text(context.t('req.leave')), onTap: () => Navigator.pop(ctx, 'leave')),
            ListTile(leading: const Icon(Icons.schedule), title: Text(context.t('req.shiftChange')), onTap: () => Navigator.pop(ctx, 'shift')),
            ListTile(leading: const Icon(Icons.edit_calendar), title: Text(context.t('req.attendanceEdit')), onTap: () => Navigator.pop(ctx, 'attendance')),
            // Money advances go through «طلب سلفة»; legacy loan create is READ_ONLY.
            ListTile(leading: const Icon(Icons.savings_outlined), title: Text(context.t('req.advance')), onTap: () => Navigator.pop(ctx, 'advance')),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;
    await _openCreateForm(type);
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
    if (!mounted) {
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
    if (_loading) return const Center(child: HudooriLoader());

    if (_error != null) {
      return ApiErrorView(error: _error!, onRetry: _load);
    }

    final leave = (_data['leave'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final loan = (_data['loan'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final shift = (_data['shiftChange'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final salary = (_data['salary'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final certificate = (_data['certificate'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final attendanceEdit = (_data['attendanceEdit'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (isNativeMobile) {
      return _buildMobile([
        _ReqType('leave', context.t('requests.tab.leave'), Icons.beach_access_rounded, const Color(0xFF0D9488), leave,
            (r) => '${r['leaveType']} • ${r['dateFrom']} → ${r['dateTo']}'),
        _ReqType('loan', context.t('requests.tab.loan'), Icons.account_balance_wallet_rounded, const Color(0xFF16A34A), loan,
            (r) => context.t('req.loanSummary', {'amount': r['amount'], 'months': r['repaymentMonths']})),
        _ReqType('shiftChange', context.t('requests.tab.shift'), Icons.swap_horiz_rounded, MobileTone.violet, shift,
            (r) => '${r['dateFrom']} → ${r['dateTo']}'),
        _ReqType('salary', context.t('requests.tab.salary'), Icons.payments_rounded, MobileUi.primary, salary,
            (r) => '${r['amount']}'),
        _ReqType('certificate', context.t('requests.tab.certificate'), Icons.workspace_premium_rounded, const Color(0xFFEA580C), certificate,
            (r) => '${r['certificateType']}'),
        _ReqType('attendanceEdit', context.t('requests.tab.attendance'), Icons.edit_calendar_rounded, MobileTone.info, attendanceEdit,
            (r) => '${r['date']}'),
      ]);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          child: PageHeader(
            title: context.t('requests.title'),
            subtitle: _hrReview
                ? context.t('requests.subtitle')
                : (_openCycleLabel ?? context.t('requests.mySubtitle')),
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

  Widget _buildMobile(List<_ReqType> types) {
    final total = types.fold<int>(0, (s, t) => s + t.items.length);
    final pending = types.fold<int>(
      0,
      (s, t) => s + t.items.where((r) => (r['state']?.toString() ?? '') == 'pending').length,
    );

    Widget stat(IconData icon, String label, int value) => Expanded(
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$value',
                      style: MobileUi.text(20, weight: FontWeight.w800, color: Colors.white, height: 1.1),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MobileUi.text(11.5, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: PageHeader(
            title: context.t('requests.title'),
            subtitle: _hrReview ? context.t('requests.subtitle') : context.t('requests.mySubtitle'),
            icon: Icons.assignment_outlined,
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
              if (!_hrReview)
                FilledButton.icon(
                  onPressed: _openCreateMenu,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(context.t('requests.newRequest')),
                ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: MobileUi.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: MobileUi.primary.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              stat(Icons.inbox_rounded, context.t('m.reqTotal'), total),
              Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.25)),
              const SizedBox(width: 12),
              stat(Icons.hourglass_top_rounded, context.t('m.reqPending'), pending),
            ],
          ),
        ),
        if (_openCycleLabel != null) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE6EBF3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.date_range_rounded, size: 18, color: MobileUi.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _openCycleLabel!,
                      style: MobileUi.text(12.5, weight: FontWeight.w700, color: MobileUi.ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        AnimatedBuilder(
          animation: _tabs,
          builder: (context, _) => SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: types.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final t = types[i];
                final selected = _tabs.index == i;
                return GestureDetector(
                  onTap: () => _tabs.animateTo(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                    decoration: BoxDecoration(
                      color: selected ? t.color : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? t.color : const Color(0xFFE6EBF3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon, size: 17, color: selected ? Colors.white : t.color),
                        const SizedBox(width: 6),
                        Text(
                          t.label,
                          style: MobileUi.text(13, weight: FontWeight.w700, color: selected ? Colors.white : MobileUi.ink, height: 1.2),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: selected ? Colors.white.withValues(alpha: 0.25) : t.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${t.items.length}',
                            textAlign: TextAlign.center,
                            style: MobileUi.text(11.5, weight: FontWeight.w800, color: selected ? Colors.white : t.color, height: 1.2),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [for (final t in types) _mobileList(t)],
          ),
        ),
      ],
    );
  }

  Widget _mobileList(_ReqType t) {
    if (t.items.isEmpty) {
      final isLoanTab = t.kind == 'loan';
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
        children: [
          MobileEmptyState(
            message: isLoanTab ? context.t('requests.loanLegacyHint') : context.t('requests.empty'),
            icon: t.icon,
          ),
          if (isLoanTab && !_hrReview) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.myAdvanceRequest),
              icon: const Icon(Icons.savings_outlined, size: 20),
              label: Text(context.t('advReq.myTitle')),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ],
      );
    }
    return RefreshIndicator(
      color: MobileUi.primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
        itemCount: t.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _mobileCard(t, t.items[i]),
      ),
    );
  }

  Widget _mobileCard(_ReqType t, Map<String, dynamic> r) {
    final state = r['state']?.toString() ?? '';
    final emp = r['employee'];
    final name = emp is Map ? (emp['name']?.toString() ?? '') : '';
    final code = emp is Map ? (emp['code']?.toString() ?? '') : '';
    final summary = t.subtitle(r);
    final reason = r['reason']?.toString() ?? '';
    final stateColor = switch (_stateTag(state)) {
      StatusTagType.success => MobileTone.success,
      StatusTagType.danger => MobileTone.danger,
      _ => MobileTone.warning,
    };
    final canReview = _hrReview && state == 'pending';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: MobileUi.card(r: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: t.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(t.icon, color: t.color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty ? name : t.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MobileUi.text(15, weight: FontWeight.w800),
                    ),
                    Text(
                      [if (code.isNotEmpty) code, t.label].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MobileUi.text(12, weight: FontWeight.w500, color: MobileUi.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(9, 4, 10, 4),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _stateAr(state),
                  style: MobileUi.text(12, weight: FontWeight.w800, color: stateColor, height: 1.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_note_rounded, size: 16, color: MobileUi.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(summary, style: MobileUi.text(13, weight: FontWeight.w700, height: 1.35)),
                    ),
                  ],
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notes_rounded, size: 16, color: MobileUi.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reason,
                          style: MobileUi.text(12, weight: FontWeight.w500, color: MobileUi.muted, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (canReview) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _approve(t.kind, r),
                    style: FilledButton.styleFrom(
                      backgroundColor: MobileTone.success,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: MobileUi.text(13.5, weight: FontWeight.w800),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: Text(context.t('req.approve')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _reject(t.kind, r),
                    style: FilledButton.styleFrom(
                      backgroundColor: MobileTone.danger.withValues(alpha: 0.1),
                      foregroundColor: MobileTone.danger,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: MobileUi.text(13.5, weight: FontWeight.w800),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    label: Text(context.t('req.reject')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _list(String kind, List<Map<String, dynamic>> items, String Function(Map<String, dynamic>) subtitle) {
    if (items.isEmpty) {
      if (kind == 'loan' && !_hrReview) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.t('requests.loanLegacyHint'), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.myAdvanceRequest),
                  icon: const Icon(Icons.savings_outlined, size: 18),
                  label: Text(context.t('advReq.myTitle')),
                ),
              ],
            ),
          ),
        );
      }
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

class _ReqType {
  const _ReqType(this.kind, this.label, this.icon, this.color, this.items, this.subtitle);
  final String kind;
  final String label;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic>) subtitle;
}

class _RequestFormDialog extends StatefulWidget {
  const _RequestFormDialog({required this.type, this.openCycle});
  final String type;
  final Map<String, dynamic>? openCycle;

  @override
  State<_RequestFormDialog> createState() => _RequestFormDialogState();
}

class _RequestFormDialogState extends State<_RequestFormDialog> {
  final _reason = TextEditingController();
  final _amount = TextEditingController(text: '1000');
  final _months = TextEditingController(text: '3');
  String _leaveType = 'annual';
  String? _shiftId;
  late DateTime _from;
  late DateTime _to;
  DateTime? _cycleFrom;
  DateTime? _cycleTo;
  List<Map<String, dynamic>> _shifts = [];
  bool _loadingShifts = false;
  bool _saving = false;

  static DateTime? _parseYmd(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw.length == 10 ? '${raw}T00:00:00' : raw);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime _clampDay(DateTime day, DateTime? min, DateTime? max) {
    var d = DateTime(day.year, day.month, day.day);
    if (min != null && d.isBefore(min)) d = min;
    if (max != null && d.isAfter(max)) d = max;
    return d;
  }

  @override
  void initState() {
    super.initState();
    _cycleFrom = _parseYmd(widget.openCycle?['dateFrom']?.toString());
    _cycleTo = _parseYmd(widget.openCycle?['dateTo']?.toString());
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _from = _clampDay(today, _cycleFrom, _cycleTo);
    var to = _from.add(const Duration(days: 1));
    if (_cycleTo != null && to.isAfter(_cycleTo!)) to = _cycleTo!;
    _to = to;
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
    final first = _cycleFrom ?? DateTime(2020);
    final last = _cycleTo ?? DateTime(2035);
    final initial = _clampDay(isFrom ? _from : _to, first, last);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last.isBefore(first) ? first : last,
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_from.isAfter(_to)) _from = _to;
      }
    });
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
    final cycleHint = (_cycleFrom != null && _cycleTo != null)
        ? context.t('requests.openCycle', {'from': _fmt(_cycleFrom!), 'to': _fmt(_cycleTo!)})
        : null;
    return AlertDialog(
      title: Text(_title),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (cycleHint != null) ...[
                Text(
                  cycleHint,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t('requests.openCycleHint'),
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
              ],
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
                  const Padding(padding: EdgeInsets.all(12), child: HudooriLoader())
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
