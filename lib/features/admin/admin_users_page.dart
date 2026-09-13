import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/utils/api_connection_help.dart';
import '../../core/widgets/alert_banner.dart';
import '../../core/widgets/hr_local_data_info.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/skeleton_box.dart';
import 'widgets/admin_role_badge.dart';
import 'widgets/admin_user_card.dart';
import '../../l10n/l10n_extension.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;
  String? _roleFilter;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final users = await api.adminUsersList();
      if (mounted) setState(() { _users = users; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = _friendlyError(e); _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _users.where((u) {
      if (_roleFilter == 'HR') {
        final role = u['role']?.toString() ?? '';
        if (role != 'HR_USER' && role != 'HR_SUPERVISOR' && role != 'HR_MANAGER' && role != 'BRANCH_MANAGER') return false;
      } else if (_roleFilter != null && u['role']?.toString() != _roleFilter) {
        return false;
      }
      final active = u['active'] != false;
      if (_statusFilter == 'active' && !active) return false;
      if (_statusFilter == 'inactive' && active) return false;
      if (q.isEmpty) return true;
      final name = u['name']?.toString().toLowerCase() ?? '';
      final login = u['login']?.toString().toLowerCase() ?? '';
      final email = u['email']?.toString().toLowerCase() ?? '';
      final location = u['locationName']?.toString().toLowerCase() ?? '';
      return name.contains(q) || login.contains(q) || email.contains(q) || location.contains(q);
    }).toList();
  }

  Future<void> _copyText(String text, String label) async {
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('admin.copied', {'label': label})),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _userLogin(Map<String, dynamic> user) => user['login']?.toString() ?? '';

  String? _userPassword(Map<String, dynamic> user) {
    final p = user['initialPassword']?.toString();
    if (p == null || p.isEmpty) return null;
    return p;
  }

  Future<void> _resetPassword(Map<String, dynamic> user) async {
    final id = user['id']?.toString();
    if (id == null || id.isEmpty) return;
    final name = user['name']?.toString() ?? context.t('admin.theUser');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('admin.resetPassword')),
        content: Text(context.t('admin.resetQuestion', {'name': name})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('common.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.t('admin.reset'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final result = await api.adminUserResetPassword(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('admin.passwordCreated')), behavior: SnackBarBehavior.floating),
      );
      final password = result['password']?.toString();
      if (password != null && password.isNotEmpty) {
        await _copyText(password, context.t('admin.password'));
      }
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _copyLogin(String login) => _copyText(login, context.t('admin.login'));

  Future<void> _confirmDeactivate(Map<String, dynamic> user) async {
    final id = user['id']?.toString();
    if (id == null || id.isEmpty) return;
    final name = user['name']?.toString() ?? context.t('admin.theUser');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('admin.deactivateTitle')),
        content: Text(context.t('admin.deactivateQuestion', {'name': name})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('common.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppThemeV2.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('admin.deactivate')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await api.adminUserDeactivate(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('admin.deactivated')), behavior: SnackBarBehavior.floating),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _showUserDetails(Map<String, dynamic> user) {
    final login = _userLogin(user);
    final password = _userPassword(user);
    var showPassword = false;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppThemeV2.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AdminUserAvatar(name: user['name']?.toString() ?? '', size: 52),
                  const Gap(14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user['name']?.toString() ?? '', style: AppThemeV2.headline.copyWith(fontSize: 20)),
                        const Gap(6),
                        AdminRoleBadge(role: user['role']?.toString() ?? ''),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap(20),
              _DetailRow(
                label: context.t('admin.login'),
                value: login,
                onCopy: login.isEmpty ? null : () => _copyLogin(login),
              ),
              if (user['email'] != null && user['email'].toString().isNotEmpty && user['email'].toString() != login)
                _DetailRow(label: context.t('admin.email'), value: user['email']?.toString() ?? ''),
              _DetailRow(
                label: context.t('admin.password'),
                value: password == null
                    ? context.t('admin.passwordNotStored')
                    : (showPassword ? password : '•' * password.length.clamp(6, 14)),
                obscured: password != null && !showPassword,
                onToggleVisibility: password == null
                    ? null
                    : () => setSheetState(() => showPassword = !showPassword),
                onCopy: password == null ? null : () => _copyText(password, context.t('admin.password')),
              ),
              if (user['locationName'] != null)
                _DetailRow(label: context.t('shiftGrid.location'), value: user['locationName']?.toString() ?? ''),
              _DetailRow(
                label: context.t('common.status'),
                value: user['active'] == false ? context.t('admin.userCard.disabled') : context.t('admin.userCard.active'),
              ),
              if (user['createdAt'] != null)
                _DetailRow(label: context.t('admin.createdAtLabel'), value: user['createdAt']?.toString().substring(0, 10) ?? ''),
              const Gap(16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: login.isEmpty ? null : () => _copyLogin(login),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(context.t('admin.copyLogin')),
                    ),
                  ),
                  if (password != null) ...[
                    const Gap(10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copyText(password, context.t('admin.password')),
                        icon: const Icon(Icons.key_rounded, size: 18),
                        label: Text(context.t('admin.copyPassword')),
                      ),
                    ),
                  ],
                ],
              ),
              if (password == null) ...[
                const Gap(10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _resetPassword(user);
                  },
                  icon: const Icon(Icons.lock_reset_rounded, size: 18),
                  label: Text(context.t('admin.newPassword')),
                ),
              ],
              if (user['active'] != false) ...[
                const Gap(10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppThemeV2.danger),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmDeactivate(user);
                  },
                  icon: const Icon(Icons.person_off_outlined, size: 18),
                  label: Text(context.t('admin.deactivate')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('Failed to fetch') || msg.contains('ClientException')) {
      return ApiConnectionHelp.connectionError(api.baseUrl);
    }
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return AppPageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.t('admin.users'),
            subtitle: context.t('admin.usersSubtitle', {
              'total': _users.length,
              'active': _users.where((u) => u['active'] != false).length,
            }),
            icon: Icons.people_outline_rounded,
            showRefresh: true,
            onRefresh: _load,
            actions: [
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.adminCreateUser),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: Text(context.t('admin.newUser')),
                style: FilledButton.styleFrom(
                  backgroundColor: AppThemeV2.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const Gap(16),
          SellixCard(
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: context.t('admin.searchHint'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppThemeV2.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const Gap(12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: context.t('common.all'),
                      selected: _roleFilter == null,
                      onTap: () => setState(() => _roleFilter = null),
                    ),
                    _FilterChip(
                      label: 'HR',
                      selected: _roleFilter == 'HR',
                      onTap: () => setState(() => _roleFilter = _roleFilter == 'HR' ? null : 'HR'),
                    ),
                    for (final role in ['EMPLOYEE', 'HR_USER', 'HR_SUPERVISOR', 'HR_MANAGER', 'BRANCH_MANAGER', 'DEVICE_MANAGER'])
                      _FilterChip(
                        label: role,
                        selected: _roleFilter == role,
                        onTap: () => setState(() => _roleFilter = _roleFilter == role ? null : role),
                      ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: context.t('admin.userCard.active'),
                      selected: _statusFilter == 'active',
                      onTap: () => setState(() => _statusFilter = _statusFilter == 'active' ? 'all' : 'active'),
                    ),
                    _FilterChip(
                      label: context.t('admin.userCard.disabled'),
                      selected: _statusFilter == 'inactive',
                      onTap: () => setState(() => _statusFilter = _statusFilter == 'inactive' ? 'all' : 'inactive'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Gap(16),
          if (_error != null)
            AlertBanner(message: _error!, tone: AlertBannerTone.error)
          else if (_loading)
            Column(
              children: List.generate(
                4,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: SkeletonBox(
                    height: 96,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
            )
          else if (filtered.isEmpty)
            HrEmptyListCard(
              message: _users.isEmpty ? context.t('admin.noUsers') : context.t('admin.noMatches'),
              actionLabel: context.t('admin.createUser'),
              onAction: () => context.go(AppRoutes.adminCreateUser),
            )
          else
            ...filtered.map(
              (u) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AdminUserCard(
                  user: u,
                  onCopyLogin: () => _copyLogin(_userLogin(u)),
                  onCopyPassword: _userPassword(u) == null
                      ? null
                      : () => _copyText(_userPassword(u)!, context.t('admin.password')),
                  onDeactivate: u['active'] == false ? null : () => _confirmDeactivate(u),
                  onTap: () => _showUserDetails(u),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppThemeV2.primarySoft,
      checkmarkColor: AppThemeV2.primary,
      side: BorderSide(color: selected ? AppThemeV2.primary.withValues(alpha: 0.3) : AppThemeV2.border),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.onCopy,
    this.onToggleVisibility,
    this.obscured = false,
  });
  final String label;
  final String value;
  final VoidCallback? onCopy;
  final VoidCallback? onToggleVisibility;
  final bool obscured;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: AppThemeV2.caption)),
          Expanded(
            child: SelectableText(
              value,
              style: AppThemeV2.body.copyWith(color: AppThemeV2.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
          if (onToggleVisibility != null)
            IconButton(
              tooltip: obscured ? context.t('admin.show') : context.t('admin.hide'),
              icon: Icon(obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
              onPressed: onToggleVisibility,
              visualDensity: VisualDensity.compact,
            ),
          if (onCopy != null)
            IconButton(
              tooltip: context.t('admin.copy'),
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: onCopy,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
