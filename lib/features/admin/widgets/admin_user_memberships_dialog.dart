import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_theme_v2.dart';
import '../../../core/utils/api_error_message.dart';
import '../../../l10n/l10n_extension.dart';

Future<void> showAdminUserMembershipsDialog(
  BuildContext context, {
  required Map<String, dynamic> user,
}) async {
  final isAr = context.l10n.isAr;
  final userId = user['id']?.toString() ?? '';
  if (userId.isEmpty) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => _MembershipsDialog(userId: userId, userName: user['name']?.toString() ?? '', isAr: isAr),
  );
}

class _MembershipsDialog extends StatefulWidget {
  const _MembershipsDialog({
    required this.userId,
    required this.userName,
    required this.isAr,
  });

  final String userId;
  final String userName;
  final bool isAr;

  @override
  State<_MembershipsDialog> createState() => _MembershipsDialogState();
}

class _MembershipsDialogState extends State<_MembershipsDialog> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _companies = [];
  bool _loading = true;
  String? _error;

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
      final results = await Future.wait([
        api.adminMembershipsList(userId: widget.userId),
        api.adminCompaniesList(),
      ]);
      final memberships = results[0]['memberships'];
      final companies = results[1]['companies'];
      if (mounted) {
        setState(() {
          _items = memberships is List
              ? memberships.map((e) => Map<String, dynamic>.from(e as Map)).toList()
              : [];
          _companies = companies is List
              ? companies.map((e) => Map<String, dynamic>.from(e as Map)).toList()
              : [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyApiError(context, e);
        });
      }
    }
  }

  Future<void> _addCompany() async {
    final linked = _items.map((e) => e['companyId']?.toString()).toSet();
    final available = _companies.where((c) => !linked.contains(c['id']?.toString())).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.isAr ? 'لا شركات إضافية' : 'No more companies')),
      );
      return;
    }
    String? picked = available.first['id']?.toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(widget.isAr ? 'ربط شركة' : 'Link company'),
          content: DropdownButtonFormField<String>(
            value: picked,
            items: [
              for (final c in available)
                DropdownMenuItem(
                  value: c['id']?.toString(),
                  child: Text('${c['name']} (${c['code']})'),
                ),
            ],
            onChanged: (v) => setLocal(() => picked = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(widget.isAr ? 'إلغاء' : 'Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(widget.isAr ? 'ربط' : 'Link')),
          ],
        ),
      ),
    );
    if (ok != true || picked == null) return;
    try {
      await api.adminMembershipsAdd(userId: widget.userId, companyId: picked!);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiError(context, e))));
      }
    }
  }

  Future<void> _remove(String companyId, String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.isAr ? 'إزالة العضوية' : 'Remove membership'),
        content: Text(widget.isAr ? 'إزالة الوصول إلى $label؟' : 'Remove access to $label?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(widget.isAr ? 'إلغاء' : 'Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(widget.isAr ? 'إزالة' : 'Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.adminMembershipsRemove(userId: widget.userId, companyId: companyId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiError(context, e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isAr ? 'عضويات — ${widget.userName}' : 'Memberships — ${widget.userName}'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Text(_error!)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final m in _items)
                        ListTile(
                          dense: true,
                          title: Text(m['companyName']?.toString() ?? ''),
                          subtitle: Text('${m['companyCode']} · ${m['role']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.link_off_rounded),
                            onPressed: () => _remove(
                              m['companyId']?.toString() ?? '',
                              m['companyName']?.toString() ?? '',
                            ),
                          ),
                        ),
                      if (_items.isEmpty) Text(widget.isAr ? 'لا عضويات' : 'No memberships'),
                    ],
                  ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.isAr ? 'إغلاق' : 'Close')),
        FilledButton.icon(
          onPressed: _loading ? null : _addCompany,
          icon: const Icon(Icons.add_link_rounded),
          label: Text(widget.isAr ? 'ربط شركة' : 'Link company'),
        ),
      ],
    );
  }
}
