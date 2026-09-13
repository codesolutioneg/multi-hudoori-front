/// Pure model for HR payroll-line edit dialog (testable without widgets).
library;

/// One editable numeric (or notes) field on a payroll line.
class PayrollLineEditField {
  const PayrollLineEditField({
    required this.key,
    required this.labelKey,
    this.isNotes = false,
  });

  final String key;

  /// Key in `app_strings.dart`; the dialog renders it in the viewer's language.
  final String labelKey;
  final bool isNotes;
}

/// Group of related fields shown as one section in the edit popup.
class PayrollLineEditSection {
  const PayrollLineEditSection({
    required this.id,
    required this.titleKey,
    required this.fields,
    this.initiallyExpanded = false,
  });

  final String id;

  /// Key in `app_strings.dart`; see [PayrollLineEditField.labelKey].
  final String titleKey;
  final List<PayrollLineEditField> fields;
  final bool initiallyExpanded;
}

/// Canonical editable layout — order matches payroll workflow.
const kPayrollLineEditSections = <PayrollLineEditSection>[
  PayrollLineEditSection(
    id: 'earnings',
    titleKey: 'payF.earnings',
    initiallyExpanded: true,
    fields: [
      PayrollLineEditField(key: 'basicSalary', labelKey: 'payF.baseSalary'),
      PayrollLineEditField(key: 'workingDays', labelKey: 'payF.workDays'),
      PayrollLineEditField(key: 'overtimeHours', labelKey: 'payF.overtimeHours'),
      PayrollLineEditField(key: 'socialInsurance', labelKey: 'payF.socialInsurance'),
      PayrollLineEditField(key: 'medicalInsurance', labelKey: 'payF.medicalInsurance'),
    ],
  ),
  PayrollLineEditSection(
    id: 'attendance',
    titleKey: 'payF.attendanceSection',
    initiallyExpanded: true,
    fields: [
      PayrollLineEditField(key: 'lateDeduction', labelKey: 'payF.lateDeduction'),
      PayrollLineEditField(key: 'lateCheckoutDeduction', labelKey: 'payF.lateLeaveDeduction'),
      PayrollLineEditField(key: 'earlyDeduction', labelKey: 'payF.earlyLeaveDeduction'),
      PayrollLineEditField(key: 'absentDeduction', labelKey: 'payF.absenceDeduction'),
      PayrollLineEditField(key: 'sickDeduction', labelKey: 'payF.sickDeduction'),
      PayrollLineEditField(key: 'punchDeductionCheckin', labelKey: 'payF.missingIn'),
      PayrollLineEditField(key: 'punchDeductionCheckout', labelKey: 'payF.missingOut'),
      PayrollLineEditField(
        key: 'leaveAbsenceDeductionValue',
        labelKey: 'payF.extraLeave',
      ),
    ],
  ),
  PayrollLineEditSection(
    id: 'manual',
    titleKey: 'payF.manualSection',
    initiallyExpanded: true,
    fields: [
      PayrollLineEditField(key: 'adminDeduction', labelKey: 'payF.adminDays'),
      PayrollLineEditField(key: 'penaltyDeductionValue', labelKey: 'payF.penaltyValue'),
      PayrollLineEditField(key: 'manualDebit', labelKey: 'payF.manualDebit'),
      PayrollLineEditField(key: 'fines', labelKey: 'payF.fines'),
      PayrollLineEditField(key: 'deductionChecks', labelKey: 'payF.personalCheques'),
      PayrollLineEditField(key: 'groupedChecks', labelKey: 'payF.pooledCheques'),
      PayrollLineEditField(
        key: 'healthCertificatesDeduction',
        labelKey: 'payF.healthCerts',
      ),
      PayrollLineEditField(key: 'fractionDeduction', labelKey: 'payF.breakage'),
      PayrollLineEditField(key: 'documentsDeduction', labelKey: 'payF.paperDeduction'),
      PayrollLineEditField(key: 'previousSettlements', labelKey: 'payF.priorAdjustments'),
      PayrollLineEditField(key: 'previousInsurance', labelKey: 'payF.priorInsurance'),
    ],
  ),
  PayrollLineEditSection(
    id: 'advances',
    titleKey: 'payF.advancesSection',
    initiallyExpanded: true,
    fields: [
      PayrollLineEditField(key: 'advanceShortTotal', labelKey: 'payF.shortAdvance'),
      PayrollLineEditField(key: 'advanceLongTotal', labelKey: 'payF.longAdvance'),
    ],
  ),
  PayrollLineEditSection(
    id: 'notes',
    titleKey: 'payF.notes',
    initiallyExpanded: false,
    fields: [
      PayrollLineEditField(key: 'notes', labelKey: 'payF.notes', isNotes: true),
    ],
  ),
];

List<PayrollLineEditField> allPayrollLineEditFields() => [
  for (final s in kPayrollLineEditSections) ...s.fields,
];

double parsePayrollEditNumber(String raw) {
  final t = raw.trim().replaceAll(',', '');
  if (t.isEmpty) return 0;
  return double.tryParse(t) ?? 0;
}

/// Build API payload from controller/text maps. Notes only included when present.
Map<String, dynamic> buildPayrollLineUpdatePayload(
  Map<String, String> values, {
  Iterable<PayrollLineEditField>? fields,
}) {
  final list = fields?.toList() ?? allPayrollLineEditFields();
  final payload = <String, dynamic>{};
  for (final f in list) {
    final raw = values[f.key] ?? '';
    if (f.isNotes) {
      payload['notes'] = raw.trim();
    } else {
      payload[f.key] = parsePayrollEditNumber(raw);
    }
  }
  return payload;
}

