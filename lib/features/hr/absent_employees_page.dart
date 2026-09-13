import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/l10n_extension.dart';

class AbsentEmployeesPage extends StatefulWidget {
  const AbsentEmployeesPage({super.key});

  @override
  State<AbsentEmployeesPage> createState() => _AbsentEmployeesPageState();
}

class _AbsentEmployeesPageState extends State<AbsentEmployeesPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _markingRead = false;
  bool _didMarkRead = false;
  int _windowDays = 7;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await api.absencesList();
      final items = ((data['items'] as List?) ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = items;
        _windowDays = (data['windowDays'] as num?)?.toInt() ?? 7;
        _loading = false;
      });
      await _markReadAfterFirstLoad();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _markReadAfterFirstLoad() async {
    if (_didMarkRead || _markingRead) return;
    _markingRead = true;
    try {
      await api.absencesMarkRead();
      _didMarkRead = true;
      if (mounted) {
        setState(() {
          _items = _items.map((item) => {...item, 'isRead': true}).toList();
        });
      }
    } catch (_) {
      // Keep the loaded list visible; a refresh can retry marking it read.
    } finally {
      _markingRead = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.t('abs.title'),
            subtitle: context.t('abs.subtitle', {'days': _windowDays}),
            icon: Icons.person_off_outlined,
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.dashboard);
              }
            },
            showRefresh: true,
            onRefresh: _load,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppThemeV2.primary),
                  )
                : _items.isEmpty
                ? SellixCard(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.how_to_reg_outlined,
                          size: 52,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(height: 12),
                        Text(context.t('abs.none')),
                      ],
                    ),
                  )
                : SellixCard(
                    padding: EdgeInsets.zero,
                    child: ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final row = _items[index];
                        final name = row['name']?.toString().trim() ?? '';
                        final code = row['code']?.toString().trim() ?? '';
                        final location =
                            row['locationName']?.toString().trim() ?? '';
                        final since =
                            row['firstAbsentDate']
                                ?.toString()
                                .split('T')
                                .first ??
                            '—';
                        final absentDays =
                            (row['absentDays'] as num?)?.toInt() ?? 0;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: AppThemeV2.warning.withValues(
                              alpha: 0.12,
                            ),
                            foregroundColor: AppThemeV2.warning,
                            child: const Icon(Icons.person_off_outlined),
                          ),
                          title: Text(
                            name.isEmpty ? '—' : name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            [
                              if (code.isNotEmpty) context.t('abs.code', {'code': code}),
                              if (location.isNotEmpty) location,
                              context.t('abs.since', {'since': since}),
                            ].join(' • '),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppThemeV2.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              context.t('abs.days', {'days': absentDays}),
                              style: const TextStyle(
                                color: AppThemeV2.warning,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          onTap: () => context.go(
                            AppRoutes.hrEmployeeDetail(
                              row['employeeId']?.toString() ?? '',
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
