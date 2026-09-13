import 'package:flutter/material.dart';

import '../../../core/theme/app_theme_v2.dart';
import '../../../core/utils/entity_id.dart';
import '../../../core/widgets/searchable_select_field.dart';
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
              width: 260,
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
              width: 260,
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
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: Text(context.t('reports.requireNationalId')),
            subtitle: Text(
              context.t('reports.requireNationalIdHint'),
              style: AppThemeV2.caption,
            ),
            value: requireNationalId,
            onChanged: (v) => onRequireNationalIdChanged(v ?? false),
          ),
        if (report == HrReport.noPunches) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: Text(context.t('reports.includeNeverScheduled')),
            subtitle: Text(
              context.t('reports.includeNeverScheduledHint'),
              style: AppThemeV2.caption,
            ),
            value: includeNeverScheduled,
            onChanged: (v) => onIncludeNeverScheduledChanged(v ?? false),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: Text(context.t('reports.includeArchived')),
            value: includeArchived,
            onChanged: (v) => onIncludeArchivedChanged(v ?? false),
          ),
        ],
        if (report == HrReport.locationMismatch) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: Text(context.t('reports.includeUnmappedDevices')),
            subtitle: Text(
              context.t('reports.includeUnmappedDevicesHint'),
              style: AppThemeV2.caption,
            ),
            value: includeUnmappedDevices,
            onChanged: (v) => onIncludeUnmappedDevicesChanged(v ?? false),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: Text(context.t('reports.includeArchived')),
            value: includeArchived,
            onChanged: (v) => onIncludeArchivedChanged(v ?? false),
          ),
        ],
        if (report == HrReport.punchSummary)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: Text(context.t('reports.includeArchived')),
            value: includeArchived,
            onChanged: (v) => onIncludeArchivedChanged(v ?? false),
          ),
        if (report == HrReport.employeeEmails)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: Text(context.t('reports.includeArchived')),
            value: includeArchived,
            onChanged: (v) => onIncludeArchivedChanged(v ?? false),
          ),
        if (report == HrReport.documents)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: Text(context.t('reports.acceptCopies')),
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
            width: 200,
            child: OutlinedButton.icon(
              onPressed: () => onPickDate(true),
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text('${context.t('common.from')}: ${_formatted(dateFrom)}'),
            ),
          ),
          SizedBox(
            width: 200,
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
            width: 260,
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
            width: 260,
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
            width: 260,
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
            width: 260,
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
            width: 260,
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
            width: 200,
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