/// Live preview mirrors backend `recalculatePayrollLineTotals` (+ derived earnings).
class PayrollLineEditPreview {
  const PayrollLineEditPreview({
    required this.workDaysSalary,
    required this.overtimeAmount,
    required this.totalEarnings,
    required this.totalDeductions,
    required this.netSalary,
  });

  final double workDaysSalary;
  final double overtimeAmount;
  final double totalEarnings;
  final double totalDeductions;
  final double netSalary;
}

double _round2(double n) => (n * 100).round() / 100;

double _adminPenaltyMoney(double basicSalary, double adminDeductionDays) {
  final daily = basicSalary / 30;
  return _round2(daily * (adminDeductionDays));
}

PayrollLineEditPreview previewPayrollLineEdit(Map<String, dynamic> payload) {
  final basic = (payload['basicSalary'] as num?)?.toDouble() ?? 0;
  final days = (payload['workingDays'] as num?)?.toDouble() ?? 0;
  final otHours = (payload['overtimeHours'] as num?)?.toDouble() ?? 0;
  final workDaysSalary = _round2((basic / 30) * days);
  final overtimeAmount = _round2((basic / 30) * otHours);
  final totalEarnings = _round2(workDaysSalary + overtimeAmount);

  final attendanceDed = _round2(
    ((payload['lateDeduction'] as num?)?.toDouble() ?? 0) +
        ((payload['lateCheckoutDeduction'] as num?)?.toDouble() ?? 0) +
        ((payload['earlyDeduction'] as num?)?.toDouble() ?? 0) +
        ((payload['punchDeductionCheckin'] as num?)?.toDouble() ?? 0) +
        ((payload['punchDeductionCheckout'] as num?)?.toDouble() ?? 0) +
        ((payload['absentDeduction'] as num?)?.toDouble() ?? 0) +
        ((payload['sickDeduction'] as num?)?.toDouble() ?? 0),
  );

  final adminPenalty = _adminPenaltyMoney(
    basic,
    (payload['adminDeduction'] as num?)?.toDouble() ?? 0,
  );

  final manualDed = _round2(
    ((payload['socialInsurance'] as num?)?.toDouble() ?? 0) +
        ((payload['medicalInsurance'] as num?)?.toDouble() ?? 0) +
        ((payload['penaltyDeductionValue'] as num?)?.toDouble() ?? 0) +
        ((payload['leaveAbsenceDeductionValue'] as num?)?.toDouble() ?? 0) +
        adminPenalty +
        ((payload['manualDebit'] as num?)?.toDouble() ?? 0) +
        ((payload['fines'] as num?)?.toDouble() ?? 0) +
        ((payload['deductionChecks'] as num?)?.toDouble() ?? 0) +
        ((payload['groupedChecks'] as num?)?.toDouble() ?? 0) +
        ((payload['healthCertificatesDeduction'] as num?)?.toDouble() ?? 0) +
        ((payload['fractionDeduction'] as num?)?.toDouble() ?? 0) +
        ((payload['documentsDeduction'] as num?)?.toDouble() ?? 0) +
        ((payload['previousSettlements'] as num?)?.toDouble() ?? 0) +
        ((payload['previousInsurance'] as num?)?.toDouble() ?? 0),
  );

  final advances = _round2(
    ((payload['advanceShortTotal'] as num?)?.toDouble() ?? 0) +
        ((payload['advanceLongTotal'] as num?)?.toDouble() ?? 0),
  );

  final totalDeductions = _round2(attendanceDed + manualDed + advances);
  final netSalary = (totalEarnings - totalDeductions).clamp(0, double.infinity).toDouble();
  return PayrollLineEditPreview(
    workDaysSalary: workDaysSalary,
    overtimeAmount: overtimeAmount,
    totalEarnings: totalEarnings,
    totalDeductions: totalDeductions,
    netSalary: _round2(netSalary),
  );
}

/// Filter sections and fields by label or key, for the search box.
///
/// Labels are translation keys, so [label] resolves each one to the text the
/// user is actually reading — searching «late» must work in English too.
List<PayrollLineEditSection> filterPayrollLineEditSections(
  String query, {
  List<PayrollLineEditSection> sections = kPayrollLineEditSections,
  String Function(String key)? label,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return sections;
  final text = label ?? (key) => key;
  bool matchesSection(PayrollLineEditSection s) =>
      text(s.titleKey).toLowerCase().contains(q);
  bool matchesField(PayrollLineEditField f) =>
      text(f.labelKey).toLowerCase().contains(q) ||
      f.key.toLowerCase().contains(q);

  return [
    for (final s in sections)
      if (matchesSection(s) || s.fields.any(matchesField))
        PayrollLineEditSection(
          id: s.id,
          titleKey: s.titleKey,
          initiallyExpanded: true,
          fields: [
            for (final f in s.fields)
              if (matchesSection(s) || matchesField(f)) f,
          ],
        ),
  ];
}

Map<String, String> initialPayrollLineEditValues(Map<String, dynamic> line) {
  final out = <String, String>{};
  for (final f in allPayrollLineEditFields()) {
    if (f.isNotes) {
      out[f.key] = line[f.key]?.toString() ?? '';
    } else {
      final v = line[f.key];
      if (v == null) {
        out[f.key] = '0';
      } else if (v is num) {
        out[f.key] = v == v.roundToDouble() ? '${v.toInt()}' : '$v';
      } else {
        out[f.key] = v.toString();
      }
    }
  }
  return out;
}
