import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/widgets/hr_local_data_info.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';
import '../../l10n/l10n_extension.dart';

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

  @override
  Widget build(BuildContext context) {
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
                        const CircularProgressIndicator(),
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
                                    child: Center(child: CircularProgressIndicator()),
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
