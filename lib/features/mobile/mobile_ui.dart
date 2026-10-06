import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme_v2.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/app_localizations.dart';

/// Design tokens for the native mobile app (attendance UI kit look).
abstract final class MobileUi {
  static const Color background = Color(0xFFF4F7FC);
  static const Color primary = Color(0xFF2F6BFF);
  static const Color primaryDeep = Color(0xFF1D4ED8);
  static const Color primarySoft = Color(0xFFE8F0FF);
  static const Color ink = Color(0xFF111827);
  static const Color muted = Color(0xFF8A94A6);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4C8DFF), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const double radius = 18;

  static List<BoxShadow> get softShadow => const [
        BoxShadow(
          color: Color(0x0F1E3A8A),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ];

  static BoxDecoration card({Color color = Colors.white, double r = radius}) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: const Color(0xFFEDF1F7)),
        boxShadow: softShadow,
      );

  static TextStyle text(
    double size, {
    FontWeight weight = FontWeight.w600,
    Color color = ink,
    double? height,
  }) =>
      AppTypography.cairo(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height ?? 1.3,
      );

  static TextStyle get sectionTitle => text(17, weight: FontWeight.w700);
}

/// Fill behind the status bar on native mobile (the app-wide SafeArea leaves
/// that strip to whatever is painted here). Screens with a colored top set it
/// after their first frame and restore it when they go away.
final mobileStatusBarColor = ValueNotifier<Color>(MobileUi.background);

/// The Hudoori fingerprint mark. [white] renders it as a white silhouette for
/// blue backgrounds — the source PNG has an opaque white background, so the
/// alpha is derived from the red channel (strokes are blue, background white).
class HudooriMark extends StatelessWidget {
  const HudooriMark({super.key, required this.size, this.white = false});

  final double size;
  final bool white;

  static const asset = 'assets/app_icon2.png';

  // No constant offsets: a filter that turns transparent pixels opaque is
  // unbounded and floods the whole screen white in release builds.
  static const ColorFilter _whiteSilhouette = ColorFilter.matrix(<double>[
    0, 0, 0, 1, 0, //
    0, 0, 0, 1, 0, //
    0, 0, 0, 1, 0, //
    -2.4, 0, 0, 2.4, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
    if (!white) return image;
    return ColorFiltered(colorFilter: _whiteSilhouette, child: image);
  }
}

/// Initials avatar with the brand gradient.
class MobileAvatar extends StatelessWidget {
  const MobileAvatar({super.key, required this.name, this.size = 46, this.photo});

  final String name;
  final double size;
  final Uint8List? photo;

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first;
    return '${parts[0].characters.first}${parts[1].characters.first}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: MobileUi.primaryGradient,
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: MobileUi.primarySoft,
          border: Border.all(color: Colors.white, width: 2),
        ),
        alignment: Alignment.center,
        clipBehavior: photo == null ? Clip.none : Clip.antiAlias,
        child: photo != null
            ? Image.memory(
                photo!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
            : Text(
                _initials.toUpperCase(),
                style: MobileUi.text(
                  size * 0.34,
                  weight: FontWeight.w800,
                  color: MobileUi.primary,
                  height: 1,
                ),
              ),
      ),
    );
  }
}

/// Square soft-tinted icon used at the top of mobile cards.
class MobileIconBadge extends StatelessWidget {
  const MobileIconBadge({
    super.key,
    required this.icon,
    this.color = MobileUi.primary,
    this.size = 34,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.52, color: color),
    );
  }
}

