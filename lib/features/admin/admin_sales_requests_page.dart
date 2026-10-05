import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/utils/file_download.dart';
import '../../core/widgets/page_header.dart';
import '../../l10n/l10n_extension.dart';

class AdminSalesRequestsPage extends StatefulWidget {
  const AdminSalesRequestsPage({super.key});

  @override
  State<AdminSalesRequestsPage> createState() => _AdminSalesRequestsPageState();
}

class _AdminSalesRequestsPageState extends State<AdminSalesRequestsPage> {
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;
  String? _error;
  String _filter = 'PENDING';

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
      final results = await Future.wait([
        api.adminSalesRequestsList(status: _filter.isEmpty ? null : _filter),
        api.adminPlansList(),
      ]);
      final data = results[0];
      final plansData = results[1];
      final raw = data['requests'];
      final list = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      final plansRaw = plansData['plans'];
      final plans = plansRaw is List
          ? plansRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _rows = list;
          _plans = plans;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyApiError(context, e);
        });
      }
    }
  }

  Future<void> _copy(String label, String value) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    final isAr = context.l10n.isAr;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isAr ? 'تم نسخ $label' : 'Copied $label')),
    );
  }

  String _csvEscape(Object? v) {
    final s = (v ?? '').toString().replaceAll('"', '""');
    return '"$s"';
  }

  void _exportExcel() {
    final isAr = context.l10n.isAr;
    final headers = [
      'status',
      'companyCode',
      'companyName',
      'contactName',
      'email',
      'phone',
      'requestedEmployees',
      'plan',
      'notes',
      'rejectionReason',
      'createdAt',
    ];
    final lines = <String>[headers.join(',')];
    for (final r in _rows) {
      final plan = r['plan'];
      final planName = plan is Map
          ? (isAr ? plan['nameAr'] : plan['nameEn'])?.toString() ?? ''
          : '';
      lines.add([
        _csvEscape(r['status']),
        _csvEscape(r['companyCode']),
        _csvEscape(r['companyName']),
        _csvEscape(r['contactName']),
        _csvEscape(r['email']),
        _csvEscape(r['phone']),
        _csvEscape(r['requestedEmployees']),
        _csvEscape(planName),
        _csvEscape(r['notes']),
        _csvEscape(r['rejectionReason']),
        _csvEscape(r['createdAt']),
      ].join(','));
    }
    final bom = utf8.encode('\uFEFF');
    final body = utf8.encode(lines.join('\n'));
    final bytes = <int>[...bom, ...body];
    final b64 = base64Encode(bytes);
    final filter = _filter.isEmpty ? 'all' : _filter.toLowerCase();
    downloadBase64File(
      b64,
      'sales-requests-$filter.csv',
      'text/csv;charset=utf-8',
    );
  }

  Future<void> _edit(Map<String, dynamic> row) async {
    final isAr = context.l10n.isAr;
    final codeCtrl = TextEditingController(text: row['companyCode']?.toString() ?? '');
    final nameCtrl = TextEditingController(text: row['companyName']?.toString() ?? '');
    final contactCtrl = TextEditingController(text: row['contactName']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: row['email']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: row['phone']?.toString() ?? '');
    final empCtrl = TextEditingController(text: row['requestedEmployees']?.toString() ?? '');
    final notesCtrl = TextEditingController(text: row['notes']?.toString() ?? '');
    String? planId = row['planId']?.toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(isAr ? 'تعديل الطلب' : 'Edit request'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeCtrl,
                    decoration: InputDecoration(labelText: isAr ? 'معرف الشركة' : 'Company code'),
                  ),
                  const Gap(10),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: isAr ? 'اسم الشركة' : 'Company name'),
                  ),
                  const Gap(10),
                  TextField(
                    controller: contactCtrl,
                    decoration: InputDecoration(labelText: isAr ? 'اسم المسؤول' : 'Contact name'),
                  ),
                  const Gap(10),
                  TextField(
                    controller: emailCtrl,
                    decoration: InputDecoration(labelText: isAr ? 'البريد' : 'Email'),
                  ),
                  const Gap(10),
                  TextField(
                    controller: phoneCtrl,
                    decoration: InputDecoration(labelText: isAr ? 'الهاتف' : 'Phone'),
                  ),
                  const Gap(10),
                  TextField(
                    controller: empCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isAr ? 'عدد الموظفين (حصة الشركة عند الموافقة)' : 'Employees (company quota on approve)',
                    ),
                  ),
                  const Gap(10),
                  DropdownButtonFormField<String?>(
                    value: planId,
                    decoration: InputDecoration(labelText: isAr ? 'الباقة' : 'Plan'),
                    items: [
                      DropdownMenuItem(value: null, child: Text(isAr ? '— بدون —' : '— none —')),
                      ..._plans
                          .where((p) => p['status']?.toString() == 'PUBLISHED' || p['id']?.toString() == planId)
                          .map(
                            (p) => DropdownMenuItem(
                              value: p['id']?.toString(),
                              child: Text(
                                isAr
                                    ? '${p['nameAr']} (${p['slug']})'
                                    : '${p['nameEn']} (${p['slug']})',
                              ),
                            ),
                          ),
                    ],
                    onChanged: (v) => setLocal(() => planId = v),
                  ),
                  const Gap(10),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(labelText: isAr ? 'ملاحظات' : 'Notes'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isAr ? 'حفظ' : 'Save')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await api.adminSalesRequestsUpdate(
        id: row['id'].toString(),
        companyCode: codeCtrl.text.trim(),
        companyName: nameCtrl.text.trim(),
        contactName: contactCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        requestedEmployees: int.tryParse(empCtrl.text.trim()),
        planId: planId,
        notes: notesCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAr ? 'تم حفظ التعديلات' : 'Saved')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(context, e))),
        );
      }
    }
  }

  Future<void> _approve(Map<String, dynamic> row) async {
    final isAr = context.l10n.isAr;
    final code = row['companyCode']?.toString() ?? '';
    final name = row['companyName']?.toString() ?? '';
    final emp = row['requestedEmployees']?.toString() ?? '';
    final email = row['email']?.toString() ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'تأكيد الموافقة' : 'Confirm approval'),
        content: Text(
          isAr
              ? 'إنشاء شركة «$name»\nالمعرف: $code\nحصة الموظفين: $emp\nإرسال بيانات الدخول إلى: $email'
              : 'Create «$name»\ncode: $code\nemployee seats: $emp\nemail credentials to: $email',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isAr ? 'موافقة' : 'Approve')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final data = await api.adminSalesRequestsApprove(id: row['id'].toString());
      if (mounted) {
        final mail = data['mail'];
        final mailMap = mail is Map ? Map<String, dynamic>.from(mail) : null;
        final sent = mailMap?['sent'] == true;
        final to = mailMap?['to']?.toString();
        final err = mailMap?['error']?.toString();
        final msg = sent
            ? (isAr
                ? 'تمت الموافقة — تم إرسال الميل إلى ${to ?? email}'
                : 'Approved — email sent to ${to ?? email}')
            : (isAr
                ? 'تمت الموافقة — الميل لم يُرسل (${err ?? 'unknown'})'
                : 'Approved — email not sent (${err ?? 'unknown'})');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(context, e))),
        );
      }
    }
  }

  Future<void> _reject(Map<String, dynamic> row) async {
    final isAr = context.l10n.isAr;
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'رفض الطلب' : 'Reject request'),
        content: TextField(
          controller: reasonCtrl,
          decoration: InputDecoration(
            labelText: isAr ? 'سبب الرفض (اختياري)' : 'Rejection reason (optional)',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: Text(isAr ? 'رفض' : 'Reject'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await api.adminSalesRequestsReject(
        id: row['id'].toString(),
        reason: reasonCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAr ? 'تم الرفض' : 'Rejected')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(context, e))),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return const Color(0xFF059669);
      case 'REJECTED':
        return const Color(0xFFDC2626);
      default:
        return AppThemeV2.primary;
    }
  }

  Widget _copyRow(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '—' : value,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                fontSize: emphasize ? 15 : 13.5,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            visualDensity: VisualDensity.compact,
            onPressed: value.isEmpty ? null : () => _copy(label, value),
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.l10n.isAr;
    return AppPageScaffold(
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: isAr ? 'طلبات المبيعات' : 'Sales requests',
            subtitle: isAr
                ? 'عدّل الحقول قبل الموافقة — الحصة تُنشأ من عدد الموظفين المعدّل ويُرسل في الميل'
                : 'Edit before approve — employee quota uses the edited count and is emailed',
            actions: [
              OutlinedButton.icon(
                onPressed: _rows.isEmpty ? null : _exportExcel,
                icon: const Icon(Icons.file_download_outlined),
                label: Text(isAr ? 'تصدير Excel' : 'Export Excel'),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          const Gap(16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in ['PENDING', 'APPROVED', 'REJECTED', ''])
                ChoiceChip(
                  label: Text(s.isEmpty ? (isAr ? 'الكل' : 'All') : s),
                  selected: _filter == s,
                  onSelected: (_) {
                    setState(() => _filter = s);
                    _load();
                  },
                ),
            ],
          ),
          const Gap(16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _rows.isEmpty
                        ? Center(child: Text(isAr ? 'لا توجد طلبات' : 'No requests'))
                        : ListView.separated(
                            itemCount: _rows.length,
                            separatorBuilder: (_, __) => const Gap(14),
                            itemBuilder: (_, i) {
                              final r = _rows[i];
                              final plan = r['plan'];
                              final planName = plan is Map
                                  ? (isAr ? plan['nameAr'] : plan['nameEn'])?.toString()
                                  : null;
                              final status = r['status']?.toString() ?? '';
                              final pending = status == 'PENDING';
                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${r['companyName']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 17,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _statusColor(status).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                color: _statusColor(status),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Gap(12),
                                      _copyRow(isAr ? 'المعرف' : 'Code', r['companyCode']?.toString() ?? '', emphasize: true),
                                      _copyRow(isAr ? 'المسؤول' : 'Contact', r['contactName']?.toString() ?? ''),
                                      _copyRow(isAr ? 'البريد' : 'Email', r['email']?.toString() ?? ''),
                                      _copyRow(isAr ? 'الهاتف' : 'Phone', r['phone']?.toString() ?? ''),
                                      _copyRow(
                                        isAr ? 'الموظفون' : 'Employees',
                                        r['requestedEmployees']?.toString() ?? '',
                                        emphasize: true,
                                      ),
                                      _copyRow(isAr ? 'الباقة' : 'Plan', planName ?? '—'),
                                      if ((r['notes']?.toString() ?? '').isNotEmpty)
                                        _copyRow(isAr ? 'ملاحظات' : 'Notes', r['notes'].toString()),
                                      if ((r['rejectionReason']?.toString() ?? '').isNotEmpty)
                                        _copyRow(isAr ? 'سبب الرفض' : 'Reason', r['rejectionReason'].toString()),
                                      if (pending) ...[
                                        const Gap(8),
                                        const Divider(height: 1),
                                        const Gap(12),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            FilledButton.icon(
                                              onPressed: () => _approve(r),
                                              icon: const Icon(Icons.check_rounded),
                                              label: Text(isAr ? 'موافقة' : 'Approve'),
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: () => _edit(r),
                                              icon: const Icon(Icons.edit_outlined),
                                              label: Text(isAr ? 'تعديل' : 'Edit'),
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: () => _reject(r),
                                              icon: const Icon(Icons.close_rounded),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red.shade700,
                                              ),
                                              label: Text(isAr ? 'رفض' : 'Reject'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
