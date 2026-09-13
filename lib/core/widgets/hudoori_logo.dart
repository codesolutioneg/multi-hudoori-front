import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme_v2.dart';

class HudooriLogo extends StatelessWidget {
  const HudooriLogo({
    super.key,
    this.iconSize = 40,
    this.showName = true,
    this.nameSize = 22,
    this.axis = Axis.horizontal,
    this.showBackground = true,
  });

  final double iconSize;
  final bool showName;
  final double nameSize;
  final Axis axis;
  final bool showBackground;

  static const _iconAsset = 'assets/app_icon2.png';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final icon = _AppIcon(size: iconSize, showBackground: showBackground);

    if (!showName) return icon;

    final name = Text(
      l10n.appName,
      style: AppThemeV2.cardTitle(color: AppColors.primary).copyWith(fontSize: nameSize),
    );

    if (axis == Axis.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [icon, const SizedBox(height: 8), name],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [icon, const SizedBox(width: 8), name],
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.size, required this.showBackground});

  final double size;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        HudooriLogo._iconAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );

    if (!showBackground) return image;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: image,
    );
  }
}
