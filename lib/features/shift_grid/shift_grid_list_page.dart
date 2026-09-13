import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../core/config/api_config.dart';
import '../../core/di/injection.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/utils/entity_id.dart';
import '../../core/utils/file_download.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/list_picker_field.dart';
import '../../core/widgets/searchable_select_field.dart';
import 'shift_grid_merge_dialog.dart';
import '../../core/widgets/status_badge.dart';
import '../auth/auth_cubit.dart';
import '../../l10n/l10n_extension.dart';
import 'shift_grid_helpers.dart';

class ShiftGridListPage extends StatefulWidget {
  const ShiftGridListPage({super.key});

  @override
  State<ShiftGridListPage> createState() => _ShiftGridListPageState();
}

class _ShiftGridListPageState extends State<ShiftGridListPage> {
  static const _pageSize = 100;

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _locations = [];
  /// Empty set = show all locations.
  final Set<String> _filterLocationIds = {};
  final Set<String> _selectedGridIds = {};
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _exporting = false;
  int _offset = 0;
  final ScrollController _scrollCtrl = ScrollController();
  /// Period keys currently expanded in the grouped list (newest open by default).
  final Set<String> _expandedPeriods = {};
  bool _didInitExpanded = false;

  List<Map<String, dynamic>> get _visibleItems {
    if (_filterLocationIds.isEmpty) return _items;
    final nameById = <String, String>{
      for (final l in _locations)
        if ((EntityId.parse(l['id']) ?? '').isNotEmpty)
          EntityId.parse(l['id'])!: (l['name']?.toString() ?? ''),
    };
    final selectedNames = {
      for (final id in _filterLocationIds)
        if ((nameById[id] ?? '').isNotEmpty) nameById[id]!,
    };
    return _items.where((g) {
      final id = EntityId.parse(g['locationId']) ?? '';
      if (id.isNotEmpty) return _filterLocationIds.contains(id);
      final name =
          g['locationName']?.toString() ?? g['gridLocation']?.toString() ?? '';
      return name.isNotEmpty && selectedNames.contains(name);
    }).toList();
  }

