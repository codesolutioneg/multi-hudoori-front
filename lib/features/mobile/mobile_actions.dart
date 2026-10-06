import 'package:flutter/material.dart';

import 'hudoori_loader.dart';
import 'mobile_ui.dart';

/// Accent color for an action icon so related actions share a tint.
Color mobileActionColor(IconData icon) => switch (icon) {
      Icons.calculate || Icons.calculate_outlined => MobileUi.primary,
      Icons.check || Icons.check_circle_outline || Icons.verified_outlined ||
      Icons.task_alt =>
        MobileTone.success,
      Icons.link || Icons.link_off || Icons.share_outlined => MobileTone.info,
      Icons.cloud_upload_outlined || Icons.cloud_sync_outlined => MobileTone.violet,
      Icons.download || Icons.download_rounded || Icons.file_download_outlined =>
        const Color(0xFF0D9488),
      Icons.upload_file || Icons.upload_rounded || Icons.file_upload_outlined =>
        const Color(0xFFEA580C),
      Icons.receipt_long_outlined || Icons.receipt_long => const Color(0xFF6366F1),
      Icons.picture_as_pdf || Icons.picture_as_pdf_outlined => MobileTone.danger,
      Icons.undo || Icons.restart_alt || Icons.settings_backup_restore =>
        const Color(0xFF64748B),
      Icons.delete_outline || Icons.delete_forever_outlined ||
      Icons.person_remove_outlined =>
        MobileTone.danger,
      Icons.lock_outline || Icons.lock_open_outlined => const Color(0xFF0F766E),
      Icons.account_balance_wallet_outlined || Icons.payments_outlined ||
      Icons.payments =>
        const Color(0xFF16A34A),
      Icons.sync || Icons.refresh || Icons.autorenew => const Color(0xFF0891B2),
      Icons.fingerprint => MobileUi.primary,
      Icons.person_add || Icons.person_add_alt_1_outlined || Icons.add ||
      Icons.add_card_outlined =>
        MobileUi.primary,
      Icons.build || Icons.content_copy || Icons.swap_horiz || Icons.route_outlined =>
        MobileTone.warning,
      _ => MobileUi.primary,
    };

/// One square action: tinted icon with its name underneath.
class MobileActionTile extends StatelessWidget {
  const MobileActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.primary = false,
    this.loading = false,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool primary;
  final bool loading;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = color ?? mobileActionColor(icon);
    final enabled = onPressed != null && !loading;
    final tile = Opacity(
      opacity: enabled || loading ? 1 : 0.38,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: primary
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color.lerp(c, Colors.white, 0.2)!, c],
                          )
                        : null,
                    color: primary ? null : c.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: primary
                        ? [
                            BoxShadow(
                              color: c.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: loading
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: HudooriLoader(size: 24),
                        )
                      : Icon(icon, size: 24, color: primary ? Colors.white : c),
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: MobileUi.text(11.5, weight: FontWeight.w700, height: 1.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return tooltip == null || tooltip!.isEmpty
        ? tile
        : Tooltip(message: tooltip!, waitDuration: const Duration(milliseconds: 500), child: tile);
  }
}

/// A titled card of [MobileActionTile]s laid out four per row; collapsible.
class MobileActionSection extends StatefulWidget {
  const MobileActionSection({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.initiallyExpanded = true,
    this.columns = 4,
    this.collapsible = true,
    this.footer,
  });

  final String title;
  final IconData? icon;
  final List<Widget> children;
  final Widget? footer;
  final bool initiallyExpanded;
  final int columns;
  final bool collapsible;

  @override
  State<MobileActionSection> createState() => _MobileActionSectionState();
}

class _MobileActionSectionState extends State<MobileActionSection> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: MobileUi.card(r: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.collapsible ? () => setState(() => _open = !_open) : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    MobileIconBadge(icon: widget.icon!, size: 30),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      widget.title,
                      style: MobileUi.text(14, weight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: MobileUi.primarySoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${widget.children.length}',
                      style: MobileUi.text(11.5, weight: FontWeight.w800, color: MobileUi.primary),
                    ),
                  ),
                  if (widget.collapsible)
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down_rounded, color: MobileUi.muted),
                    ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(builder: (context, c) {
                          final w = c.maxWidth / widget.columns;
                          return Wrap(
                            children: [
                              for (final child in widget.children)
                                SizedBox(width: w, child: child),
                            ],
                          );
                        }),
                        if (widget.footer != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                            child: widget.footer,
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
