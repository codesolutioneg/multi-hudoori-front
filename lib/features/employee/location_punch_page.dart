import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/widgets/page_header.dart';
import '../../l10n/l10n_extension.dart';
import '../auth/auth_cubit.dart';

/// Employee GPS check-in / check-out (same transactions table as BioTime).
class LocationPunchPage extends StatefulWidget {
  const LocationPunchPage({super.key});

  @override
  State<LocationPunchPage> createState() => _LocationPunchPageState();
}

class _LocationPunchPageState extends State<LocationPunchPage> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _context;
  Position? _position;
  String? _geoError;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ctx = await api.mobilePunchContext();
      await _readGps();
      if (!mounted) return;
      setState(() {
        _context = ctx;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _readGps() async {
    try {
      final service = await Geolocator.isLocationServiceEnabled();
      if (!service) {
        _geoError = 'LOCATION_SERVICE_DISABLED';
        _position = null;
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _geoError = 'LOCATION_PERMISSION_DENIED';
        _position = null;
        return;
      }
      _position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _geoError = null;
    } catch (e) {
      _geoError = e.toString();
      _position = null;
    }
  }

  double? _distanceMeters() {
    final loc = _context?['location'];
    if (loc is! Map || _position == null) return null;
    final lat = (loc['latitude'] as num?)?.toDouble();
    final lng = (loc['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return Geolocator.distanceBetween(
      _position!.latitude,
      _position!.longitude,
      lat,
      lng,
    );
  }

  Future<void> _punch({required bool checkIn}) async {
    final isAr = context.l10n.isAr;
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr ? 'تعذر قراءة الموقع — فعّل GPS' : 'GPS unavailable — enable location'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      if (checkIn) {
        await api.mobilePunchCheckIn(
          latitude: _position!.latitude,
          longitude: _position!.longitude,
        );
      } else {
        await api.mobilePunchCheckOut(
          latitude: _position!.latitude,
          longitude: _position!.longitude,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(checkIn
              ? (isAr ? 'تم تسجيل الحضور' : 'Checked in')
              : (isAr ? 'تم تسجيل الانصراف' : 'Checked out')),
        ),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.l10n.isAr;
    final auth = context.watch<AuthCubit>().state;
    final companyLabel = [
      if ((auth.activeCompanyName ?? '').isNotEmpty) auth.activeCompanyName,
      if ((auth.activeCompanyCode ?? '').isNotEmpty) '(${auth.activeCompanyCode})',
    ].join(' ');

    final enabled = _context?['enabled'] == true;
    final next = _context?['nextAction']?.toString();
    final last = _context?['lastPunch'];
    final loc = _context?['location'];
    final radius = loc is Map ? (loc['geofenceRadiusMeters'] as num?)?.toDouble() ?? 200 : 200.0;
    final distance = _distanceMeters();
    final inside = distance != null && distance <= radius;

    return AppPageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: isAr ? 'بصمة الموقع' : 'Location punch',
            subtitle: companyLabel.isNotEmpty
                ? companyLabel
                : (isAr ? 'حضور وانصراف عبر GPS' : 'Check-in / out via GPS'),
            icon: Icons.my_location_outlined,
            showRefresh: true,
            onRefresh: _refresh,
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
          else if (_error != null)
            Text(_error!, style: TextStyle(color: Colors.red.shade700))
          else if (!enabled)
            Text(
              isAr
                  ? 'بصمة الموقع غير مفعّلة لفرعك. راجع إعدادات HR.'
                  : 'Location punch is not enabled for your branch. Ask HR to enable it.',
              style: AppThemeV2.caption,
            )
          else ...[
            if (companyLabel.isNotEmpty)
              Text(companyLabel, style: AppThemeV2.title),
            if (loc is Map)
              Text(
                '${isAr ? 'الفرع' : 'Branch'}: ${loc['name'] ?? ''}',
                style: AppThemeV2.caption,
              ),
            const SizedBox(height: 12),
            if (_geoError != null)
              Text(
                isAr ? 'مشكلة GPS: $_geoError' : 'GPS issue: $_geoError',
                style: TextStyle(color: Colors.orange.shade800),
              )
            else if (_position != null)
              Text(
                isAr
                    ? 'موقعك: ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}'
                    : 'You: ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
                style: AppThemeV2.caption,
              ),
            if (distance != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  inside
                      ? (isAr
                          ? 'داخل النطاق (${distance.round()} م / $radius م)'
                          : 'Inside geofence (${distance.round()} m / $radius m)')
                      : (isAr
                          ? 'خارج النطاق (${distance.round()} م / $radius م)'
                          : 'Outside geofence (${distance.round()} m / $radius m)'),
                  style: TextStyle(
                    color: inside ? Colors.green.shade700 : Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (last is Map)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  isAr
                      ? 'آخر بصمة: ${last['isCheckIn'] == true ? 'حضور' : 'انصراف'} — ${last['punchTime'] ?? ''}'
                      : 'Last punch: ${last['isCheckIn'] == true ? 'In' : 'Out'} — ${last['punchTime'] ?? ''}',
                  style: AppThemeV2.caption,
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy || !inside || next == 'check_out'
                        ? null
                        : () => _punch(checkIn: true),
                    icon: const Icon(Icons.login),
                    label: Text(isAr ? 'حضور' : 'Check in'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _busy || !inside || next == 'check_in'
                        ? null
                        : () => _punch(checkIn: false),
                    icon: const Icon(Icons.logout),
                    label: Text(isAr ? 'انصراف' : 'Check out'),
                  ),
                ),
              ],
            ),
            if (kIsWeb)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  isAr
                      ? 'ملاحظة: على الويب يحتاج المتصفح إذن الموقع.'
                      : 'Note: the browser must allow location access.',
                  style: AppThemeV2.caption,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