  String get _locationFilterSummary {
    if (_filterLocationIds.isEmpty) return tr('shiftGrid.allLocations');
    final names = <String>[];
    for (final l in _locations) {
      final id = EntityId.parse(l['id']) ?? '';
      if (_filterLocationIds.contains(id)) {
        names.add(l['name']?.toString() ?? id);
      }
    }
    if (names.isEmpty) return tr('shiftGrid.allLocations');
    if (names.length <= 2) return names.join(tr('common.listSeparator'));
    return '${names.take(2).join(tr('common.listSeparator'))} +${names.length - 2}';
  }

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadLocations();
    _load(reset: true);
  }

  Future<void> _loadLocations() async {
    try {
      final locations = await api.locationsList();
      if (!mounted) return;
      locations.sort(
        (a, b) => (a['name']?.toString() ?? '').compareTo(
          b['name']?.toString() ?? '',
        ),
      );
      setState(() => _locations = locations);
    } catch (_) {
      // Filter stays hidden / empty if locations fail to load.
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load({bool reset = true}) async {
    if (reset) setState(() => _loading = true);
    try {
      final page = await api.shiftGridListPage(limit: _pageSize, offset: 0);
      if (mounted) {
        setState(() {
          _items = page.items;
          _offset = page.items.length;
          _hasMore = page.hasMore;
          _loading = false;
          if (reset) {
            _didInitExpanded = false;
            _expandedPeriods.clear();
            _selectedGridIds.clear();
          }
        });
      }
      // Period expand/list should see every grid — keep paging until done.
      await _ensureAllLoaded();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _snack(e.toString());
    }
  }

  /// Drain remaining pages so period groups aren't truncated by pagination.
  Future<void> _ensureAllLoaded() async {
    while (mounted && _hasMore && !_loadingMore) {
      await _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await api.shiftGridListPage(
        limit: _pageSize,
        offset: _offset,
      );
      if (mounted) {
        setState(() {
          _items.addAll(page.items);
          _offset += page.items.length;
          _hasMore = page.hasMore;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMore = false);
      _snack(e.toString());
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openMerge() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const ShiftGridMergeDialog(),
    );
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.t('grid.mergeDone'))));
    await _load(reset: true);
  }

  Future<void> _openCreate() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateShiftGridDialog(),
    );
    if (created == true) _load(reset: true);
  }

  Future<void> _openCreateAllLocations() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateAllLocationsGridDialog(),
    );
    if (created == true) _load(reset: true);
  }

  /// Load every page, then export selected grids.
  Future<void> _exportSelected({required bool byDepartment}) async {
    if (_exporting) return;
    final gridIds = _selectedGridIds
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (gridIds.isEmpty) {
      _snack(context.t('grid.exportSelectFirst'));
      return;
    }

    setState(() => _exporting = true);
    final navigator = Navigator.of(context, rootNavigator: true);
    var dialogShown = false;
    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    byDepartment
                        ? context.t('grid.exportDepartmentsBulkBusy')
                        : context.t('grid.exportFullSelectedBusy'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      dialogShown = true;

      final r = byDepartment
          ? await api.shiftGridExportXlsxByDepartmentBulk(gridIds: gridIds)
          : await api.shiftGridExportXlsxBulk(gridIds: gridIds);

      final base64 = r['base64']?.toString() ?? r['file']?.toString() ?? '';
      final filename = r['filename']?.toString() ??
          (byDepartment
              ? 'shift_grids_by_department.zip'
              : 'shift_grids.zip');
      if (base64.isEmpty) throw Exception(context.t('common.emptyFile'));
      downloadBase64File(
        base64,
        filename,
        r['mimeType']?.toString() ?? 'application/zip',
      );

      final files = (r['fileCount'] as num?)?.toInt() ?? 0;
      final grids = (r['gridCount'] as num?)?.toInt() ?? gridIds.length;
      if (!mounted) return;
      _snack(
        context
            .t(
              byDepartment
                  ? 'grid.exportDepartmentsBulkDone'
                  : 'grid.exportFullSelectedDone',
            )
            .replaceAll('{files}', '$files')
            .replaceAll('{grids}', '$grids'),
      );
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (dialogShown && mounted && navigator.canPop()) {
        navigator.pop();
      }
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _toggleGridSelected(String id, bool? selected) {
    if (id.isEmpty) return;
    setState(() {
      if (selected == true) {
        _selectedGridIds.add(id);
      } else {
        _selectedGridIds.remove(id);
      }
    });
  }

  void _selectPeriodGrids(List<Map<String, dynamic>> grids, {required bool select}) {
    setState(() {
      for (final g in grids) {
        final id = g['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        if (select) {
          _selectedGridIds.add(id);
        } else {
          _selectedGridIds.remove(id);
        }
      }
    });
  }

  BadgeTone _stateTone(String state) {
    if (state == 'confirmed') return BadgeTone.online;
    if (state == 'grid') return BadgeTone.info;
    return BadgeTone.warning;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1360),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildLocationFilter(),
              const SizedBox(height: 24),
              Skeletonizer(
                enabled: _loading,
                child: _loading
                    ? _buildPlaceholderList()
                    : _visibleItems.isEmpty
                    ? _buildEmptyState()
                    : _buildGroupedList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final canCreate = context.watch<AuthCubit>().state.roles.isBranchStaff;
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppThemeV2.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppThemeV2.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const Gap(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.t('grid.title'), style: AppThemeV2.headline),
                    const Gap(4),
                    Text(context.t('grid.subtitle'), style: AppThemeV2.caption),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loading ? null : () => _load(reset: true),
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppThemeV2.textMuted,
                ),
                tooltip: context.t('common.refresh'),
              ),
              if (canCreate)
                IconButton(
                  onPressed: _loading ? null : _openMerge,
                  icon: const Icon(
                    Icons.merge_type_rounded,
                    color: AppThemeV2.textMuted,
                  ),
                  tooltip: context.t('grid.mergeAction'),
                ),
              if (canCreate) ...[
                const Gap(8),
                FilledButton.icon(
                  onPressed: _openCreate,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppThemeV2.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(context.t('grid.new')),
                ),
                const Gap(8),
                OutlinedButton.icon(
                  onPressed: _openCreateAllLocations,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppThemeV2.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.account_tree_outlined, size: 18),
                  label: Text(context.t('grid.newAllLocations')),
                ),
              ],
            ],
          ),
          const Gap(14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: (_loading || _exporting || _selectedGridIds.isEmpty)
                    ? null
                    : () => _exportSelected(byDepartment: false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppThemeV2.primary,
                  side: BorderSide(
                    color: _selectedGridIds.isEmpty
                        ? AppThemeV2.border
                        : AppThemeV2.primary,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.table_view_outlined, size: 18),
                label: Text(context.t('grid.exportFullSelected')),
              ),
              OutlinedButton.icon(
                onPressed: (_loading || _exporting || _selectedGridIds.isEmpty)
                    ? null
                    : () => _exportSelected(byDepartment: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppThemeV2.primary,
                  side: BorderSide(
                    color: _selectedGridIds.isEmpty
                        ? AppThemeV2.border
                        : AppThemeV2.primary,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.folder_zip_outlined, size: 18),
                label: Text(context.t('grid.exportDepartmentsBulk')),
              ),
              if (_selectedGridIds.isNotEmpty)
                TextButton(
                  onPressed: _exporting
                      ? null
                      : () => setState(() => _selectedGridIds.clear()),
                  child: Text(
                    context
                        .t('grid.selectedCount')
                        .replaceAll('{n}', '${_selectedGridIds.length}'),
                  ),
                )
              else
                Text(
                  context.t('grid.exportSelectFirst'),
                  style: AppThemeV2.caption,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationFilter() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _pickLocations,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: context.t('common.locationBranch'),
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
              child: Text(
                _locationFilterSummary,
                style: TextStyle(
                  fontSize: 16,
                  color: _filterLocationIds.isEmpty
                      ? Theme.of(context).hintColor
                      : null,
                ),
              ),
            ),
          ),
          if (_filterLocationIds.isNotEmpty) ...[
            const Gap(10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final l in _locations)
                  if (_filterLocationIds.contains(EntityId.parse(l['id']) ?? ''))
                    InputChip(
                      label: Text(
                        l['name']?.toString() ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onDeleted: () {
                        setState(() {
                          _filterLocationIds.remove(
                            EntityId.parse(l['id']) ?? '',
                          );
                          _didInitExpanded = false;
                          _expandedPeriods.clear();
                        });
                      },
                    ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filterLocationIds.clear();
                      _didInitExpanded = false;
                      _expandedPeriods.clear();
                    });
                  },
                  child: Text(context.t('common.clearAll')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickLocations() async {
    final draft = Set<String>.from(_filterLocationIds);
    final confirmed = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(context.t('shiftGrid.pickLocationsTitle')),
              content: SizedBox(
                width: 360,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CheckboxListTile(
                        dense: true,
                        value: draft.isEmpty,
                        title: Text(context.t('shiftGrid.allLocations')),
                        onChanged: (v) {
                          setLocal(() {
                            if (v == true) draft.clear();
                          });
                        },
                      ),
                      const Divider(height: 1),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _locations.length,
                          itemBuilder: (_, i) {
                            final l = _locations[i];
                            final id = EntityId.parse(l['id']) ?? '';
                            if (id.isEmpty) return const SizedBox.shrink();
                            final selected = draft.contains(id);
                            return CheckboxListTile(
                              dense: true,
                              value: selected,
                              title: Text(l['name']?.toString() ?? id),
                              onChanged: (v) {
                                setLocal(() {
                                  if (v == true) {
                                    draft.add(id);
                                  } else {
                                    draft.remove(id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(context.t('common.cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, draft),
                  child: Text(
                    draft.isEmpty
                        ? context.t('shiftGrid.showAll')
                        : context.t('shiftGrid.applyCount', {'count': draft.length}),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed == null || !mounted) return;
    setState(() {
      _filterLocationIds
        ..clear()
        ..addAll(confirmed);
      if (_filterLocationIds.isNotEmpty) {
        _selectedGridIds.removeWhere((id) {
          Map<String, dynamic>? g;
          for (final item in _items) {
            if (item['id']?.toString() == id) {
              g = item;
              break;
            }
          }
          if (g == null) return true;
          final locId = EntityId.parse(g['locationId']) ?? '';
          return locId.isNotEmpty && !_filterLocationIds.contains(locId);
        });
      }
      _didInitExpanded = false;
      _expandedPeriods.clear();
    });
  }

  Widget _buildPlaceholderList() {
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          GlassCard(
            animated: false,
            child: Column(
              children: List.generate(
                2,
                (_) => const ListTile(title: Text('Loading...')),
              ),
            ),
          ),
          const Gap(16),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    final canCreate = context.watch<AuthCubit>().state.roles.isBranchStaff;
    return GlassCard(
      animated: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppThemeV2.primarySoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.table_chart_outlined,
                size: 36,
                color: AppThemeV2.primary,
              ),
            ),
            const Gap(16),
            Text(context.t('grid.empty'), style: AppThemeV2.title),
            const Gap(8),
            Text(context.t('grid.emptyHint'), style: AppThemeV2.body),
            const Gap(20),
            if (canCreate)
              FilledButton.icon(
                onPressed: _openCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: AppThemeV2.primary,
                ),
                icon: const Icon(Icons.add_rounded),
                label: Text(context.t('grid.create')),
              ),
              const Gap(8),
              OutlinedButton.icon(
                onPressed: _openCreateAllLocations,
                icon: const Icon(Icons.account_tree_outlined),
                label: Text(context.t('grid.newAllLocations')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedList() {
    final groups = groupShiftGridsByPeriod(_visibleItems);
    if (!_didInitExpanded && groups.isNotEmpty) {
      // Expand the newest period on first load (after this frame).
      final firstKey = groups.first.key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didInitExpanded) return;
        setState(() {
          _expandedPeriods.add(firstKey);
          _didInitExpanded = true;
        });
      });
    }
    return Column(
      children: [
        for (var gi = 0; gi < groups.length; gi++) ...[
          _ExpandablePeriodSection(
            label: groups[gi].key,
            count: groups[gi].value.length,
            expanded: _expandedPeriods.contains(groups[gi].key),
            selectedInPeriod: groups[gi].value
                .where(
                  (g) => _selectedGridIds.contains(g['id']?.toString() ?? ''),
                )
                .length,
            onSelectAll: () =>
                _selectPeriodGrids(groups[gi].value, select: true),
            onClearPeriod: () =>
                _selectPeriodGrids(groups[gi].value, select: false),
            onToggle: () async {
              final key = groups[gi].key;
              final opening = !_expandedPeriods.contains(key);
              setState(() {
                if (opening) {
                  _expandedPeriods.add(key);
                } else {
                  _expandedPeriods.remove(key);
                }
              });
              if (opening) await _ensureAllLoaded();
            },
            child: GlassCard(
              animated: false,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < groups[gi].value.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: AppThemeV2.border.withValues(alpha: 0.6),
                      ),
                    _GridListTile(
                      item: groups[gi].value[i],
                      stateTone: _stateTone(
                        groups[gi].value[i]['state']?.toString() ?? '',
                      ),
                      index: i,
                      selected: _selectedGridIds.contains(
                        groups[gi].value[i]['id']?.toString() ?? '',
                      ),
                      onSelectedChanged: (v) {
                        final id =
                            groups[gi].value[i]['id']?.toString() ?? '';
                        _toggleGridSelected(id, v);
                      },
                      onTap: () {
                        final id = groups[gi].value[i]['id'];
                        if (id != null) {
                          context.go('${AppRoutes.hrShiftGrid}/$id');
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          )
              .animate(delay: Duration(milliseconds: gi * 80))
              .fadeIn(duration: 300.ms)
              .slideX(begin: 0.05, end: 0),
          const Gap(16),
        ],
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppThemeV2.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class _ExpandablePeriodSection extends StatelessWidget {
  const _ExpandablePeriodSection({
    required this.label,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.selectedInPeriod = 0,
    this.onSelectAll,
    this.onClearPeriod,
  });

  final String label;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  final int selectedInPeriod;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClearPeriod;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppThemeV2.primarySoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppThemeV2.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      size: 22,
                      color: AppThemeV2.primary,
                    ),
                  ),
                  const Gap(6),
                  const Icon(
                    Icons.date_range_rounded,
                    size: 18,
                    color: AppThemeV2.primary,
                  ),
                  const Gap(10),
                  Expanded(
                    child: Text(
                      label,
                      style: AppThemeV2.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppThemeV2.primary,
                      ),
                    ),
                  ),
                  if (onSelectAll != null) ...[
                    TextButton(
                      onPressed: onSelectAll,
                      child: Text(context.t('grid.selectAllPeriod')),
                    ),
                    if (selectedInPeriod > 0 && onClearPeriod != null)
                      TextButton(
                        onPressed: onClearPeriod,
                        child: Text(context.t('grid.clearSelection')),
                      ),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppThemeV2.border),
                    ),
                    child: Text(
                      selectedInPeriod > 0
                          ? context.t('shiftGrid.gridsCountSelected', {'count': count, 'selected': selectedInPeriod})
                          : context.t('shiftGrid.gridsCount', {'count': count}),
                      style: AppThemeV2.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppThemeV2.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: child,
          ),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }
}

class _GridListTile extends StatelessWidget {
  const _GridListTile({
    required this.item,
    required this.stateTone,
    required this.index,
    required this.onTap,
    required this.selected,
    required this.onSelectedChanged,
  });

  final Map<String, dynamic> item;
  final BadgeTone stateTone;
  final int index;
  final VoidCallback onTap;
  final bool selected;
  final ValueChanged<bool?> onSelectedChanged;

  @override
  Widget build(BuildContext context) {
    final device = item['deviceName']?.toString() ?? '';
    final location =
        item['locationName']?.toString() ??
        item['gridLocation']?.toString() ??
        '';
    final employees = item['employeeCount'] ?? item['lineCount'] ?? 0;
    final days = item['daysCount'] ?? 0;
    final name = item['name']?.toString() ?? tr('shiftGrid.gridWord');

    final meta = [
      if (location.isNotEmpty) location,
      if (device.isNotEmpty) device,
      tr('shiftGrid.employeesCount', {'count': employees}),
      if (days != 0) tr('shiftGrid.daysCount', {'count': days}),
    ];

    return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppThemeV2.cardRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Checkbox(
                    value: selected,
                    onChanged: onSelectedChanged,
                  ),
                  const Gap(4),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppThemeV2.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppThemeV2.border),
                    ),
                    child: const Icon(
                      Icons.calendar_month_outlined,
                      size: 22,
                      color: AppThemeV2.primary,
                    ),
                  ),
                  const Gap(14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: AppThemeV2.title.copyWith(fontSize: 15),
                              ),
                            ),
                            if (item['hasAssignedShift'] == true) ...[
                              const Gap(8),
                              StatusBadge(
                                label: context.t('grid.modifiedBadge'),
                                tone: BadgeTone.warning,
                              ),
                            ],
                          ],
                        ),
                        if (meta.isNotEmpty) ...[
                          const Gap(4),
                          Text(
                            meta.join('  ·  '),
                            style: AppThemeV2.caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Gap(12),
                  StatusBadge(
                    label: stateLabel(item['state']?.toString() ?? ''),
                    tone: stateTone,
                  ),
                  if (item['isMergedGrid'] == true) ...[
                    const Gap(6),
                    StatusBadge(
                      label: context.t('grid.mergeBadgeMonthly'),
                      tone: BadgeTone.info,
                    ),
                  ] else if (item['mergedIntoGridId'] != null &&
                      '${item['mergedIntoGridId']}'.isNotEmpty) ...[
                    const Gap(6),
                    StatusBadge(
                      label: context.t('grid.mergeBadgeAdded'),
                      tone: BadgeTone.online,
                    ),
                  ],
                  const Gap(4),
                  const Icon(
                    Icons.chevron_right,
                    color: AppThemeV2.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        )
        .animate(delay: Duration(milliseconds: index * 40))
        .fadeIn(duration: 250.ms);
  }
}

class _CreateShiftGridDialog extends StatefulWidget {
  const _CreateShiftGridDialog();

  @override
  State<_CreateShiftGridDialog> createState() => _CreateShiftGridDialogState();
}

enum _ShiftGridSelectionMode { device, location }

class _CreateShiftGridDialogState extends State<_CreateShiftGridDialog> {
  _ShiftGridSelectionMode _selectionMode = _ShiftGridSelectionMode.location;
  String? _locationId;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now().add(const Duration(days: 6));
  String? _deviceId;
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _employees = [];
  final Set<String> _selectedEmployeeIds = {};
  final TextEditingController _employeeSearchCtrl = TextEditingController();
  bool _loading = true;
  bool _loadingEmployees = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _employeeSearchCtrl.addListener(() => setState(() {}));
    _loadOptions();
  }

  @override
  void dispose() {
    _employeeSearchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    final q = _employeeSearchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _employees;
    return _employees.where((e) => _employeeMatchesSearch(e, q)).toList();
  }

  bool _employeeMatchesSearch(Map<String, dynamic> e, String q) {
    final parts = <String?>[
      e['displayName']?.toString(),
      e['name']?.toString(),
      e['code']?.toString(),
      e['locationName']?.toString(),
      e['location']?.toString(),
      e['nationalIdConfirm']?.toString(),
      e['identificationId']?.toString(),
      e['workPhone']?.toString(),
      e['mobilePhone']?.toString(),
    ];
    final haystack = parts
        .where((s) => s != null && s.isNotEmpty)
        .join(' ')
        .toLowerCase();
    return haystack.contains(q);
  }

  void _selectAllVisibleEmployees() {
    setState(() {
      for (final e in _filteredEmployees) {
        final id = EntityId.parse(e['id']);
        if (id != null) _selectedEmployeeIds.add(id);
      }
    });
  }

  Future<void> _loadOptions() async {
    try {
      if (ApiConfig.showBiotimeDeviceUi) {
        final devices = await api.devicesList();
        if (mounted) _devices = devices;
      }
      final locations = await api.locationsList();
      final auth = context.read<AuthCubit>().state;
      final branchLocationId = auth.user?.locationId;
      if (mounted) {
        setState(() {
          _locations = locations;
          _selectionMode = _ShiftGridSelectionMode.location;
          if (auth.roles.isBranchManager &&
              branchLocationId != null &&
              branchLocationId.isNotEmpty) {
            _locationId = branchLocationId;
          } else if (locations.isNotEmpty) {
            _locationId = EntityId.parse(locations.first['id']);
          }
          _loading = false;
        });
        _loadEmployees();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setSelectionMode(_ShiftGridSelectionMode mode) {
    if (_selectionMode == mode) return;
    setState(() {
      _selectionMode = mode;
      if (mode == _ShiftGridSelectionMode.device) {
        _locationId = null;
        if (_devices.isNotEmpty) {
          _deviceId = EntityId.parse(_devices.first['id']);
        }
      } else {
        _deviceId = null;
        if (_locations.isNotEmpty) {
          _locationId = EntityId.parse(_locations.first['id']);
        }
      }
    });
    _loadEmployees();
  }

  Future<List<Map<String, dynamic>>> _loadAllEmployees({
    Object? locationId,
  }) async {
    final all = <Map<String, dynamic>>[];
    var offset = 0;
    const limit = 100;
    while (true) {
      final page = await api.employeesList(
        locationId: locationId,
        limit: limit,
        offset: offset,
      );
      all.addAll(page.items);
      if (!page.hasMore) break;
      offset += limit;
    }
    return all;
  }

  Future<void> _loadEmployees() async {
    if (_selectionMode == _ShiftGridSelectionMode.location) {
      if (_locationId == null) {
        setState(() {
          _employees = [];
          _selectedEmployeeIds.clear();
          _employeeSearchCtrl.clear();
        });
        return;
      }
      setState(() => _loadingEmployees = true);
      try {
        final employees = await _loadAllEmployees(locationId: _locationId);
        if (mounted) {
          setState(() {
            _employees = employees;
            _loadingEmployees = false;
            _employeeSearchCtrl.clear();
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loadingEmployees = false);
      }
      return;
    }

    if (_deviceId == null) {
      setState(() {
        _employees = [];
        _selectedEmployeeIds.clear();
        _employeeSearchCtrl.clear();
      });
      return;
    }
    setState(() => _loadingEmployees = true);
    try {
      final page = await api.employeesList(
        biotimeDeviceId: _deviceId,
        limit: 500,
      );
      if (mounted) {
        setState(() {
          _employees = page.items;
          _selectedEmployeeIds
            ..clear()
            ..addAll(
              page.items
                  .map((e) => EntityId.parse(e['id']))
                  .whereType<String>(),
            );
          _loadingEmployees = false;
          _employeeSearchCtrl.clear();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingEmployees = false);
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from.add(const Duration(days: 6));
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_selectionMode == _ShiftGridSelectionMode.device) {
      if (_deviceId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t('shiftGrid.pickDevice'))));
        return;
      }
    } else {
      if (_locationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('shiftGrid.pickLocationFirst'))),
        );
        return;
      }
    }
    if (_selectedEmployeeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('shiftGrid.pickEmployee'))),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await api.shiftGridCreate(
        dateFrom: _fmt(_from),
        dateTo: _fmt(_to),
        deviceId: _selectionMode == _ShiftGridSelectionMode.device
            ? _deviceId
            : null,
        locationId: _selectionMode == _ShiftGridSelectionMode.location
            ? _locationId
            : null,
        selectionMethod: _selectionMode == _ShiftGridSelectionMode.device
            ? 'device'
            : 'location',
        employeeIds: _selectedEmployeeIds.isNotEmpty
            ? _selectedEmployeeIds.toList()
            : null,
        generate: false,
      );
      if (!mounted) return;
      final grid = result['grid'] as Map<String, dynamic>?;
      final id = grid?['id'];
      Navigator.pop(context, true);
      if (id != null) context.go('${AppRoutes.hrShiftGrid}/$id');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationLocked = context
        .watch<AuthCubit>()
        .state
        .roles
        .isBranchManager;
    return AlertDialog(
      backgroundColor: AppThemeV2.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppThemeV2.cardRadius),
        side: const BorderSide(color: AppThemeV2.border),
      ),
      title: Text(context.t('shiftGrid.newGrid'), style: AppThemeV2.title),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppThemeV2.primary),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (ApiConfig.showBiotimeDeviceUi) ...[
                      Text(
                        context.t('shiftGrid.employeeSource'),
                        style: AppThemeV2.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Gap(8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<_ShiftGridSelectionMode>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                context.t('shiftGrid.device'),
                                style: AppThemeV2.body.copyWith(fontSize: 14),
                              ),
                              value: _ShiftGridSelectionMode.device,
                              groupValue: _selectionMode,
                              onChanged: (v) {
                                if (v != null) _setSelectionMode(v);
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<_ShiftGridSelectionMode>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                context.t('shiftGrid.location'),
                                style: AppThemeV2.body.copyWith(fontSize: 14),
                              ),
                              value: _ShiftGridSelectionMode.location,
                              groupValue: _selectionMode,
                              onChanged: (v) {
                                if (v != null) _setSelectionMode(v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const Gap(8),
                    ] else
                      Text(
                        context.t('common.locationBranch'),
                        style: AppThemeV2.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const Gap(8),
                    if (ApiConfig.showBiotimeDeviceUi &&
                        _selectionMode == _ShiftGridSelectionMode.device) ...[
                      ListPickerField<String>(
                        label: context.t('shiftGrid.device'),
                        value: _deviceId,
                        options: [
                          for (final d in _devices)
                            (
                              value: EntityId.parse(d['id']) ?? '',
                              label: d['name']?.toString() ?? '',
                            ),
                        ],
                        onChanged: (v) {
                          setState(() => _deviceId = v);
                          _loadEmployees();
                        },
                      ),
                      if (_devices.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            context.t('shiftGrid.noDevices'),
                            style: AppThemeV2.caption,
                          ),
                        ),
                    ] else ...[
                      SearchableSelectField<String>(
                        label: context.t('common.locationBranch'),
                        allowNull: false,
                        value: _locationId,
                        options: [
                          for (final l in _locations)
                            SearchableSelectOption(
                              value: EntityId.parse(l['id']) ?? '',
                              label: l['name']?.toString() ?? '',
                            ),
                        ],
                        onChanged: locationLocked
                            ? (_) {}
                            : (v) {
                                setState(() {
                                  _locationId = v;
                                  _employees = [];
                                  _selectedEmployeeIds.clear();
                                  _employeeSearchCtrl.clear();
                                });
                                _loadEmployees();
                              },
                      ),
                      if (_locations.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            context.t('shiftGrid.addLocationsHint'),
                            style: AppThemeV2.caption,
                          ),
                        ),
                    ],
                    const Gap(12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pickDate(true),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppThemeV2.primary,
                              side: const BorderSide(color: AppThemeV2.border),
                            ),
                            child: Text(context.t('common.fromLabel', {'date': _fmt(_from)})),
                          ),
                        ),
                        const Gap(8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pickDate(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppThemeV2.primary,
                              side: const BorderSide(color: AppThemeV2.border),
                            ),
                            child: Text(context.t('common.toLabel', {'date': _fmt(_to)})),
                          ),
                        ),
                      ],
                    ),
                    const Gap(12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectionMode == _ShiftGridSelectionMode.device
                                ? context.t('shiftGrid.deviceEmployees')
                                : context.t('shiftGrid.allEmployees'),
                            style: AppThemeV2.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _employees.isEmpty
                              ? null
                              : _selectAllVisibleEmployees,
                          child: Text(
                            _employeeSearchCtrl.text.trim().isEmpty
                                ? context.t('common.all')
                                : context.t('shiftGrid.allShown'),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _selectedEmployeeIds.clear()),
                          child: Text(context.t('common.none')),
                        ),
                      ],
                    ),
                    if (_employees.isNotEmpty) ...[
                      const Gap(8),
                      TextField(
                        controller: _employeeSearchCtrl,
                        decoration: InputDecoration(
                          hintText: context.t('grid.searchHint'),
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _employeeSearchCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _employeeSearchCtrl.clear();
                                    FocusScope.of(context).unfocus();
                                  },
                                ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppThemeV2.border,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppThemeV2.border,
                            ),
                          ),
                        ),
                      ),
                      if (_employeeSearchCtrl.text.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            context.t('shiftGrid.ofTotal', {'shown': _filteredEmployees.length, 'total': _employees.length}),
                            style: AppThemeV2.caption,
                          ),
                        ),
                    ],
                    if (_loadingEmployees)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppThemeV2.primary,
                          ),
                        ),
                      )
                    else if (_employees.isEmpty)
                      Text(
                        _selectionMode == _ShiftGridSelectionMode.device
                            ? context.t('shiftGrid.noDeviceEmployees')
                            : context.t('shiftGrid.noEmployees'),
                        style: AppThemeV2.caption,
                      )
                    else if (_filteredEmployees.isEmpty)
                      Text(context.t('shiftGrid.noSearchResults'), style: AppThemeV2.caption)
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _filteredEmployees.length,
                          itemBuilder: (_, i) {
                            final e = _filteredEmployees[i];
                            return CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: _selectedEmployeeIds.contains(
                                EntityId.parse(e['id']),
                              ),
                              title: Text(
                                e['displayName']?.toString() ??
                                    e['name']?.toString() ??
                                    '',
                              ),
                              subtitle: Text(
                                [
                                      e['code']?.toString(),
                                      if (_selectionMode ==
                                          _ShiftGridSelectionMode.location)
                                        e['locationName']?.toString() ??
                                            e['location']?.toString(),
                                    ]
                                    .where((s) => s != null && s.isNotEmpty)
                                    .join('  •  '),
                                style: AppThemeV2.caption,
                              ),
                              onChanged: (checked) {
                                final id = EntityId.parse(e['id']);
                                if (id == null) return;
                                setState(() {
                                  if (checked == true) {
                                    _selectedEmployeeIds.add(id);
                                  } else {
                                    _selectedEmployeeIds.remove(id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: AppThemeV2.primary),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(context.t('shiftGrid.createAndSetup')),
        ),
      ],
    );
  }
}

