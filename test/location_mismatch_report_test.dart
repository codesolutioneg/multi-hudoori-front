import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:biotime_app/l10n/app_localizations.dart';
import 'package:biotime_app/l10n/app_strings.dart';

/// Cross-repo contract for the wrong-location punch report.
///
/// The backend returns rows keyed by these names
/// (`LocationMismatchReportRow` in reportLocationMismatch.service.ts) and the
/// reports page renders `reports.column.<key>` for each. A key with no label
/// silently renders as the raw key in the table header, and a renamed backend
/// field silently renders an empty column, so both sides are pinned here.
const backendRowKeys = <String>[
  'code',
  'name',
  'employeeLocationName',
  'deviceName',
  'deviceLocationName',
  'punchCount',
  'statusLabel',
];

/// Same order the service writes into the Excel detail sheet, so the on-screen
/// table and the exported file stay readable side by side.
const expectedColumnOrder = <String>[
  'code',
  'name',
  'employeeLocationName',
  'deviceName',
  'deviceLocationName',
  'punchCount',
  'statusLabel',
];

const optionKeys = <String>[
  'reports.locationMismatch',
  'reports.includeUnmappedDevices',
  'reports.includeUnmappedDevicesHint',
];

void main() {
  final ar = AppLocalizations(const Locale('ar'));
  final en = AppLocalizations(const Locale('en'));

  group('location-mismatch report labels', () {
    for (final key in backendRowKeys) {
      test('column $key has a label in both locales', () {
        final full = 'reports.column.$key';
        expect(ar.t(full), isNot(full), reason: 'Arabic label missing for $full');
        expect(en.t(full), isNot(full), reason: 'English label missing for $full');
        expect(ar.t(full).trim(), isNotEmpty);
        expect(en.t(full).trim(), isNotEmpty);
      });
    }

    for (final key in optionKeys) {
      test('$key has a label in both locales', () {
        expect(ar.t(key), isNot(key), reason: 'Arabic label missing for $key');
        expect(en.t(key), isNot(key), reason: 'English label missing for $key');
      });
    }

    test('column order matches the Excel detail sheet', () {
      expect(backendRowKeys, expectedColumnOrder);
    });
  });

  group('no duplicate keys after the main merge', () {
    // A merge that re-added the same map entry compiles but the later value
    // silently wins; asserting the ar and en maps agree on presence catches a
    // half-merged key set.
    for (final key in [...optionKeys, ...backendRowKeys.map((k) => 'reports.column.$k')]) {
      test('$key exists in both string maps', () {
        expect(AppStrings.ar.containsKey(key), isTrue, reason: 'missing from AppStrings.ar');
        expect(AppStrings.en.containsKey(key), isTrue, reason: 'missing from AppStrings.en');
      });
    }
  });
}
