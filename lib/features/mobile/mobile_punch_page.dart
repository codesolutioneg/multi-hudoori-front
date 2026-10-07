import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/utils/api_error_message.dart';
import '../../l10n/app_localizations.dart';
import 'mobile_punch_controller.dart';
import 'mobile_ui.dart';

import 'hudoori_loader.dart';
/// Native mobile location punch: live clock, one big punch button that
/// knows whether the next punch is in or out, and the branch geofence state.
class MobilePunchPage extends StatefulWidget {
  const MobilePunchPage({super.key});

  @override
  State<MobilePunchPage> createState() => _MobilePunchPageState();
}

class _MobilePunchPageState extends State<MobilePunchPage>
    with SingleTickerProviderStateMixin {
  final _punch = MobilePunchController();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  late Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _punch.refresh();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    _pulse.dispose();
    _punch.dispose();
    super.dispose();
  }

  String _geoMessage(AppLocalizations l10n, PunchGeoIssue issue) =>
      switch (issue) {
        PunchGeoIssue.serviceOff => l10n.t('m.gpsOff'),
        PunchGeoIssue.denied => l10n.t('m.gpsDenied'),
        PunchGeoIssue.error => l10n.t('m.gpsError'),
      };

  Future<void> _doPunch() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    HapticFeedback.mediumImpact();
    String text;
    var ok = false;
    try {
      final checkedIn = await _punch.punch();
      text = l10n.t(checkedIn ? 'm.checkedIn' : 'm.checkedOut');
      ok = true;
    } on PunchGeoIssue catch (issue) {
      text = _geoMessage(l10n, issue);
    } catch (e) {
      if (!mounted) return;
      text = friendlyApiError(context, e);
    }
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ok ? MobileTone.success : MobileTone.danger,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: Text(text, style: MobileUi.text(14, color: Colors.white)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: MobileUi.background,
      child: ListenableBuilder(
        listenable: _punch,
        builder: (context, _) {
          final p = _punch;
          return RefreshIndicator(
            color: MobileUi.primary,
            onRefresh: p.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 48),
              children: [
                _clockHeader(l10n),
                const SizedBox(height: 22),
                if (p.loading && p.context == null)
                  const Padding(
                    padding: EdgeInsets.all(60),
                    child: Center(child: HudooriLoader()),
                  )
                else if (p.error != null)
                  _infoCard(
                    icon: Icons.cloud_off_rounded,
                    color: MobileTone.danger,
                    text: friendlyApiError(context, p.error!),
                  )
                else if (!p.enabled)
                  _infoCard(
                    icon: Icons.location_disabled_rounded,
                    color: MobileTone.warning,
                    text: l10n.t('m.punchDisabled'),
                  )
                else ...[
                  Center(child: _punchButton(l10n, p)),
                  const SizedBox(height: 26),
                  _geofenceCard(l10n, p),
                  const SizedBox(height: 12),
                  if (p.lastPunch != null) _lastPunchCard(l10n, p),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _clockHeader(AppLocalizations l10n) {
    final h = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final mm = _now.minute.toString().padLeft(2, '0');
    final ss = _now.second.toString().padLeft(2, '0');
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          textDirection: TextDirection.ltr,
          children: [
            Text(
              '$h:$mm',
              style: MobileUi.text(46, weight: FontWeight.w800, height: 1.1),
            ),
            const SizedBox(width: 6),
            Text(
              ':$ss',
              style: MobileUi.text(20, weight: FontWeight.w700, color: MobileUi.muted),
            ),
            const SizedBox(width: 8),
            Text(
              _now.hour < 12 ? l10n.t('m.am') : l10n.t('m.pm'),
              style: MobileUi.text(18, weight: FontWeight.w700, color: MobileUi.primary),
            ),
          ],
        ),
        Text(
          '${weekdayShort(l10n, _now)}${l10n.isAr ? '،' : ','} ${_now.day} ${monthShort(l10n, _now)} ${_now.year}',
          style: MobileUi.text(14, weight: FontWeight.w500, color: MobileUi.muted),
        ),
      ],
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _punchButton(AppLocalizations l10n, MobilePunchController p) {
    final checkIn = p.nextIsCheckIn;
    final canTap = !p.busy && (p.inside || p.geoIssue != null);
    final colors = checkIn
        ? const [Color(0xFF5B9BFF), Color(0xFF2563EB)]
        : const [Color(0xFFFF9A62), Color(0xFFF2552C)];

    return Column(
      children: [
        GestureDetector(
          onTap: canTap ? _doPunch : null,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (canTap)
                    for (var i = 0; i < 2; i++)
                      Builder(builder: (_) {
                        final t = (_pulse.value + i / 2) % 1.0;
                        final d = 190 + 70 * t;
                        return Container(
                          width: d,
                          height: d,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.last.withValues(alpha: 0.16 * (1 - t)),
                          ),
                        );
                      }),
                  child!,
                ],
              ),
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: canTap || p.busy ? 1 : 0.5,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white, width: 6),
                  boxShadow: [
                    BoxShadow(
                      color: colors.last.withValues(alpha: 0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: p.busy
                    ? const Center(
                        child: SizedBox(
                          width: 54,
                          height: 54,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const HudooriMark(size: 110, white: true),
                          Transform.translate(
                            offset: const Offset(0, -12),
                            child: Text(
                              l10n.t(checkIn ? 'm.checkIn' : 'm.checkOut'),
                              style: MobileUi.text(16, weight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        Text(
          p.busy
              ? l10n.t('m.punching')
              : l10n.t(checkIn ? 'm.tapToPunchIn' : 'm.tapToPunchOut'),
          style: MobileUi.text(14, weight: FontWeight.w600, color: MobileUi.muted),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).scaleXY(begin: 0.94, end: 1, curve: Curves.easeOutBack);
  }

  Widget _geofenceCard(AppLocalizations l10n, MobilePunchController p) {
    final distance = p.distance;
    final (Color color, IconData icon, String text) = p.geoIssue != null
        ? (MobileTone.warning, Icons.gps_off_rounded, _geoMessage(l10n, p.geoIssue!))
        : distance == null
            ? (MobileUi.muted, Icons.gps_not_fixed_rounded, l10n.t('m.locating'))
            : p.inside
                ? (
                    MobileTone.success,
                    Icons.verified_rounded,
                    l10n.t('m.insideRange', {'distance': distance.round()}),
                  )
                : (
                    MobileTone.danger,
                    Icons.wrong_location_rounded,
                    l10n.t('m.outsideRange', {
                      'distance': distance.round(),
                      'radius': p.radius.round(),
                    }),
                  );
    final ratio = distance == null ? 0.0 : (1 - distance / (p.radius * 2)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: MobileUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MobileIconBadge(icon: Icons.storefront_outlined, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  p.branchName.isEmpty ? '—' : l10n.t('m.branch', {'name': p.branchName}),
                  style: MobileUi.text(15, weight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: p.loading ? null : p.refresh,
                icon: const Icon(Icons.my_location_rounded, color: MobileUi.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  text,
                  style: MobileUi.text(13, weight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 120.ms, duration: 380.ms).slideY(begin: 0.08, end: 0);
  }

  Widget _lastPunchCard(AppLocalizations l10n, MobilePunchController p) {
    final last = p.lastPunch!;
    final isIn = last['isCheckIn'] == true;
    final at = parseWallClock(last['punchTime']);
    final color = isIn ? MobileUi.primary : const Color(0xFFF2552C);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: MobileUi.card(),
      child: Row(
        children: [
          MobileIconBadge(
            icon: isIn ? Icons.login_rounded : Icons.logout_rounded,
            color: color,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('m.lastPunch'),
                  style: MobileUi.text(12, weight: FontWeight.w500, color: MobileUi.muted),
                ),
                Text(
                  l10n.t(isIn ? 'm.checkIn' : 'm.checkOut'),
                  style: MobileUi.text(15, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatClock(l10n, at),
                style: MobileUi.text(15, weight: FontWeight.w800),
              ),
              if (at != null)
                Text(
                  '${at.day} ${monthShort(l10n, at)}',
                  style: MobileUi.text(12, weight: FontWeight.w500, color: MobileUi.muted),
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 380.ms).slideY(begin: 0.08, end: 0);
  }

  Widget _infoCard({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: MobileUi.card(),
      child: Column(
        children: [
          MobileIconBadge(icon: icon, color: color, size: 56),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: MobileUi.text(14, weight: FontWeight.w600, color: MobileUi.ink),
          ),
        ],
      ),
    );
  }
}
