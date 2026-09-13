import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/l10n_extension.dart';

class EmployeeTabSection extends StatelessWidget {
  const EmployeeTabSection({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SellixCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// Wraps a row/option with light grey hover + bottom divider.
class EmployeeHoverRow extends StatefulWidget {
  const EmployeeHoverRow({
    super.key,
    required this.child,
    this.showDivider = true,
  });

  final Widget child;
  final bool showDivider;

  @override
  State<EmployeeHoverRow> createState() => _EmployeeHoverRowState();
}

class _EmployeeHoverRowState extends State<EmployeeHoverRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _hover ? const Color(0xFFF1F5F9) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: widget.showDivider
              ? const Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        margin: const EdgeInsets.only(bottom: 4),
        child: widget.child,
      ),
    );
  }
}

class EmployeeBoolField extends StatelessWidget {
  const EmployeeBoolField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.withHover = true,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool withHover;

  @override
  Widget build(BuildContext context) {
    final tile = SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      value: value,
      onChanged: onChanged,
    );
    if (!withHover) return tile;
    return EmployeeHoverRow(child: tile);
  }
}

class EmployeeDateField extends StatelessWidget {
  const EmployeeDateField({
    super.key,
    required this.label,
    required this.controller,
    this.onPick,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: onPick != null,
      enableInteractiveSelection: onPick == null,
      onTap: onPick == null
          ? null
          : () {
              FocusManager.instance.primaryFocus?.unfocus();
              onPick!();
            },
      decoration: InputDecoration(
        labelText: label,
        hintText: 'YYYY-MM-DD',
        suffixIcon: onPick == null ? null : const Icon(Icons.calendar_today, size: 18),
      ),
    );
  }
}

class EmployeeNumberField extends StatelessWidget {
  const EmployeeNumberField({
    super.key,
    required this.label,
    required this.controller,
  });

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class EmployeeSelectField<T> extends StatelessWidget {
  const EmployeeSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.allowEmpty = true,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool allowEmpty;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: [
        if (allowEmpty) DropdownMenuItem<T>(value: null, child: const Text('—')),
        ...items,
      ],
      onChanged: onChanged,
    );
  }
}

Future<bool> pickDate(BuildContext context, TextEditingController controller) async {
  final current = DateTime.tryParse(controller.text.trim());
  final picked = await showDatePicker(
    context: context,
    initialDate: current ?? DateTime.now(),
    firstDate: DateTime(1950),
    lastDate: DateTime.now(),
  );
  if (picked == null) return false;
  controller.text =
      '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
  return true;
}

int? ageFromBirthdayText(String text) {
  final bday = DateTime.tryParse(text.trim());
  if (bday == null) return null;
  final today = DateTime.now();
  var age = today.year - bday.year;
  if (today.month < bday.month || (today.month == bday.month && today.day < bday.day)) {
    age--;
  }
  return age >= 0 ? age : null;
}

const employeeDocumentStatusKeys = <String>{'none', 'copy', 'original'};

/// Kept for validation of stored status values.
const employeeDocumentStatuses = <String, String>{
  'none': 'none',
  'copy': 'copy',
  'original': 'original',
};

class EmployeeDocumentField extends StatelessWidget {
  const EmployeeDocumentField({
    super.key,
    required this.label,
    this.statusValue,
    this.onStatusChanged,
    required this.hasFile,
    required this.uploading,
    required this.onUpload,
    this.onView,
    this.useBoolStatus = false,
    this.boolValue = false,
    this.onBoolChanged,
  });

  final String label;
  final String? statusValue;
  final ValueChanged<String>? onStatusChanged;
  final bool hasFile;
  final bool uploading;
  final VoidCallback onUpload;
  final VoidCallback? onView;
  final bool useBoolStatus;
  final bool boolValue;
  final ValueChanged<bool>? onBoolChanged;

  @override
  Widget build(BuildContext context) {
    return EmployeeHoverRow(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (useBoolStatus && onBoolChanged != null)
            EmployeeBoolField(
              label: label,
              value: boolValue,
              onChanged: onBoolChanged!,
              withHover: false,
            )
          else if (statusValue != null && onStatusChanged != null)
            EmployeeDocumentStatusField(label: label, value: statusValue!, onChanged: onStatusChanged!)
          else
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: uploading ? null : onUpload,
                icon: uploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file, size: 18),
                label: Text(
                  uploading
                      ? context.t('employees.docs.uploading')
                      : context.t('employees.docs.upload'),
                ),
              ),
              if (hasFile && onView != null)
                OutlinedButton.icon(
                  onPressed: onView,
                  icon: const Icon(Icons.visibility, size: 18),
                  label: Text(context.t('employees.docs.view')),
                ),
              if (hasFile)
                Chip(
                  label: Text(
                    context.t('employees.docs.uploaded'),
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class EmployeeDocumentStatusField extends StatelessWidget {
  const EmployeeDocumentStatusField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = employeeDocumentStatusKeys.contains(value) ? value : 'none';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final key in employeeDocumentStatusKeys)
              FilterChip(
                label: Text(context.t('employees.docStatus.$key')),
                selected: current == key,
                onSelected: (_) => onChanged(key),
              ),
          ],
        ),
      ],
    );
  }
}

Map<String, String> employeeSkillLevels(BuildContext context) => <String, String>{
  'beginner': context.t('tab.beginner'),
  'intermediate': context.t('tab.intermediate'),
  'advanced': context.t('tab.advanced'),
  'expert': context.t('tab.expert'),
};

Map<String, String> employeeInsuranceStatuses(BuildContext context) => <String, String>{
  'active': context.t('tab.insured'),
  'inactive': context.t('tab.uninsured'),
  'suspended': context.t('tab.suspended'),
  'retired': context.t('tab.pension'),
};

Map<String, String> employeeMedicalInsuranceStatuses(BuildContext context) => <String, String>{
  'active': context.t('tab.enabled'),
  'inactive': context.t('tab.disabled'),
  'pending': context.t('tab.pending'),
};

Widget employeeTabHint(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
  );
}
