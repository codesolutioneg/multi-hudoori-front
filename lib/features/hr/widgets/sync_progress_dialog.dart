import 'package:flutter/material.dart';
import '../../../l10n/l10n_extension.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/skeleton_box.dart';

class SyncDialogState {
  const SyncDialogState({
    this.title,
    this.message,
    this.progress = 0,
    this.employees,
    this.departments,
    this.devices,
    this.transactions,
    this.status,
    this.done = false,
    this.failed = false,
  });

  final String? title;
  final String? message;
  final int progress;
  final int? employees;
  final int? departments;
  final int? devices;
  final int? transactions;
  final String? status;
  final bool done;
  final bool failed;

  SyncDialogState copyWith({
    String? title,
    String? message,
    int? progress,
    int? employees,
    int? departments,
    int? devices,
    int? transactions,
    String? status,
    bool? done,
    bool? failed,
  }) {
    return SyncDialogState(
      title: title ?? this.title,
      message: message ?? this.message,
      progress: progress ?? this.progress,
      employees: employees ?? this.employees,
      departments: departments ?? this.departments,
      devices: devices ?? this.devices,
      transactions: transactions ?? this.transactions,
      status: status ?? this.status,
      done: done ?? this.done,
      failed: failed ?? this.failed,
    );
  }
}

class SyncProgressDialog extends StatelessWidget {
  const SyncProgressDialog({super.key, required this.stateListenable});

  final ValueNotifier<SyncDialogState> stateListenable;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: ValueListenableBuilder<SyncDialogState>(
            valueListenable: stateListenable,
            builder: (context, state, _) {
              final showCounts = state.employees != null;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        state.failed
                            ? Icons.error_outline
                            : state.done
                                ? Icons.check_circle_outline
                                : Icons.cloud_sync_outlined,
                        color: state.failed
                            ? AppColors.danger
                            : state.done
                                ? AppColors.success
                                : AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state.title ?? context.t('sync.title'),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.message ?? context.t('sync.connecting'),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  if (!state.done && !state.failed) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: state.progress > 0 ? (state.progress / 100).clamp(0.05, 1.0) : null,
                        minHeight: 6,
                        backgroundColor: AppColors.border,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (showCounts) ...[
                      _CountRow(label: context.t('sync.employees'), value: state.employees),
                      _CountRow(label: context.t('sync.departments'), value: state.departments),
                      _CountRow(label: context.t('sync.devices'), value: state.devices),
                      _CountRow(label: context.t('sync.punches'), value: state.transactions),
                    ] else ...[
                      const SkeletonListTile(),
                      const SkeletonListTile(),
                      const SkeletonListTile(),
                    ],
                  ],
                  if (state.done || state.failed) ...[
                    const SizedBox(height: 12),
                    if (showCounts)
                      Text(
                        context.t('sync.counts', {
          'emp': state.employees,
          'dep': state.departments,
          'dev': state.devices,
          'tx': state.transactions,
        }),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: value != null
                ? Text('$value', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))
                : const SkeletonBox(height: 12),
          ),
        ],
      ),
    );
  }
}
