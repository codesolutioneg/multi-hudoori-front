import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/file_pick.dart';
import '../../l10n/l10n_extension.dart';

/// Import / export monthly shift-report Excel for merged grids.
class MonthlyReportsDialog extends StatefulWidget {
  const MonthlyReportsDialog({super.key});

  @override
  State<MonthlyReportsDialog> createState() => _MonthlyReportsDialogState();
}

class _MonthlyReportsDialogState extends State<MonthlyReportsDialog> {
  bool _loadingPeriods = true;
  bool _busy = false;
  List<Map<String, dynamic>> _periods = [];
  String? _selectedKey;
  String? _error;
  Map<String, dynamic>? _lastImport;

  @override
  void initState() {
    super.initState();
    _loadPeriods();
  }

  Future<void> _loadPeriods() async {
    setState(() {
      _loadingPeriods = true;
      _error = null;
    });
    try {
      final r = await api.shiftGridMonthlyReportsPeriods();
      final list = (r['periods'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];
      if (!mounted) return;
      setState(() {
        _periods = list;
        if (list.isNotEmpty) {
          _selectedKey =
              '${list.first['dateFrom']}|${list.first['dateTo']}';
        }
        _loadingPeriods = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPeriods = false;
        _error = e.toString();
      });
    }
  }

  Map<String, dynamic>? get _selectedPeriod {
    if (_selectedKey == null) return null;
    for (final p in _periods) {
      final key = '${p['dateFrom']}|${p['dateTo']}';
      if (key == _selectedKey) return p;
    }
    return null;
  }

  Future<void> _exportTemplate() async {
    final period = _selectedPeriod;
    if (period == null) return;
    final emptyMsg = context.t('common.emptyFile');
    final doneMsg = context.t('grid.monthlyReports.exportDone');
    setState(() => _busy = true);
    try {
      final r = await api.shiftGridMonthlyReportsExportTemplate(
        dateFrom: period['dateFrom']?.toString() ?? '',
        dateTo: period['dateTo']?.toString() ?? '',
      );
      final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
      final filename =
          r['filename']?.toString() ?? 'monthly_reports_template.xlsx';
      if (base64.isEmpty) throw Exception(emptyMsg);
      downloadBase64File(
        base64,
        filename,
        r['mimeType']?.toString() ??
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(doneMsg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFile() async {
    final period = _selectedPeriod;
    if (period == null) return;
    final base64 = await pickExcelBase64();
    if (base64 == null || base64.isEmpty) return;
    setState(() {
      _busy = true;
      _lastImport = null;
    });
    try {
      final r = await api.shiftGridMonthlyReportsImport(
        base64: base64,
        dateFrom: period['dateFrom']?.toString() ?? '',
        dateTo: period['dateTo']?.toString() ?? '',
      );
      if (!mounted) return;
      setState(() => _lastImport = r);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _downloadFailures() {
    final file = _lastImport?['failuresFile'];
    if (file is! Map) return;
    final base64 = file['base64']?.toString() ?? file['file']?.toString() ?? '';
    final filename =
        file['filename']?.toString() ?? 'monthly_reports_rejected.xlsx';
    if (base64.isEmpty) return;
    downloadBase64File(
      base64,
      filename,
      file['mimeType']?.toString() ??
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  @override
  Widget build(BuildContext context) {
    final periodItems = _periods.map((p) {
      final from = p['dateFrom']?.toString() ?? '';
      final to = p['dateTo']?.toString() ?? '';
      final count = p['mergedGridCount'] ?? 0;
      final key = '$from|$to';
      final label = context
          .t('grid.monthlyReports.periodItem')
          .replaceAll('{from}', from)
          .replaceAll('{to}', to)
          .replaceAll('{count}', '$count');
      return DropdownMenuItem<String>(value: key, child: Text(label));
    }).toList();

    final applied = (_lastImport?['applied'] as num?)?.toInt() ?? 0;
    final rejected =
        (_lastImport?['rejectedCount'] as num?)?.toInt() ??
        ((_lastImport?['rejected'] as List?)?.length ?? 0);
    final hasFailures = _lastImport?['failuresFile'] is Map;

    return AlertDialog(
      title: Text(context.t('grid.monthlyReports.title')),
      content: SizedBox(
        width: 480,
        child: _loadingPeriods
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.t('grid.monthlyReports.hint'),
                    style: AppThemeV2.caption,
                  ),
                  const Gap(16),
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const Gap(8),
                    TextButton(
                      onPressed: _loadPeriods,
                      child: Text(context.t('common.retry')),
                    ),
                  ] else if (_periods.isEmpty) ...[
                    Text(context.t('grid.monthlyReports.noPeriods')),
                  ] else ...[
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: context.t('grid.monthlyReports.period'),
                        border: const OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedKey,
                          items: periodItems,
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => _selectedKey = v),
                        ),
                      ),
                    ),
                    const Gap(20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy || _selectedPeriod == null
                                ? null
                                : _exportTemplate,
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: Text(
                              context.t('grid.monthlyReports.export'),
                            ),
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy || _selectedPeriod == null
                                ? null
                                : _importFile,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppThemeV2.primary,
                            ),
                            icon: _busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.upload_file_rounded, size: 18),
                            label: Text(
                              context.t('grid.monthlyReports.import'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_lastImport != null) ...[
                    const Gap(20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppThemeV2.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppThemeV2.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context
                                .t('grid.monthlyReports.result')
                                .replaceAll('{applied}', '$applied')
                                .replaceAll('{rejected}', '$rejected'),
                            style: AppThemeV2.body,
                          ),
                          if (hasFailures) ...[
                            const Gap(10),
                            OutlinedButton.icon(
                              onPressed: _downloadFailures,
                              icon: const Icon(Icons.table_view_outlined, size: 18),
                              label: Text(
                                context.t('grid.monthlyReports.downloadRejected'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(true),
          child: Text(context.t('common.close')),
        ),
      ],
    );
  }
}
