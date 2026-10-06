import 'package:flutter/material.dart';
import '../../../core/platform/mobile_platform.dart';

import '../../../core/theme/app_theme_v2.dart';
import '../../../core/utils/entity_id.dart';
import '../../../core/widgets/searchable_select_field.dart';
import '../../mobile/mobile_ui.dart';
import '../../../l10n/l10n_extension.dart';
import '../reports_page.dart';

/// The per-report option controls. Split out of ReportsPage because the five
/// option sets together are longer than the page that hosts them.
class ReportOptionsPanel extends StatelessWidget {
  const ReportOptionsPanel({
    super.key,
    required this.report,
    required this.locations,
    required this.departments,
    required this.documentTypes,
    required this.locationId,
    required this.departmentId,
    required this.requireNationalId,
    required this.includeArchived,
    required this.dateFrom,
    required this.dateTo,
    required this.includeNeverScheduled,
    required this.includeUnmappedDevices,
    required this.fawryFilter,
    required this.insuranceKind,
    required this.insuranceFilter,
    required this.requiredDocuments,
    required this.documentsFilter,
    required this.acceptCopies,
    required this.healthMode,
    required this.warningDaysController,
    required this.onLocationChanged,
    required this.onDepartmentChanged,
    required this.onRequireNationalIdChanged,
    required this.onIncludeArchivedChanged,
    required this.onPickDate,
    required this.onIncludeNeverScheduledChanged,
    required this.onIncludeUnmappedDevicesChanged,
    required this.onFawryFilterChanged,
    required this.onInsuranceKindChanged,
    required this.onInsuranceFilterChanged,
    required this.onToggleDocument,
    required this.onDocumentsFilterChanged,
    required this.onAcceptCopiesChanged,
    required this.onHealthModeChanged,
  });

  final HrReport report;
  final List<Map<String, dynamic>> locations;
  final List<Map<String, dynamic>> departments;
  final List<Map<String, dynamic>> documentTypes;
  final String? locationId;
  final String? departmentId;
  final bool requireNationalId;
  final bool includeArchived;
  final DateTime dateFrom;
  final DateTime dateTo;
  final bool includeNeverScheduled;
  final bool includeUnmappedDevices;
  final String fawryFilter;
  final String insuranceKind;
  final String insuranceFilter;
  final Set<String> requiredDocuments;
  final String documentsFilter;
  final bool acceptCopies;
  final String healthMode;
  final TextEditingController warningDaysController;

  final ValueChanged<String?> onLocationChanged;
  final ValueChanged<String?> onDepartmentChanged;
  final ValueChanged<bool> onRequireNationalIdChanged;
  final ValueChanged<bool> onIncludeArchivedChanged;
  final ValueChanged<bool> onPickDate;
  final ValueChanged<bool> onIncludeNeverScheduledChanged;
  final ValueChanged<bool> onIncludeUnmappedDevicesChanged;
  final ValueChanged<String> onFawryFilterChanged;
  final ValueChanged<String> onInsuranceKindChanged;
  final ValueChanged<String> onInsuranceFilterChanged;
  final void Function(String type, bool selected) onToggleDocument;
  final ValueChanged<String> onDocumentsFilterChanged;
  final ValueChanged<bool> onAcceptCopiesChanged;
  final ValueChanged<String> onHealthModeChanged;

