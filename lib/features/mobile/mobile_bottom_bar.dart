import 'package:flutter/material.dart';

import 'mobile_ui.dart';

class MobileNavEntry {
  const MobileNavEntry({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
}

/// White bar with rounded top corners and a smooth notch cradling
/// [MobileCenterButton] (docked with `FloatingActionButtonLocation.centerDocked`).
/// Icon-only tabs; the selected one gets a soft pill and a top indicator.
class MobileBottomBar extends StatelessWidget {
  const MobileBottomBar({super.key, required this.items});

  /// Two entries before the center button, two after.
  final List<MobileNavEntry> items;

  static const double barHeight = 66;

  @override
  Widget build(BuildContext context) {
    final half = (items.length / 2).ceil();
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return CustomPaint(
      painter: _NotchedBarPainter(),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: barHeight,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i == half) const SizedBox(width: 84),
                Expanded(child: _NavButton(entry: items[i])),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotchedBarPainter extends CustomPainter {
  static const _corner = 28.0;
  static const _notchRadius = 38.0;
  static const _smooth = 14.0;

  Path _shape(Size size) {
    final cx = size.width / 2;
    final r = _notchRadius;
    return Path()
      ..moveTo(0, _corner)
      ..quadraticBezierTo(0, 0, _corner, 0)
      ..lineTo(cx - r - _smooth, 0)
      ..quadraticBezierTo(cx - r, 0, cx - r + 2, 8)
      ..arcToPoint(
        Offset(cx + r - 2, 8),
        radius: const Radius.circular(_notchRadius),
        clockwise: false,
      )
      ..quadraticBezierTo(cx + r, 0, cx + r + _smooth, 0)
      ..lineTo(size.width - _corner, 0)
      ..quadraticBezierTo(size.width, 0, size.width, _corner)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _shape(size);
    canvas.drawShadow(path, const Color(0xFF1E3A8A), 14, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_NotchedBarPainter old) => false;
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.entry});
  final MobileNavEntry entry;

  @override
  Widget build(BuildContext context) {
    final selected = entry.selected;
    return Semantics(
      button: true,
      selected: selected,
      label: entry.label,
      child: Tooltip(
        message: entry.label,
        child: InkResponse(
          onTap: entry.onTap,
          radius: 30,
          highlightColor: Colors.transparent,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  width: selected ? 26 : 0,
                  height: 4,
                  decoration: const BoxDecoration(
                    gradient: MobileUi.primaryGradient,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(4),
                    ),
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: 50,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? MobileUi.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  scale: selected ? 1.06 : 1,
                  child: Icon(
                    selected ? entry.activeIcon : entry.icon,
                    size: 25,
                    color: selected ? MobileUi.primary : const Color(0xFFA3ADBD),
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

/// Raised gradient button in the bar's notch. Shows the Hudoori fingerprint
/// for location punch, or [icon] for the role's main screen.
class MobileCenterButton extends StatefulWidget {
  const MobileCenterButton({
    super.key,
    required this.onTap,
    this.icon,
    this.selected = false,
    this.tooltip,
  });

  final VoidCallback onTap;
  final IconData? icon;
  final bool selected;
  final String? tooltip;

  @override
  State<MobileCenterButton> createState() => _MobileCenterButtonState();
}

class _MobileCenterButtonState extends State<MobileCenterButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip ?? '',
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _glow,
                builder: (context, _) {
                  final t = _glow.value;
                  return Container(
                    width: 64 + 18 * t,
                    height: 64 + 18 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MobileUi.primary.withValues(alpha: 0.16 * (1 - t)),
                    ),
                  );
                },
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5B9BFF), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: MobileUi.primary.withValues(
                        alpha: widget.selected ? 0.55 : 0.4,
                      ),
                      blurRadius: widget.selected ? 22 : 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: widget.icon != null
                    ? Icon(widget.icon, color: Colors.white, size: 28)
                    : const HudooriMark(size: 56, white: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
