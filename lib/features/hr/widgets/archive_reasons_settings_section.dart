import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/sellix_card.dart';
import '../../../l10n/l10n_extension.dart';

class ArchiveReasonsSettingsSection extends StatefulWidget {
  const ArchiveReasonsSettingsSection({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ArchiveReasonsSettingsSection> createState() =>
      _ArchiveReasonsSettingsSectionState();
}

class _ArchiveReasonsSettingsSectionState
    extends State<ArchiveReasonsSettingsSection> {
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
      final items = await api.archiveReasonsList(activeOnly: false);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
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

  Future<void> _openForm([Map<String, dynamic>? reason]) async {
    final nameCtrl = TextEditingController(text: reason?['name']?.toString() ?? '');
    var active = reason == null ? true : reason['active'] != false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(reason == null ? context.t('set.archiveReasonNew') : context.t('set.archiveReasonEdit')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: context.t('set.reasonField'),
                  hintText: context.t('set.reasonExample'),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.t('common.active')),
                value: active,
                onChanged: (v) => setDialogState(() => active = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('common.cancel'))),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                try {
                  if (reason == null) {
                    await api.archiveReasonCreate({'name': name, 'active': active});
                  } else {
                    await api.archiveReasonUpdate(reason['id'], {
                      'name': name,
                      'active': active,
                    });
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: Text(context.t('common.save')),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    if (ok == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> reason) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('set.archiveReasonDelete')),
        content: Text(context.t('common.deleteQuestion', {'name': reason['name']})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('common.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.t('common.delete'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.archiveReasonDelete(reason['id']);
      _load();
    } catch (e) {
      _popup(context.t('common.error'), e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.embedded
                    ? context.t('set.archiveReasonsHint')
                    : context.t('set.archiveReasons'),
                style: widget.embedded
                    ? const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      )
                    : const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: Icon(Icons.refresh, size: 20),
              tooltip: context.t('common.refresh'),
            ),
            FilledButton.icon(
              onPressed: () => _openForm(),
              icon: Icon(Icons.add, size: 16),
              label: Text(context.t('set.newReason')),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
                Text(context.t('set.noReasons')),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _openForm(),
                  child: Text(context.t('set.newReason')),
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
                      _items[i]['active'] == false ? context.t('common.inactive') : context.t('common.active'),
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
              ],
            ),
          ),
      ],
    );
  }
}
