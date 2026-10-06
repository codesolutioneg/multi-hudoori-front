import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'mobile_ui.dart';

class MobileGridColumn {
  const MobileGridColumn(this.label, {this.width = 96, this.color, this.bold = false});

  final String label;
  final double width;
  final Color? color;
  final bool bold;
}

class MobileGridRow {
  const MobileGridRow({
    required this.title,
    required this.cells,
    this.subtitle,
    this.onTap,
    this.warn = false,
  });

  final String title;
  final String? subtitle;
  final List<String> cells;
  final VoidCallback? onTap;
  final bool warn;
}

/// Wide table for phones: the first column stays pinned while the rest scroll
/// horizontally under a single shared scrollbar.
class MobileDataGrid extends StatefulWidget {
  const MobileDataGrid({
    super.key,
    required this.pinnedLabel,
    required this.columns,
    required this.rows,
    this.total,
    this.pinnedWidth = 138,
  });

  final String pinnedLabel;
  final List<MobileGridColumn> columns;
  final List<MobileGridRow> rows;
  final MobileGridRow? total;
  final double pinnedWidth;

  @override
  State<MobileDataGrid> createState() => _MobileDataGridState();
}

class _MobileDataGridState extends State<MobileDataGrid> {
  static const _headH = 46.0;
  static const _rowH = 58.0;
  static const _line = Color(0xFFEDF1F7);
  static const _zebra = Color(0xFFF8FAFE);
  static const _totalBg = Color(0xFFEAF1FF);
  static const _warnBg = Color(0xFFFFF6E5);

  final _ctrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _rowBg(int i, MobileGridRow r) => r.warn ? _warnBg : (i.isOdd ? _zebra : Colors.white);

  Widget _pinnedCell(MobileGridRow r, Color bg, {bool total = false}) {
    return InkWell(
      onTap: r.onTap,
      child: Container(
        height: _rowH,
        color: bg,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 8, 6),
        alignment: AlignmentDirectional.centerStart,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MobileUi.text(
                12.5,
                weight: FontWeight.w800,
                color: total ? MobileUi.primaryDeep : MobileUi.ink,
                height: 1.25,
              ),
            ),
            if ((r.subtitle ?? '').isNotEmpty)
              Text(
                r.subtitle!,
                maxLines: 1,
                style: MobileUi.text(11, weight: FontWeight.w600, color: MobileUi.muted, height: 1.3),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cells(MobileGridRow r, Color bg, {bool total = false}) {
    return InkWell(
      onTap: r.onTap,
      child: Container(
        height: _rowH,
        color: bg,
        child: Row(
          children: [
            for (var c = 0; c < widget.columns.length; c++)
              Container(
                width: widget.columns[c].width,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                child: Text(
                  c < r.cells.length ? r.cells[c] : '',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: MobileUi.text(
                    12.5,
                    weight: total || widget.columns[c].bold ? FontWeight.w800 : FontWeight.w600,
                    color: widget.columns[c].color ?? (total ? MobileUi.primaryDeep : MobileUi.ink),
                    height: 1.25,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, thickness: 1, color: _line);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = widget.total;
    final headStyle = MobileUi.text(11.5, weight: FontWeight.w800, color: Colors.white, height: 1.2);

    final pinned = Column(
      children: [
        Container(
          height: _headH,
          padding: const EdgeInsetsDirectional.only(start: 12),
          alignment: AlignmentDirectional.centerStart,
          decoration: const BoxDecoration(gradient: MobileUi.primaryGradient),
          child: Text(widget.pinnedLabel, style: headStyle),
        ),
        if (total != null) ...[_pinnedCell(total, _totalBg, total: true), _divider()],
        for (var i = 0; i < widget.rows.length; i++) ...[
          _pinnedCell(widget.rows[i], _rowBg(i, widget.rows[i])),
          _divider(),
        ],
      ],
    );

    final scrolling = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: _headH,
          decoration: const BoxDecoration(gradient: MobileUi.primaryGradient),
          child: Row(
            children: [
              for (final c in widget.columns)
                Container(
                  width: c.width,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  child: Text(
                    c.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: headStyle,
                  ),
                ),
            ],
          ),
        ),
        if (total != null) ...[_cells(total, _totalBg, total: true), _divider()],
        for (var i = 0; i < widget.rows.length; i++) ...[
          _cells(widget.rows[i], _rowBg(i, widget.rows[i])),
          _divider(),
        ],
      ],
    );

    final scrollWidth = widget.columns.fold<double>(0, (s, c) => s + c.width);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Row(
            children: [
              const Icon(Icons.swipe_rounded, size: 17, color: MobileUi.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.t('m.scrollHint'),
                  style: MobileUi.text(11.5, weight: FontWeight.w600, color: MobileUi.muted),
                ),
              ),
              MobileChip(label: '${widget.rows.length}', icon: Icons.people_alt_outlined),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: widget.pinnedWidth,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: Offset(Directionality.of(context) == TextDirection.rtl ? -4 : 4, 0),
                  ),
                ],
              ),
              child: pinned,
            ),
            Expanded(
              child: Scrollbar(
                controller: _ctrl,
                thumbVisibility: true,
                thickness: 5,
                radius: const Radius.circular(8),
                child: SingleChildScrollView(
                  controller: _ctrl,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(width: scrollWidth, child: scrolling),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
