import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/platform/mobile_platform.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/money_format.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/l10n_extension.dart';
import '../mobile/hudoori_loader.dart';
import '../mobile/mobile_ui.dart';

class MyPayrollPage extends StatefulWidget {
  const MyPayrollPage({super.key});

  @override
  State<MyPayrollPage> createState() => _MyPayrollPageState();
}

class _MyPayrollPageState extends State<MyPayrollPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  Object? _error;

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
      final items = await api.myPayroll();
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  String _payrollTitle(Map<String, dynamic> item) {
    final name = item['payrollName'] ?? item['name'];
    if (name != null && name.toString().trim().isNotEmpty) return name.toString();
    return '${_periodFrom(item)} → ${_periodTo(item)}';
  }

  String _periodFrom(Map<String, dynamic> item) =>
      item['dateFrom']?.toString() ?? item['periodFrom']?.toString() ?? '—';

  String _periodTo(Map<String, dynamic> item) =>
      item['dateTo']?.toString() ?? item['periodTo']?.toString() ?? '—';

  num _netSalary(Map<String, dynamic> item) {
    final line = item['line'];
    if (line is Map) return (line['netSalary'] as num?) ?? 0;
    return (item['netSalary'] as num?) ?? 0;
  }

  String? _lineId(Map<String, dynamic> item) {
    final line = item['line'];
    if (line is Map) return line['id']?.toString();
    return item['lineId']?.toString();
  }

  String _fmtMoney(dynamic v) => formatMoney(v);

  Future<void> _openPayslip(Map<String, dynamic> item) async {
    final lineId = _lineId(item);
    if (lineId == null || lineId.isEmpty) return;
    try {
      final detail = await api.payrollPayslipDetail(lineId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => _PayslipBreakdownDialog(detail: detail, lineId: lineId),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(context, e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isNativeMobile) return _buildMobile();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        children: [
          PageHeader(
            title: context.t('payroll.myTitle'),
            subtitle: context.t('payroll.mySubtitle'),
            actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: HudooriLoader())
          else if (_error != null)
            SellixCard(child: Text(friendlyApiError(context, _error!)))
          else if (_items.isEmpty)
            SellixCard(child: Text(context.t('payroll.emptyMy')))
          else
            SellixCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final item in _items)
                    ListTile(
                      title: Text(
                        _payrollTitle(item),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('${_periodFrom(item)} → ${_periodTo(item)}'),
                      trailing: Text(
                        _fmtMoney(_netSalary(item)),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onTap: () => _openPayslip(item),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobile() {
    return ColoredBox(
      color: MobileUi.background,
      child: RefreshIndicator(
        color: MobileUi.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 48),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('payroll.myTitle'),
                        style: MobileUi.text(22, weight: FontWeight.w800),
                      ),
                      Text(
                        context.t('payroll.mySubtitle'),
                        style: MobileUi.text(13, weight: FontWeight.w500, color: MobileUi.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  color: MobileUi.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: HudooriLoader()),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: MobileUi.card(),
                child: Text(
                  friendlyApiError(context, _error!),
                  style: MobileUi.text(13, color: MobileTone.danger),
                ),
              )
            else if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: MobileUi.card(),
                child: Text(
                  context.t('payroll.emptyMy'),
                  textAlign: TextAlign.center,
                  style: MobileUi.text(14, weight: FontWeight.w500, color: MobileUi.muted),
                ),
              )
            else
              for (final item in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openPayslip(item),
                      borderRadius: BorderRadius.circular(20),
                      child: Ink(
                        padding: const EdgeInsets.all(14),
                        decoration: MobileUi.card(r: 20),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: MobileUi.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.payments_rounded, color: MobileUi.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _payrollTitle(item),
                                    style: MobileUi.text(15, weight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_periodFrom(item)} → ${_periodTo(item)}',
                                    style: MobileUi.text(12.5, weight: FontWeight.w500, color: MobileUi.muted),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _fmtMoney(_netSalary(item)),
                              style: MobileUi.text(15, weight: FontWeight.w800, color: MobileUi.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _PayslipBreakdownDialog extends StatelessWidget {
  const _PayslipBreakdownDialog({required this.detail, required this.lineId});

  final Map<String, dynamic> detail;
  final String lineId;

  String _fmt(dynamic v) {
    if (v == '-' || v == null) return '—';
    if (v is num) return formatMoney(v);
    return v.toString();
  }

  Widget _rows(String title, List<dynamic> rows, Color headerColor) {
    final list = rows.whereType<List>().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: headerColor.withValues(alpha: 0.15),
          child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        for (final row in list)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              children: [
                Expanded(child: Text(row.length > 1 ? row[1].toString() : '')),
                Text(_fmt(row.isNotEmpty ? row[0] : ''), style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _downloadPdf(BuildContext context) async {
    try {
      final r = await api.payrollPayslipPdf(lineId);
      if (!context.mounted) return;
      final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
      final filename = r['filename']?.toString() ?? 'payslip.pdf';
      if (base64.isEmpty) throw Exception(context.t('set.emptyFile'));
      downloadBase64File(base64, filename, r['mimeType']?.toString() ?? 'application/pdf');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('emp.downloaded', {'file': filename}))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiError(context, e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final earn = detail['earningRows'] as List? ?? [];
    final ded = detail['deductionRows'] as List? ?? [];
    return AlertDialog(
      title: Text(context.t('payslip.title', {'name': detail['employeeName'] ?? ''})),
      content: SizedBox(
        width: 520,
        height: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${detail['payrollName'] ?? ''}\n${detail['dateFrom']} → ${detail['dateTo']}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _rows(context.t('pay.earnings'), earn, AppColors.primary)),
                  const SizedBox(width: 12),
                  Expanded(child: _rows(context.t('pay.deductions'), ded, AppColors.danger)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  context.t('payslip.netSalary', {
                    'amount': _fmt(detail['excelNet'] ?? detail['netSalary']),
                  }),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: () => _downloadPdf(context),
          icon: const Icon(Icons.picture_as_pdf, size: 18),
          label: const Text('PDF'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t('common.close'))),
      ],
    );
  }
}
