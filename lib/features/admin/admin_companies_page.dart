import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/utils/company_quota.dart';
import '../../core/widgets/page_header.dart';
import '../../l10n/l10n_extension.dart';
import '../auth/auth_cubit.dart';

import '../mobile/hudoori_loader.dart';
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
    final maxEmployeesCtrl = TextEditingController();
    final maxUsersCtrl = TextEditingController();
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
                    isAr ? 'حدود الاشتراك (إلزامي)' : 'Subscription limits (required)',
                    style: AppThemeV2.caption,
                  ),
                ),
                const Gap(8),
                _QuotaFields(
                  maxEmployeesCtrl: maxEmployeesCtrl,
                  maxUsersCtrl: maxUsersCtrl,
                  isAr: isAr,
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
    final maxEmployees = int.tryParse(maxEmployeesCtrl.text.trim());
    final maxUsers = int.tryParse(maxUsersCtrl.text.trim());
    if (maxEmployees == null || maxUsers == null || maxEmployees < 0 || maxUsers < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr
                ? 'أدخل أقصى عدد موظفين وأقصى عدد مستخدمين (أرقام صحيحة)'
                : 'Enter max employees and max users (whole numbers)',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    try {
      await api.adminCompaniesCreate(
        code: codeCtrl.text.trim(),
        name: nameCtrl.text.trim(),
        maxEmployees: maxEmployees,
        maxUsers: maxUsers,
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
        SnackBar(content: Text(friendlyApiError(context, e)), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Future<void> _editQuota(Map<String, dynamic> c) async {
    final id = c['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final isAr = context.l10n.isAr;
    final quota = _quotaOf(c);
    final maxEmployeesCtrl = TextEditingController(
      text: quota.employeesMax?.toString() ?? '',
    );
    final maxUsersCtrl = TextEditingController(text: quota.usersMax?.toString() ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isAr ? 'حدود اشتراك ${c['name'] ?? ''}' : 'Limits for ${c['name'] ?? ''}',
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isAr
                    ? 'المستخدم حالياً: ${quota.employeesUsed} موظف · ${quota.usersUsed} مستخدم. '
                        'اترك الحقل فارغاً = بلا حد. تقليل الحد تحت المستخدم الحالي يمنع الإضافة فقط ولا يحذف بيانات.'
                    : 'In use: ${quota.employeesUsed} employees · ${quota.usersUsed} users. '
                        'Leave empty = unlimited. Lowering below usage only blocks new rows; nothing is deleted.',
                style: AppThemeV2.caption,
              ),
              const Gap(12),
              _QuotaFields(
                maxEmployeesCtrl: maxEmployeesCtrl,
                maxUsersCtrl: maxUsersCtrl,
                isAr: isAr,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isAr ? 'حفظ' : 'Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    int? parse(String raw) => raw.trim().isEmpty ? null : int.tryParse(raw.trim());
    final maxEmployees = parse(maxEmployeesCtrl.text);
    final maxUsers = parse(maxUsersCtrl.text);
    final invalid = (maxEmployeesCtrl.text.trim().isNotEmpty && (maxEmployees == null || maxEmployees < 0)) ||
        (maxUsersCtrl.text.trim().isNotEmpty && (maxUsers == null || maxUsers < 0));
    if (invalid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr ? 'الحدود لازم تكون أرقام صحيحة ≥ 0' : 'Limits must be whole numbers ≥ 0'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    try {
      await api.adminCompaniesUpdateQuota(id: id, maxEmployees: maxEmployees, maxUsers: maxUsers);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAr ? 'تم تحديث حدود الاشتراك' : 'Limits updated')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiError(context, e)), backgroundColor: Colors.red.shade700),
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

  Future<void> _manageFeatures(Map<String, dynamic> c) async {
    final id = c['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final isAr = context.l10n.isAr;
    List<Map<String, dynamic>> catalog = [];
    Map<String, bool> enabledByKey = {};
    String planLabel = '';
    try {
      final data = await api.adminCompaniesFeaturesGet(id: id);
      final company = data['company'];
      if (company is Map) {
        final m = Map<String, dynamic>.from(company);
        planLabel = isAr
            ? (m['planNameAr']?.toString().trim().isNotEmpty == true
                ? m['planNameAr'].toString()
                : (m['planNameEn']?.toString() ?? ''))
            : (m['planNameEn']?.toString().trim().isNotEmpty == true
                ? m['planNameEn'].toString()
                : (m['planNameAr']?.toString() ?? ''));
      }
      final raw = data['features'];
      if (raw is List) {
        for (final item in raw) {
          if (item is! Map) continue;
          final row = Map<String, dynamic>.from(item);
          final key = row['key']?.toString() ?? '';
          if (key.isEmpty) continue;
          enabledByKey[key] = row['enabled'] == true;
        }
      }
      final catData = await api.adminPlansFeatureCatalog();
      final rawCat = catData['features'];
      if (rawCat is List) {
        catalog = rawCat.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiError(context, e)), backgroundColor: Colors.red.shade700),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: Text(isAr ? 'ميزات ${c['name'] ?? ''}' : 'Features — ${c['name'] ?? ''}'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (planLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          isAr ? 'الباقة عند الاشتراك: $planLabel' : 'Subscribed plan (snapshot): $planLabel',
                          style: AppThemeV2.caption,
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          isAr
                              ? 'لا توجد باقة مسجّلة — الشركات القديمة تعامل ككل الميزات مفعّلة حتى تُعدّل.'
                              : 'No plan on file — legacy companies behave as all features on until you change toggles.',
                          style: AppThemeV2.caption,
                        ),
                      ),
                    for (final f in catalog)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          isAr ? (f['nameAr'] ?? f['key']).toString() : (f['nameEn'] ?? f['key']).toString(),
                        ),
                        subtitle: Text(f['key']?.toString() ?? '', style: AppThemeV2.caption),
                        value: enabledByKey[f['key']?.toString()] ?? false,
                        onChanged: (v) => setLocal(() {
                          final k = f['key']?.toString() ?? '';
                          if (k.isEmpty) return;
                          enabledByKey[k] = v;
                        }),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'إلغاء' : 'Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isAr ? 'حفظ' : 'Save')),
            ],
          );
        },
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final features = enabledByKey.entries
          .map((e) => {'key': e.key, 'enabled': e.value})
          .toList();
      await api.adminCompaniesFeaturesUpdate(id: id, features: features);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isAr ? 'تم تحديث الميزات' : 'Features updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiError(context, e)), backgroundColor: Colors.red.shade700),
      );
    }
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
            const Center(child: Padding(padding: EdgeInsets.all(48), child: HudooriLoader()))
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
              final quota = _quotaOf(c);
              String seats(int used, int? max) => max == null
                  ? '$used / ${isAr ? 'بلا حد' : 'unlimited'}'
                  : '$used / $max';
              final active = c['active'] != false;
              final full = quota.employeesFull || quota.usersFull;
              final planSnap = isAr
                  ? (c['planNameAr']?.toString().trim().isNotEmpty == true
                      ? c['planNameAr'].toString()
                      : c['planNameEn']?.toString())
                  : (c['planNameEn']?.toString().trim().isNotEmpty == true
                      ? c['planNameEn'].toString()
                      : c['planNameAr']?.toString());
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
                    [
                      if (planSnap != null && planSnap.isNotEmpty)
                        isAr ? 'الباقة: $planSnap' : 'Plan: $planSnap',
                      isAr
                          ? 'موظفون: ${seats(quota.employeesUsed, quota.employeesMax)} · '
                              'مستخدمون: ${seats(quota.usersUsed, quota.usersMax)} · '
                              '${active ? 'نشطة' : 'موقوفة'}'
                          : 'Employees: ${seats(quota.employeesUsed, quota.employeesMax)} · '
                              'Users: ${seats(quota.usersUsed, quota.usersMax)} · '
                              '${active ? 'Active' : 'Inactive'}',
                    ].join(' · '),
                    style: full ? TextStyle(color: Colors.orange.shade800) : null,
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => _selectCompany(c),
                        child: Text(isAr ? 'اختيار' : 'Select'),
                      ),
                      TextButton(
                        onPressed: () => _editQuota(c),
                        child: Text(isAr ? 'تعديل الحصة' : 'Edit limits'),
                      ),
                      TextButton(
                        onPressed: () => _manageFeatures(c),
                        child: Text(isAr ? 'الميزات' : 'Features'),
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

  CompanyQuota _quotaOf(Map<String, dynamic> c) {
    final q = c['quota'];
    return CompanyQuota.fromJson(q is Map ? Map<String, dynamic>.from(q) : null);
  }
}

class _QuotaFields extends StatelessWidget {
  const _QuotaFields({
    required this.maxEmployeesCtrl,
    required this.maxUsersCtrl,
    required this.isAr,
  });

  final TextEditingController maxEmployeesCtrl;
  final TextEditingController maxUsersCtrl;
  final bool isAr;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: maxEmployeesCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: isAr ? 'أقصى موظفين' : 'Max employees',
              helperText: isAr ? 'يشمل المؤرشفين' : 'Includes archived',
            ),
          ),
        ),
        const Gap(12),
        Expanded(
          child: TextField(
            controller: maxUsersCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: isAr ? 'أقصى مستخدمين' : 'Max users',
              helperText: isAr ? 'حسابات لوحة HR' : 'Dashboard logins',
            ),
          ),
        ),
      ],
    );
  }
}
