import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';
import '../../l10n/l10n_extension.dart';

class MyAttendancePage extends StatefulWidget {
  const MyAttendancePage({super.key});

  @override
  State<MyAttendancePage> createState() => _MyAttendancePageState();
}

class _MyAttendancePageState extends State<MyAttendancePage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await api.myAttendance();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  StatusTagType _tag(String status) {
    final s = status.toLowerCase();
    if (s.contains('present') || s.contains('حاضر')) return StatusTagType.success;
    if (s.contains('absent') || s.contains('غائب')) return StatusTagType.danger;
    if (s.contains('leave') || s.contains('إجازة')) return StatusTagType.info;
    return StatusTagType.warning;
  }

  String _statusLabel(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return context.l10n.isAr ? 'حاضر' : 'Present';
      case 'absent':
        return context.l10n.isAr ? 'غائب' : 'Absent';
      case 'late':
        return context.l10n.isAr ? 'متأخر' : 'Late';
      case 'leave':
      case 'off':
        return context.l10n.isAr ? 'إجازة' : 'Leave';
      default:
        return status;
    }
  }

  String _formatTime(dynamic value) {
    if (value == null || value == false || value.toString().isEmpty) return '--:--';
    try {
      // Check-in/out are stored as device wall-clock tagged UTC; keep them in UTC so
      // we render the actual punch time and do not add the device offset on top.
      final dt = DateTime.parse(value.toString());
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      child: Column(
        children: [
          PageHeader(
            title: context.t('attendance.myTitle'),
            subtitle: context.t('attendance.mySubtitle'),
            icon: Icons.fact_check_outlined,
            actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            SellixCard(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
          else if (_items.isEmpty)
            SellixCard(child: Text(context.t('attendance.emptyPeriod')))
          else
            SellixCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final item in _items)
                    ListTile(
                      title: Text(item['date']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${_formatTime(item['firstCheckIn'] ?? item['checkIn'])} → ${_formatTime(item['lastCheckOut'] ?? item['checkOut'])}',
                      ),
                      trailing: StatusTag(
                        label: _statusLabel(context, item['status']?.toString() ?? '-'),
                        type: _tag(item['status']?.toString() ?? ''),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
