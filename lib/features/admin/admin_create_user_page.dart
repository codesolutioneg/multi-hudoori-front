import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/widgets/hr_local_data_info.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import 'widgets/admin_role_badge.dart';
import '../../l10n/l10n_extension.dart';

class AdminCreateUserPage extends StatefulWidget {
  const AdminCreateUserPage({super.key});

  @override
  State<AdminCreateUserPage> createState() => _AdminCreateUserPageState();
}

class _AdminCreateUserPageState extends State<AdminCreateUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _login = TextEditingController();
  final _password = TextEditingController();
  String _role = 'EMPLOYEE';
  String? _locationId;
  List<Map<String, dynamic>> _locations = [];
  bool _loadingLocations = true;
  bool _loading = false;
  bool _obscurePassword = true;

  bool get _requiresLocation => _role == 'HR_USER' || _role == 'BRANCH_MANAGER';

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _name.dispose();
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    setState(() => _loadingLocations = true);
    try {
      final locations = await api.locationsList();
      if (!mounted) return;
      setState(() {
        _locations = locations;
        _loadingLocations = false;
        if (_requiresLocation && _locationId == null && locations.isNotEmpty) {
          _locationId = locations.first['id']?.toString();
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLocations = false);
    }
  }

  void _suggestPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#\$%';
    final rand = Random.secure();
    final buf = StringBuffer();
    for (var i = 0; i < 14; i++) {
      buf.write(chars[rand.nextInt(chars.length)]);
    }
    setState(() {
      _password.text = buf.toString();
      _obscurePassword = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_requiresLocation && (_locationId == null || _locationId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('admin.pickLocationForHr')), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await api.adminUserCreate(
        name: _name.text.trim(),
        login: _login.text.trim(),
        password: _password.text,
        role: _role,
        locationId: _requiresLocation ? _locationId : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('admin.userCreated')), behavior: SnackBarBehavior.floating),
        );
        context.go(AppRoutes.adminUsers);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _locationLabel(Map<String, dynamic> loc) {
    final name = loc['name']?.toString() ?? '';
    final code = loc['code']?.toString();
    if (code != null && code.isNotEmpty) return '$name ($code)';
    return name;
  }

  InputDecoration _fieldDecoration(String label, {String? hint, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      filled: true,
      fillColor: AppThemeV2.surfaceElevated,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppThemeV2.border.withValues(alpha: 0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppThemeV2.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: context.t('admin.createUser'),
              subtitle: context.t('admin.createUserSubtitle'),
              icon: Icons.person_add_alt_1_outlined,
              onBack: () => context.go(AppRoutes.adminUsers),
            ),
            const Gap(16),
            if (_requiresLocation)
              HrLocalDataBanner(
                title: context.t('admin.locationRestrictTitle'),
                hint: context.t('admin.locationRestrictHint'),
              ),
            const Gap(16),
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 900;
                final form = SellixCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(context.t('admin.accountData'), style: AppThemeV2.title),
                      Gap(4),
                      Text(context.t('admin.accountDataHint'), style: AppThemeV2.caption),
                      Gap(20),
                      TextFormField(
                        controller: _name,
                        decoration: _fieldDecoration(context.t('admin.fullName')),
                        validator: (v) => v == null || v.trim().isEmpty ? context.t('admin.nameRequired') : null,
                      ),
                      Gap(14),
                      TextFormField(
                        controller: _login,
                        decoration: _fieldDecoration(context.t('admin.emailOrLogin'), hint: 'user@company.com'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v == null || v.trim().isEmpty ? context.t('admin.emailRequired') : null,
                      ),
                      Gap(14),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        decoration: _fieldDecoration(
                          context.t('admin.password'),
                          suffix: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: context.t('admin.suggestPassword'),
                                onPressed: _suggestPassword,
                                icon: const Icon(Icons.auto_fix_high_outlined, size: 20),
                              ),
                              IconButton(
                                tooltip: _obscurePassword ? context.t('admin.show') : context.t('admin.hide'),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                              ),
                            ],
                          ),
                        ),
                        validator: (v) => v == null || v.length < 6 ? context.t('admin.passwordMin') : null,
                      ),
                      Gap(14),
                      DropdownButtonFormField<String>(
                        value: _role,
                        decoration: _fieldDecoration(context.t('admin.role')),
                        items: [
                          DropdownMenuItem(value: 'EMPLOYEE', child: Text(context.t('admin.roleOption.employee'))),
                          DropdownMenuItem(value: 'HR_USER', child: Text(context.t('admin.roleOption.hrUser'))),
                          DropdownMenuItem(
                            value: 'HR_SUPERVISOR',
                            child: Text(context.t('admin.roleOption.hrSupervisor')),
                          ),
                          DropdownMenuItem(value: 'HR_MANAGER', child: Text(context.t('admin.roleOption.hrManager'))),
                          DropdownMenuItem(value: 'BRANCH_MANAGER', child: Text(context.t('admin.roleOption.branchManager'))),
                          DropdownMenuItem(value: 'DEVICE_MANAGER', child: Text(tr('admin.role.deviceManager'))),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _role = v ?? 'EMPLOYEE';
                            if (_requiresLocation && _locationId == null && _locations.isNotEmpty) {
                              _locationId = _locations.first['id']?.toString();
                            }
                          });
                        },
                      ),
                      const Gap(10),
                      AdminRoleBadge(role: _role),
                      if (_requiresLocation) ...[
                        const Gap(16),
                        const Divider(),
                        const Gap(16),
                        Text(context.t('shiftGrid.location'), style: AppThemeV2.title),
                        const Gap(4),
                        Text(context.t('admin.locationHint'), style: AppThemeV2.caption),
                        const Gap(14),
                        if (_loadingLocations)
                          const LinearProgressIndicator()
                        else if (_locations.isEmpty)
                          Text(
                            context.t('admin.noLocations'),
                            style: AppThemeV2.body.copyWith(color: AppThemeV2.warning),
                          )
                        else
                          DropdownButtonFormField<String>(
                            value: _locationId,
                            decoration: _fieldDecoration(context.t('admin.pickLocation')),
                            items: _locations
                                .map(
                                  (loc) => DropdownMenuItem(
                                    value: loc['id']?.toString(),
                                    child: Text(_locationLabel(loc)),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _locationId = v),
                            validator: _requiresLocation
                                ? (v) => v == null || v.isEmpty ? context.t('admin.locationRequired') : null
                                : null,
                          ),
                      ],
                    ],
                  ),
                );

                final actions = SellixCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(context.t('admin.saveSection'), style: AppThemeV2.title),
                      const Gap(8),
                      Text(
                        context.t('admin.saveHint'),
                        style: AppThemeV2.caption,
                      ),
                      const Gap(16),
                      FilledButton.icon(
                        onPressed: _loading || (_requiresLocation && _locations.isEmpty) ? null : _submit,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_rounded, size: 20),
                        label: Text(_loading ? context.t('admin.creating') : context.t('admin.createUser')),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppThemeV2.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const Gap(10),
                      OutlinedButton(
                        onPressed: _loading ? null : () => context.go(AppRoutes.adminUsers),
                        child: Text(context.t('common.cancel')),
                      ),
                    ],
                  ),
                );

                if (!wide) {
                  return Column(
                    children: [form, const Gap(16), actions],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: form),
                    const Gap(16),
                    Expanded(flex: 2, child: actions),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
