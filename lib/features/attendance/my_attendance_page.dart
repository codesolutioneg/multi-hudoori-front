import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/di/injection.dart';
import '../../core/platform/mobile_platform.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';
import '../../l10n/l10n_extension.dart';
import '../mobile/mobile_ui.dart';

import '../mobile/hudoori_loader.dart';
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

  Color _statusColor(String status) => switch (_tag(status)) {
        StatusTagType.success => MobileTone.success,
        StatusTagType.danger => MobileTone.danger,
        StatusTagType.info => MobileTone.info,
        _ => MobileTone.warning,
      };

  Widget _buildMobile(BuildContext context) {
    final l10n = context.l10n;
    final items = [..._items]
      ..sort((a, b) =>
          (b['date']?.toString() ?? '').compareTo(a['date']?.toString() ?? ''));

    return ColoredBox(
      color: MobileUi.background,
      child: RefreshIndicator(
        color: MobileUi.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 48),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.t('attendance.myTitle'), style: MobileUi.text(22, weight: FontWeight.w800)),
                      Text(
                        _loading ? context.t('attendance.mySubtitle') : l10n.t('m.records', {'count': items.length}),
                        style: MobileUi.text(13, weight: FontWeight.w500, color: MobileUi.muted),
                      ),
                    ],
                  ),
                ),
                const MobileIconBadge(icon: Icons.fact_check_outlined, size: 44),
              ],
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: HudooriLoader()),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: MobileUi.card(),
                child: Text(_error!, style: MobileUi.text(13, color: MobileTone.danger)),
              )
            else if (items.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: MobileUi.card(),
                child: Text(
                  context.t('attendance.emptyPeriod'),
                  textAlign: TextAlign.center,
                  style: MobileUi.text(14, weight: FontWeight.w500, color: MobileUi.muted),
                ),
              )
            else
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _mobileRecord(context, items[i])
                      .animate(delay: Duration(milliseconds: 40 * (i.clamp(0, 10))))
                      .fadeIn(duration: 320.ms)
                      .slideY(begin: 0.06, end: 0),
                ),
          ],
        ),
      ),
    );
  }

  Widget _mobileRecord(BuildContext context, Map<String, dynamic> item) {
    final l10n = context.l10n;
    final status = item['status']?.toString() ?? '';
    final color = _statusColor(status);
    final day = DateTime.tryParse(item['date']?.toString() ?? '');
    final inAt = parseWallClock(item['firstCheckIn'] ?? item['checkIn']);
    final outAt = parseWallClock(item['lastCheckOut'] ?? item['checkOut']);
    final hours = inAt != null && outAt != null && outAt.isAfter(inAt)
        ? formatDuration(l10n, outAt.difference(inAt))
        : '--';

    Widget cell(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: MobileUi.text(11.5, weight: FontWeight.w500, color: MobileUi.muted)),
              const SizedBox(height: 2),
              Text(
                value,
                textDirection: TextDirection.ltr,
                style: MobileUi.text(14, weight: FontWeight.w800),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: MobileUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: MobileUi.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      day == null ? '--' : day.day.toString().padLeft(2, '0'),
                      style: MobileUi.text(17, weight: FontWeight.w800, color: MobileUi.primary, height: 1.1),
                    ),
                    if (day != null)
                      Text(
                        monthShort(l10n, day),
                        style: MobileUi.text(10, weight: FontWeight.w600, color: MobileUi.primary),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  day == null ? (item['date']?.toString() ?? '') : '${weekdayShort(l10n, day)} · ${day.year}',
                  style: MobileUi.text(15, weight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(context, status.isEmpty ? '-' : status),
                  style: MobileUi.text(12, weight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFEDF1F7)),
          ),
          Row(
            children: [
              cell(l10n.t('m.checkIn'), formatClock(l10n, inAt)),
              cell(l10n.t('m.checkOut'), formatClock(l10n, outAt)),
              cell(l10n.t('m.workHours'), hours),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isNativeMobile) return _buildMobile(context);
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
            const Center(child: HudooriLoader())
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