class _CreateAllLocationsGridDialog extends StatefulWidget {
  const _CreateAllLocationsGridDialog();

  @override
  State<_CreateAllLocationsGridDialog> createState() =>
      _CreateAllLocationsGridDialogState();
}

class _CreateAllLocationsGridDialogState
    extends State<_CreateAllLocationsGridDialog> {
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now().add(const Duration(days: 6));
  bool _saving = false;

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pick(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from.add(const Duration(days: 6));
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final result = await api.shiftGridCreateAllLocations(
        dateFrom: _fmt(_from),
        dateTo: _fmt(_to),
      );
      if (!mounted) return;
      final created = (result['createdCount'] as num?)?.toInt() ?? 0;
      final skipped = (result['skippedCount'] as num?)?.toInt() ?? 0;
      final errors = (result['errorCount'] as num?)?.toInt() ?? 0;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('grid.newAllLocationsDone', {
              'created': created,
              'skipped': skipped,
              'errors': errors,
            }),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('grid.newAllLocationsDialog')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('grid.newAllLocationsBody')),
            const Gap(16),
            ListTile(
              title: Text(context.t('common.from')),
              subtitle: Text(_fmt(_from)),
              onTap: () => _pick(true),
            ),
            ListTile(
              title: Text(context.t('common.to')),
              subtitle: Text(_fmt(_to)),
              onTap: () => _pick(false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(context.t('grid.create')),
        ),
      ],
    );
  }
}
