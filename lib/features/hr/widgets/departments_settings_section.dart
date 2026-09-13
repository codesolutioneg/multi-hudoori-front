import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/sellix_card.dart';
import '../../../l10n/l10n_extension.dart';

class DepartmentsSettingsSection extends StatefulWidget {
  const DepartmentsSettingsSection({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<DepartmentsSettingsSection> createState() => _DepartmentsSettingsSectionState();
}

class _DepartmentsSettingsSectionState extends State<DepartmentsSettingsSection> {
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
      final items = await api.departmentsList(activeOnly: false);
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _snack(e.toString());
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openForm([Map<String, dynamic>? department]) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DepartmentFormDialog(department: department),
    );
    if (ok == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> department) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('set.departmentDelete')),
        content: Text(context.t('common.deleteQuestion', {'name': department['name']})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('common.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.t('common.delete'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.departmentDelete(department['id']);
      _load();
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
              Expanded(child: Text(context.t('set.departments'), style: TextStyle(fontWeight: FontWeight.w700))),
              IconButton(onPressed: _load, icon: Icon(Icons.refresh, size: 20)),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: Icon(Icons.add, size: 16),
                label: Text(context.t('set.departmentNew')),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  context.t('set.departmentsHint'),
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
              ),
              IconButton(onPressed: _load, icon: Icon(Icons.refresh, size: 20), tooltip: context.t('common.refresh')),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: Icon(Icons.add, size: 16),
                label: Text(context.t('set.departmentNew')),
              ),
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
                Text(context.t('set.departmentsNone')),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => _openForm(), child: Text(context.t('set.departmentNew'))),
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
                    title: Text(_items[i]['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      if ((_items[i]['nameEn']?.toString() ?? '').isNotEmpty) 'EN: ${_items[i]['nameEn']}',
                      if ((_items[i]['code']?.toString() ?? '').isNotEmpty) context.t('common.codeValue', {'code': _items[i]['code']}),
                      _items[i]['active'] == false ? context.t('common.inactive') : context.t('common.active'),
                    ].join(' • ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _openForm(_items[i])),
                        IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => _delete(_items[i])),
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

class _DepartmentFormDialog extends StatefulWidget {
  const _DepartmentFormDialog({this.department});
  final Map<String, dynamic>? department;

  @override
  State<_DepartmentFormDialog> createState() => _DepartmentFormDialogState();
}

class _DepartmentFormDialogState extends State<_DepartmentFormDialog> {
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _sequence = TextEditingController(text: '10');
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final department = widget.department;
    if (department != null) {
      _nameAr.text = department['name']?.toString() ?? department['nameAr']?.toString() ?? '';
      _nameEn.text = department['nameEn']?.toString() ?? '';
      _sequence.text = '${department['sequence'] ?? 10}';
      _active = department['active'] != false;
    }
  }

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _sequence.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameAr.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final body = {
        'name': _nameAr.text.trim(),
        'nameAr': _nameAr.text.trim(),
        'nameEn': _nameEn.text.trim(),
        'sequence': int.tryParse(_sequence.text.trim()) ?? 10,
        'active': _active,
      };
      if (widget.department != null) {
        await api.departmentUpdate(widget.department!['id'], body);
      } else {
        await api.departmentCreate(body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.department?['code']?.toString() ?? '';
    return AlertDialog(
      title: Text(widget.department == null ? context.t('set.departmentNew') : context.t('set.departmentEdit')),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameAr, decoration: InputDecoration(labelText: context.t('set.departmentNameAr'))),
            const SizedBox(height: 12),
            TextField(controller: _nameEn, decoration: InputDecoration(labelText: context.t('set.departmentNameEn'))),
            if (code.isNotEmpty) ...[
              const SizedBox(height: 12),
              InputDecorator(
                decoration: InputDecoration(labelText: context.t('common.code')),
                child: Text(code, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(context.t('common.autoCodeHint'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 12),
            TextField(controller: _sequence, decoration: InputDecoration(labelText: context.t('common.order')), keyboardType: TextInputType.number),
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
