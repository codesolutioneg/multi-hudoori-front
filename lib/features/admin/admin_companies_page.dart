import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/widgets/page_header.dart';
import '../../l10n/l10n_extension.dart';
import '../auth/auth_cubit.dart';

class AdminCompaniesPage extends StatefulWidget {
  const AdminCompaniesPage({super.key});

  @override
  State<AdminCompaniesPage> createState() => _AdminCompaniesPageState();
}

class _AdminCompaniesPageState extends State<AdminCompaniesPage> {
  List<Map<String, dynamic>> _companies = [];
  bool _loading = true;
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
      final data = await api.adminCompaniesList();
      final raw = data['companies'];
      final list = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _companies = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _createCompany() async {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final hrLoginCtrl = TextEditingController();
    final hrPassCtrl = TextEditingController();
    final hrNameCtrl = TextEditingController(text: 'HR Manager');
    final isAr = context.l10n.isAr;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'إضافة شركة' : 'Add company'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  decoration: InputDecoration(
                    labelText: isAr ? 'معرف الشركة (للدخول)' : 'Company code (login)',
                    hintText: 'acme',
                  ),
                ),
                const Gap(12),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: isAr ? 'اسم الشركة' : 'Company name',
                  ),
                ),
                const Gap(16),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    isAr ? 'أول مدير HR (اختياري)' : 'First HR manager (optional)',
                    style: AppThemeV2.caption,
                  ),
                ),
                const Gap(8),
                TextField(
                  controller: hrNameCtrl,
                  decoration: InputDecoration(labelText: isAr ? 'الاسم' : 'Name'),
                ),
                const Gap(8),
                TextField(
                  controller: hrLoginCtrl,
                  decoration: InputDecoration(labelText: isAr ? 'الإيميل / الدخول' : 'Email / login'),
                ),
                const Gap(8),
                TextField(
                  controller: hrPassCtrl,
                  obscureText: true,
                  decoration: InputDecoration(labelText: isAr ? 'كلمة المرور' : 'Password'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isAr ? 'إنشاء' : 'Create')),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    try {
      await api.adminCompaniesCreate(
        code: codeCtrl.text.trim(),
        name: nameCtrl.text.trim(),
        hrManagerName: hrNameCtrl.text.trim().isEmpty ? null : hrNameCtrl.text.trim(),
        hrManagerLogin: hrLoginCtrl.text.trim().isEmpty ? null : hrLoginCtrl.text.trim(),
        hrManagerPassword: hrPassCtrl.text.isEmpty ? null : hrPassCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAr ? 'تم إنشاء الشركة' : 'Company created')),
      );
      await context.read<AuthCubit>().refreshCompanies();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _selectCompany(Map<String, dynamic> c) async {
    final id = c['id']?.toString() ?? '';
    final name = c['name']?.toString() ?? '';
    final code = c['code']?.toString() ?? '';
    if (id.isEmpty) return;
    await context.read<AuthCubit>().setActiveCompany(
          id: id,
          name: name,
          code: code,
        );
    if (!mounted) return;
    final isAr = context.l10n.isAr;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAr ? 'تم اختيار الشركة: $name' : 'Selected company: $name',
        ),
      ),
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> c) async {
    final id = c['id']?.toString() ?? '';
    final active = c['active'] != false;
    if (id.isEmpty) return;
    try {
      await api.adminCompaniesUpdate(id: id, active: !active);
      await context.read<AuthCubit>().refreshCompanies();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.l10n.isAr;
    final activeId = context.watch<AuthCubit>().state.activeCompanyId;

    return AppPageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: isAr ? 'الشركات' : 'Companies',
            subtitle: isAr
                ? 'أضف الشركات واختر واحدة للتحكم في مستخدميها وإعداداتها'
                : 'Add companies and select one to manage users and settings',
            icon: Icons.apartment_outlined,
            showRefresh: true,
            onRefresh: _load,
            actions: [
              FilledButton.icon(
                onPressed: _createCompany,
                icon: const Icon(Icons.add_business_outlined, size: 18),
                label: Text(isAr ? 'شركة جديدة' : 'New company'),
              ),
            ],
          ),
          const Gap(16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
          else if (_error != null)
            Text(_error!, style: TextStyle(color: Colors.red.shade700))
          else if (_companies.isEmpty)
            Text(
              isAr ? 'لا توجد شركات بعد — أنشئ أول شركة.' : 'No companies yet — create the first one.',
              style: AppThemeV2.caption,
            )
          else
            ..._companies.map((c) {
              final id = c['id']?.toString() ?? '';
              final selected = id == activeId;
              final counts = c['_count'] is Map ? Map<String, dynamic>.from(c['_count'] as Map) : {};
              final users = counts['users'] ?? 0;
              final employees = counts['employees'] ?? 0;
              final active = c['active'] != false;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: selected ? AppThemeV2.primarySoft : AppThemeV2.surface,
                child: ListTile(
                  leading: Icon(
                    selected ? Icons.check_circle : Icons.business_outlined,
                    color: selected ? AppThemeV2.primary : AppThemeV2.textMuted,
                  ),
                  title: Text(
                    '${c['name'] ?? ''} (${c['code'] ?? ''})',
                    style: AppThemeV2.cardTitle(),
                  ),
                  subtitle: Text(
                    isAr
                        ? 'مستخدمون: $users · موظفون: $employees · ${active ? 'نشطة' : 'موقوفة'}'
                        : 'Users: $users · Employees: $employees · ${active ? 'Active' : 'Inactive'}',
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => _selectCompany(c),
                        child: Text(isAr ? 'اختيار' : 'Select'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await _selectCompany(c);
                          if (!context.mounted) return;
                          context.go(AppRoutes.hrSettings);
                        },
                        child: Text(isAr ? 'الإعدادات' : 'Settings'),
                      ),
                      TextButton(
                        onPressed: () => _toggleActive(c),
                        child: Text(active ? (isAr ? 'إيقاف' : 'Disable') : (isAr ? 'تفعيل' : 'Enable')),
                      ),
                    ],
                  ),
                  onTap: () => _selectCompany(c),
                ),
              );
            }),
        ],
      ),
    );
  }
}
