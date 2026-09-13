import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/l10n_extension.dart';

class DeductionImportSkippedPanel extends StatelessWidget {
  const DeductionImportSkippedPanel({
    super.key,
    required this.message,
    required this.skipped,
    this.onClose,
  });

  final String message;
  final List<Map<String, dynamic>> skipped;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    if (skipped.isEmpty) return const SizedBox.shrink();

    return SellixCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message.isNotEmpty ? message : context.t('wiz.importedWithSkips'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (onClose != null)
                IconButton(onPressed: onClose, icon: const Icon(Icons.close, size: 20)),
            ],
          ),
          const SizedBox(height: 8),
          Text(context.t('wiz.skippedRows', {'count': skipped.length}), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: skipped.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final row = skipped[i];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(row['code']?.toString() ?? '—'),
                  subtitle: Text(row['reason']?.toString() ?? ''),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
