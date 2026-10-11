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
  final homeCompanyId = user['companyId']?.toString() ?? '';

  await showDialog<void>(
    context: context,
    builder: (ctx) => _MembershipsDialog(
      userId: userId,
      userName: user['name']?.toString() ?? '',
      homeCompanyId: homeCompanyId,
      isAr: isAr,
    ),
  );
}

class _MembershipsDialog extends StatefulWidget {
  const _MembershipsDialog({
    required this.userId,
    required this.userName,
    required this.homeCompanyId,
    required this.isAr,
  });

  final String userId;
  final String userName;
  final String homeCompanyId;
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

  bool _isChildUnderHome(String companyId) {
    if (widget.homeCompanyId.isEmpty) return false;
    final byId = {
      for (final c in _companies) c['id']?.toString() ?? '': c,
    };
    var cur = companyId;
    for (var i = 0; i < 32; i++) {
      final row = byId[cur];
      if (row == null) return false;
      final parentId = row['parentCompanyId']?.toString();
      if (parentId == null || parentId.isEmpty) return false;
      if (parentId == widget.homeCompanyId) return true;
      cur = parentId;
    }
    return false;
  }

  List<Map<String, dynamic>> _linkableChildCompanies() {
    final linked = _items.map((e) => e['companyId']?.toString()).toSet();
    return _companies.where((c) {
      final id = c['id']?.toString() ?? '';
      if (id.isEmpty || id == widget.homeCompanyId) return false;
      final parentId = c['parentCompanyId']?.toString();
      if (parentId == null || parentId.isEmpty) return false;
      if (linked.contains(id)) return false;
      return _isChildUnderHome(id);
    }).toList()
      ..sort((a, b) => (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));
  }

  String _childLabel(Map<String, dynamic> c) {
    final parent = c['parentCompany'];
    if (parent is Map) {
      final pn = parent['name']?.toString();
      if (pn != null && pn.isNotEmpty) {
        return '${c['name']} (${c['code']}) — ${widget.isAr ? 'تابعة لـ' : 'under'} $pn';
      }
    }
    return '${c['name']} (${c['code']})';
  }

  Future<void> _addCompany() async {
    if (widget.homeCompanyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isAr
                ? 'المستخدم بدون شركة منزل — أنشئه على الشركة الرئيسية أولاً'
                : 'User has no home company',
          ),
        ),
      );
      return;
    }

    Map<String, dynamic>? home;
    for (final c in _companies) {
      if (c['id']?.toString() == widget.homeCompanyId) {
        home = c;
        break;
      }
    }
    if (home != null && home['parentCompanyId']?.toString().isNotEmpty == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isAr
                ? 'ضع HR على الشركة الرئيسية (بدون شركة أم) ثم اربط الفروع'
                : 'Move HR to the parent company first, then link branches',
          ),
        ),
      );
      return;
    }

    final available = _linkableChildCompanies();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isAr
                ? 'لا فروع متاحة تحت الشركة الرئيسية لهذا المستخدم'
                : 'No branch companies available under this parent',
          ),
        ),
      );
      return;
    }
    String? picked = available.first['id']?.toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(widget.isAr ? 'ربط شركة فرعية' : 'Link branch company'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isAr
                    ? 'يظهر الفروع فقط (شركات لها شركة رئيسية).'
                    : 'Only branch companies (with a parent) are listed.',
                style: AppThemeV2.caption,
              ),
              const Gap(12),
              DropdownButtonFormField<String>(
                value: picked,
                isExpanded: true,
                items: [
                  for (final c in available)
                    DropdownMenuItem(
                      value: c['id']?.toString(),
                      child: Text(_childLabel(c)),
                    ),
                ],
                onChanged: (v) => setLocal(() => picked = v),
              ),
            ],
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
    if (companyId == widget.homeCompanyId) return;
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
    String? homeName;
    for (final c in _companies) {
      if (c['id']?.toString() == widget.homeCompanyId) {
        homeName = c['name']?.toString();
        break;
      }
    }

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
                      if (homeName != null)
                        Text(
                          widget.isAr ? 'الشركة المنزل: $homeName' : 'Home company: $homeName',
                          style: AppThemeV2.caption.copyWith(fontWeight: FontWeight.w600),
                        ),
                      const Gap(8),
                      for (final m in _items)
                        ListTile(
                          dense: true,
                          title: Text(m['companyName']?.toString() ?? ''),
                          subtitle: Text('${m['companyCode']} · ${m['role']}'),
                          trailing: m['companyId']?.toString() == widget.homeCompanyId
                              ? null
                              : IconButton(
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
          label: Text(widget.isAr ? 'ربط فرع' : 'Link branch'),
        ),
      ],
    );
  }
}
