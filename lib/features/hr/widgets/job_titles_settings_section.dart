import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/sellix_card.dart';
import '../../../l10n/l10n_extension.dart';

class JobTitlesSettingsSection extends StatefulWidget {
  const JobTitlesSettingsSection({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<JobTitlesSettingsSection> createState() => _JobTitlesSettingsSectionState();
}

class _JobTitlesSettingsSectionState extends State<JobTitlesSettingsSection> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await api.jobTitlesList(activeOnly: false);
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _popup(context.t('common.error'), e.toString());
    }
  }

  Future<void> _popup(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('common.ok'))),
        ],
      ),
    );
  }

  Future<void> _openForm([Map<String, dynamic>? title]) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _JobTitleFormDialog(title: title),
    );
    if (ok == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('set.jobTitleDelete')),
        content: Text(context.t('common.deleteQuestion', {'name': title['name']})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('common.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.t('common.delete'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.jobTitleDelete(title['id']);
      _load();
    } catch (e) {
      _popup(context.t('common.error'), e.toString());
    }
  }

  Future<void> _syncFromEmployees() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final result = await api.jobTitlesSyncFromEmployees();
      final message = result['message']?.toString() ?? context.t('set.synced');
      if (mounted) {
        final titles = result['titles'];
        if (titles is List) {
          setState(() {
            _items = titles
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            _syncing = false;
          });
        } else {
          setState(() => _syncing = false);
          await _load();
        }
        await _popup(context.t('set.synced'), message);
      }
    } catch (e) {
      if (mounted) setState(() => _syncing = false);
      _popup(context.t('common.error'), e.toString());
    }
  }

  Widget _toolbarButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: Icon(Icons.refresh, size: 20),
          tooltip: context.t('common.refresh'),
        ),
        OutlinedButton.icon(
          onPressed: _syncing ? null : _syncFromEmployees,
          icon: _syncing
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.sync, size: 16),
          label: Text(context.t('set.syncFromEmployees')),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => _openForm(),
          icon: Icon(Icons.add, size: 16),
          label: Text(context.t('set.jobTitleNew')),
        ),
      ],
    );
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
                child: Text(context.t('set.jobTitles'), style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              _toolbarButtons(),
            ],
          ),
          const SizedBox(height: 8),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  context.t('set.jobTitlesHint'),
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
              ),
              _toolbarButtons(),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (_items.isEmpty)
          SellixCard(
            child: Column(
              children: [
                Text(context.t('set.jobTitlesNone')),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => _openForm(), child: Text(context.t('set.jobTitleNew'))),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _syncing ? null : _syncFromEmployees,
                  child: Text(context.t('set.syncFromEmployees')),
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
                    subtitle: Text([
                      if ((_items[i]['code']?.toString() ?? '').isNotEmpty) context.t('common.codeValue', {'code': _items[i]['code']}),
                      _items[i]['active'] == false ? context.t('common.inactive') : context.t('common.active'),
                    ].join(' • ')),
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
              ],
            ),
          ),
      ],
    );
  }
}

class _JobTitleFormDialog extends StatefulWidget {
  const _JobTitleFormDialog({this.title});
  final Map<String, dynamic>? title;

  @override
  State<_JobTitleFormDialog> createState() => _JobTitleFormDialogState();
}

class _JobTitleFormDialogState extends State<_JobTitleFormDialog> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final title = widget.title;
    if (title != null) {
      _name.text = title['name']?.toString() ?? '';
      _code.text = title['code']?.toString() ?? '';
      _active = title['active'] != false;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _showError(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('common.error')),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('common.ok'))),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final code = _code.text.trim();
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        'active': _active,
        if (code.isNotEmpty) 'code': code,
      };
      if (widget.title != null) {
        // Allow clearing code on update by always sending the field.
        body['code'] = code.isEmpty ? null : code;
        await api.jobTitleUpdate(widget.title!['id'], body);
      } else {
        await api.jobTitleCreate(body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        await _showError(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title == null ? context.t('set.jobTitleNew') : context.t('set.jobTitleEdit')),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: context.t('set.jobTitleName')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              decoration: InputDecoration(
                labelText: context.t('set.jobTitleCodeOpt'),
                helperText: context.t('set.jobTitleCodeHint'),
              ),
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
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t('common.cancel'))),
        FilledButton(onPressed: _saving ? null : _save, child: Text(context.t('common.save'))),
      ],
    );
  }
}
