import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/utils/department_name.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/l10n_extension.dart';

class HealthCertificatesPage extends StatefulWidget {
  const HealthCertificatesPage({super.key});

  @override
  State<HealthCertificatesPage> createState() => _HealthCertificatesPageState();
}

class _HealthCertificatesPageState extends State<HealthCertificatesPage> {
  List<Map<String, dynamic>> _alerts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final alerts = await api.healthCertificateAlerts();
      if (mounted) setState(() { _alerts = alerts; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Color _statusColor(Map<String, dynamic> row) {
    if (row['expired'] == true) return AppThemeV2.danger;
    final days = (row['daysRemaining'] as num?)?.toInt() ?? 0;
    if (days <= 7) return AppThemeV2.warning;
    return AppThemeV2.info;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.t('health.title'),
            subtitle: context.t('health.subtitleAlerts'),
            icon: Icons.health_and_safety_outlined,
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.dashboard);
              }
            },
            actions: [
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppThemeV2.primary))
                : _alerts.isEmpty
                    ? SellixCard(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified_outlined, size: 48, color: AppColors.textSecondary),
                            const SizedBox(height: 12),
                            Text(context.t('health.empty')),
                          ],
                        ),
                      )
                    : SellixCard(
                        padding: EdgeInsets.zero,
                        child: ListView.separated(
                          itemCount: _alerts.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final row = _alerts[index];
                            final color = _statusColor(row);
                            return ListTile(
                              onTap: () => context.go(AppRoutes.hrEmployeeDetail(row['id'])),
                              title: Text(
                                row['displayName']?.toString() ?? row['name']?.toString() ?? '—',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                [
                                  if (employeeDepartmentName(row, context).isNotEmpty) employeeDepartmentName(row, context),
                                  context.t('health.expiry', {'date': row['healthCertificateExpiryDate'] ?? '—'}),
                                ].join(' • '),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  row['statusLabel']?.toString() ?? '—',
                                  style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
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
