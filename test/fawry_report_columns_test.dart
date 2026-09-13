import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:biotime_app/l10n/app_localizations.dart';
import 'package:biotime_app/l10n/app_strings.dart';

/// The Fawry report number column falls back to a phone when no Fawry number is
/// stored, so the table has to say which one is shown. A missing label renders
/// the raw key as a header, so the backend row keys are pinned here.
const fawryRowKeys = <String>[
  'code',
  'name',
  'locationName',
  'hasFlag',
  'fawryNumber',
  'numberSourceLabel',
  'statusLabel',
];

void main() {
  final ar = AppLocalizations(const Locale('ar'));
  final en = AppLocalizations(const Locale('en'));

  group('fawry report columns', () {
    for (final key in fawryRowKeys) {
      test('column $key has a label in both locales', () {
        final full = 'reports.column.$key';
        expect(ar.t(full), isNot(full), reason: 'Arabic label missing for $full');
        expect(en.t(full), isNot(full), reason: 'English label missing for $full');
        expect(AppStrings.ar.containsKey(full), isTrue);
        expect(AppStrings.en.containsKey(full), isTrue);
      });
    }

    test('the number source sits right after the number', () {
      expect(
        fawryRowKeys.indexOf('numberSourceLabel'),
        fawryRowKeys.indexOf('fawryNumber') + 1,
      );
    });

    // The table localizes the source from the backend enum rather than showing
    // the Arabic label the Excel uses, so every enum value needs both locales.
    for (final source in const [
      'fawry',
      'work_phone',
      'mobile_phone',
      'biotime_mobile',
      'none',
    ]) {
      test('source $source is localized in both locales', () {
        final key = 'reports.fawrySource.$source';
        expect(ar.t(key), isNot(key), reason: 'Arabic label missing for $key');
        expect(en.t(key), isNot(key), reason: 'English label missing for $key');
      });
    }
  });
}
