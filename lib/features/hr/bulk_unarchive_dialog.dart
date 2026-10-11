import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/file_pick.dart';
import '../../l10n/l10n_extension.dart';

/// Export archived employees to Excel, then import a list of codes to unarchive.
/// Pops `true` when at least one employee was restored.
class BulkUnarchiveDialog extends StatefulWidget {
  const BulkUnarchiveDialog({super.key});

  @override
  State<BulkUnarchiveDialog> createState() => _BulkUnarchiveDialogState();
}

class _BulkUnarchiveDialogState extends State<BulkUnarchiveDialog> {
  bool _busy = false;
  bool _anyRestored = false;
  Map<String, dynamic>? _lastImport;

  static const _xlsxMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _export() async {
    final emptyMsg = context.t('common.emptyFile');
    final doneMsg = context.t('emp.bulkUnarchive.exportDone');
    setState(() => _busy = true);
    try {
      final r = await api.employeesBulkRestoreExportXlsx();
      final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
      final filename = r['filename']?.toString() ?? 'archived_employees.xlsx';
      if (base64.isEmpty) throw Exception(emptyMsg);
      downloadBase64File(base64, filename, r['mimeType']?.toString() ?? _xlsxMime);
      if (!mounted) return;
      _snack(doneMsg);
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final base64 = await pickExcelBase64();
    if (base64 == null || base64.isEmpty) return;
    setState(() {
      _busy = true;
      _lastImport = null;
    });
    try {
      final r = await api.employeesBulkRestoreImportXlsx(base64);
      if (!mounted) return;
      final restored = (r['restored'] as List?)?.length ?? 0;
      setState(() {
        _lastImport = r;
        if (restored > 0) _anyRestored = true;
      });
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _downloadFailures() {
    final file = _lastImport?['failuresFile'];
    if (file is! Map) return;
    final base64 = file['base64']?.toString() ?? file['file']?.toString() ?? '';
    if (base64.isEmpty) return;
    downloadBase64File(
      base64,
      file['filename']?.toString() ?? 'unarchive_rejected.xlsx',
      file['mimeType']?.toString() ?? _xlsxMime,
    );
  }

  List<Map<String, dynamic>> _rows(String key) =>
      (_lastImport?[key] as List?)
          ?.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList() ??
      [];

  Widget _resultSection({
    required String title,
    required Color color,
    required List<Map<String, dynamic>> rows,
    required bool showReason,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: AppThemeV2.body.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const Gap(6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final row = rows[i];
              final code = row['code']?.toString() ?? '';
              final name = row['name']?.toString() ?? '';
              final reason = row['reason']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? code : '$code — $name',
                      style: AppThemeV2.body,
                    ),
                    if (showReason && reason.isNotEmpty)
                      Text(reason, style: AppThemeV2.caption),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final restored = _rows('restored');
    final rejected = _rows('rejected');
    final hasFailures = _lastImport?['failuresFile'] is Map;

    return AlertDialog(
      title: Text(context.t('emp.bulkUnarchive.title')),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.t('emp.bulkUnarchive.hint'),
                style: AppThemeV2.caption,
              ),
              const Gap(16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _export,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(context.t('emp.bulkUnarchive.export')),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _import,
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
                      label: Text(context.t('emp.bulkUnarchive.import')),
                    ),
                  ),
                ],
              ),
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
                        context.t('emp.bulkUnarchive.result', {
                          'restored': restored.length,
                          'rejected': rejected.length,
                        }),
                        style: AppThemeV2.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (restored.isNotEmpty) ...[
                        const Gap(12),
                        _resultSection(
                          title: context.t('emp.bulkUnarchive.restoredTitle', {
                            'count': restored.length,
                          }),
                          color: Colors.green.shade700,
                          rows: restored,
                          showReason: false,
                        ),
                      ],
                      if (rejected.isNotEmpty) ...[
                        const Gap(12),
                        _resultSection(
                          title: context.t('emp.bulkUnarchive.rejectedTitle', {
                            'count': rejected.length,
                          }),
                          color: Colors.red.shade700,
                          rows: rejected,
                          showReason: true,
                        ),
                      ],
                      if (hasFailures) ...[
                        const Gap(10),
                        OutlinedButton.icon(
                          onPressed: _downloadFailures,
                          icon: const Icon(Icons.table_view_outlined, size: 18),
                          label: Text(
                            context.t('emp.bulkUnarchive.downloadRejected'),
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
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(_anyRestored),
          child: Text(context.t('common.close')),
        ),
      ],
    );
  }
}
