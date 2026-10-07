import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/platform/mobile_platform.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/widgets/hr_local_data_info.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';
import '../../l10n/l10n_extension.dart';
import '../mobile/mobile_ui.dart';

import '../mobile/hudoori_loader.dart';
class HrAttendancePage extends StatefulWidget {
  const HrAttendancePage({super.key});

  @override
  State<HrAttendancePage> createState() => _HrAttendancePageState();
}

class _HrAttendancePageState extends State<HrAttendancePage> {
  static const _pageSize = 50;

  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  String? _statusFilter;
  final List<Map<String, dynamic>> _records = [];
  Timer? _searchDebounce;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _total = 0;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
  }

  String get _dateFrom =>
      DateTime(_month.year, _month.month, 1).toIso8601String().slice(0, 10);

  String get _dateTo =>
      DateTime(_month.year, _month.month + 1, 0).toIso8601String().slice(0, 10);

  String get _monthLabel => DateFormat.yMMMM('ar').format(_month);

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _loadingMore || _loading) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 280) {
      _loadMore();
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _offset = 0;
        _records.clear();
      });
    }
    try {
      final page = await api.attendanceList(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        search: _searchCtrl.text.trim(),
        status: _statusFilter,
        limit: _pageSize,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _records
          ..clear()
          ..addAll(page.items);
        _total = page.total;
        _offset = page.items.length;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_offset >= _total || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await api.attendanceList(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        search: _searchCtrl.text.trim(),
        status: _statusFilter,
        limit: _pageSize,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        _records.addAll(page.items);
        _offset += page.items.length;
        _total = page.total;
        _loadingMore = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  String? _generateMessage;

  Future<void> _generate() async {
    final progressState = ValueNotifier<_GenerateProgress>(
      _GenerateProgress(
        message: context.t('att.preparing'),
        percent: 0,
      ),
    );
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: ValueListenableBuilder<_GenerateProgress>(
            valueListenable: progressState,
            builder: (_, state, __) {
              final pct = state.percent.clamp(0, 100);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.t('att.generate'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: pct <= 0 ? null : pct / 100,
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    pct > 0 ? context.t('att.pctComplete', {'pct': pct}) : context.t('att.preparingShort'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    setState(() {
      _loading = true;
      _generateMessage = progressState.value.message;
    });
    try {
      final result = await api.attendanceGenerate(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        onProgress: (msg, {int? progress}) {
          progressState.value = _GenerateProgress(
            message: msg,
            percent: progress ?? progressState.value.percent,
          );
          if (mounted) setState(() => _generateMessage = msg);
        },
      );
      await _load(reset: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ?? context.t('att.generated'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _generateMessage = null);
      }
      progressState.dispose();
    }
  }

  String _displayName(Map<String, dynamic> r) {
    final name = r['employeeName']?.toString().trim() ??
        r['employee']?['displayName']?.toString().trim() ??
        r['employee']?['name']?.toString().trim() ??
        '';
    final code = r['employeeCode']?.toString().trim() ??
        r['employee']?['code']?.toString().trim() ??
        '';
    if (name.isNotEmpty && name != code) return name;
    if (code.isNotEmpty) return context.t('att.employeeCode', {'code': code});
    return context.t('att.unknownEmployee');
  }

  String _formatHours(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
    if (n == n.roundToDouble()) return '${n.round()}';
    return n.toStringAsFixed(2);
  }

  String _subtitle(Map<String, dynamic> r) {
    final code = r['employeeCode']?.toString() ?? r['employee']?['code']?.toString() ?? '';
    final dept = r['departmentName']?.toString() ?? '';
    final status = _statusAr(r['status']?.toString() ?? '');
    final hours = r['workedHours'] ?? 0;
    final net = r['netWorkedHours'] ?? hours;
    final ot = r['overtimeHours'] ?? 0;
    final early = r['earlyLeaveMinutes'] ?? 0;
    final date = r['date']?.toString() ?? '';
    final parts = <String>[
      if (code.isNotEmpty) code,
      if (dept.isNotEmpty) dept,
      status,
      context.t('att.netHours', {'hours': _formatHours(net)}),
      if ((ot as num) > 0) context.t('att.overtime', {'hours': _formatHours(ot)}),
      if ((early as num) > 0) context.t('att.earlyMinutes', {'minutes': early}),
      date,
    ];
    return parts.join(' • ');
  }

  String _statusAr(String s) {
    switch (s) {
      case 'present': return context.t('att.present');
      case 'absent': return context.t('att.absent');
      case 'late': return context.t('att.late');
      case 'early_leave': return context.t('att.earlyLeave');
      case 'late_early': return context.t('att.lateAndEarly');
      case 'rest_day': return context.t('att.weeklyRest');
      case 'leave': return context.t('att.leave');
      case 'off': return context.t('att.rest');
      case 'sick': return context.t('att.sick');
      default: return s;
    }
  }

  StatusTagType _statusType(String s) {
    switch (s) {
      case 'present': return StatusTagType.success;
      case 'absent': return StatusTagType.danger;
      case 'late': return StatusTagType.warning;
      default: return StatusTagType.info;
    }
  }

  Color _statusColor(String s) => switch (s) {
        'early_leave' => const Color(0xFFF2552C),
        'late_early' => const Color(0xFFD97706),
        'rest_day' || 'off' => MobileTone.violet,
        _ => switch (_statusType(s)) {
            StatusTagType.success => MobileTone.success,
            StatusTagType.danger => MobileTone.danger,
            StatusTagType.warning => MobileTone.warning,
            _ => MobileTone.info,
          },
      };

  Widget _buildMobile(BuildContext context) {
    final filters = <(String?, String)>[
      (null, context.t('common.all')),
      ('present', context.t('attendance.status.present')),
      ('late', context.t('attendance.status.late')),
      ('absent', context.t('attendance.status.absent')),
      ('early_leave', context.t('attendance.status.earlyLeave')),
      ('late_early', context.t('attendance.status.lateEarly')),
      ('rest_day', context.t('attendance.status.restDay')),
    ];

    Widget circleButton(IconData icon, VoidCallback? onTap) => Material(
          color: Colors.white,
          shape: const CircleBorder(side: BorderSide(color: Color(0xFFE6EBF3))),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, size: 22, color: MobileUi.ink),
            ),
          ),
        );

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: MobileUi.primaryGradient,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: MobileUi.primary.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.fact_check_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('attendance.title'),
                    style: MobileUi.text(24, weight: FontWeight.w800, height: 1.2),
                  ),
                  Text(
                    _loading && _records.isEmpty
                        ? context.t('common.loading')
                        : context.l10n.t('m.records', {'count': _total}),
                    style: MobileUi.text(13, weight: FontWeight.w500, color: MobileUi.muted),
                  ),
                ],
              ),
            ),
            circleButton(Icons.refresh_rounded, () => _load(reset: true)),
            const SizedBox(width: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: MobileUi.primaryGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: MobileUi.primary.withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: _loading ? null : _generate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, size: 18, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          context.t('m.generate'),
                          style: MobileUi.text(14, weight: FontWeight.w700, color: Colors.white, height: 1.2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: MobileUi.card(),
          child: Row(
            children: [
              IconButton(
                tooltip: context.t('attendance.prevMonth'),
                onPressed: _loading ? null : () => _shiftMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded, color: MobileUi.primary),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 18, color: MobileUi.primary),
                    const SizedBox(width: 8),
                    Text(_monthLabel, style: MobileUi.text(15, weight: FontWeight.w700)),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.t('attendance.nextMonth'),
                onPressed: _loading ? null : () => _shiftMonth(1),
                icon: const Icon(Icons.chevron_right_rounded, color: MobileUi.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchCtrl,
          style: MobileUi.text(14, weight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: context.t('m.searchEmployee'),
            hintStyle: MobileUi.text(14, weight: FontWeight.w500, color: MobileUi.muted),
            prefixIcon: const Icon(Icons.search_rounded, color: MobileUi.muted),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {});
                      _load(reset: true);
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFEDF1F7)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: MobileUi.primary, width: 1.4),
            ),
          ),
          onChanged: (v) {
            setState(() {});
            _onSearchChanged(v);
          },
          onSubmitted: (_) => _load(reset: true),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final (value, label) = filters[i];
              final selected = _statusFilter == value;
              return GestureDetector(
                onTap: () {
                  if (selected) return;
                  setState(() => _statusFilter = value);
                  _load(reset: true);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: selected ? MobileUi.primaryGradient : null,
                    color: selected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(
                      color: selected ? Colors.transparent : const Color(0xFFE6EBF3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (value != null) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: selected ? Colors.white : _statusColor(value),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ] else ...[
                        Icon(
                          Icons.apps_rounded,
                          size: 15,
                          color: selected ? Colors.white : MobileUi.muted,
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        label,
                        style: MobileUi.text(
                          13,
                          weight: FontWeight.w700,
                          color: selected ? Colors.white : MobileUi.ink,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );

    Widget body;
    if (_loading && _records.isEmpty) {
      body = SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Column(
            children: [
              const HudooriLoader(),
              if (_generateMessage != null) ...[
                const SizedBox(height: 12),
                Text(_generateMessage!, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      );
    } else if (_error != null) {
      body = SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: MobileUi.card(),
          child: Text(_error!, style: MobileUi.text(13, color: MobileTone.danger)),
        ),
      );
    } else if (_records.isEmpty) {
      body = SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: MobileUi.card(),
          child: Column(
            children: [
              const MobileIconBadge(icon: Icons.event_busy_rounded, size: 52),
              const SizedBox(height: 12),
              Text(
                _searchCtrl.text.trim().isNotEmpty
                    ? context.t('attendance.emptySearch', {
                        'q': _searchCtrl.text.trim(),
                        'month': _monthLabel,
                      })
                    : context.t('attendance.emptyMonth', {'month': _monthLabel}),
                textAlign: TextAlign.center,
                style: MobileUi.text(14, weight: FontWeight.w500, color: MobileUi.muted),
              ),
              if (_searchCtrl.text.trim().isEmpty) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _generate,
                  icon: const Icon(Icons.bolt_rounded),
                  label: Text(context.t('attendance.generate')),
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      body = SliverList.separated(
        itemCount: _records.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i >= _records.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: HudooriLoader()),
            );
          }
          return _mobileRecord(context, _records[i]);
        },
      );
    }

    return ColoredBox(
      color: MobileUi.background,
      child: RefreshIndicator(
        color: MobileUi.primary,
        onRefresh: () => _load(reset: true),
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              sliver: SliverToBoxAdapter(child: header),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 48),
              sliver: body,
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileRecord(BuildContext context, Map<String, dynamic> r) {
    final status = r['status']?.toString() ?? '';
    final color = _statusColor(status);
    final code = r['employeeCode']?.toString() ?? r['employee']?['code']?.toString() ?? '';
    final dept = r['departmentName']?.toString() ?? '';
    final net = r['netWorkedHours'] ?? r['workedHours'] ?? 0;
    final late = (r['lateMinutes'] as num?) ?? 0;
    final ot = (r['overtimeHours'] as num?) ?? 0;
    final early = (r['earlyLeaveMinutes'] as num?) ?? 0;
    final date = r['date']?.toString() ?? '';
    final name = _displayName(r);

    Widget metric(IconData icon, String text, Color c) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: c),
              const SizedBox(width: 4),
              Text(text, style: MobileUi.text(11.5, weight: FontWeight.w700, color: c, height: 1.2)),
            ],
          ),
        );

    final l10n = context.l10n;
    final day = DateTime.tryParse(date);
    final inAt = parseWallClock(r['firstCheckIn'] ?? r['checkIn']);
    final outAt = parseWallClock(r['lastCheckOut'] ?? r['checkOut']);
    final hasMetrics = late > 0 || ot > 0 || early > 0;

    Widget timeCell(IconData icon, Color c, String label, String value) => Expanded(
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: c),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MobileUi.text(11, weight: FontWeight.w600, color: MobileUi.muted, height: 1.2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  textDirection: TextDirection.ltr,
                  style: MobileUi.text(14, weight: FontWeight.w800, height: 1.2),
                ),
              ),
            ],
          ),
        );
    final divider = Container(width: 1, height: 28, color: const Color(0xFFE3E9F5));

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: MobileUi.card(r: 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
          Row(
            children: [
              if (day != null)
                Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${day.day}',
                        style: MobileUi.text(18, weight: FontWeight.w800, color: color, height: 1.1),
                      ),
                      Text(
                        weekdayShort(l10n, day),
                        style: MobileUi.text(10.5, weight: FontWeight.w700, color: MobileUi.muted, height: 1.2),
                      ),
                    ],
                  ),
                )
              else
                MobileAvatar(name: name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MobileUi.text(15, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [if (code.isNotEmpty) code, if (dept.isNotEmpty) dept].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MobileUi.text(12, weight: FontWeight.w500, color: MobileUi.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(9, 4, 10, 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _statusAr(status),
                      style: MobileUi.text(12, weight: FontWeight.w800, color: color, height: 1.2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                timeCell(Icons.login_rounded, MobileTone.success, l10n.t('m.checkIn'), formatClock(l10n, inAt)),
                divider,
                timeCell(Icons.logout_rounded, const Color(0xFFF2552C), l10n.t('m.checkOut'), formatClock(l10n, outAt)),
                divider,
                timeCell(Icons.timer_outlined, MobileUi.primary, l10n.t('m.workHours'), '${_formatHours(net)}h'),
              ],
            ),
          ),
          if (hasMetrics) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (late > 0)
                metric(
                  Icons.schedule_rounded,
                  context.t('attendance.lateMins', {'n': late}),
                  MobileTone.warning,
                ),
              if (ot > 0)
                metric(
                  Icons.trending_up_rounded,
                  context.t('attendance.otHours', {'n': _formatHours(ot)}),
                  MobileTone.success,
                ),
              if (early > 0)
                metric(
                  Icons.directions_walk_rounded,
                  context.t('att.earlyMinutes', {'minutes': early}),
                  MobileTone.danger,
                ),
            ],
          ),
          ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isNativeMobile) return _buildMobile(context);
    return AppPageScaffold(
      scrollable: false,
      padding: EdgeInsets.fromLTRB(
        isMobile(context) ? 12 : 24,
        isMobile(context) ? 12 : 20,
        isMobile(context) ? 12 : 24,
        isMobile(context) ? 12 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.t('attendance.title'),
            subtitle: _loading && _records.isEmpty
                ? context.t('common.loading')
                : context.t('attendance.monthSubtitle', {
                    'month': _monthLabel,
                    'shown': _records.length,
                    'total': _total,
                  }),
            icon: Icons.fact_check_outlined,
            actions: [
              IconButton(onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh_rounded)),
              FilledButton.icon(
                onPressed: _loading ? null : _generate,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(context.t('attendance.generate')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SellixCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: context.t('attendance.prevMonth'),
                  onPressed: _loading ? null : () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    _monthLabel,
                    textAlign: TextAlign.center,
                    style: AppThemeV2.title.copyWith(fontSize: 15),
                  ),
                ),
                IconButton(
                  tooltip: context.t('attendance.nextMonth'),
                  onPressed: _loading ? null : () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SellixCard(
            child: DropdownButtonFormField<String?>(
              value: _statusFilter,
              decoration: InputDecoration(
                labelText: context.t('attendance.statusFilter'),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(context.t('common.all'))),
                DropdownMenuItem(value: 'present', child: Text(context.t('attendance.status.present'))),
                DropdownMenuItem(value: 'absent', child: Text(context.t('attendance.status.absent'))),
                DropdownMenuItem(value: 'late', child: Text(context.t('attendance.status.late'))),
                DropdownMenuItem(value: 'early_leave', child: Text(context.t('attendance.status.earlyLeave'))),
                DropdownMenuItem(value: 'late_early', child: Text(context.t('attendance.status.lateEarly'))),
                DropdownMenuItem(value: 'rest_day', child: Text(context.t('attendance.status.restDay'))),
              ],
              onChanged: (v) {
                setState(() => _statusFilter = v);
                _load(reset: true);
              },
            ),
          ),
          const SizedBox(height: 16),
          SellixCard(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: context.t('attendance.searchHint'),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                          _load(reset: true);
                        },
                      )
                    : null,
                isDense: true,
              ),
              onChanged: (v) {
                setState(() {});
                _onSearchChanged(v);
              },
              onSubmitted: (_) => _load(reset: true),
            ),
          ),
          const SizedBox(height: 12),
          HrLocalDataBanner(
            title: context.t('attendance.localBanner'),
            hint: context.t('attendance.localHint'),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading && _records.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const HudooriLoader(),
                        if (_generateMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(_generateMessage!, textAlign: TextAlign.center),
                        ],
                      ],
                    ),
                  )
                : _error != null
                    ? Center(child: Text(_error!))
                    : _records.isEmpty
                        ? HrEmptyListCard(
                            message: _searchCtrl.text.trim().isNotEmpty
                                ? context.t('attendance.emptySearch', {
                                    'q': _searchCtrl.text.trim(),
                                    'month': _monthLabel,
                                  })
                                : context.t('attendance.emptyMonth', {
                                    'month': _monthLabel,
                                  }),
                            actionLabel: _searchCtrl.text.trim().isNotEmpty
                                ? null
                                : context.t('attendance.generate'),
                            onAction: _searchCtrl.text.trim().isNotEmpty
                                ? null
                                : _generate,
                          )
                        : RefreshIndicator(
                            onRefresh: () => _load(reset: true),
                            child: ListView.separated(
                              controller: _scrollCtrl,
                              padding: EdgeInsets.zero,
                              itemCount: _records.length + (_loadingMore ? 1 : 0),
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                if (i >= _records.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(child: HudooriLoader()),
                                  );
                                }
                                final r = _records[i];
                                final status = r['status']?.toString() ?? '';
                                return SellixCard(
                                  child: ListTile(
                                    title: Text(
                                      _displayName(r),
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(_subtitle(r)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        StatusTag(label: _statusAr(status), type: _statusType(status)),
                                        if ((r['lateMinutes'] as num? ?? 0) > 0) ...[
                                          const SizedBox(width: 6),
                                          Chip(
                                            label: Text(
                                              context.t('attendance.lateMins', {
                                                'n': r['lateMinutes'],
                                              }),
                                            ),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                        if ((r['overtimeHours'] as num? ?? 0) > 0) ...[
                                          const SizedBox(width: 6),
                                          Chip(
                                            label: Text(
                                              context.t('attendance.otHours', {
                                                'n': _formatHours(r['overtimeHours']),
                                              }),
                                            ),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

extension on String {
  String slice(int start, int end) => substring(start, end.clamp(0, length));
}

class _GenerateProgress {
  const _GenerateProgress({required this.message, required this.percent});
  final String message;
  final int percent;
}
