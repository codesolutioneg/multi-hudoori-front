import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../../l10n/l10n_extension.dart';

/// Web-safe alternative to [DropdownButtonFormField] inside dialogs.
class ListPickerField<T> extends StatelessWidget {
  const ListPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final T? value;
  final List<({T value, String label})> options;
  final ValueChanged<T> onChanged;
  final String? hint;

  String _labelFor(BuildContext context, T? v) {
    final placeholder = hint ?? context.t('common.choose');
    if (v == null) return placeholder;
    for (final o in options) {
      if (o.value == v) return o.label;
    }
    return v.toString();
  }

  List<({T value, String label})> get _validOptions =>
      options.where((o) => o.label.isNotEmpty && o.value.toString().isNotEmpty).toList();

  Future<void> _pick(BuildContext context) async {
    final picked = await showDialog<T>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final o in _validOptions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(o.label),
                  trailing: value == o.value
                      ? const Icon(Icons.check_circle, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, o.value),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          _labelFor(context, value),
          style: TextStyle(
            fontSize: 16,
            color: value == null ? Theme.of(context).hintColor : null,
          ),
        ),
      ),
    );
  }
}
