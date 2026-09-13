import 'dart:async';
import '../../l10n/l10n_extension.dart';

import 'package:flutter/material.dart';

import '../di/injection.dart';
import '../../l10n/app_localizations.dart';
import '../utils/department_name.dart';

class EmployeeSearchField extends StatefulWidget {
  const EmployeeSearchField({
    super.key,
    this.initialId,
    this.initialName,
    this.locationId,
    this.biotimeDeviceId,
    this.excludeGridId,
    this.excludeEmployeeId,
    this.includeInactive = false,
    this.label,
    this.onSelected,
  });
  final String? initialId;
  final String? initialName;
  final String? locationId;
  final String? biotimeDeviceId;
  final String? excludeGridId;
  final String? excludeEmployeeId;
  final bool includeInactive;
  final String? label;
  final void Function(String? employeeId, String name)? onSelected;

  @override
  State<EmployeeSearchField> createState() => _EmployeeSearchFieldState();
}

class _EmployeeSearchFieldState extends State<EmployeeSearchField> {
  static const _pageSize = 30;

  final _ctrl = TextEditingController();
  Timer? _searchDebounce;
  int _searchGeneration = 0;
  List<Map<String, dynamic>> _results = [];
  String? _searchError;
  bool _searching = false;
  String? _selectedId;
  String _selectedName = '';

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialId;
    _selectedName = widget.initialName?.trim() ?? '';
    if (_selectedName.isNotEmpty) {
      _ctrl.text = _selectedName;
    }
  }

  @override
  void didUpdateWidget(covariant EmployeeSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialId != widget.initialId ||
        oldWidget.initialName != widget.initialName) {
      _selectedId = widget.initialId;
      _selectedName = widget.initialName?.trim() ?? '';
      if (_selectedName.isNotEmpty) {
        _ctrl.text = _selectedName;
      } else if (widget.initialId == null) {
        _ctrl.clear();
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _search(q),
    );
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    final generation = ++_searchGeneration;
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _searchError = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final page = await api.employeesList(
        search: query,
        locationId: widget.locationId,
        biotimeDeviceId: widget.biotimeDeviceId,
        excludeGridId: widget.excludeGridId,
        includeInactive: widget.includeInactive,
        limit: _pageSize,
      );
      if (!mounted || generation != _searchGeneration) return;
      final exclude = widget.excludeEmployeeId;
      final items = exclude == null || exclude.isEmpty
          ? page.items
          : page.items
              .where((e) => e['id']?.toString() != exclude)
              .toList();
      setState(() {
        _results = items;
        _searchError = null;
        _searching = false;
      });
    } catch (e) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = [];
        _searchError = e.toString();
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            labelText: widget.label ?? context.t('search.byNameOrCode'),
            hintText: _selectedName.isNotEmpty ? _selectedName : null,
            prefixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.search, size: 20),
            suffixIcon: _selectedId != null
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      setState(() {
                        _selectedId = null;
                        _selectedName = '';
                        _ctrl.clear();
                        _results = [];
                      });
                      widget.onSelected?.call(null, '');
                    },
                  )
                : null,
          ),
          onChanged: _onSearchChanged,
          onSubmitted: _search,
        ),
        if (_searchError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _searchError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          )
        else if (_ctrl.text.trim().isNotEmpty && _results.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              context.t('search.noResults'),
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          )
        else if (_results.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 4),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final e in _results.take(12))
                    ListTile(
                      dense: true,
                      title: Text(
                        e['displayName']?.toString() ??
                            e['name']?.toString() ??
                            '',
                      ),
                      subtitle: Text(
                        [
                          if ((e['code']?.toString() ?? '').isNotEmpty)
                            context.t('search.code', {'code': e['code']}),
                          if (employeeDepartmentName(e, context).isNotEmpty)
                            employeeDepartmentName(e, context),
                          if (e['active'] == false) context.t('search.archived'),
                        ].join('  •  '),
                      ),
                      onTap: () {
                        final id = e['id']?.toString();
                        final name =
                            e['displayName']?.toString() ??
                            e['name']?.toString() ??
                            '';
                        setState(() {
                          _selectedId = id;
                          _selectedName = name;
                          _results = [];
                          _ctrl.text = name;
                        });
                        widget.onSelected?.call(id, name);
                      },
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
