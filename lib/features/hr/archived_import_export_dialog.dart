import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/file_pick.dart';
import '../../l10n/l10n_extension.dart';

/// Export archived employees / archive-status template / import status sheet.
/// Pops `true` when at least one employee was archived, updated, or restored.
class ArchivedImportExportDialog extends StatefulWidget {
  const ArchivedImportExportDialog({super.key});

  @override
  State<ArchivedImportExportDialog> createState() =>
      _ArchivedImportExportDialogState();
}

class _ArchivedImportExportDialogState
    extends State<ArchivedImportExportDialog> {
  bool _busy = false;
  bool _anyChanged = false;
  Map<String, dynamic>? _lastImport;

  static const _xlsxMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _download(Map<String, dynamic> r, String fallbackName) async {
    final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
    final filename = r['filename']?.toString() ?? fallbackName;
    if (base64.isEmpty) throw Exception(context.t('set.emptyFile'));
    downloadBase64File(
      base64,
      filename,
      r['mimeType']?.toString() ?? _xlsxMime,
    );
  }

  Future<void> _exportAllArchived() async {
    setState(() => _busy = true);
    try {
      final r = await api.employeesArchivedExportXlsx();
      if (!mounted) return;
      await _download(r, 'archived_employees_full.xlsx');
      if (!mounted) return;
      _snack(context.t('emp.archivedIo.exportDone'));
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportTemplate() async {
    setState(() => _busy = true);
    try {
      final r = await api.employeesArchivedTemplateXlsx();
      if (!mounted) return;
      await _download(r, 'archive_status_template.xlsx');
      if (!mounted) return;
      _snack(context.t('emp.archivedIo.templateDone'));
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
      final r = await api.employeesArchivedImportXlsx(base64);
      if (!mounted) return;
      final archived = (r['archived'] as num?)?.toInt() ?? 0;
      final updated = (r['archiveUpdated'] as num?)?.toInt() ?? 0;
      final restored = (r['restored'] as num?)?.toInt() ?? 0;
      setState(() {
        _lastImport = r;
        if (archived + updated + restored > 0) _anyChanged = true;
      });
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Map<String, dynamic>> get _details =>
      (_lastImport?['details'] as List?)
          ?.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList() ??
      [];

  Color _actionColor(String action) {
    switch (action) {
      case 'archived':
        return Colors.orange.shade800;
      case 'archive_updated':
        return Colors.blue.shade800;
      case 'restored':
        return Colors.green.shade700;
      default:
        return Colors.red.shade700;
    }
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'archived':
        return context.t('emp.archivedIo.actionArchived');
      case 'archive_updated':
        return context.t('emp.archivedIo.actionUpdated');
      case 'restored':
        return context.t('emp.archivedIo.actionRestored');
      default:
        return context.t('emp.archivedIo.actionSkipped');
    }
  }

  @override
  Widget build(BuildContext context) {
    final archived = (_lastImport?['archived'] as num?)?.toInt() ?? 0;
    final updated = (_lastImport?['archiveUpdated'] as num?)?.toInt() ?? 0;
    final restored = (_lastImport?['restored'] as num?)?.toInt() ?? 0;
    final skipped = (_lastImport?['skipped'] as num?)?.toInt() ?? 0;
    final details = _details;

    return AlertDialog(
      title: Text(context.t('emp.archivedIo.title')),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.t('emp.archivedIo.hint'),
                style: AppThemeV2.caption,
              ),
              const Gap(16),
              OutlinedButton.icon(
                onPressed: _busy ? null : _exportAllArchived,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(context.t('emp.archivedIo.exportAll')),
              ),
              const Gap(10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _exportTemplate,
                icon: const Icon(Icons.note_add_outlined, size: 18),
                label: Text(context.t('emp.archivedIo.exportTemplate')),
              ),
              const Gap(10),
              FilledButton.icon(
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
                label: Text(context.t('emp.archivedIo.import')),
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
                        context.t('emp.archivedIo.result', {
                          'archived': archived,
                          'updated': updated,
                          'restored': restored,
                          'skipped': skipped,
                        }),
                        style: AppThemeV2.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Gap(12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: details.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final row = details[i];
                            final code = row['code']?.toString() ?? '';
                            final name = row['name']?.toString() ?? '';
                            final action = row['action']?.toString() ?? 'skipped';
                            final detail = row['detail']?.toString() ?? '';
                            final label = name.isEmpty
                                ? code
                                : (code.isEmpty ? name : '$code — $name');
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _actionColor(action)
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _actionLabel(action),
                                          style: AppThemeV2.caption.copyWith(
                                            color: _actionColor(action),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const Gap(8),
                                      Expanded(
                                        child: Text(
                                          label,
                                          style: AppThemeV2.body,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (detail.isNotEmpty) ...[
                                    const Gap(2),
                                    Text(detail, style: AppThemeV2.caption),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
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
          onPressed:
              _busy ? null : () => Navigator.of(context).pop(_anyChanged),
          child: Text(context.t('common.close')),
        ),
      ],
    );
  }
}
