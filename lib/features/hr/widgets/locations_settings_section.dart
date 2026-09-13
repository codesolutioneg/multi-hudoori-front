import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_download.dart';
import '../../../core/utils/file_pick.dart';
import '../../../core/widgets/sellix_card.dart';
import '../../../l10n/l10n_extension.dart';

class LocationsSettingsSection extends StatefulWidget {
  const LocationsSettingsSection({super.key, this.embedded = false});

  /// When true, hides the section title (parent accordion provides it).
  final bool embedded;

  @override
  State<LocationsSettingsSection> createState() =>
      _LocationsSettingsSectionState();
}

class _LocationsSettingsSectionState extends State<LocationsSettingsSection> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await api.locationsList(activeOnly: false);
      if (mounted)
        setState(() {
          _items = items;
          _loading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _snack(e.toString());
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openForm([Map<String, dynamic>? loc]) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _LocationFormDialog(location: loc),
    );
    if (ok == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> loc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('set.locationDelete')),
        content: Text(context.t('common.deleteQuestion', {'name': loc['name']})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('common.delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.locationDelete(loc['id']);
      _load();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _exportExcel() async {
    try {
      final r = await api.locationsExportXlsx();
      final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
      if (base64.isEmpty) throw Exception(context.t('set.emptyFile'));
      downloadBase64File(
        base64,
        r['filename']?.toString() ?? 'locations.xlsx',
        r['mimeType']?.toString() ??
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      _snack(context.t('set.exported'));
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _importExcel() async {
    try {
      final base64 = await pickExcelBase64();
      if (base64 == null || base64.isEmpty) return;
      final r = await api.locationsImportXlsx(base64);
      _load();
      _snack(r['message']?.toString() ?? context.t('set.imported'));
    } catch (e) {
      _snack(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  context.t('set.locations'),
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: Icon(Icons.refresh, size: 20),
              ),
              OutlinedButton.icon(
                onPressed: _exportExcel,
                icon: Icon(Icons.download, size: 16),
                label: Text('Excel'),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: Icon(Icons.add, size: 16),
                label: Text(context.t('set.locationNew')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.t('set.locationsHint'),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  context.t('set.locationsHint'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                    height: 1.4,
                  ),
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: Icon(Icons.refresh, size: 20),
                tooltip: context.t('common.refresh'),
              ),
              OutlinedButton.icon(
                onPressed: _exportExcel,
                icon: Icon(Icons.download, size: 16),
                label: Text('Excel'),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: Icon(Icons.add, size: 16),
                label: Text(context.t('set.locationNew')),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_items.isEmpty)
          SellixCard(
            child: Column(
              children: [
                Text(context.t('set.locationsNone')),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () => _openForm(),
                      child: Text(context.t('set.locationNew')),
                    ),
                    OutlinedButton(
                      onPressed: _importExcel,
                      child: Text(context.t('set.importExcel')),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          SellixCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _items.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    title: Text(
                      _items[i]['name']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      [
                        if ((_items[i]['actualName']?.toString() ?? '')
                            .trim()
                            .isNotEmpty)
                          _items[i]['actualName'].toString(),
                        if ((_items[i]['code']?.toString() ?? '').isNotEmpty)
                          context.t('common.codeValue', {'code': _items[i]['code']}),
                        _items[i]['active'] == false ? context.t('common.inactive') : context.t('common.active'),
                      ].join(' • '),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _openForm(_items[i]),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _delete(_items[i]),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.upload_file, size: 20),
                  title: Text(context.t('set.importFromExcel')),
                  onTap: _importExcel,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LocationFormDialog extends StatefulWidget {
  const _LocationFormDialog({this.location});
  final Map<String, dynamic>? location;

  @override
  State<_LocationFormDialog> createState() => _LocationFormDialogState();
}

class _LocationFormDialogState extends State<_LocationFormDialog> {
  final _name = TextEditingController();
  final _actualName = TextEditingController();
  final _sequence = TextEditingController(text: '10');
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final loc = widget.location;
    if (loc != null) {
      _name.text = loc['name']?.toString() ?? '';
      _actualName.text = loc['actualName']?.toString() ?? '';
      _sequence.text = '${loc['sequence'] ?? 10}';
      _active = loc['active'] != false;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _actualName.dispose();
    _sequence.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final body = {
        'name': _name.text.trim(),
        'actualName': _actualName.text.trim(),
        'sequence': int.tryParse(_sequence.text.trim()) ?? 10,
        'active': _active,
      };
      if (widget.location != null) {
        await api.locationUpdate(widget.location!['id'], body);
      } else {
        await api.locationCreate(body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.location?['code']?.toString() ?? '';
    return AlertDialog(
      title: Text(widget.location == null ? context.t('set.locationNew') : context.t('set.locationEdit')),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: context.t('set.locationName')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _actualName,
              decoration: InputDecoration(
                labelText: context.t('set.locationActualName'),
                helperText:
                    context.t('set.locationActualHint'),
              ),
            ),
            if (code.isNotEmpty) ...[
              const SizedBox(height: 12),
              InputDecorator(
                decoration: InputDecoration(labelText: context.t('common.code')),
                child: Text(
                  code,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                context.t('common.autoCodeHint'),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _sequence,
              decoration: InputDecoration(labelText: context.t('common.order')),
              keyboardType: TextInputType.number,
            ),
            SwitchListTile(
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: Text(context.t('common.active'), style: TextStyle(fontSize: 14)),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(context.t('common.save')),
        ),
      ],
    );
  }
}
