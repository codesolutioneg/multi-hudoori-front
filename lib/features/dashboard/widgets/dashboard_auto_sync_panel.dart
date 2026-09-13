import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme_v2.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/v2_checkbox.dart';
import '../../../l10n/l10n_extension.dart';

/// HR manager control: enable/disable scheduled BioTime auto sync (12h cron).
class DashboardAutoSyncPanel extends StatefulWidget {
  const DashboardAutoSyncPanel({super.key});

  @override
  State<DashboardAutoSyncPanel> createState() => _DashboardAutoSyncPanelState();
}

class _DashboardAutoSyncPanelState extends State<DashboardAutoSyncPanel> {
  bool _loading = true;
  bool _saving = false;
  bool _enabled = true;
  int _intervalHours = 12;
  String? _lastEmployeeSync;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await api.configGet();
      if (!mounted) return;
      setState(() {
        _enabled = config['scheduledAutoSyncEnabled'] != false;
        _intervalHours = (config['employeeSyncIntervalHours'] as num?)?.toInt() ?? 12;
        final last = config['lastEmployeeSync'];
        _lastEmployeeSync = last == null || last == false ? null : last.toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.t('sync.loadError');
      });
    }
  }

  Future<void> _toggle(bool value) async {
    if (_saving) {
      appLog('AutoSyncPanel', 'ignored — already saving', 'requested=$value');
      return;
    }

    final previous = _enabled;
    appLog('AutoSyncPanel', 'start', {'requested': value, 'previous': previous});

    setState(() {
      _saving = true;
      _enabled = value;
    });

    try {
      appLog('AutoSyncPanel', 'api.configUpdate request', {'scheduledAutoSyncEnabled': value});
      final config = await api.configUpdate({'scheduledAutoSyncEnabled': value});
      final serverEnabled = config['scheduledAutoSyncEnabled'] != false;
      appLog('AutoSyncPanel', 'api.configUpdate response', {
        'raw': config['scheduledAutoSyncEnabled'],
        'parsed': serverEnabled,
        'matchesRequest': serverEnabled == value,
      });

      if (!mounted) return;
      setState(() {
        _enabled = serverEnabled;
        _saving = false;
      });
      appLog('AutoSyncPanel', 'done', {'uiEnabled': _enabled});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? context.t('sync.enabledSnack') : context.t('sync.disabledSnack')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, st) {
      appLog('AutoSyncPanel', 'error — reverting', {'error': e, 'stack': st});
      if (!mounted) return;
      setState(() {
        _enabled = previous;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animated: false,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: _loading
          ? const SizedBox(
              height: 56,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: _enabled
                      ? AppThemeV2.primarySoft.withValues(alpha: 0.45)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _saving ? null : () => _toggle(!_enabled),
                    borderRadius: BorderRadius.circular(12),
                    hoverColor: AppThemeV2.primarySoft.withValues(alpha: 0.3),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          V2Checkbox(
                            value: _enabled,
                            loading: _saving,
                          ),
                          const Gap(14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        context.t('sync.title'),
                                        style: AppThemeV2.title.copyWith(fontSize: 17),
                                      ),
                                    ),
                                    StatusBadge(
                                      label: _enabled ? context.t('sync.enabled') : context.t('sync.disabled'),
                                      tone: _enabled ? BadgeTone.online : BadgeTone.offline,
                                    ),
                                  ],
                                ),
                                const Gap(4),
                                Text(
                                  _enabled
                                      ? context.t('sync.enabledDesc', {'n': _intervalHours})
                                      : context.t('sync.disabledDesc'),
                                  style: AppThemeV2.caption,
                                ),
                                if (_lastEmployeeSync != null) ...[
                                  const Gap(4),
                                  Text(
                                    context.t('sync.lastEmployeeSync', {
                                      'time': _formatLastSync(_lastEmployeeSync!),
                                    }),
                                    style: AppThemeV2.caption.copyWith(fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: AppThemeV2.normal,
                  curve: Curves.easeOut,
                  child: _saving
                      ? const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: LinearProgressIndicator(
                            minHeight: 2,
                            color: AppThemeV2.primary,
                            backgroundColor: AppThemeV2.primarySoft,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                if (_error != null) ...[
                  const Gap(8),
                  Text(_error!, style: AppThemeV2.caption.copyWith(color: AppThemeV2.danger)),
                ],
                const Gap(10),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: () => context.go(AppRoutes.hrSettings),
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: Text(context.t('sync.advancedSettings')),
                  ),
                ),
              ],
            ),
    );
  }

  String _formatLastSync(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
