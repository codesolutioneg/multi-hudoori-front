import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import 'mobile_ui.dart';

/// Bottom sheet for picking several items (branches, departments…) on mobile.
/// Returns the selected ids, or null when dismissed.
Future<Set<String>?> showMobileMultiSelectSheet(
  BuildContext context, {
  required String title,
  required List<(String, String)> options,
  required Set<String> initial,
  required String applyLabel,
  required String selectAllLabel,
  required String clearLabel,
  String? hint,
  IconData icon = Icons.storefront_outlined,
  bool allowEmpty = false,
}) {
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MultiSelectSheet(
      title: title,
      options: options,
      initial: initial,
      applyLabel: applyLabel,
      selectAllLabel: selectAllLabel,
      clearLabel: clearLabel,
      hint: hint,
      icon: icon,
      allowEmpty: allowEmpty,
    ),
  );
}

class _MultiSelectSheet extends StatefulWidget {
  const _MultiSelectSheet({
    required this.title,
    required this.options,
    required this.initial,
    required this.applyLabel,
    required this.selectAllLabel,
    required this.clearLabel,
    required this.hint,
    required this.icon,
    required this.allowEmpty,
  });

  final String title;
  final List<(String, String)> options;
  final Set<String> initial;
  final String applyLabel;
  final String selectAllLabel;
  final String clearLabel;
  final String? hint;
  final IconData icon;
  final bool allowEmpty;

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late final Set<String> _selected = Set.of(widget.initial);
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? widget.options
        : widget.options.where((o) => o.$2.toLowerCase().contains(q)).toList();
    final canApply = widget.allowEmpty || _selected.isNotEmpty;
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
        child: Container(
          decoration: const BoxDecoration(
            color: MobileUi.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5DCE8),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 10, 0),
                child: Row(
                  children: [
                    MobileIconBadge(icon: widget.icon, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(widget.title, style: MobileUi.text(18, weight: FontWeight.w800)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: MobileUi.muted),
                    ),
                  ],
                ),
              ),
              if (widget.hint != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  child: Text(
                    widget.hint!,
                    style: MobileUi.text(12, weight: FontWeight.w500, color: MobileUi.muted, height: 1.45),
                  ),
                ),
              if (widget.options.length > 6)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: context.t('common.search'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  children: [
                    _Pill(
                      icon: Icons.done_all_rounded,
                      label: widget.selectAllLabel,
                      onTap: () => setState(() => _selected.addAll(widget.options.map((o) => o.$1))),
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      icon: Icons.remove_done_rounded,
                      label: widget.clearLabel,
                      onTap: _selected.isEmpty ? null : () => setState(_selected.clear),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: MobileUi.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_selected.length} / ${widget.options.length}',
                        style: MobileUi.text(12, weight: FontWeight.w800, color: Colors.white, height: 1.2),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final (id, label) = visible[i];
                    final on = _selected.contains(id);
                    return _OptionCard(
                      label: label,
                      icon: widget.icon,
                      selected: on,
                      onTap: () => setState(() => on ? _selected.remove(id) : _selected.add(id)),
                    );
                  },
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + media.padding.bottom),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: canApply ? () => Navigator.pop(context, _selected) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: MobileUi.primary,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: MobileUi.text(15, weight: FontWeight.w800),
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    _selected.isEmpty ? widget.applyLabel : '${widget.applyLabel} (${_selected.length})',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE3E9F5)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: MobileUi.primary),
                const SizedBox(width: 5),
                Text(label, style: MobileUi.text(12.5, weight: FontWeight.w700, color: MobileUi.primary, height: 1.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: selected ? MobileUi.primarySoft : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? MobileUi.primary : const Color(0xFFE8EDF5),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected ? MobileUi.primary : const Color(0xFFF2F5FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: selected ? Colors.white : MobileUi.muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MobileUi.text(14, weight: selected ? FontWeight.w800 : FontWeight.w600, height: 1.3),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: Icon(
                  selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  key: ValueKey(selected),
                  color: selected ? MobileUi.primary : const Color(0xFFC5CEDC),
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
