import 'package:flutter_test/flutter_test.dart';
import 'package:biotime_app/l10n/app_strings.dart';
import 'package:biotime_app/features/payroll/payroll_line_edit_model.dart';

void main() {
  group('payroll line edit sections', () {
    test('covers attendance, manual, advances, earnings, and notes', () {
      final ids = kPayrollLineEditSections.map((s) => s.id).toSet();
      expect(
        ids,
        containsAll(['earnings', 'attendance', 'manual', 'advances', 'notes']),
      );
    });

    test('includes the fields HR asked to edit', () {
      final keys = allPayrollLineEditFields().map((f) => f.key).toSet();
      expect(
        keys,
        containsAll([
          'workingDays',
          'overtimeHours',
          'lateDeduction',
          'absentDeduction',
          'punchDeductionCheckin',
          'manualDebit',
          'deductionChecks',
          'penaltyDeductionValue',
          'advanceShortTotal',
          'advanceLongTotal',
          'basicSalary',
          'notes',
        ]),
      );
    });

    test('filter finds late deduction by Arabic label', () {
      final filtered = filterPayrollLineEditSections(
        'تأخير',
        label: (key) => AppStrings.ar[key] ?? key,
      );
      expect(filtered, isNotEmpty);
      final keys = [
        for (final s in filtered)
          for (final f in s.fields) f.key,
      ];
      expect(keys, contains('lateDeduction'));
      expect(keys, isNot(contains('advanceShortTotal')));
    });
  });

  group('buildPayrollLineUpdatePayload', () {
    test('parses numbers and keeps notes as string', () {
      final payload = buildPayrollLineUpdatePayload({
        'basicSalary': '9000',
        'workingDays': '28.5',
        'overtimeHours': '2',
        'lateDeduction': '100',
        'lateCheckoutDeduction': '0',
        'earlyDeduction': '0',
        'absentDeduction': '300',
        'sickDeduction': '0',
        'punchDeductionCheckin': '0',
        'punchDeductionCheckout': '0',
        'leaveAbsenceDeductionValue': '0',
        'adminDeduction': '1',
        'penaltyDeductionValue': '50',
        'manualDebit': '10',
        'fines': '0',
        'deductionChecks': '0',
        'groupedChecks': '0',
        'healthCertificatesDeduction': '0',
        'fractionDeduction': '0',
        'documentsDeduction': '0',
        'previousSettlements': '0',
        'previousInsurance': '0',
        'socialInsurance': '200',
        'medicalInsurance': '100',
        'advanceShortTotal': '1500',
        'advanceLongTotal': '0',
        'notes': 'تعديل يدوي للاختبار',
      });

      expect(payload['basicSalary'], 9000);
      expect(payload['workingDays'], 28.5);
      expect(payload['notes'], 'تعديل يدوي للاختبار');
      expect(payload['advanceShortTotal'], 1500);
    });

    test('empty / invalid number becomes 0', () {
      expect(parsePayrollEditNumber(''), 0);
      expect(parsePayrollEditNumber('abc'), 0);
      expect(parsePayrollEditNumber('1,250.5'), 1250.5);
    });
  });

  group('previewPayrollLineEdit', () {
    test('matches backend-style earnings and deductions', () {
      final payload = buildPayrollLineUpdatePayload({
        for (final f in allPayrollLineEditFields())
          f.key: f.isNotes ? '' : '0',
        'basicSalary': '3000',
        'workingDays': '30',
        'overtimeHours': '3',
        'lateDeduction': '100',
        'absentDeduction': '100',
        'manualDebit': '50',
        'advanceShortTotal': '200',
        'socialInsurance': '0',
        'medicalInsurance': '0',
      });

      final preview = previewPayrollLineEdit(payload);
      // work days = 3000, OT = 300, earnings = 3300
      expect(preview.workDaysSalary, 3000);
      expect(preview.overtimeAmount, 300);
      expect(preview.totalEarnings, 3300);
      // late+absent+manual+advance = 450
      expect(preview.totalDeductions, 450);
      expect(preview.netSalary, 2850);
    });

    test('admin deduction days converts to money via daily rate', () {
      final payload = <String, dynamic>{
        'basicSalary': 3000,
        'workingDays': 30,
        'overtimeHours': 0,
        'adminDeduction': 1.5, // 1.5 * (3000/30) = 150
        for (final k in [
          'lateDeduction',
          'lateCheckoutDeduction',
          'earlyDeduction',
          'punchDeductionCheckin',
          'punchDeductionCheckout',
          'absentDeduction',
          'sickDeduction',
          'socialInsurance',
          'medicalInsurance',
          'penaltyDeductionValue',
          'leaveAbsenceDeductionValue',
          'manualDebit',
          'fines',
          'deductionChecks',
          'groupedChecks',
          'healthCertificatesDeduction',
          'fractionDeduction',
          'documentsDeduction',
          'previousSettlements',
          'previousInsurance',
          'advanceShortTotal',
          'advanceLongTotal',
        ])
          k: 0,
      };
      final preview = previewPayrollLineEdit(payload);
      expect(preview.totalDeductions, 150);
      expect(preview.netSalary, 2850);
    });

    test('net never goes negative', () {
      final preview = previewPayrollLineEdit({
        'basicSalary': 1000,
        'workingDays': 10,
        'overtimeHours': 0,
        'advanceShortTotal': 99999,
        'lateDeduction': 0,
        'lateCheckoutDeduction': 0,
        'earlyDeduction': 0,
        'punchDeductionCheckin': 0,
        'punchDeductionCheckout': 0,
        'absentDeduction': 0,
        'sickDeduction': 0,
        'socialInsurance': 0,
        'medicalInsurance': 0,
        'penaltyDeductionValue': 0,
        'leaveAbsenceDeductionValue': 0,
        'adminDeduction': 0,
        'manualDebit': 0,
        'fines': 0,
        'deductionChecks': 0,
        'groupedChecks': 0,
        'healthCertificatesDeduction': 0,
        'fractionDeduction': 0,
        'documentsDeduction': 0,
        'previousSettlements': 0,
        'previousInsurance': 0,
        'advanceLongTotal': 0,
      });
      expect(preview.netSalary, 0);
    });
  });

  group('initialPayrollLineEditValues', () {
    test('loads line map into string controllers map', () {
      final values = initialPayrollLineEditValues({
        'basicSalary': 12500,
        'workingDays': 29,
        'notes': 'hi',
        'advanceShortTotal': 0,
      });
      expect(values['basicSalary'], '12500');
      expect(values['workingDays'], '29');
      expect(values['notes'], 'hi');
      expect(values['lateDeduction'], '0');
    });
  });
}