  String _formatted(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// The national ID gate only means something where the underlying data depends
  /// on one, so it is hidden elsewhere rather than shown as a no-op.
  bool get _showNationalIdGate =>
      report == HrReport.fawry ||
      report == HrReport.insurance ||
      report == HrReport.documents ||
      report == HrReport.healthCertificates ||
      report == HrReport.employeeEmails;

  Widget _dropdown({
    required BuildContext context,
    required String label,
    required String value,
    required List<(String, String)> options,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final (optionValue, optionLabel) in options)
          DropdownMenuItem(value: optionValue, child: Text(optionLabel)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: isNativeMobile ? double.infinity : 260,
              child: SearchableSelectField<String>(
                label: context.t('reports.filterLocation'),
                allLabel: report == HrReport.punchSummary
                    ? context.t('reports.punchReportSelectLocation')
                    : context.t('common.all'),
                value: locationId,
                options: [
                  for (final l in locations)
                    SearchableSelectOption(
                      value: EntityId.parse(l['id']) ?? '',
                      label: l['name']?.toString() ?? '',
                    ),
                ],
                onChanged: onLocationChanged,
              ),
            ),
            SizedBox(
              width: isNativeMobile ? double.infinity : 260,
              child: SearchableSelectField<String>(
                label: context.t('reports.filterDepartment'),
                allLabel: context.t('common.all'),
                value: departmentId,
                options: [
                  for (final d in departments)
                    SearchableSelectOption(
                      value: EntityId.parse(d['id']) ?? '',
                      label: d['name']?.toString() ?? '',
                    ),
                ],
                onChanged: onDepartmentChanged,
              ),
            ),
            ..._reportSpecific(context),
          ],
        ),
        const SizedBox(height: 4),
        if (_showNationalIdGate)
          _OptionToggle(
            title: context.t('reports.requireNationalId'),
            hint: context.t('reports.requireNationalIdHint'),
            value: requireNationalId,
            onChanged: (v) => onRequireNationalIdChanged(v ?? false),
          ),
        if (report == HrReport.noPunches) ...[
          _OptionToggle(
            title: context.t('reports.includeNeverScheduled'),
            hint: context.t('reports.includeNeverScheduledHint'),
            value: includeNeverScheduled,
            onChanged: (v) => onIncludeNeverScheduledChanged(v ?? false),
          ),
          _OptionToggle(
            title: context.t('reports.includeArchived'),
            value: includeArchived,
            onChanged: (v) => onIncludeArchivedChanged(v ?? false),
          ),
        ],
        if (report == HrReport.locationMismatch) ...[
          _OptionToggle(
            title: context.t('reports.includeUnmappedDevices'),
            hint: context.t('reports.includeUnmappedDevicesHint'),
            value: includeUnmappedDevices,
            onChanged: (v) => onIncludeUnmappedDevicesChanged(v ?? false),
          ),
          _OptionToggle(
            title: context.t('reports.includeArchived'),
            value: includeArchived,
            onChanged: (v) => onIncludeArchivedChanged(v ?? false),
          ),
        ],
        if (report == HrReport.punchSummary)
          _OptionToggle(
            title: context.t('reports.includeArchived'),
            value: includeArchived,
            onChanged: (v) => onIncludeArchivedChanged(v ?? false),
          ),
        if (report == HrReport.employeeEmails)
          _OptionToggle(
            title: context.t('reports.includeArchived'),
            value: includeArchived,
            onChanged: (v) => onIncludeArchivedChanged(v ?? false),
          ),
        if (report == HrReport.documents)
          _OptionToggle(
            title: context.t('reports.acceptCopies'),
            value: acceptCopies,
            onChanged: (v) => onAcceptCopiesChanged(v ?? true),
          ),
        if (report == HrReport.documents) ...[
          const SizedBox(height: 8),
          Text(context.t('reports.requiredDocuments'), style: AppThemeV2.caption),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in documentTypes)
                FilterChip(
                  label: Text(type['label']?.toString() ?? ''),
                  selected: requiredDocuments.contains(type['value']?.toString()),
                  onSelected: (selected) =>
                      onToggleDocument(type['value']?.toString() ?? '', selected),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            requiredDocuments.isEmpty
                ? context.t('reports.allDocumentsRequired')
                : context.t('reports.selectedDocumentsRequired', {
                    'count': '${requiredDocuments.length}',
                  }),
            style: AppThemeV2.caption,
          ),
          const SizedBox(height: 4),
          Text(
            context.t('reports.documentsMatchAnyHint'),
            style: AppThemeV2.caption,
          ),
        ],
      ],
    );
  }

  List<Widget> _reportSpecific(BuildContext context) {
    switch (report) {
      case HrReport.noPunches:
      case HrReport.locationMismatch:
      case HrReport.punchSummary:
      case HrReport.employeeHirings:
      case HrReport.employeeExits:
        return [
          SizedBox(
            width: isNativeMobile ? double.infinity : 200,
            child: OutlinedButton.icon(
              onPressed: () => onPickDate(true),
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text('${context.t('common.from')}: ${_formatted(dateFrom)}'),
            ),
          ),
          SizedBox(
            width: isNativeMobile ? double.infinity : 200,
            child: OutlinedButton.icon(
              onPressed: () => onPickDate(false),
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text('${context.t('common.to')}: ${_formatted(dateTo)}'),
            ),
          ),
        ];
      case HrReport.employeeEmails:
        return const [];
      case HrReport.fawry:
        return [
          SizedBox(
            width: isNativeMobile ? double.infinity : 260,
            child: _dropdown(
              context: context,
              label: context.t('reports.show'),
              value: fawryFilter,
              options: [
                ('all', context.t('common.all')),
                ('with_card', context.t('reports.fawryWith')),
                ('without_card', context.t('reports.fawryWithout')),
                ('data_errors', context.t('reports.fawryErrors')),
              ],
              onChanged: onFawryFilterChanged,
            ),
          ),
        ];
      case HrReport.insurance:
        return [
          SizedBox(
            width: isNativeMobile ? double.infinity : 260,
            child: _dropdown(
              context: context,
              label: context.t('reports.insuranceKind'),
              value: insuranceKind,
              options: [
                ('both', context.t('reports.insuranceBoth')),
                ('social', context.t('reports.insuranceSocial')),
                ('medical', context.t('reports.insuranceMedical')),
              ],
              onChanged: onInsuranceKindChanged,
            ),
          ),
          SizedBox(
            width: isNativeMobile ? double.infinity : 260,
            child: _dropdown(
              context: context,
              label: context.t('reports.show'),
              value: insuranceFilter,
              options: [
                ('all', context.t('common.all')),
                ('insured', context.t('reports.insured')),
                ('not_insured', context.t('reports.notInsured')),
              ],
              onChanged: onInsuranceFilterChanged,
            ),
          ),
        ];
      case HrReport.documents:
        return [
          SizedBox(
            width: isNativeMobile ? double.infinity : 260,
            child: _dropdown(
              context: context,
              label: context.t('reports.show'),
              value: documentsFilter,
              options: [
                ('incomplete', context.t('reports.documentsIncomplete')),
                ('complete', context.t('reports.documentsComplete')),
                ('all', context.t('common.all')),
              ],
              onChanged: onDocumentsFilterChanged,
            ),
          ),
        ];
      case HrReport.healthCertificates:
        return [
          SizedBox(
            width: isNativeMobile ? double.infinity : 260,
            child: _dropdown(
              context: context,
              label: context.t('reports.show'),
              value: healthMode,
              options: [
                ('expired_or_expiring', context.t('reports.healthExpiredOrExpiring')),
                ('expired', context.t('reports.healthExpired')),
                ('expiring', context.t('reports.healthExpiring')),
                ('missing', context.t('reports.healthMissing')),
                ('all', context.t('common.all')),
              ],
              onChanged: onHealthModeChanged,
            ),
          ),
          SizedBox(
            width: isNativeMobile ? double.infinity : 200,
            child: TextField(
              decoration: InputDecoration(labelText: context.t('reports.warningDays')),
              keyboardType: TextInputType.number,
              controller: warningDaysController,
            ),
          ),
        ];
    }
  }
}

/// Report option: a checkbox on web, a switch card on native mobile.
class _OptionToggle extends StatelessWidget {
  const _OptionToggle({
    required this.title,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String title;
  final String? hint;
  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!isNativeMobile) {
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
        title: Text(title),
        subtitle: hint == null ? null : Text(hint!, style: AppThemeV2.caption),
        value: value,
        onChanged: onChanged,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: value ? MobileUi.primarySoft : const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: MobileUi.text(13.5, weight: FontWeight.w700, height: 1.3),
                      ),
                      if (hint != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          hint!,
                          style: MobileUi.text(11.5, weight: FontWeight.w500, color: MobileUi.muted, height: 1.35),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
