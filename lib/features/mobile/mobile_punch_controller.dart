import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/di/injection.dart';

enum PunchGeoIssue { serviceOff, denied, error }

/// Branch geofence + GPS state for the employee's location punch.
class MobilePunchController extends ChangeNotifier {
  bool loading = true;
  bool busy = false;
  Object? error;
  Map<String, dynamic>? context;
  Position? position;
  PunchGeoIssue? geoIssue;

  bool _disposed = false;

  bool get enabled => context?['enabled'] == true;

  Map? get location {
    final loc = context?['location'];
    return loc is Map ? loc : null;
  }

  Map? get lastPunch {
    final last = context?['lastPunch'];
    return last is Map ? last : null;
  }

  String get branchName => location?['name']?.toString() ?? '';

  double get radius =>
      (location?['geofenceRadiusMeters'] as num?)?.toDouble() ?? 200;

  /// The server says which punch is allowed next; when it doesn't, alternate
  /// from the last recorded punch.
  bool get nextIsCheckIn {
    final next = context?['nextAction']?.toString();
    if (next == 'check_in') return true;
    if (next == 'check_out') return false;
    return lastPunch?['isCheckIn'] != true;
  }

  double? get distance {
    final loc = location;
    final pos = position;
    if (loc == null || pos == null) return null;
    final lat = (loc['latitude'] as num?)?.toDouble();
    final lng = (loc['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lng);
  }

  bool get inside {
    final d = distance;
    return d != null && d <= radius;
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    _notify();
    try {
      context = await api.mobilePunchContext();
      if (enabled) await _readGps();
    } catch (e) {
      error = e;
    }
    loading = false;
    _notify();
  }

  Future<void> _readGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        geoIssue = PunchGeoIssue.serviceOff;
        position = null;
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        geoIssue = PunchGeoIssue.denied;
        position = null;
        return;
      }
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      geoIssue = null;
    } catch (_) {
      geoIssue = PunchGeoIssue.error;
      position = null;
    }
  }

  /// Records the next punch. Throws [PunchGeoIssue] or the API error; returns
  /// whether it was a check-in.
  Future<bool> punch() async {
    busy = true;
    _notify();
    try {
      await _readGps();
      final issue = geoIssue;
      if (issue != null) throw issue;
      final pos = position!;
      final checkIn = nextIsCheckIn;
      if (checkIn) {
        await api.mobilePunchCheckIn(
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
      } else {
        await api.mobilePunchCheckOut(
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
      }
      context = await api.mobilePunchContext();
      return checkIn;
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
