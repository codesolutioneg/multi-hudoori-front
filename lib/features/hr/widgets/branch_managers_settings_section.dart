import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/utils/api_error_message.dart';
import '../../../core/widgets/api_error_view.dart';
import '../../../core/widgets/sellix_card.dart';
import '../../../core/widgets/status_tag.dart';
import '../../../l10n/l10n_extension.dart';

/// «مدير الفرع» — who signs off advance requests for each branch.
///
/// A branch with nobody chosen falls back to the head the org chart derives, and
/// the row says so. A branch where neither exists is called out, because its
/// employees cannot raise an advance request at all until someone is set.
class BranchManagersSettingsSection extends StatefulWidget {
  const BranchManagersSettingsSection({super.key});

  @override
  State<BranchManagersSettingsSection> createState() =>
      _BranchManagersSettingsSectionState();
}

class _BranchManagersSettingsSectionState
    extends State<BranchManagersSettingsSection> {
  List<Map<String, dynamic>> _branches = const [];
  bool _loading = true;
  Object? _error;

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
      final rows = await api.branchManagersList();
      if (mounted) setState(() { _branches = rows; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e; });
    }
  }

  Future<void> _pick(Map<String, dynamic> branch) async {
    final picked = await showDialog<_PickResult>(
      context: context,
      builder: (_) => _BranchManagerPicker(
        locationId: branch['locationId'],
        locationName: branch['locationName']?.toString() ?? '',
      ),
    );
    if (picked == null) return;
    try {
      await api.branchManagerSet(
        locationId: branch['locationId'],
        employeeId: picked.employeeId,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(context, e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppDimensions.spaceLg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) return ApiErrorView(error: _error!, onRetry: _load);

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
          child: Text(
            context.t('branchMgr.hint'),
            style: theme.textTheme.bodySmall,
          ),
        ),
        ..._branches.map(_row),
      ],
    );
  }

  Widget _row(Map<String, dynamic> branch) {
    final theme = Theme.of(context);
    final manager = branch['manager'] as Map<String, dynamic>?;
    final explicit = manager?['source'] == 'explicit';
    final canApprove = manager?['canApprove'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
      child: SellixCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branch['locationName']?.toString() ?? '',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    manager == null
                        ? context.t('branchMgr.none')
                        : manager['employeeName']?.toString() ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: manager == null ? theme.colorScheme.error : null,
                    ),
                  ),
                  if (manager != null && !canApprove)
                    Text(
                      context.t('branchMgr.noLoginWarn'),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                ],
              ),
            ),
            if (manager != null)
              StatusTag(
                label: context.t(explicit ? 'branchMgr.explicit' : 'branchMgr.derived'),
                type: explicit ? StatusTagType.success : StatusTagType.info,
              ),
            const SizedBox(width: AppDimensions.spaceSm),
            TextButton(onPressed: () => _pick(branch), child: Text(context.t('branchMgr.change'))),
          ],
        ),
      ),
    );
  }
}

class _PickResult {
  const _PickResult(this.employeeId);

  /// Null clears the designation and hands the branch back to the org chart.
  final String? employeeId;
}

class _BranchManagerPicker extends StatefulWidget {
  const _BranchManagerPicker({required this.locationId, required this.locationName});

  final Object locationId;
  final String locationName;

  @override
  State<_BranchManagerPicker> createState() => _BranchManagerPickerState();
}

class _BranchManagerPickerState extends State<_BranchManagerPicker> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _employees = const [];
  Timer? _debounce;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String value) async {
    setState(() => _loading = true);
    try {
      final page = await api.employeesList(
        locationId: widget.locationId,
        search: value.trim().isEmpty ? null : value.trim(),
        limit: 30,
      );
      if (mounted) setState(() { _employees = page.items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('branchMgr.pickTitle', {'name': widget.locationName})),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: _onChanged,
              decoration: InputDecoration(
                labelText: context.t('branchMgr.search'),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            ListTile(
              dense: true,
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text(context.t('branchMgr.fromOrgChart')),
              onTap: () => Navigator.pop(context, const _PickResult(null)),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _employees.length,
                      itemBuilder: (_, i) {
                        final e = _employees[i];
                        final hasLogin = e['hasUser'] == true || e['userId'] != null;
                        return ListTile(
                          dense: true,
                          title: Text(e['name']?.toString() ?? ''),
                          subtitle: Text(
                            [
                              e['code']?.toString() ?? '',
                              if (!hasLogin) context.t('branchMgr.noLogin'),
                            ].where((s) => s.isNotEmpty).join(' • '),
                          ),
                          onTap: () => Navigator.pop(
                            context,
                            _PickResult(e['id']?.toString()),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('common.cancel')),
        ),
      ],
    );
  }
}
