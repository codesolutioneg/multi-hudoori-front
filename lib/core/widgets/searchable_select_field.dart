import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme_v2.dart';

class SearchableSelectOption<T> {
  const SearchableSelectOption({required this.value, required this.label});
  final T value;
  final String label;
}

/// TextFormField-style searchable select with focus bounce + debounced filter.
class SearchableSelectField<T> extends StatefulWidget {
  const SearchableSelectField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hint,
    this.allLabel,
    this.allowNull = true,
    this.debounce = const Duration(milliseconds: 300),
  });

  final String label;
  final String? hint;
  final String? allLabel;
  final List<SearchableSelectOption<T>> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final bool allowNull;
  /// Delay before applying the typed filter (code/name search).
  final Duration debounce;

  @override
  State<SearchableSelectField<T>> createState() =>
      _SearchableSelectFieldState<T>();
}

class _SearchableSelectFieldState<T> extends State<SearchableSelectField<T>>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;
  late final AnimationController _bounce;
  late final Animation<double> _scale;
  String _query = '';
  Timer? _debounce;
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.03), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.03, end: 0.99), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.99, end: 1), weight: 25),
    ]).animate(CurvedAnimation(parent: _bounce, curve: Curves.easeOut));
    _syncDisplayFromValue();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant SearchableSelectField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.options != widget.options) {
      _syncDisplayFromValue();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _ctrl.dispose();
    _bounce.dispose();
    super.dispose();
  }

  void _syncDisplayFromValue() {
    if (widget.value == null) {
      if (!_focus.hasFocus) {
        _ctrl.text = widget.allLabel ?? '';
      }
      return;
    }
    for (final o in widget.options) {
      if (o.value == widget.value) {
        if (!_focus.hasFocus) _ctrl.text = o.label;
        return;
      }
    }
  }

  void _onFocusChange() {
    if (_focus.hasFocus) {
      _bounce.forward(from: 0);
      _query = '';
      _ctrl.clear();
      _showOverlay();
    } else {
      // Longer delay: some Chrome builds deliver overlay pointer events after blur.
      Future.delayed(const Duration(milliseconds: 280), () {
        if (!mounted) return;
        if (!_focus.hasFocus) {
          _removeOverlay();
          _syncDisplayFromValue();
        }
      });
    }
  }

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(widget.debounce, () {
      if (!mounted) return;
      setState(() => _query = v);
      if (_overlay == null) {
        _showOverlay();
      } else {
        _rebuildOverlay();
      }
    });
    // Keep overlay open while typing even before debounce fires.
    if (_overlay == null) _showOverlay();
  }

  List<SearchableSelectOption<T?>> get _filtered {
    final q = _query.trim().toLowerCase();
    final list = <SearchableSelectOption<T?>>[
      if (widget.allowNull)
        SearchableSelectOption<T?>(
          value: null,
          label: widget.allLabel ?? '—',
        ),
      ...widget.options.map(
        (o) => SearchableSelectOption<T?>(value: o.value, label: o.label),
      ),
    ];
    if (q.isEmpty) return list;
    return list.where((o) {
      final label = o.label.toLowerCase();
      // Match full label ("code — name") or any token (code / name parts).
      if (label.contains(q)) return true;
      return label.split(RegExp(r'[\s—\-_/,]+')).any((t) => t.contains(q));
    }).toList();
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 280;

    _overlay = OverlayEntry(
      builder: (ctx) {
        final items = _filtered;
        return Positioned(
          width: width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, (box?.size.height ?? 48) + 4),
            // Keep TextField focus when tapping overlay items (Chrome web race).
            child: TextFieldTapRegion(
              child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: AppThemeV2.surface,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('—', textAlign: TextAlign.center),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shrinkWrap: true,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: AppThemeV2.border.withValues(alpha: 0.6),
                        ),
                        itemBuilder: (_, i) {
                          final item = items[i];
                          final selected = item.value == widget.value;
                          return Material(
                            color: selected
                                ? AppThemeV2.primary.withValues(alpha: 0.08)
                                : Colors.transparent,
                            child: InkWell(
                              // Select on pointer-down so Chrome blur cannot cancel the choice.
                              onTapDown: (_) => _select(item.value),
                              hoverColor: const Color(0xFFF1F5F9),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? AppThemeV2.primary
                                        : AppThemeV2.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            ),
          ),
        );
      },
    );
    overlay.insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _select(T? value) {
    if (_selecting) return;
    _selecting = true;
    _debounce?.cancel();
    widget.onChanged(value);
    _removeOverlay();
    if (value == null) {
      _ctrl.text = widget.allLabel ?? '';
    } else {
      for (final o in widget.options) {
        if (o.value == value) {
          _ctrl.text = o.label;
          break;
        }
      }
    }
    // Unfocus after updating text so blur handler does not wipe the selection.
    _focus.unfocus();
    setState(() {});
    // Allow a later open/select after this gesture fully ends.
    Future.microtask(() => _selecting = false);
  }

  void _rebuildOverlay() {
    _overlay?.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: ScaleTransition(
        scale: _scale,
        child: TextFormField(
          controller: _ctrl,
          focusNode: _focus,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            isDense: true,
            suffixIcon: Icon(
              _focus.hasFocus
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 22,
            ),
          ),
          onChanged: _onQueryChanged,
          onTap: () {
            if (!_focus.hasFocus) {
              _focus.requestFocus();
            } else if (_overlay == null) {
              _showOverlay();
            }
          },
        ),
      ),
    );
  }
}
