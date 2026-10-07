import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme_v2.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';

/// Shown when the signed-in user has more than one company membership.
class HrCompanySwitcher extends StatelessWidget {
  const HrCompanySwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (a, b) =>
          a.memberships != b.memberships ||
          a.activeCompanyId != b.activeCompanyId ||
          a.isPlatformAdmin != b.isPlatformAdmin,
      builder: (context, auth) {
        if (auth.isPlatformAdmin || auth.memberships.length <= 1) {
          return const SizedBox.shrink();
        }
        final active = auth.activeCompanyId;
        CompanyMembership? current;
        for (final m in auth.memberships) {
          if (m.companyId == active) {
            current = m;
            break;
          }
        }
        final label = current?.companyName ?? auth.activeCompanyName ?? '—';
        return Padding(
          padding: const EdgeInsets.only(left: 8, right: 4),
          child: PopupMenuButton<String>(
            tooltip: 'تبديل الشركة',
            onSelected: (id) async {
              CompanyMembership? picked;
              for (final m in auth.memberships) {
                if (m.companyId == id) {
                  picked = m;
                  break;
                }
              }
              if (picked == null) return;
              await context.read<AuthCubit>().switchActiveCompany(
                    id: picked.companyId,
                    name: picked.companyName,
                    code: picked.companyCode,
                  );
            },
            itemBuilder: (ctx) => [
              for (final m in auth.memberships)
                PopupMenuItem<String>(
                  value: m.companyId,
                  child: Row(
                    children: [
                      if (m.companyId == active)
                        const Icon(Icons.check_rounded, size: 18, color: AppThemeV2.primary)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${m.companyName} (${m.companyCode})',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppThemeV2.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppThemeV2.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business_rounded, size: 16, color: AppThemeV2.primary),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppThemeV2.caption.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
