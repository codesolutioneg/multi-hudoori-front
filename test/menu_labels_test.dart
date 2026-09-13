import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:biotime_app/l10n/app_localizations.dart';
import 'package:biotime_app/l10n/app_strings.dart';

/// The backend decides the navigation: it sends a menu id per entry and the app
/// looks up the label. An id with no label silently renders as the raw id in the
/// nav bar, so the mapping is a cross-repo contract worth pinning.
const backendMenuIds = <String>[
  'dashboard',
  'my_schedule',
  'my_attendance',
  'my_requests',
  'my_payslip',
  'hr_dashboard',
  'employees',
  'hiring_appointments',
  'shifts',
  'shift_grid',
  'attendance',
  'deductions',
  'advances',
  'payroll',
  'settings',
];

/// Keys whose English copy quotes Arabic on purpose — a worked example of the
/// very field the hint is about.
const bilingualByDesign = <String>{'employees.field.jobTitleHint'};

void main() {
  final ar = AppLocalizations(const Locale('ar'));
  final en = AppLocalizations(const Locale('en'));

  group('menu labels', () {
    for (final id in backendMenuIds) {
      test('$id has a label in both locales', () {
        expect(ar.menuLabel(id), isNot(id), reason: 'Arabic label missing for $id');
        expect(en.menuLabel(id), isNot(id), reason: 'English label missing for $id');
        expect(ar.menuLabel(id).trim(), isNotEmpty);
        expect(en.menuLabel(id).trim(), isNotEmpty);
      });
    }

    test('an unknown id falls back to the id rather than throwing', () {
      expect(ar.menuLabel('not_a_menu'), 'not_a_menu');
    });
  });

  group('string table', () {
    test('both locales define exactly the same keys', () {
      final missingFromEn = AppStrings.ar.keys.where((k) => !AppStrings.en.containsKey(k));
      final missingFromAr = AppStrings.en.keys.where((k) => !AppStrings.ar.containsKey(k));
      expect(missingFromEn, isEmpty, reason: 'Keys absent from the English table');
      expect(missingFromAr, isEmpty, reason: 'Keys absent from the Arabic table');
    });

    test('no key resolves to an empty string', () {
      final blank = AppStrings.ar.entries
          .where((e) => e.value.trim().isEmpty)
          .map((e) => e.key)
          .followedBy(
            AppStrings.en.entries.where((e) => e.value.trim().isEmpty).map((e) => e.key),
          );
      expect(blank, isEmpty);
    });

    test('English values are English', () {
      final arabic = RegExp(r'[\u0600-\u06FF]');
      final leaked = AppStrings.en.entries
          .where((e) => arabic.hasMatch(e.value) && !bilingualByDesign.contains(e.key))
          .map((e) => '${e.key} = ${e.value}');
      expect(leaked, isEmpty, reason: 'Arabic left in the English table');
    });

    test('every key referenced in the app exists in the table', () {
      final call = RegExp(r"(?:context\.t|\bt|\btr)\(\s*'([\w.]+)'");
      final source = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('app_strings.dart'));

      final unknown = <String>{};
      for (final file in source) {
        for (final m in call.allMatches(file.readAsStringSync())) {
          final key = m.group(1)!;
          if (!AppStrings.ar.containsKey(key)) unknown.add('$key (${file.path})');
        }
      }
      expect(unknown, isEmpty, reason: 'Keys that would render as raw ids');
    });
  });
}
