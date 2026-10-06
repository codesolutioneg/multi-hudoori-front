import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import 'mobile_ui.dart';

/// Continues Android's launch splash (white logo circle on brand blue): the
/// circle morphs into a glowing logo card, an arc orbits it, the fingerprint
/// is scanned, and the name rises in.
///
/// Stays up until the intro has played and [ready] is true, then fades out
/// and calls [onFinished].
class HudooriSplash extends StatefulWidget {
  const HudooriSplash({
    super.key,
    required this.ready,
    required this.onFinished,
  });

  final bool ready;
  final VoidCallback onFinished;

  /// Matches `windowSplashScreenBackground` in `values-v31/styles.xml`.
  static const Color launchBlue = Color(0xFF2563EB);

  @override
  State<HudooriSplash> createState() => _HudooriSplashState();
}

class _HudooriSplashState extends State<HudooriSplash>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _intro.forward().whenComplete(_maybeExit);
    _exit.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onFinished();
    });
  }

  @override
  void didUpdateWidget(covariant HudooriSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready && !oldWidget.ready) _maybeExit();
  }

  void _maybeExit() {
    if (_exiting || !widget.ready || !_intro.isCompleted || !mounted) return;
    _exiting = true;
    _exit.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    _exit.dispose();
    super.dispose();
  }

  double _seg(double begin, double end, [Curve curve = Curves.linear]) {
    final t = ((_intro.value - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF1E3A8A),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: Listenable.merge([_intro, _loop, _exit]),
          builder: (context, _) {
            final exitT = Curves.easeInCubic.transform(_exit.value);
            final morph = _seg(0.0, 0.32, Curves.easeInOutCubic);
            final aura = _seg(0.15, 0.45, Curves.easeOut);
            final scan = _seg(0.34, 0.74, Curves.easeInOutSine);
            final title = _seg(0.48, 0.74, Curves.easeOutCubic);
            final tagline = _seg(0.60, 0.86, Curves.easeOutCubic);
            final footer = _seg(0.70, 0.95, Curves.easeOut);
            final progress = _seg(0.70, 1.0, Curves.easeInOut);

            return Opacity(
              opacity: 1 - exitT,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _BackdropPainter(
                      vignette: morph,
                      drift: _loop.value,
                    ),
                  ),
                  Center(
                    child: Transform.scale(
                      scale: 1 + exitT * 0.12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 280,
                            height: 280,
                            child: CustomPaint(
                              painter: _AuraPainter(
                                appear: aura,
                                spin: _loop.value,
                              ),
                              child: Center(
                                child: _LogoCard(morph: morph, scan: scan),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Opacity(
                            opacity: title,
                            child: Transform.translate(
                              offset: Offset(0, 22 * (1 - title)),
                              child: Text(
                                l10n.appName,
                                style: MobileUi.text(
                                  40,
                                  weight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Opacity(
                            opacity: tagline * 0.9,
                            child: Transform.translate(
                              offset: Offset(0, 14 * (1 - tagline)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Text(
                                  l10n.t('m.splashTagline'),
                                  style: MobileUi.text(
                                    13.5,
                                    weight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 40 + MediaQuery.paddingOf(context).bottom,
                    child: Opacity(
                      opacity: footer,
                      child: Column(
                        children: [
                          _ProgressBar(value: progress, shimmer: _loop.value),
                          const SizedBox(height: 14),
                          Text(
                            l10n.t('m.poweredBy'),
                            style: MobileUi.text(
                              12,
                              weight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// White logo surface: starts as Android's 160dp launch circle and settles
/// into a rounded card while a scan line sweeps the fingerprint.
class _LogoCard extends StatelessWidget {
  const _LogoCard({required this.morph, required this.scan});

  final double morph;
  final double scan;

  @override
  Widget build(BuildContext context) {
    final size = 160 - 28 * morph;
    final radius = size / 2 - (size / 2 - 38) * morph;
    // Android draws the 108dp adaptive foreground at 240dp inside the circle.
    final imageSize = 240 - 60 * morph;
    final scanning = scan > 0 && scan < 1;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B1F66).withValues(alpha: 0.35 * morph),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: const Color(0xFF93C5FD).withValues(alpha: 0.55 * morph),
            blurRadius: 30,
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.hardEdge,
          children: [
            OverflowBox(
              maxWidth: imageSize,
              maxHeight: imageSize,
              child: HudooriMark(size: imageSize),
            ),
            if (scanning) ...[
              Positioned(
                left: 0,
                right: 0,
                top: size * (0.14 + 0.72 * scan) - 36,
                height: 36,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF38BDF8).withValues(alpha: 0),
                        const Color(0xFF38BDF8).withValues(alpha: 0.22),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: size * 0.12,
                right: size * 0.12,
                top: size * (0.14 + 0.72 * scan) - 1.5,
                height: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: const Color(0xFF0EA5E9),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.9),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Brand blue with a vignette and two slowly drifting light blobs.
class _BackdropPainter extends CustomPainter {
  _BackdropPainter({required this.vignette, required this.drift});

  final double vignette;
  final double drift;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = HudooriSplash.launchBlue);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.15),
          radius: 1.1,
          colors: [
            const Color(0xFF3B82F6).withValues(alpha: 0),
            const Color(0xFF1E3A8A).withValues(alpha: 0.85 * vignette),
          ],
        ).createShader(rect),
    );

    final a = drift * math.pi * 2;
    void blob(Offset c, double r, Color color) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.38 * vignette),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    blob(
      Offset(size.width * 0.1 + math.cos(a) * 16, size.height * 0.12 + math.sin(a) * 12),
      size.width * 0.7,
      const Color(0xFF7DD3FC),
    );
    blob(
      Offset(size.width * 0.95 - math.sin(a) * 14, size.height * 0.86 + math.cos(a) * 16),
      size.width * 0.75,
      const Color(0xFF818CF8),
    );

    final center = Offset(size.width / 2, size.height / 2 - 40);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 1; i <= 4; i++) {
      ring.color = Colors.white.withValues(alpha: 0.05 * vignette);
      canvas.drawCircle(center, 120.0 + i * 70, ring);
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.vignette != vignette || old.drift != drift;
}

/// Orbiting gradient arc + expanding ripples around the logo card.
class _AuraPainter extends CustomPainter {
  _AuraPainter({required this.appear, required this.spin});

  final double appear;
  final double spin;

  @override
  void paint(Canvas canvas, Size size) {
    if (appear <= 0) return;
    final c = size.center(Offset.zero);

    for (var i = 0; i < 2; i++) {
      final t = (spin + i / 2) % 1.0;
      final r = 80 + 60 * Curves.easeOut.transform(t);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: 0.3 * (1 - t) * appear),
      );
    }

    const radius = 104.0;
    final arcRect = Rect.fromCircle(center: c, radius: radius);
    final start = spin * math.pi * 2;
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.12 * appear),
    );
    canvas.drawArc(
      arcRect,
      start,
      math.pi * 0.9,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 0.9,
          transform: GradientRotation(start),
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.95 * appear),
          ],
        ).createShader(arcRect),
    );
    final head = c + Offset(math.cos(start + math.pi * 0.9), math.sin(start + math.pi * 0.9)) * radius;
    canvas.drawCircle(
      head,
      4.5,
      Paint()..color = Colors.white.withValues(alpha: appear),
    );
    canvas.drawCircle(
      head,
      10,
      Paint()..color = const Color(0xFFBAE6FD).withValues(alpha: 0.35 * appear),
    );
  }

  @override
  bool shouldRepaint(_AuraPainter old) =>
      old.appear != appear || old.spin != spin;
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.shimmer});

  final double value;
  final double shimmer;

  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: Directionality.of(context) == TextDirection.rtl,
      child: SizedBox(
        width: 140,
        height: 4,
        child: CustomPaint(
          painter: _ProgressPainter(value: value, shimmer: shimmer),
        ),
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter({required this.value, required this.shimmer});

  final double value;
  final double shimmer;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, r),
      Paint()..color = Colors.white.withValues(alpha: 0.2),
    );
    final fill = Rect.fromLTWH(0, 0, size.width * value, size.height);
    if (fill.width <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(fill, r),
      Paint()
        ..shader = LinearGradient(
          colors: const [Color(0xFFBAE6FD), Colors.white, Color(0xFFBAE6FD)],
          stops: [
            (shimmer - 0.3).clamp(0.0, 1.0),
            shimmer,
            (shimmer + 0.3).clamp(0.0, 1.0),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      old.value != value || old.shimmer != shimmer;
}
