import 'package:flutter/material.dart';

import '../core/locale/locale_cubit.dart';
import 'app_localizations.dart';
import 'app_strings.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String t(String key, [Map<String, Object?> params = const {}]) => l10n.t(key, params);
}

/// Translate without a `BuildContext`, using whatever language is on screen.
///
/// Only for code that genuinely cannot reach a context — the API client
/// turning transport failures into messages. Widgets should use `context.t`.
String tr(String key, [Map<String, Object?> params = const {}]) {
  final map = LocaleCubit.activeLanguageCode == 'ar' ? AppStrings.ar : AppStrings.en;
  var text = map[key] ?? AppStrings.ar[key] ?? key;
  for (final e in params.entries) {
    text = text.replaceAll('{${e.key}}', e.value?.toString() ?? '');
  }
  return text;
}
