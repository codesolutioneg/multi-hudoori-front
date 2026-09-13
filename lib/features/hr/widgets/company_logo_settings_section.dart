import 'dart:convert';
import 'dart:typed_data';
import '../../../l10n/l10n_extension.dart';

import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_pick.dart';
import '../../../core/widgets/sellix_card.dart';

class CompanyLogoSettingsSection extends StatefulWidget {
  const CompanyLogoSettingsSection({super.key, this.hasLogo = false, this.onChanged});

  final bool hasLogo;
  final VoidCallback? onChanged;

  @override
  State<CompanyLogoSettingsSection> createState() => _CompanyLogoSettingsSectionState();
}

class _CompanyLogoSettingsSectionState extends State<CompanyLogoSettingsSection> {
  Uint8List? _logoBytes;
  bool _loading = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.hasLogo) _loadLogo();
  }

  @override
  void didUpdateWidget(covariant CompanyLogoSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasLogo && _logoBytes == null && !_loading) {
      _loadLogo();
    }
    if (!widget.hasLogo && _logoBytes != null) {
      setState(() => _logoBytes = null);
    }
  }

  Future<void> _loadLogo() async {
    setState(() => _loading = true);
    try {
      final file = await api.companyLogoGet();
      final base64 = file['base64']?.toString() ?? '';
      if (mounted && base64.isNotEmpty) {
        setState(() => _logoBytes = base64Decode(base64));
      }
    } catch (_) {
      // Logo may have been removed.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _upload() async {
    final picked = await pickImageBase64();
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      await api.companyLogoUpload(base64: picked.base64, mimeType: picked.mimeType);
      widget.onChanged?.call();
      await _loadLogo();
      if (mounted) _snack(context.t('logo.uploaded'));
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('logo.deleteTitle')),
        content: Text(context.t('logo.deleteAsk')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('common.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.t('common.delete'))),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _uploading = true);
    try {
      await api.companyLogoDelete();
      if (mounted) setState(() => _logoBytes = null);
      widget.onChanged?.call();
      _snack(context.t('logo.deleted'));
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t('logo.hint'),
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 12),
        SellixCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else if (_logoBytes != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 220, maxHeight: 80),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.memory(_logoBytes!, fit: BoxFit.contain),
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(context.t('logo.none'), textAlign: TextAlign.center),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _uploading ? null : _upload,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: Text(widget.hasLogo ? context.t('logo.change') : context.t('logo.upload')),
                  ),
                  if (widget.hasLogo || _logoBytes != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _delete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(context.t('common.delete')),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
