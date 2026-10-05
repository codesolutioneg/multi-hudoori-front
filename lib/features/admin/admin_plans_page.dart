import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/widgets/page_header.dart';
import '../../l10n/l10n_extension.dart';

class AdminPlansPage extends StatefulWidget {
  const AdminPlansPage({super.key});

  @override
  State<AdminPlansPage> createState() => _AdminPlansPageState();
}

class _AdminPlansPageState extends State<AdminPlansPage> {
  List<Map<String, dynamic>> _plans = [];
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
      final data = await api.adminPlansList();
      final raw = data['plans'];
      final list = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _plans = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyApiError(context, e);
        });
      }
    }
  }

  List<String> _asStringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    return [];
  }

  Future<void> _setStatus(Map<String, dynamic> plan, String status) async {
    final isAr = context.l10n.isAr;
    try {
      await api.adminPlansSetStatus(id: plan['id'].toString(), status: status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAr ? 'تم تحديث الحالة' : 'Status updated')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(context, e))),
        );
      }
    }
  }

  Future<void> _editPlan(Map<String, dynamic>? plan) async {
    final isAr = context.l10n.isAr;
    List<Map<String, dynamic>> catalog = [];
    try {
      final catData = await api.adminPlansFeatureCatalog();
      final rawCat = catData['features'];
      if (rawCat is List) {
        catalog = rawCat.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAr ? 'تعذّر تحميل كتالوج الميزات' : 'Could not load feature catalog')),
        );
      }
    }
    final slug = TextEditingController(text: plan?['slug']?.toString() ?? '');
    final nameAr = TextEditingController(text: plan?['nameAr']?.toString() ?? '');
    final nameEn = TextEditingController(text: plan?['nameEn']?.toString() ?? '');
    final descAr = TextEditingController(text: plan?['descriptionAr']?.toString() ?? '');
    final descEn = TextEditingController(text: plan?['descriptionEn']?.toString() ?? '');
    final priceAr = TextEditingController(text: plan?['priceDisplayAr']?.toString() ?? '');
    final priceEn = TextEditingController(text: plan?['priceDisplayEn']?.toString() ?? '');
    final maxEmp = TextEditingController(text: plan?['defaultMaxEmployees']?.toString() ?? '');
    final maxUsers = TextEditingController(text: plan?['defaultMaxUsers']?.toString() ?? '');
    final sort = TextEditingController(text: plan?['sortOrder']?.toString() ?? '0');
    final featuresAr = List<TextEditingController>.from(
      _asStringList(plan?['featuresAr']).map((e) => TextEditingController(text: e)),
    );
    final featuresEn = List<TextEditingController>.from(
      _asStringList(plan?['featuresEn']).map((e) => TextEditingController(text: e)),
    );
    if (featuresAr.isEmpty) featuresAr.add(TextEditingController());
    if (featuresEn.isEmpty) featuresEn.add(TextEditingController());
    var highlighted = plan?['highlighted'] == true;
    final selectedFeatureKeys = {..._asStringList(plan?['featureKeys'])};

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Widget featureEditor({
            required String title,
            required List<TextEditingController> ctrls,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const Gap(8),
                for (var i = 0; i < ctrls.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ctrls[i],
                            decoration: InputDecoration(
                              labelText: isAr ? 'سطر ${i + 1}' : 'Line ${i + 1}',
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: ctrls.length <= 1
                              ? null
                              : () => setLocal(() => ctrls.removeAt(i)),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => setLocal(() => ctrls.add(TextEditingController())),
                    icon: const Icon(Icons.add),
                    label: Text(isAr ? 'إضافة سطر' : 'Add line'),
                  ),
                ),
              ],
            );
          }

          return AlertDialog(
            title: Text(plan == null ? (isAr ? 'باقة جديدة' : 'New plan') : (isAr ? 'تعديل الباقة (كل الأسطر)' : 'Edit plan (every line)')),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: slug, decoration: const InputDecoration(labelText: 'Slug')),
                    TextField(controller: nameAr, decoration: InputDecoration(labelText: isAr ? 'العنوان (ع)' : 'Title (AR)')),
                    TextField(controller: nameEn, decoration: InputDecoration(labelText: isAr ? 'العنوان (EN)' : 'Title (EN)')),
                    TextField(controller: descAr, decoration: InputDecoration(labelText: isAr ? 'الوصف (ع)' : 'Description (AR)'), maxLines: 2),
                    TextField(controller: descEn, decoration: InputDecoration(labelText: isAr ? 'الوصف (EN)' : 'Description (EN)'), maxLines: 2),
                    TextField(controller: priceAr, decoration: InputDecoration(labelText: isAr ? 'السعر المعروض (ع) — مثال \$2 أو حسب الطلب' : 'Price display (AR)')),
                    TextField(controller: priceEn, decoration: InputDecoration(labelText: isAr ? 'السعر المعروض (EN) — e.g. \$2 or Custom' : 'Price display (EN)')),
                    TextField(controller: maxEmp, decoration: InputDecoration(labelText: isAr ? 'حد موظفين افتراضي' : 'Default max employees'), keyboardType: TextInputType.number),
                    TextField(controller: maxUsers, decoration: InputDecoration(labelText: isAr ? 'حد مستخدمين' : 'Default max users'), keyboardType: TextInputType.number),
                    TextField(controller: sort, decoration: InputDecoration(labelText: isAr ? 'ترتيب العرض' : 'Sort order'), keyboardType: TextInputType.number),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(isAr ? 'الأكثر رواجاً (highlighted)' : 'Most popular (highlighted)'),
                      value: highlighted,
                      onChanged: (v) => setLocal(() => highlighted = v),
                    ),
                    const Gap(8),
                    featureEditor(title: isAr ? 'مميزات البطاقة (عربي) — كل سطر' : 'Card features (AR) — each line', ctrls: featuresAr),
                    const Gap(12),
                    featureEditor(title: isAr ? 'مميزات البطاقة (EN) — كل سطر' : 'Card features (EN) — each line', ctrls: featuresEn),
                    if (catalog.isNotEmpty) ...[
                      const Gap(16),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          isAr ? 'صلاحيات المنتج (entitlements)' : 'Product entitlements',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Gap(8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final f in catalog)
                            FilterChip(
                              label: Text(
                                isAr ? (f['nameAr'] ?? f['key']).toString() : (f['nameEn'] ?? f['key']).toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: selectedFeatureKeys.contains(f['key']?.toString()),
                              onSelected: (v) => setLocal(() {
                                final k = f['key']?.toString() ?? '';
                                if (k.isEmpty) return;
                                if (v) {
                                  selectedFeatureKeys.add(k);
                                } else {
                                  selectedFeatureKeys.remove(k);
                                }
                              }),
                            ),
                        ],
                      ),
                    ],
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

    final featAr = featuresAr.map((c) => c.text.trim()).where((e) => e.isNotEmpty).toList();
    final featEn = featuresEn.map((c) => c.text.trim()).where((e) => e.isNotEmpty).toList();

    try {
      if (plan == null) {
        await api.adminPlansCreate(
          slug: slug.text.trim(),
          nameAr: nameAr.text.trim(),
          nameEn: nameEn.text.trim(),
          descriptionAr: descAr.text.trim(),
          descriptionEn: descEn.text.trim(),
          priceDisplayAr: priceAr.text.trim(),
          priceDisplayEn: priceEn.text.trim(),
          featuresAr: featAr,
          featuresEn: featEn,
          defaultMaxEmployees: int.tryParse(maxEmp.text.trim()),
          defaultMaxUsers: int.tryParse(maxUsers.text.trim()),
          sortOrder: int.tryParse(sort.text.trim()) ?? 0,
          highlighted: highlighted,
          status: 'DRAFT',
          featureKeys: selectedFeatureKeys.toList(),
        );
      } else {
        await api.adminPlansUpdate(
          id: plan['id'].toString(),
          slug: slug.text.trim(),
          nameAr: nameAr.text.trim(),
          nameEn: nameEn.text.trim(),
          descriptionAr: descAr.text.trim(),
          descriptionEn: descEn.text.trim(),
          priceDisplayAr: priceAr.text.trim(),
          priceDisplayEn: priceEn.text.trim(),
          featuresAr: featAr,
          featuresEn: featEn,
          defaultMaxEmployees: int.tryParse(maxEmp.text.trim()),
          defaultMaxUsers: int.tryParse(maxUsers.text.trim()),
          sortOrder: int.tryParse(sort.text.trim()),
          highlighted: highlighted,
          featureKeys: selectedFeatureKeys.toList(),
        );
      }
      _load();
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
    final isAr = context.l10n.isAr;
    return AppPageScaffold(
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: isAr ? 'باقات الاشتراك' : 'Subscription plans',
            subtitle: isAr
                ? 'عدّل كل سطر في كارت الـlanding (عنوان، وصف، سعر، مميزات) — نشر/مسودة بدون حذف'
                : 'Edit every landing-card line (title, desc, price, features) — publish/draft, no delete',
            actions: [
              FilledButton.icon(
                onPressed: () => _editPlan(null),
                icon: const Icon(Icons.add),
                label: Text(isAr ? 'باقة جديدة' : 'New plan'),
              ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          const Gap(16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _plans.isEmpty
                        ? Center(child: Text(isAr ? 'لا توجد باقات' : 'No plans'))
                        : ListView.separated(
                            itemCount: _plans.length,
                            separatorBuilder: (_, __) => const Gap(14),
                            itemBuilder: (_, i) {
                              final p = _plans[i];
                              final status = p['status']?.toString() ?? '';
                              final highlighted = p['highlighted'] == true;
                              final title = isAr ? (p['nameAr'] ?? '') : (p['nameEn'] ?? '');
                              final desc = isAr ? (p['descriptionAr'] ?? '') : (p['descriptionEn'] ?? '');
                              final price = isAr ? (p['priceDisplayAr'] ?? '') : (p['priceDisplayEn'] ?? '');
                              final feats = _asStringList(isAr ? p['featuresAr'] : p['featuresEn']);
                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: highlighted ? const Color(0xFF6366F1) : Colors.grey.shade200,
                                    width: highlighted ? 1.5 : 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '$title (${p['slug']})',
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                                            ),
                                          ),
                                          if (highlighted)
                                            Chip(
                                              label: Text(isAr ? 'الأكثر رواجاً' : 'Popular'),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          Chip(
                                            label: Text(status),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ],
                                      ),
                                      if (desc.toString().isNotEmpty) ...[
                                        const Gap(6),
                                        Text(desc.toString(), style: TextStyle(color: Colors.grey.shade700)),
                                      ],
                                      const Gap(8),
                                      Text(
                                        price.toString(),
                                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                                      ),
                                      const Gap(10),
                                      for (final f in feats)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A)),
                                              const Gap(8),
                                              Expanded(child: Text(f)),
                                            ],
                                          ),
                                        ),
                                      const Gap(8),
                                      Text(
                                        isAr
                                            ? 'حد موظفين: ${p['defaultMaxEmployees'] ?? '—'} · مستخدمين: ${p['defaultMaxUsers'] ?? '—'}'
                                            : 'Max emp: ${p['defaultMaxEmployees'] ?? '—'} · users: ${p['defaultMaxUsers'] ?? '—'}',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      ),
                                      const Gap(12),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => _editPlan(p),
                                            icon: const Icon(Icons.edit_outlined),
                                            label: Text(isAr ? 'تعديل كل الأسطر' : 'Edit all lines'),
                                          ),
                                          if (status == 'PUBLISHED')
                                            TextButton(
                                              onPressed: () => _setStatus(p, 'DRAFT'),
                                              child: Text(isAr ? 'تحويل لمسودة' : 'Set draft'),
                                            )
                                          else
                                            TextButton(
                                              onPressed: () => _setStatus(p, 'PUBLISHED'),
                                              child: Text(isAr ? 'نشر على الـlanding' : 'Publish to landing'),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
