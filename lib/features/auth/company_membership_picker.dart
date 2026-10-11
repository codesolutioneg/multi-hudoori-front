import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme_v2.dart';
import '../../l10n/l10n_extension.dart';
import 'auth_cubit.dart';
import 'auth_state.dart';

/// Modal after login when the HR user has more than one company membership.
Future<void> showCompanyMembershipPicker(
  BuildContext context, {
  required List<CompanyMembership> memberships,
  String? activeCompanyId,
}) async {
  if (memberships.length <= 1) return;
  final isAr = context.l10n.isAr;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(isAr ? 'اختر الشركة' : 'Choose company'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isAr
                  ? 'حسابك مربوط بأكثر من شركة. اختر الشركة التي تريد العمل عليها الآن.'
                  : 'Your account is linked to more than one company. Pick which one to use now.',
              style: AppThemeV2.caption,
            ),
            const SizedBox(height: 12),
            for (final m in memberships)
              ListTile(
                leading: Icon(
                  m.companyId == activeCompanyId
                      ? Icons.check_circle_rounded
                      : Icons.business_outlined,
                  color: m.companyId == activeCompanyId
                      ? AppThemeV2.primary
                      : AppThemeV2.textMuted,
                ),
                title: Text(m.companyName, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${m.companyCode} · ${m.role}'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await context.read<AuthCubit>().switchActiveCompany(
                        id: m.companyId,
                        name: m.companyName,
                        code: m.companyCode,
                      );
                  if (context.mounted) {
                    context.read<AuthCubit>().clearPendingCompanyPicker();
                  }
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            context.read<AuthCubit>().clearPendingCompanyPicker();
          },
          child: Text(isAr ? 'متابعة بالشركة الحالية' : 'Keep current company'),
        ),
      ],
    ),
  );
}
