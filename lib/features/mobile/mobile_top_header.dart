import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'mobile_ui.dart';
import 'my_photo.dart';

/// Blue app header on native mobile: the signed-in employee's photo, name and
/// role, plus round action buttons (language, notifications).
class MobileTopHeader extends StatelessWidget {
  const MobileTopHeader({
    super.key,
    required this.name,
    required this.role,
    this.company,
    this.onCompanyTap,
    this.actions = const [],
    this.flat = false,
  });

  /// Square bottom edge, for pages that continue the blue band below.
  final bool flat;

  /// Matches the header's top edge so the status bar strip blends in.
  static const Color top = Color(0xFF3F80FF);
  static const Color _bottom = Color(0xFF2357E8);

  final String name;
  final String role;
  final String? company;
  /// When set (multi-company HR), company label is tappable to switch.
  final VoidCallback? onCompanyTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final greeting =
        l10n.t(DateTime.now().hour < 12 ? 'm.goodMorning' : 'm.goodEvening');

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, _bottom],
        ),
        borderRadius: flat
            ? null
            : const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: flat
            ? null
            : [
                BoxShadow(
                  color: MobileUi.primary.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -36,
            top: -46,
            child: _Bubble(size: 150, alpha: 0.09),
          ),
          if (!flat)
            PositionedDirectional(
              start: 70,
              bottom: -64,
              child: _Bubble(size: 120, alpha: 0.06),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 16, 18),
            child: Row(
              children: [
                ValueListenableBuilder<Uint8List?>(
                  valueListenable: MyPhoto.bytes,
                  builder: (context, photo, _) => _Avatar(name: name, photo: photo),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        greeting,
                        style: MobileUi.text(
                          12,
                          weight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.78),
                          height: 1.2,
                        ),
                      ),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MobileUi.text(
                          17.5,
                          weight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 190),
                            child: _RolePill(role: role),
                          ),
                          if ((company ?? '').isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: InkWell(
                                onTap: onCompanyTap,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          company!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: MobileUi.text(
                                            11.5,
                                            weight: FontWeight.w600,
                                            color: Colors.white.withValues(alpha: 0.75),
                                          ),
                                        ),
                                      ),
                                      if (onCompanyTap != null) ...[
                                        const SizedBox(width: 2),
                                        Icon(
                                          Icons.expand_more_rounded,
                                          size: 16,
                                          color: Colors.white.withValues(alpha: 0.85),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                for (final a in actions) ...[const SizedBox(width: 8), a],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Translucent round button for the blue header.
class MobileHeaderButton extends StatelessWidget {
  const MobileHeaderButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Center(
              child: IconTheme(
                data: const IconThemeData(color: Colors.white, size: 22),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.photo});

  final String name;
  final Uint8List? photo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        children: [
          Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.35),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              alignment: Alignment.center,
              child: photo != null
                  ? Image.memory(
                      photo!,
                      width: 54,
                      height: 54,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  : Text(
                      _initials(name),
                      style: MobileUi.text(
                        19,
                        weight: FontWeight.w800,
                        color: MobileUi.primary,
                        height: 1,
                      ),
                    ),
            ),
          ),
          PositionedDirectional(
            end: 1,
            bottom: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: MobileTone.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts[0].characters.first}${parts[1].characters.first}'.toUpperCase();
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 9, 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_user_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MobileUi.text(11.5, weight: FontWeight.w700, color: Colors.white, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.alpha});
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}
