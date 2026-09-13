import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:biotime_app/l10n/app_localizations.dart';
import 'package:biotime_app/l10n/app_strings.dart';

/// Cross-repo contract for تقرير البصمات.
///
/// The backend returns `PunchSummaryReportRow` (reportPunchSummary.service.ts),
/// which spreads `EmployeeSummaryRow` — the same 13 figures the punch-report
/// Excel prints under each employee. The table renders
/// `reports.column.<backend key>`, so a renamed field shows an empty column and
/// a missing label shows the raw key as a header.
const backendRowKeys = <String>[
  'code',
  'name',
  'locationName',
  'workingDays',
  'earnedLeaveCapped',
  'actualWorkingDays',
  'singlePunch',
  'punchDeduction',
  'absentCount',
  'adminPenalty',
  'overtime',
  'lateDeduction',
  'earlyDeduction',
  'sickDayCount',
  'sickDeduction',
  'totalPenalties',
  'measured',
];

const optionKeys = <String>['reports.punchSummary'];

void main() {
  final ar = AppLocalizations(const Locale('ar'));
  final en = AppLocalizations(const Locale('en'));

  group('punch summary report labels', () {
    for (final key in backendRowKeys) {
      test('column $key has a label in both locales', () {
        final full = 'reports.column.$key';
        expect(ar.t(full), isNot(full), reason: 'Arabic label missing for $full');
        expect(en.t(full), isNot(full), reason: 'English label missing for $full');
        expect(AppStrings.ar.containsKey(full), isTrue);
        expect(AppStrings.en.containsKey(full), isTrue);
      });
    }

    for (final key in optionKeys) {
      test('$key has a label in both locales', () {
        expect(ar.t(key), isNot(key), reason: 'Arabic label missing for $key');
        expect(en.t(key), isNot(key), reason: 'English label missing for $key');
      });
    }

    // HR reads this table next to the Excel export, so the Arabic headers have
    // to be the same words the workbook uses (reportPunchSummary HEADERS).
    test('Arabic column labels match the workbook vocabulary', () {
      expect(ar.t('reports.column.workingDays'), 'عدد أيام العمل');
      expect(ar.t('reports.column.actualWorkingDays'), 'أيام العمل الفعلية');
      expect(ar.t('reports.column.earnedLeaveCapped'), 'أيام الإجازة المستحقة');
      expect(ar.t('reports.column.overtime'), 'الإضافي');
      expect(ar.t('reports.column.absentCount'), 'غياب بدون إذن');
      expect(ar.t('reports.column.lateDeduction'), 'تأخير الحضور');
      expect(ar.t('reports.column.earlyDeduction'), 'تأخير الانصراف');
      expect(ar.t('reports.column.punchDeduction'), 'خصم تكرار البصمة');
      expect(ar.t('reports.column.sickDeduction'), 'خصم الإجازة المرضية');
      expect(ar.t('reports.column.totalPenalties'), 'إجمالي الجزاءات');
      expect(ar.t('reports.punchSummary'), 'تقرير البصمات');
      expect(en.t('reports.punchSummary'), 'Punch report');
    });

    test('the penalty total is the last figure before the measured flag', () {
      expect(backendRowKeys.last, 'measured');
      expect(backendRowKeys[backendRowKeys.length - 2], 'totalPenalties');
    });

    /// totalPenalties is the sum of these, so all of them have to be on screen
    /// or HR cannot reconcile the total without opening the export.
    test('every penalty component is a visible column', () {
      for (final component in const [
        'punchDeduction',
        'absentCount',
        'adminPenalty',
        'lateDeduction',
        'earlyDeduction',
        'sickDeduction',
      ]) {
        expect(backendRowKeys, contains(component));
      }
    });
  });
}
