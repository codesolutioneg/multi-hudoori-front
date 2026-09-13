import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../core/theme/app_theme_v2.dart';
import '../../../core/widgets/sellix_card.dart';
import '../../../core/widgets/status_badge.dart';
import 'admin_role_badge.dart';
import '../../../l10n/l10n_extension.dart';

class AdminUserCard extends StatefulWidget {
  const AdminUserCard({
    super.key,
    required this.user,
    required this.onCopyLogin,
    this.onCopyPassword,
    this.onDeactivate,
    this.onTap,
  });

  final Map<String, dynamic> user;
  final VoidCallback onCopyLogin;
  final VoidCallback? onCopyPassword;
  final VoidCallback? onDeactivate;
  final VoidCallback? onTap;

  @override
  State<AdminUserCard> createState() => _AdminUserCardState();
}

class _AdminUserCardState extends State<AdminUserCard> {
  bool _showPassword = false;

  bool get _active => widget.user['active'] != false;

  String get _name => widget.user['name']?.toString() ?? '';

  String get _login => widget.user['login']?.toString() ?? '';

  String? get _email {
    final email = widget.user['email']?.toString();
    if (email == null || email.isEmpty || email == _login) return null;
    return email;
  }

  String? get _password {
    final p = widget.user['initialPassword']?.toString();
    if (p == null || p.isEmpty) return null;
    return p;
  }

  String get _role => widget.user['role']?.toString() ?? '';

  String? get _locationName {
    final name = widget.user['locationName']?.toString();
    return name != null && name.isNotEmpty ? name : null;
  }

  String? get _createdAt {
    final raw = widget.user['createdAt']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  @override
  Widget build(BuildContext context) {
    return SellixCard(
      hover: true,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppThemeV2.cardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AdminUserAvatar(name: _name),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(_name, style: AppThemeV2.title),
                        ),
                        AdminRoleBadge(role: _role),
                        const Gap(8),
                        StatusBadge(
                          label: _active ? context.t('admin.userCard.active') : context.t('admin.userCard.disabled'),
                          tone: _active ? BadgeTone.online : BadgeTone.offline,
                        ),
                      ],
                    ),
                    const Gap(8),
                    _CredentialRow(
                      icon: Icons.login_rounded,
                      label: context.t('admin.login'),
                      value: _login,
                      obscure: false,
                      onCopy: _login.isEmpty ? null : widget.onCopyLogin,
                    ),
                    if (_email != null) ...[
                      const Gap(4),
                      _CredentialRow(
                        icon: Icons.alternate_email_rounded,
                        label: context.t('admin.email'),
                        value: _email!,
                        obscure: false,
                      ),
                    ],
                    if (_password != null) ...[
                      const Gap(4),
                      _CredentialRow(
                        icon: Icons.lock_outline_rounded,
                        label: context.t('admin.password'),
                        value: _password!,
                        obscure: !_showPassword,
                        onToggleVisibility: () => setState(() => _showPassword = !_showPassword),
                        onCopy: widget.onCopyPassword,
                      ),
                    ],
                    if (_locationName != null) ...[
                      const Gap(4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: AppThemeV2.textMuted),
                          const Gap(6),
                          Expanded(
                            child: Text(
                              _locationName!,
                              style: AppThemeV2.caption.copyWith(color: AppThemeV2.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_createdAt != null) ...[
                      const Gap(4),
                      Text(
                        context.t('admin.createdAt', {'date': _createdAt}),
                        style: AppThemeV2.caption,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.obscure,
    this.onCopy,
    this.onToggleVisibility,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool obscure;
  final VoidCallback? onCopy;
  final VoidCallback? onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: AppThemeV2.textMuted),
        const Gap(6),
        Text('$label: ', style: AppThemeV2.caption.copyWith(fontWeight: FontWeight.w600)),
        Expanded(
          child: SelectableText(
            obscure ? '•' * value.length.clamp(6, 14) : value,
            style: AppThemeV2.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        if (onToggleVisibility != null)
          IconButton(
            tooltip: obscure ? context.t('admin.show') : context.t('admin.hide'),
            onPressed: onToggleVisibility,
            icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        if (onCopy != null)
          IconButton(
            tooltip: context.t('admin.copyField', {'label': label}),
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 18),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
      ],
    );
  }
}
