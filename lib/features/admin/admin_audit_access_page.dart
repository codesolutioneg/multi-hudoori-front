import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';
import '../../l10n/l10n_extension.dart';

class AdminAuditAccessPage extends StatefulWidget {
  const AdminAuditAccessPage({
    super.key,
    this.feature = 'audit_log',
    this.strings = 'auditPerm',
  });

  final String feature;

  /// Key prefix in `app_strings.dart`; the page reads `<prefix>.title`,
  /// `.subtitle`, `.hint`, `.on` and `.off` from it.
  final String strings;

  @override
  State<AdminAuditAccessPage> createState() => _AdminAuditAccessPageState();
}

class _AdminAuditAccessPageState extends State<AdminAuditAccessPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

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
      final data = await api.adminFeatureGrantsList(feature: widget.feature);
      final items = ((data['items'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggle(Map<String, dynamic> row, bool enabled) async {
    final userId = row['userId']?.toString() ?? '';
    if (userId.isEmpty) return;
    setState(() => _busy.add(userId));
    try {
      await api.adminFeatureGrantSet(
        userId: userId,
        enabled: enabled,
        feature: widget.feature,
      );
      if (!mounted) return;
      setState(() {
        row['enabled'] = enabled;
        _busy.remove(userId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('${widget.strings}.${enabled ? 'on' : 'off'}'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(userId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: context.t('${widget.strings}.title'),
          subtitle: context.t('${widget.strings}.subtitle'),
          icon: Icons.manage_accounts_outlined,
          actions: [
            IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        SellixCard(
          child: Text(
            context.t('${widget.strings}.hint'),
            style: const TextStyle(height: 1.4, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger))))
        else if (_items.isEmpty)
          Expanded(child: Center(child: Text(context.t('admin.noHrUsers'))))
        else
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final row = _items[i];
                final userId = row['userId']?.toString() ?? '';
                final enabled = row['enabled'] == true;
                final busy = _busy.contains(userId);
                return SellixCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          (row['name']?.toString().isNotEmpty == true
                                  ? row['name'].toString()[0]
                                  : '?')
                              .toUpperCase(),
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row['name']?.toString() ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              row['login']?.toString() ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusTag(
                        label: row['role']?.toString() ?? '',
                        type: StatusTagType.info,
                      ),
                      const SizedBox(width: 12),
                      if (busy)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Switch.adaptive(
                          value: enabled,
                          onChanged: (v) => _toggle(row, v),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
