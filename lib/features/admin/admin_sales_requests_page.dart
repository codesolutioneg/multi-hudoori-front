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
  Map<String, dynamic>? _analytics;
  bool _loading = true;
  String? _error;
  String _filter = 'PENDING';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        api.adminSalesRequestsList(
          status: _filter.isEmpty ? null : _filter,
          q: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        ),
        api.adminPlansList(),
      ]);
      final data = results[0];
      final plansData = results[1];
      final analyticsRaw = data['analytics'];
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
          _analytics = analyticsRaw is Map ? Map<String, dynamic>.from(analyticsRaw) : null;
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

  Future<void> _openDetail(Map<String, dynamic> row) async {
    final isAr = context.l10n.isAr;
    try {
      final data = await api.adminSalesRequestsGet(id: row['id'].toString());
      final req = data['request'];
      if (req is! Map || !mounted) return;
      final detail = Map<String, dynamic>.from(req);
      final noteCtrl = TextEditingController();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(detail['companyName']?.toString() ?? ''),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _copyRow(isAr ? 'الحالة' : 'Status', detail['status']?.toString() ?? ''),
                  _copyRow(isAr ? 'المعرف' : 'Code', detail['companyCode']?.toString() ?? ''),
                  _copyRow(isAr ? 'المسؤول' : 'Contact', detail['contactName']?.toString() ?? ''),
                  _copyRow(isAr ? 'البريد' : 'Email', detail['email']?.toString() ?? ''),
                  _copyRow(isAr ? 'المصدر' : 'Source', detail['source']?.toString() ?? ''),
                  const Gap(12),
                  Text(isAr ? 'الأنشطة' : 'Activity', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const Gap(8),
                  ...(((detail['activities'] as List?) ?? []).map((a) {
                    final m = a is Map ? Map<String, dynamic>.from(a) : <String, dynamic>{};
                    final body = m['body']?.toString() ?? m['kind']?.toString() ?? '';
                    final at = m['createdAt']?.toString() ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $body${at.isNotEmpty ? ' — $at' : ''}', style: const TextStyle(fontSize: 12)),
                    );
                  })),
                  const Gap(12),
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(labelText: isAr ? 'ملاحظة جديدة' : 'New note'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? 'إغلاق' : 'Close')),
            if (detail['status']?.toString() == 'PENDING') ...[
              TextButton(onPressed: () { Navigator.pop(ctx); _edit(detail); }, child: Text(isAr ? 'تعديل' : 'Edit')),
              FilledButton(onPressed: () { Navigator.pop(ctx); _approve(detail); }, child: Text(isAr ? 'موافقة' : 'Approve')),
            ],
            FilledButton(
              onPressed: () async {
                final body = noteCtrl.text.trim();
                if (body.isEmpty) return;
                await api.adminSalesRequestsNote(id: detail['id'].toString(), body: body);
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: Text(isAr ? 'حفظ ملاحظة' : 'Save note'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiError(context, e))));
      }
    }
  }

  Future<void> _createManual() async {
    final isAr = context.l10n.isAr;
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final empCtrl = TextEditingController(text: '10');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'طلب يدوي' : 'Manual request'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: codeCtrl, decoration: InputDecoration(labelText: isAr ? 'معرف الشركة' : 'Company code')),
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: isAr ? 'اسم الشركة' : 'Company name')),
              TextField(controller: contactCtrl, decoration: InputDecoration(labelText: isAr ? 'المسؤول' : 'Contact')),
              TextField(controller: emailCtrl, decoration: InputDecoration(labelText: isAr ? 'البريد' : 'Email')),
              TextField(controller: phoneCtrl, decoration: InputDecoration(labelText: isAr ? 'الهاتف' : 'Phone')),
              TextField(controller: empCtrl, decoration: InputDecoration(labelText: isAr ? 'عدد الموظفين' : 'Employees'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isAr ? 'إنشاء' : 'Create')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await api.adminSalesRequestsCreate(
        companyCode: codeCtrl.text.trim(),
        companyName: nameCtrl.text.trim(),
        contactName: contactCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        requestedEmployees: int.tryParse(empCtrl.text.trim()) ?? 1,
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiError(context, e))));
      }
    }
  }

  Widget _kpiTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
            const Gap(4),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
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
              FilledButton.icon(
                onPressed: _createManual,
                icon: const Icon(Icons.add_rounded),
                label: Text(isAr ? 'طلب يدوي' : 'Manual'),
              ),
              OutlinedButton.icon(
                onPressed: _rows.isEmpty ? null : _exportExcel,
                icon: const Icon(Icons.file_download_outlined),
                label: Text(isAr ? 'تصدير Excel' : 'Export Excel'),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          if (_analytics != null) ...[
            const Gap(12),
            Row(
              children: [
                _kpiTile(
                  isAr ? 'قيد المراجعة' : 'Pending',
                  '${(_analytics!['statusCounts'] as Map?)?['PENDING'] ?? 0}',
                  AppThemeV2.primary,
                ),
                const Gap(8),
                _kpiTile(
                  isAr ? 'موافق' : 'Approved',
                  '${(_analytics!['statusCounts'] as Map?)?['APPROVED'] ?? 0}',
                  const Color(0xFF059669),
                ),
                const Gap(8),
                _kpiTile(
                  isAr ? 'مرفوض' : 'Rejected',
                  '${(_analytics!['statusCounts'] as Map?)?['REJECTED'] ?? 0}',
                  const Color(0xFFDC2626),
                ),
                const Gap(8),
                _kpiTile(
                  isAr ? 'الإجمالي' : 'Total',
                  '${_analytics!['total'] ?? _rows.length}',
                  AppThemeV2.textPrimary,
                ),
              ],
            ),
          ],
          const Gap(12),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: isAr ? 'بحث…' : 'Search…',
              isDense: true,
            ),
            onSubmitted: (_) => _load(),
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
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final r = _rows[i];
                              final status = r['status']?.toString() ?? '';
                              return ListTile(
                                dense: true,
                                onTap: () => _openDetail(r),
                                title: Text(
                                  r['companyName']?.toString() ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  '${r['companyCode']} · ${r['contactName']} · ${r['email']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      status,
                                      style: TextStyle(
                                        color: _statusColor(status),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      r['requestedEmployees']?.toString() ?? '',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
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
