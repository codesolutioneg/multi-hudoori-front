import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../router/app_router.dart';

/// Converts every [SnackBar] into a modal popup (success / error / notice).
///
/// Wrap the [MaterialApp.builder] child with this so `ScaffoldMessenger.of`
/// from pages hits this messenger first.
class PopupScaffoldMessenger extends ScaffoldMessenger {
  const PopupScaffoldMessenger({super.key, required super.child});

  @override
  PopupScaffoldMessengerState createState() => PopupScaffoldMessengerState();
}

class PopupScaffoldMessengerState extends ScaffoldMessengerState {
  bool _passthrough = false;
  bool _dialogOpen = false;
  final List<({String message, bool isError})> _queue = [];

  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) {
    if (_passthrough || _isSilentSnackBar(snackBar)) {
      return super.showSnackBar(
        snackBar,
        snackBarAnimationStyle: snackBarAnimationStyle,
      );
    }

    final message = extractSnackBarMessage(snackBar)?.trim() ?? '';
    if (message.isNotEmpty) {
      _enqueuePopup(message: message, isError: isErrorSnackBar(snackBar));
    }

    // Satisfy the API / callers without painting a visible snackbar.
    _passthrough = true;
    try {
      return super.showSnackBar(
        const SnackBar(
          content: SizedBox.shrink(),
          duration: Duration.zero,
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
        snackBarAnimationStyle: snackBarAnimationStyle,
      );
    } finally {
      _passthrough = false;
    }
  }

  void _enqueuePopup({required String message, required bool isError}) {
    _queue.add((message: message, isError: isError));
    _drainQueue();
  }

  Future<void> _drainQueue() async {
    if (_dialogOpen || _queue.isEmpty) return;
    _dialogOpen = true;
    try {
      while (_queue.isNotEmpty) {
        final item = _queue.removeAt(0);
        await showAppPopupMessage(
          message: item.message,
          isError: item.isError,
        );
      }
    } finally {
      _dialogOpen = false;
    }
  }
}

/// Direct popup API (prefer this for new code). Uses the root navigator when
/// [context] is omitted / unavailable.
Future<void> showAppPopupMessage({
  BuildContext? context,
  required String message,
  bool isError = false,
  String? title,
}) async {
  final trimmed = message.trim();
  if (trimmed.isEmpty) return;

  final ctx =
      context ??
      appRootNavigatorKey.currentContext ??
      appRootNavigatorKey.currentState?.context;
  if (ctx == null || !ctx.mounted) return;

  final l10n = Localizations.of<AppLocalizations>(ctx, AppLocalizations);
  final resolvedTitle =
      title ??
      (isError
          ? (l10n?.t('common.error') ?? 'Error')
          : (l10n?.t('common.done') ?? 'Done'));
  final okLabel = l10n?.t('common.ok') ?? 'OK';

  await showDialog<void>(
    context: ctx,
    useRootNavigator: true,
    barrierDismissible: true,
    builder: (dialogCtx) => AlertDialog(
      title: Text(resolvedTitle),
      content: Text(trimmed, style: const TextStyle(height: 1.45)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: Text(okLabel),
        ),
      ],
    ),
  );
}

bool isErrorSnackBar(SnackBar snackBar) {
  final bg = snackBar.backgroundColor;
  if (bg == null) return false;
  // Prefer component accessors (0–1); fall back to 0–255 ints.
  final red = bg.r;
  final green = bg.g;
  final blue = bg.b;
  final r = red > 1 ? red / 255.0 : red;
  final g = green > 1 ? green / 255.0 : green;
  final b = blue > 1 ? blue / 255.0 : blue;
  // Treat clearly red / danger backgrounds as errors.
  return r > 0.55 && g < 0.45 && b < 0.45;
}

bool _isSilentSnackBar(SnackBar snackBar) {
  final c = snackBar.content;
  return c is SizedBox && c.child == null && (c.width == null || c.width == 0);
}

String? extractSnackBarMessage(SnackBar snackBar) {
  return _widgetText(snackBar.content);
}

String? _widgetText(Widget? widget) {
  if (widget == null) return null;
  if (widget is Text) {
    if (widget.data != null) return widget.data;
    return widget.textSpan?.toPlainText();
  }
  if (widget is RichText) return widget.text.toPlainText();
  if (widget is SelectableText) {
    if (widget.data != null) return widget.data;
    return widget.textSpan?.toPlainText();
  }
  if (widget is DefaultTextStyle) return _widgetText(widget.child);
  if (widget is Padding) return _widgetText(widget.child);
  if (widget is Center) return _widgetText(widget.child);
  if (widget is Align) return _widgetText(widget.child);
  if (widget is SizedBox) return _widgetText(widget.child);
  if (widget is Flexible) return _widgetText(widget.child);
  if (widget is Expanded) return _widgetText(widget.child);
  if (widget is SingleChildScrollView) return _widgetText(widget.child);
  if (widget is IconTheme) return _widgetText(widget.child);
  if (widget is MergeSemantics) return _widgetText(widget.child);
  if (widget is Semantics) return _widgetText(widget.child);
  if (widget is ExcludeSemantics) return _widgetText(widget.child);

  if (widget is Row || widget is Column || widget is Wrap || widget is Flex) {
    final children = (widget as dynamic).children as List<Widget>;
    final parts = <String>[];
    for (final child in children) {
      final t = _widgetText(child)?.trim();
      if (t != null && t.isNotEmpty) parts.add(t);
    }
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  if (widget is ListView) {
    // Rare in snackbars — skip.
    return null;
  }

  return null;
}
