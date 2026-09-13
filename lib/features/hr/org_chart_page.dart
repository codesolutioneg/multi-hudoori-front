import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/utils/entity_id.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/l10n_extension.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';

class OrgChartPage extends StatefulWidget {
  const OrgChartPage({super.key});

  @override
  State<OrgChartPage> createState() => _OrgChartPageState();
}

class _OrgChartPageState extends State<OrgChartPage> {
  String _scope = 'company';
  String? _locationId;
  List<Map<String, dynamic>> _locations = [];
  List<Map<String, dynamic>> _roots = [];
  int _employeeCount = 0;
  bool _canChooseScope = false;
  String _viewLabel = '';
  String? _focusEmployeeId;
  bool _loading = false;
  bool _bootstrapped = false;
  String? _error;

  bool _canPickCompany(AuthState auth) =>
      auth.isPlatformAdmin ||
      auth.roles.isHrManager ||
      auth.roles.isHrSupervisor;

  bool _isLocationLocked(AuthState auth) =>
      auth.isLocationScoped || auth.roles.isBranchManager;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    final auth = context.read<AuthCubit>().state;
    if (_canPickCompany(auth)) {
      _scope = 'company';
    } else if (_isLocationLocked(auth)) {
      _scope = 'location';
      _locationId = auth.scopedLocationId ?? auth.user?.locationId;
    } else {
      _scope = 'mine';
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthCubit>().state;
    if (_canPickCompany(auth)) {
      try {
        final locations = await api.locationsList(activeOnly: true);
        if (!mounted) return;
        setState(() => _locations = locations);
      } catch (_) {}
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await api.orgChartTree(
        scope: _scope,
        locationId: _scope == 'location' ? _locationId : null,
      );
      if (!mounted) return;
      final roots = (data['roots'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _roots = roots;
        _employeeCount = (data['employeeCount'] as num?)?.toInt() ?? 0;
        _canChooseScope = data['canChooseScope'] == true;
        _viewLabel = data['viewLabel']?.toString() ?? _scope;
        _focusEmployeeId = EntityId.parse(data['focusEmployeeId']);
        final lockedLoc = EntityId.parse(data['locationId']);
        if (lockedLoc != null && !_canChooseScope) {
          _locationId = lockedLoc;
          _scope = 'location';
        }
        if (data['scope']?.toString() == 'mine') {
          _scope = 'mine';
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _roots = [];
        _employeeCount = 0;
      });
    }
  }

  /// Reassigns the node's manager. A manual manager overrides the derived line,
  /// so the employee stays where they were put even if their job title changes.
  Future<void> _moveEmployee(Map<String, dynamic> node) async {
    final id = EntityId.parse(node['id']);
    if (id == null || id.isEmpty) return;

    final choice = await showDialog<_MoveResult>(
      context: context,
      builder: (_) => _MoveEmployeeDialog(
        employeeId: id,
        employeeName: node['name']?.toString() ?? '',
      ),
    );
    if (choice == null || !mounted) return;

    try {
      await api.orgChartSetManager(employeeId: id, managerId: choice.managerId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('orgChart.moveDone')),
          backgroundColor: AppColors.success,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  String _subtitle(BuildContext context) {
    if (_viewLabel == 'mine' || _scope == 'mine') {
      return context.t('orgChart.subtitleMine');
    }
    if (_scope == 'location' && !_canChooseScope) {
      return context.t('orgChart.subtitleLocation');
    }
    return context.t('orgChart.subtitle');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    final showChooser = _canChooseScope || _canPickCompany(auth);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PageHeader(
          title: context.t('orgChart.title'),
          subtitle: _subtitle(context),
        ),
        const SizedBox(height: 16),
        if (showChooser)
          SellixCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'company',
                      label: Text(context.t('orgChart.scopeCompany')),
                      icon: const Icon(Icons.apartment_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: 'location',
                      label: Text(context.t('orgChart.scopeLocation')),
                      icon: const Icon(Icons.place_outlined, size: 18),
                    ),
                  ],
                  selected: {_scope == 'location' ? 'location' : 'company'},
                  onSelectionChanged: (s) {
                    setState(() => _scope = s.first);
                    if (_scope == 'company' || _locationId != null) {
                      _load();
                    } else {
                      setState(() {
                        _roots = [];
                        _employeeCount = 0;
                        _error = null;
                      });
                    }
                  },
                ),
                if (_scope == 'location') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: _locationId,
                    decoration: InputDecoration(
                      labelText: context.t('orgChart.selectLocation'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(context.t('orgChart.selectLocation')),
                      ),
                      for (final loc in _locations)
                        DropdownMenuItem(
                          value: EntityId.parse(loc['id']),
                          child: Text(loc['name']?.toString() ?? ''),
                        ),
                    ],
                    onChanged: (v) {
                      setState(() => _locationId = v);
                      if (v != null) _load();
                    },
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  context.t('orgChart.employeeCount', {'n': '$_employeeCount'}),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppThemeV2.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          SellixCard(
            child: Text(
              context.t('orgChart.employeeCount', {'n': '$_employeeCount'}),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppThemeV2.textSecondary),
            ),
          ),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          SellixCard(
            child: Column(
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _load,
                  child: Text(context.t('common.retry')),
                ),
              ],
            ),
          )
        else if (_scope == 'location' && _canChooseScope && _locationId == null)
          SellixCard(
            child: Text(
              context.t('orgChart.pickLocationHint'),
              textAlign: TextAlign.center,
            ),
          )
        else if (_roots.isEmpty)
          SellixCard(
            child: Text(
              _employeeCount == 0
                  ? context.t('orgChart.emptyNoEmployees')
                  : context.t('orgChart.emptyNoManagers'),
              textAlign: TextAlign.center,
            ),
          )
        else
          OrgTreeView(
            key: ValueKey('$_scope-${_locationId ?? ''}-${_roots.length}'),
            roots: _roots,
            focusEmployeeId: _focusEmployeeId,
            // A single site (or a personal line) is small enough to open whole and
            // scale to fit; the all-company view would be unreadable that way.
            startExpanded: _scope != 'company',
            allowOpenProfile:
                auth.roles.isHrStaff ||
                auth.isPlatformAdmin ||
                auth.roles.isBranchManager,
            onMoveEmployee: auth.roles.isHrManager || auth.isPlatformAdmin
                ? _moveEmployee
                : null,
          ),
      ],
    );
  }
}