/// Small tinted pill for metadata (code, branch, status, amounts).
class MobileChip extends StatelessWidget {
  const MobileChip({
    super.key,
    required this.label,
    this.icon,
    this.color = MobileUi.muted,
  });

  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final neutral = color == MobileUi.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: neutral ? const Color(0xFFF2F5FA) : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: neutral ? const Color(0xFF64748B) : color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MobileUi.text(
                11.5,
                weight: FontWeight.w700,
                color: neutral ? const Color(0xFF475569) : color,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Expandable group row (payroll cycle / branch) used by grouped lists.
Widget mobileGroupHeader({
  required bool expanded,
  required VoidCallback onTap,
  required IconData icon,
  required String title,
  required String subtitle,
  bool nested = false,
}) {
  final row = InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(nested ? 14 : 0),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: nested ? 10 : 14, vertical: nested ? 10 : 14),
      child: Row(
        children: [
          MobileIconBadge(
            icon: icon,
            size: nested ? 34 : 40,
            color: nested ? MobileTone.violet : MobileUi.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MobileUi.text(nested ? 14 : 15, weight: FontWeight.w800, height: 1.3),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: MobileUi.text(12, weight: FontWeight.w500, color: MobileUi.muted, height: 1.4),
                ),
              ],
            ),
          ),
          AnimatedRotation(
            turns: expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 220),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: expanded ? MobileUi.primarySoft : const Color(0xFFF2F5FA),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: expanded ? MobileUi.primary : MobileUi.muted,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  if (!nested) return Material(color: Colors.transparent, child: row);
  return Padding(
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
    child: Material(
      color: const Color(0xFFF7F9FD),
      borderRadius: BorderRadius.circular(14),
      child: row,
    ),
  );
}

/// Grand total + cash / Fawry / commission chips for payroll-style sheets.
class MobileMoneySummary extends StatelessWidget {
  const MobileMoneySummary({
    super.key,
    required this.total,
    required this.cash,
    required this.fawry,
    required this.commission,
    required this.format,
  });

  final double total;
  final double cash;
  final double fawry;
  final double commission;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                l10n.t('m.grandTotal'),
                style: MobileUi.text(12, weight: FontWeight.w600, color: MobileUi.muted),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  format(total),
                  style: MobileUi.text(18, weight: FontWeight.w800, color: MobileUi.primaryDeep, height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              MobileChip(
                icon: Icons.payments_outlined,
                color: MobileTone.success,
                label: l10n.t('m.cashAmount', {'amount': format(cash)}),
              ),
              MobileChip(
                icon: Icons.bolt_rounded,
                color: MobileTone.violet,
                label: l10n.t('m.fawryAmount', {'amount': format(fawry)}),
              ),
              if (commission > 0)
                MobileChip(
                  icon: Icons.percent_rounded,
                  color: MobileTone.warning,
                  label: l10n.t('m.commissionAmount', {'amount': format(commission)}),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Centered illustration-style empty state card.
class MobileEmptyState extends StatelessWidget {
  const MobileEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.action,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: MobileUi.card(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: MobileUi.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: MobileUi.primary),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: MobileUi.text(14, weight: FontWeight.w600, color: MobileUi.muted, height: 1.5),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Attendance check-in/out values are device wall-clock times tagged as UTC,
/// so their fields are read as-is and never shifted to the phone's zone.
DateTime? parseWallClock(dynamic value) {
  if (value == null || value == false) return null;
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

/// "Now" expressed in the same wall-clock convention as [reference].
DateTime wallClockNow(DateTime reference) {
  final n = DateTime.now();
  return reference.isUtc
      ? DateTime.utc(n.year, n.month, n.day, n.hour, n.minute, n.second)
      : n;
}

String formatClock(AppLocalizations l10n, DateTime? t) {
  if (t == null) return '--:--';
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final mm = t.minute.toString().padLeft(2, '0');
  final suffix = t.hour < 12 ? l10n.t('m.am') : l10n.t('m.pm');
  return '$h12:$mm $suffix';
}

String formatDuration(AppLocalizations l10n, Duration d) {
  if (d.isNegative) d = Duration.zero;
  return l10n.t('m.hoursShort', {
    'h': d.inHours,
    'm': (d.inMinutes % 60).toString().padLeft(2, '0'),
  });
}

String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String weekdayShort(AppLocalizations l10n, DateTime d) {
  const ar = ['إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد'];
  const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return (l10n.isAr ? ar : en)[d.weekday - 1];
}

String monthShort(AppLocalizations l10n, DateTime d) {
  const ar = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', //
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];
  const en = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return (l10n.isAr ? ar : en)[d.month - 1];
}

/// Mobile surfaces reuse the web palette for semantic colors.
abstract final class MobileTone {
  static const Color success = AppThemeV2.success;
  static const Color warning = AppThemeV2.warning;
  static const Color danger = AppThemeV2.danger;
  static const Color info = AppThemeV2.info;
  static const Color violet = Color(0xFF7C3AED);
}
