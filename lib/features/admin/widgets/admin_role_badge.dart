import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_v2.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../l10n/l10n_extension.dart';

class AdminRoleBadge extends StatelessWidget {
  const AdminRoleBadge({super.key, required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (role.toUpperCase()) {
      'HR_MANAGER' => (tr('admin.role.hrManager'), BadgeTone.warning),
      'HR_SUPERVISOR' => (tr('admin.role.hrSupervisor'), BadgeTone.info),
      'BRANCH_MANAGER' => (tr('admin.role.branchManager'), BadgeTone.online),
      'HR_USER' => (tr('admin.role.hrUser'), BadgeTone.info),
      'DEVICE_MANAGER' => (tr('admin.role.deviceManager'), BadgeTone.draft),
      'EMPLOYEE' => (tr('admin.role.employee'), BadgeTone.online),
      _ => (role, BadgeTone.offline),
    };
    return StatusBadge(label: label, tone: tone);
  }
}

class AdminUserAvatar extends StatelessWidget {
  const AdminUserAvatar({super.key, required this.name, this.size = 44});

  final String name;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppThemeV2.primaryGradient,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppThemeV2.primary.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}