/// Nodes with more direct reports than this start collapsed, so a site with one
/// supervisor over 60 people opens as a chip instead of an unreadable wall.
const int _kAutoCollapseOver = 10;

const double _kStubHeight = 18;
const double _kSiblingGap = 14;

List<Map<String, dynamic>> _childrenOf(Map<String, dynamic> node) =>
    (node['children'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

/// Responsive org chart: a pannable/zoomable diagram on wide screens, and an
/// indented, expandable outline on phones where a horizontal tree can't fit.
class OrgTreeView extends StatefulWidget {
  const OrgTreeView({
    super.key,
    required this.roots,
    this.focusEmployeeId,
    this.allowOpenProfile = false,
    this.startExpanded = false,
    this.onMoveEmployee,
  });

  final List<Map<String, dynamic>> roots;
  final String? focusEmployeeId;
  final bool allowOpenProfile;

  /// Open every branch on first render and scale the diagram down to fit.
  final bool startExpanded;

  /// Reassigns a node's manager. Null hides the «نقل» control entirely.
  final void Function(Map<String, dynamic> node)? onMoveEmployee;

  @override
  State<OrgTreeView> createState() => _OrgTreeViewState();
}

class _OrgTreeViewState extends State<OrgTreeView> {
  final Set<String> _collapsed = {};
  final TransformationController _view = TransformationController();
  final GlobalKey _contentKey = GlobalKey();
  Size? _viewport;

  @override
  void initState() {
    super.initState();
    if (!widget.startExpanded) _applyDefaultCollapse();
    _scheduleFit();
  }

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  void _applyDefaultCollapse() {
    void walk(Map<String, dynamic> node, int depth) {
      final kids = _childrenOf(node);
      final id = EntityId.parse(node['id']) ?? '';
      if (id.isNotEmpty && depth > 0 && kids.length > _kAutoCollapseOver) {
        _collapsed.add(id);
      }
      for (final k in kids) {
        walk(k, depth + 1);
      }
    }

    for (final r in widget.roots) {
      walk(r, 0);
    }
  }

  /// Scale + centre the diagram so the whole tree lands inside the viewport.
  void _fitToScreen() {
    final viewport = _viewport;
    final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || box == null || !box.hasSize) return;
    final content = box.size;
    if (content.width <= 0 || content.height <= 0) return;

    // Never magnify past 1:1 — a two-person branch should stay readable, not huge.
    final scale = math
        .min(viewport.width / content.width, viewport.height / content.height)
        .clamp(0.15, 1.0);
    final dx = (viewport.width - content.width * scale) / 2;
    final dy = (viewport.height - content.height * scale) / 2;
    _view.value = Matrix4.identity()
      ..translateByDouble(dx, math.max(dy, 0), 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  /// The tree is laid out lazily, so retry briefly until it reports a size.
  void _scheduleFit([int attempt = 0]) {
    if (attempt > 3) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _contentKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || _viewport == null) {
        _scheduleFit(attempt + 1);
        return;
      }
      _fitToScreen();
    });
  }

  void _forEachNode(void Function(Map<String, dynamic> node) fn) {
    void walk(Map<String, dynamic> node) {
      fn(node);
      for (final k in _childrenOf(node)) {
        walk(k);
      }
    }

    for (final r in widget.roots) {
      walk(r);
    }
  }

  void _expandAll() {
    setState(_collapsed.clear);
    _scheduleFit();
  }

  void _collapseAll() {
    setState(() {
      _collapsed.clear();
      _forEachNode((node) {
        final id = EntityId.parse(node['id']) ?? '';
        if (id.isNotEmpty && _childrenOf(node).isNotEmpty) _collapsed.add(id);
      });
      // Keep the roots open so the chart is never entirely blank.
      for (final r in widget.roots) {
        _collapsed.remove(EntityId.parse(r['id']) ?? '');
      }
    });
    _scheduleFit();
  }

  void _toggle(String id) => setState(() {
    if (!_collapsed.remove(id)) _collapsed.add(id);
  });

  void _zoom(double factor) {
    final next = (_view.value.getMaxScaleOnAxis() * factor).clamp(0.3, 2.5);
    _view.value = Matrix4.identity()..scaleByDouble(next, next, next, 1);
  }

  void _openProfile(String id) {
    if (!widget.allowOpenProfile || id.isEmpty) return;
    context.push(AppRoutes.hrEmployeeDetail(id));
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    return SellixCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(context, mobile),
          const Divider(height: 1),
          if (mobile) _mobileBody() else _desktopBody(context),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context, bool mobile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          _toolBtn(
            icon: Icons.unfold_more,
            tooltip: context.t('orgChart.expandAll'),
            onTap: _expandAll,
          ),
          _toolBtn(
            icon: Icons.unfold_less,
            tooltip: context.t('orgChart.collapseAll'),
            onTap: _collapseAll,
          ),
          if (!mobile) ...[
            const SizedBox(width: 4),
            const SizedBox(height: 20, child: VerticalDivider(width: 1)),
            const SizedBox(width: 4),
            _toolBtn(
              icon: Icons.zoom_out,
              tooltip: context.t('orgChart.zoomOut'),
              onTap: () => _zoom(1 / 1.2),
            ),
            _toolBtn(
              icon: Icons.zoom_in,
              tooltip: context.t('orgChart.zoomIn'),
              onTap: () => _zoom(1.2),
            ),
            _toolBtn(
              icon: Icons.fit_screen_outlined,
              tooltip: context.t('orgChart.resetView'),
              onTap: _fitToScreen,
            ),
            const Spacer(),
            Flexible(
              child: Text(
                context.t('orgChart.panHint'),
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: AppThemeV2.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _toolBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(icon, size: 19),
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      color: AppThemeV2.textSecondary,
    );
  }

  Widget _desktopBody(BuildContext context) {
    final height = (MediaQuery.sizeOf(context).height * 0.68).clamp(
      420.0,
      900.0,
    );
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = Size(constraints.maxWidth, constraints.maxHeight);
          if (_viewport != viewport) {
            _viewport = viewport;
            _scheduleFit();
          }
          return InteractiveViewer(
            transformationController: _view,
            minScale: 0.15,
            maxScale: 2.5,
            boundaryMargin: const EdgeInsets.all(800),
            constrained: false,
            child: Padding(
              key: _contentKey,
              padding: const EdgeInsets.all(28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.roots.length; i++) ...[
                    if (i > 0) const SizedBox(width: 40),
                    _DesktopNode(
                      node: widget.roots[i],
                      collapsed: _collapsed,
                      onToggle: _toggle,
                      focusEmployeeId: widget.focusEmployeeId,
                      onOpenProfile: widget.allowOpenProfile
                          ? _openProfile
                          : null,
                      onMoveEmployee: widget.onMoveEmployee,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _mobileBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final root in widget.roots)
            _MobileNode(
              node: root,
              collapsed: _collapsed,
              onToggle: _toggle,
              focusEmployeeId: widget.focusEmployeeId,
              onOpenProfile: widget.allowOpenProfile ? _openProfile : null,
              onMoveEmployee: widget.onMoveEmployee,
            ),
        ],
      ),
    );
  }
}

/// One subtree of the wide-screen diagram: card, drop stub, elbow bus, children.
class _DesktopNode extends StatelessWidget {
  const _DesktopNode({
    required this.node,
    required this.collapsed,
    required this.onToggle,
    required this.focusEmployeeId,
    required this.onOpenProfile,
    required this.onMoveEmployee,
  });

  final Map<String, dynamic> node;
  final Set<String> collapsed;
  final void Function(String id) onToggle;
  final String? focusEmployeeId;
  final void Function(String id)? onOpenProfile;
  final void Function(Map<String, dynamic> node)? onMoveEmployee;

  @override
  Widget build(BuildContext context) {
    final children = _childrenOf(node);
    final id = EntityId.parse(node['id']) ?? '';
    final isOpen = children.isNotEmpty && !collapsed.contains(id);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final line = AppColors.primary.withValues(alpha: 0.32);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OrgPersonCard(
          name: node['name']?.toString() ?? '',
          jobTitle: node['jobTitle']?.toString() ?? '',
          photoUrl: node['photoUrl']?.toString() ?? '',
          highlighted:
              node['isSelf'] == true ||
              (focusEmployeeId != null && id == focusEmployeeId),
          reportCount: children.length,
          expanded: isOpen,
          onToggle: children.isEmpty || id.isEmpty ? null : () => onToggle(id),
          onTap: onOpenProfile == null || id.isEmpty
              ? null
              : () => onOpenProfile!(id),
          onMove: onMoveEmployee == null || id.isEmpty
              ? null
              : () => onMoveEmployee!(node),
        ),
        if (isOpen) ...[
          Container(width: 2, height: _kStubHeight, color: line),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++)
                IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: _kStubHeight,
                        child: CustomPaint(
                          painter: _ElbowPainter(
                            // Siblings sit on the visual left/right depending on
                            // text direction, so flip the bus ends for RTL.
                            extendStart: rtl ? i < children.length - 1 : i > 0,
                            extendEnd: rtl ? i > 0 : i < children.length - 1,
                            color: line,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _kSiblingGap / 2,
                        ),
                        child: _DesktopNode(
                          node: children[i],
                          collapsed: collapsed,
                          onToggle: onToggle,
                          focusEmployeeId: focusEmployeeId,
                          onOpenProfile: onOpenProfile,
                          onMoveEmployee: onMoveEmployee,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Rounded elbow joining a child to its parent's horizontal bus.
class _ElbowPainter extends CustomPainter {
  const _ElbowPainter({
    required this.extendStart,
    required this.extendEnd,
    required this.color,
  });

  final bool extendStart;
  final bool extendEnd;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final r = size.height.clamp(0.0, 10.0);
    final path = Path();

    if (!extendStart && !extendEnd) {
      path.moveTo(cx, 0);
      path.lineTo(cx, size.height);
      canvas.drawPath(path, paint);
      return;
    }

    // Horizontal bus, rounded where it turns down into this child.
    if (extendStart) {
      path.moveTo(0, 0);
      path.lineTo(cx - r, 0);
      path.quadraticBezierTo(cx, 0, cx, r);
    }
    if (extendEnd) {
      path.moveTo(size.width, 0);
      path.lineTo(cx + r, 0);
      path.quadraticBezierTo(cx, 0, cx, r);
    }
    path.moveTo(cx, extendStart || extendEnd ? r : 0);
    path.lineTo(cx, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ElbowPainter old) =>
      old.extendStart != extendStart ||
      old.extendEnd != extendEnd ||
      old.color != color;
}

/// Phone layout: indented outline with a guide rail per level.
class _MobileNode extends StatelessWidget {
  const _MobileNode({
    required this.node,
    required this.collapsed,
    required this.onToggle,
    required this.focusEmployeeId,
    required this.onOpenProfile,
    required this.onMoveEmployee,
  });

  final Map<String, dynamic> node;
  final Set<String> collapsed;
  final void Function(String id) onToggle;
  final String? focusEmployeeId;
  final void Function(String id)? onOpenProfile;
  final void Function(Map<String, dynamic> node)? onMoveEmployee;

  @override
  Widget build(BuildContext context) {
    final children = _childrenOf(node);
    final id = EntityId.parse(node['id']) ?? '';
    final isOpen = children.isNotEmpty && !collapsed.contains(id);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MobileRow(
          node: node,
          childCount: children.length,
          expanded: isOpen,
          highlighted:
              node['isSelf'] == true ||
              (focusEmployeeId != null && id == focusEmployeeId),
          onToggle: children.isEmpty || id.isEmpty ? null : () => onToggle(id),
          onTap: onOpenProfile == null || id.isEmpty
              ? null
              : () => onOpenProfile!(id),
          onMove: onMoveEmployee == null || id.isEmpty
              ? null
              : () => onMoveEmployee!(node),
        ),
        if (isOpen)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 18),
            child: Container(
              decoration: BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    width: 2,
                  ),
                ),
              ),
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final child in children)
                    _MobileNode(
                      node: child,
                      collapsed: collapsed,
                      onToggle: onToggle,
                      focusEmployeeId: focusEmployeeId,
                      onOpenProfile: onOpenProfile,
                      onMoveEmployee: onMoveEmployee,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MobileRow extends StatelessWidget {
  const _MobileRow({
    required this.node,
    required this.childCount,
    required this.expanded,
    required this.highlighted,
    required this.onToggle,
    required this.onTap,
    required this.onMove,
  });

  final Map<String, dynamic> node;
  final int childCount;
  final bool expanded;
  final bool highlighted;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onMove;

  @override
  Widget build(BuildContext context) {
    final name = node['name']?.toString() ?? '';
    final jobTitle = node['jobTitle']?.toString() ?? '';
    final photoUrl = node['photoUrl']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: highlighted
            ? AppColors.primary.withValues(alpha: 0.07)
            : AppThemeV2.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 6, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: highlighted ? AppColors.primary : AppThemeV2.border,
                width: highlighted ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                _Avatar(name: name, photoUrl: photoUrl, radius: 17),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        jobTitle.isEmpty ? '—' : jobTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppThemeV2.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onMove != null)
                  IconButton(
                    onPressed: onMove,
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    tooltip: context.t('orgChart.move'),
                    visualDensity: VisualDensity.compact,
                    color: AppThemeV2.textSecondary,
                  ),
                if (childCount > 0)
                  InkWell(
                    onTap: onToggle,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$childCount',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          Icon(
                            expanded ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.photoUrl,
    required this.radius,
  });

  final String name;
  final String photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((p) => p.isEmpty ? '' : p[0])
              .join()
              .toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundImage: photoUrl.startsWith('http')
          ? NetworkImage(photoUrl)
          : null,
      child: photoUrl.startsWith('http')
          ? null
          : Text(
              initials,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: radius * (initials.length > 1 ? 0.5 : 0.64),
              ),
            ),
    );
  }
}

class _OrgPersonCard extends StatelessWidget {
  const _OrgPersonCard({
    required this.name,
    required this.jobTitle,
    required this.photoUrl,
    this.highlighted = false,
    this.reportCount = 0,
    this.expanded = false,
    this.onToggle,
    this.onTap,
    this.onMove,
  });

  final String name;
  final String jobTitle;
  final String photoUrl;
  final bool highlighted;
  final int reportCount;
  final bool expanded;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onMove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 172,
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: _body(context),
                ),
                if (onMove != null)
                  PositionedDirectional(
                    top: 2,
                    start: 2,
                    child: Tooltip(
                      message: context.t('orgChart.move'),
                      child: InkWell(
                        onTap: onMove,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.swap_horiz,
                            size: 15,
                            color: AppThemeV2.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (onToggle != null) ...[
              const SizedBox(height: 6),
              _ReportsChip(
                count: reportCount,
                expanded: expanded,
                onTap: onToggle!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppThemeV2.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted ? AppColors.primary : AppThemeV2.border,
          width: highlighted ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppThemeV2.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _Avatar(name: name, photoUrl: photoUrl, radius: 28),
          const SizedBox(height: 10),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            jobTitle.isEmpty ? '—' : jobTitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppThemeV2.textSecondary,
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
          if (highlighted) ...[
            const SizedBox(height: 6),
            Text(
              context.t('orgChart.you'),
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// «12 تابع» pill under a card; also the expand/collapse control for that branch.
class _ReportsChip extends StatelessWidget {
  const _ReportsChip({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: expanded
              ? AppThemeV2.surface
              : AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: expanded ? 0.30 : 0.55),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.t('orgChart.directReports', {'n': '$count'}),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoveResult {
  const _MoveResult(this.managerId);

  /// Null detaches the employee so derivation picks their manager again.
  final String? managerId;
}

/// Picks the new manager for an employee. The server has already excluded anyone
/// whose selection would close a cycle, so every row here is a valid choice.
class _MoveEmployeeDialog extends StatefulWidget {
  const _MoveEmployeeDialog({
    required this.employeeId,
    required this.employeeName,
  });

  final String employeeId;
  final String employeeName;

  @override
  State<_MoveEmployeeDialog> createState() => _MoveEmployeeDialogState();
}

class _MoveEmployeeDialogState extends State<_MoveEmployeeDialog> {
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _options = [];
  bool _loading = true;
  String? _error;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final options = await api.orgChartManagerOptions(
        employeeId: widget.employeeId,
        search: _search.text,
      );
      // A slower earlier request must not overwrite a newer result.
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _options = options;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        context.t('orgChart.moveTitle', {'name': widget.employeeName}),
      ),
      content: SizedBox(
        width: 420,
        height: 460,
        child: Column(
          children: [
            TextField(
              controller: _search,
              autofocus: true,
              onSubmitted: (_) => _fetch(),
              onChanged: (_) => _fetch(),
              decoration: InputDecoration(
                hintText: context.t('orgChart.moveSearchHint'),
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, const _MoveResult(null)),
              icon: const Icon(Icons.link_off, size: 16),
              label: Text(context.t('orgChart.moveDetach')),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(child: _list()),
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

  Widget _list() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
      );
    }
    if (_options.isEmpty) {
      return Center(
        child: Text(
          context.t('orgChart.moveNoResults'),
          style: TextStyle(color: AppThemeV2.textMuted),
        ),
      );
    }
    return ListView.separated(
      itemCount: _options.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final m = _options[i];
        final name = m['name']?.toString() ?? '';
        final jobTitle = m['jobTitle']?.toString() ?? '';
        final location = m['locationName']?.toString() ?? '';
        final code = m['code']?.toString() ?? '';
        return ListTile(
          dense: true,
          leading: _Avatar(name: name, photoUrl: '', radius: 16),
          title: Text(name, style: const TextStyle(fontSize: 13)),
          subtitle: Text(
            [jobTitle, location, code].where((s) => s.isNotEmpty).join(' · '),
            style: const TextStyle(fontSize: 11),
          ),
          onTap: () =>
              Navigator.pop(context, _MoveResult(EntityId.parse(m['id']))),
        );
      },
    );
  }
}
