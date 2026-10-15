import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/utils/file_download.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../core/widgets/status_tag.dart';
import '../../l10n/l10n_extension.dart';
import 'insurance_form_dialog.dart';

class InsuranceFormsPage extends StatefulWidget {
  const InsuranceFormsPage({super.key});

  @override
  State<InsuranceFormsPage> createState() => _InsuranceFormsPageState();
}

class _InsuranceFormsPageState extends State<InsuranceFormsPage> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _typeFilter;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final data = await api.insuranceFormsList(
        formType: _typeFilter,
        search: _searchCtrl.text.trim(),
      );
      final items = (data['items'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiError(context, e))),
      );
    }
  }

  Future<void> _openCreate(String type) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => InsuranceFormDialog(formType: type),
    );
    if (changed == true) await _reload();
  }

  Future<void> _openExisting(Map<String, dynamic> form) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => InsuranceFormDialog(
        formType: form['formType']?.toString() ?? 'S1',
        existing: form,
      ),
    );
    if (changed == true) await _reload();
  }

  Future<void> _downloadPdf(Map<String, dynamic> form) async {
    final id = form['id'];
    if (id == null) return;
    try {
      final file = await api.insuranceFormPdf(id);
      downloadBase64File(
        file['base64']?.toString() ?? '',
        file['filename']?.toString() ?? 'insurance.pdf',
        file['mimeType']?.toString() ?? 'application/pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiError(context, e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.t('insForm.pageTitle'),
            subtitle: context.t('insForm.pageSubtitle'),
            icon: Icons.policy_outlined,
            actions: [
              OutlinedButton.icon(
                onPressed: () => _openCreate('S6'),
                icon: const Icon(Icons.note_add_outlined, size: 18),
                label: Text(context.t('insForm.newS6')),
              ),
              FilledButton.icon(
                onPressed: () => _openCreate('S1'),
                icon: const Icon(Icons.note_add, size: 18),
                label: Text(context.t('insForm.newS1')),
              ),
            ],
          ),
          const Gap(16),
          SellixCard(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      labelText: context.t('insForm.search'),
                      prefixIcon: const Icon(Icons.search, size: 20),
                    ),
                    onSubmitted: (_) => _reload(),
                  ),
                ),
                const Gap(12),
                DropdownButton<String?>(
                  value: _typeFilter,
                  hint: Text(context.t('common.all')),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(context.t('common.all')),
                    ),
                    DropdownMenuItem(
                      value: 'S1',
                      child: Text(context.t('insForm.typeS1')),
                    ),
                    DropdownMenuItem(
                      value: 'S6',
                      child: Text(context.t('insForm.typeS6')),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _typeFilter = v);
                    _reload();
                  },
                ),
                const Gap(8),
                IconButton(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  tooltip: context.t('common.refresh'),
                ),
              ],
            ),
          ),
          const Gap(16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? SellixCard(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(context.t('insForm.empty')),
                          ),
                        ),
                      )
                    : SellixCard(
                        padding: EdgeInsets.zero,
                        child: ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final f = _items[i];
                            final type = f['formTypeLabel']?.toString() ??
                                f['formType']?.toString() ??
                                '';
                            final created =
                                f['createdAt']?.toString().split('T').first ??
                                    '';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppThemeV2.primarySoft,
                                child: Text(
                                  type,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Text(
                                f['employeeName']?.toString() ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  if ((f['employeeCode']?.toString() ?? '')
                                      .isNotEmpty)
                                    f['employeeCode'],
                                  if ((f['insuranceNumber']?.toString() ?? '')
                                      .isNotEmpty)
                                    f['insuranceNumber'],
                                  created,
                                  f['createdByName'],
                                ].whereType<String>().where((e) => e.isNotEmpty).join(' · '),
                              ),
                              trailing: Wrap(
                                spacing: 6,
                                children: [
                                  StatusTag(
                                    label: type,
                                    type: type.contains('1')
                                        ? StatusTagType.info
                                        : StatusTagType.warning,
                                  ),
                                  IconButton(
                                    tooltip: context.t('insForm.downloadPdf'),
                                    onPressed: () => _downloadPdf(f),
                                    icon: const Icon(
                                      Icons.picture_as_pdf_outlined,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: context.t('insForm.open'),
                                    onPressed: () => _openExisting(f),
                                    icon: const Icon(Icons.open_in_new),
                                  ),
                                ],
                              ),
                              onTap: () => _openExisting(f),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
