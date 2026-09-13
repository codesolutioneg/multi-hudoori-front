import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_localizations.dart';
import '../locale/locale_cubit.dart';
import '../theme/app_colors.dart';

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.watch<LocaleCubit>().state;

    return PopupMenuButton<String>(
      tooltip: l10n.language,
      onSelected: (code) => context.read<LocaleCubit>().setLocale(Locale(code)),
      itemBuilder: (context) => [
        CheckedPopupMenuItem(value: 'ar', checked: locale.languageCode == 'ar', child: Text(l10n.arabic)),
        CheckedPopupMenuItem(value: 'en', checked: locale.languageCode == 'en', child: Text(l10n.english)),
      ],
      child: compact
          ? const Icon(Icons.translate, color: AppColors.primary)
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.translate, size: 20, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(locale.languageCode.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              ),
            ),
    );
  }
}
