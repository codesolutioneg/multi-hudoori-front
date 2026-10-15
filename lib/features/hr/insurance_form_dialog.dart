import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/utils/file_download.dart';
import '../../l10n/l10n_extension.dart';

/// Create / edit س1 or س6 insurance form.
class InsuranceFormDialog extends StatefulWidget {
  const InsuranceFormDialog({
    super.key,
    required this.formType,
    this.existing,
  });

  /// `S1` or `S6`
  final String formType;
  final Map<String, dynamic>? existing;

  @override
  State<InsuranceFormDialog> createState() => _InsuranceFormDialogState();
}

class _InsuranceFormDialogState extends State<InsuranceFormDialog> {
  final _lookupCtrl = TextEditingController();
  final _controllers = <String, TextEditingController>{};
  List<Map<String, dynamic>> _establishments = [];
  String? _establishmentId;
  String? _employeeId;
  bool _loading = true;
  bool _busy = false;
  String? _formId;

  bool get _isS1 => widget.formType.toUpperCase() == 'S1';

  TextEditingController _c(String key, [String initial = '']) {
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(text: initial),
    );
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _lookupCtrl.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final establishments = await api.insuranceEstablishmentsList(
        activeOnly: true,
      );
      final existing = widget.existing;
      if (existing != null) {
        _formId = existing['id']?.toString();
        _employeeId = existing['employeeId']?.toString();
        _establishmentId = existing['establishmentId']?.toString();
        final payload = Map<String, dynamic>.from(
          (existing['payload'] as Map?) ?? {},
        );
        for (final e in payload.entries) {
          _c(e.key, e.value?.toString() ?? '');
        }
      } else {
        _c('issueDate', DateTime.now().toIso8601String().sliceDate);
        if (!_isS1) _c('endReason', '');
      }
      if (!mounted) return;
      setState(() {
        _establishments = establishments;
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

  Future<void> _lookup() async {
    final q = _lookupCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _busy = true);
    try {
      final emp = await api.insuranceFormLookupEmployee(q);
      _employeeId = emp['employeeId']?.toString();
      void fill(String key, dynamic value) {
        _c(key).text = value?.toString() ?? '';
      }

      fill('employeeName', emp['employeeName']);
      fill('employeeCode', emp['employeeCode']);
      fill('insuranceNumber', emp['insuranceNumber']);
      fill('nationalId', emp['nationalId']);
      fill('nationality', emp['nationality']);
      fill('jobTitle', emp['jobTitle']);
      fill('subscriptionStartDate', emp['subscriptionStartDate']);
      fill('subscriptionWage', emp['subscriptionWage']);
      fill('totalWage', emp['totalWage']);
      fill('phone', emp['phone']);
      fill('street', emp['street']);
      if (!_isS1) {
        fill('subscriptionEndDate', emp['departureDate']);
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiError(context, e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyEstablishment(String? id) {
    _establishmentId = id;
    if (id == null) {
      setState(() {});
      return;
    }
    Map<String, dynamic>? est;
    for (final e in _establishments) {
      if (e['id']?.toString() == id) {
        est = e;
        break;
      }
    }
    if (est == null) return;
    void fill(String key, dynamic value) {
      if ((value?.toString() ?? '').isEmpty) return;
      _c(key).text = value.toString();
    }

    fill('establishmentName', est['name']);
    fill('establishmentInsuranceNumber', est['insuranceNumber']);
    fill('office', est['office']);
    fill('establishmentAddress', est['address']);
    fill('buildingNumber', est['buildingNumber']);
    fill('street', est['street']);
    fill('village', est['village']);
    fill('district', est['district']);
    fill('governorate', est['governorate']);
    fill('establishmentType', est['establishmentType']);
    fill('establishmentPhone', est['phone']);
    setState(() {});
  }

  Map<String, dynamic> _payload() {
    final out = <String, dynamic>{};
    for (final e in _controllers.entries) {
      out[e.key] = e.value.text.trim();
    }
    return out;
  }

  Future<void> _save({bool downloadPdf = false}) async {
    setState(() => _busy = true);
    try {
      final form = await api.insuranceFormSave({
        if (_formId != null) 'id': _formId,
        'formType': widget.formType,
        if (_employeeId != null) 'employeeId': _employeeId,
        if (_establishmentId != null) 'establishmentId': _establishmentId,
        'payload': _payload(),
      });
      _formId = form['id']?.toString();
      if (downloadPdf && _formId != null) {
        final file = await api.insuranceFormPdf(_formId!);
        downloadBase64File(
          file['base64']?.toString() ?? '',
          file['filename']?.toString() ?? 'insurance.pdf',
          file['mimeType']?.toString() ?? 'application/pdf',
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiError(context, e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String key, String label, {int maxLines = 1}) {
    return TextField(
      controller: _c(key),
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isS1
        ? context.t('insForm.s1Title')
        : context.t('insForm.s6Title');
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 720,
        child: _loading
            ? const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.t('insForm.lookupHint'),
                      style: AppThemeV2.caption,
                    ),
                    const Gap(8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _lookupCtrl,
                            decoration: InputDecoration(
                              labelText: context.t('insForm.lookupField'),
                            ),
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _lookup(),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9A-Za-z]'),
                              ),
                            ],
                          ),
                        ),
                        const Gap(8),
                        FilledButton(
                          onPressed: _busy ? null : _lookup,
                          child: Text(context.t('insForm.lookup')),
                        ),
                      ],
                    ),
                    const Gap(12),
                    DropdownButtonFormField<String?>(
                      value: _establishmentId,
                      decoration: InputDecoration(
                        labelText: context.t('insForm.establishment'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(context.t('insForm.establishmentManual')),
                        ),
                        for (final e in _establishments)
                          DropdownMenuItem(
                            value: e['id']?.toString(),
                            child: Text(e['name']?.toString() ?? ''),
                          ),
                      ],
                      onChanged: _busy ? null : _applyEstablishment,
                    ),
                    const Gap(12),
                    Text(
                      context.t('insForm.employeeSection'),
                      style: AppThemeV2.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(8),
                    _field('employeeName', context.t('insForm.employeeName')),
                    const Gap(8),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            'insuranceNumber',
                            context.t('insForm.insuranceNumber'),
                          ),
                        ),
                        const Gap(8),
                        Expanded(
                          child: _field(
                            'nationalId',
                            context.t('insForm.nationalId'),
                          ),
                        ),
                      ],
                    ),
                    const Gap(8),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            'jobTitle',
                            context.t('insForm.jobTitle'),
                          ),
                        ),
                        const Gap(8),
                        Expanded(
                          child: _field('phone', context.t('insForm.phone')),
                        ),
                      ],
                    ),
                    if (_isS1) ...[
                      const Gap(8),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              'nationality',
                              context.t('insForm.nationality'),
                            ),
                          ),
                          const Gap(8),
                          Expanded(
                            child: _field(
                              'qualification',
                              context.t('insForm.qualification'),
                            ),
                          ),
                        ],
                      ),
                      const Gap(8),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              'subscriptionStartDate',
                              context.t('insForm.subscriptionStart'),
                            ),
                          ),
                          const Gap(8),
                          Expanded(
                            child: _field(
                              'subscriptionWage',
                              context.t('insForm.subscriptionWage'),
                            ),
                          ),
                        ],
                      ),
                      const Gap(8),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              'sector',
                              context.t('insForm.sector'),
                            ),
                          ),
                          const Gap(8),
                          Expanded(
                            child: _field(
                              'subscriptionCode',
                              context.t('insForm.subscriptionCode'),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const Gap(8),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              'subscriptionEndDate',
                              context.t('insForm.subscriptionEnd'),
                            ),
                          ),
                          const Gap(8),
                          Expanded(
                            child: _field(
                              'endReason',
                              context.t('insForm.endReason'),
                            ),
                          ),
                        ],
                      ),
                      const Gap(8),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              'noticeNumber',
                              context.t('insForm.noticeNumber'),
                            ),
                          ),
                          const Gap(8),
                          Expanded(
                            child: _field(
                              'noticeDate',
                              context.t('insForm.noticeDate'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Gap(16),
                    Text(
                      context.t('insForm.establishmentSection'),
                      style: AppThemeV2.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(8),
                    _field(
                      'establishmentName',
                      context.t('insForm.establishmentName'),
                    ),
                    const Gap(8),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            'establishmentInsuranceNumber',
                            context.t('insForm.establishmentInsuranceNumber'),
                          ),
                        ),
                        const Gap(8),
                        Expanded(
                          child: _field('office', context.t('insForm.office')),
                        ),
                      ],
                    ),
                    const Gap(8),
                    _field(
                      'establishmentAddress',
                      context.t('insForm.establishmentAddress'),
                      maxLines: 2,
                    ),
                    if (_isS1) ...[
                      const Gap(8),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              'buildingNumber',
                              context.t('insForm.buildingNumber'),
                            ),
                          ),
                          const Gap(8),
                          Expanded(
                            child: _field(
                              'street',
                              context.t('insForm.street'),
                            ),
                          ),
                        ],
                      ),
                      const Gap(8),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              'district',
                              context.t('insForm.district'),
                            ),
                          ),
                          const Gap(8),
                          Expanded(
                            child: _field(
                              'governorate',
                              context.t('insForm.governorate'),
                            ),
                          ),
                        ],
                      ),
                      const Gap(8),
                      _field(
                        'establishmentType',
                        context.t('insForm.establishmentType'),
                      ),
                    ],
                    const Gap(16),
                    Text(
                      context.t('insForm.applicantSection'),
                      style: AppThemeV2.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(8),
                    _field('applicantName', context.t('insForm.applicantName')),
                    const Gap(8),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            'applicantRole',
                            context.t('insForm.applicantRole'),
                          ),
                        ),
                        const Gap(8),
                        Expanded(
                          child: _field(
                            'applicantPhone',
                            context.t('insForm.applicantPhone'),
                          ),
                        ),
                      ],
                    ),
                    const Gap(8),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            'applicantInsuranceNumber',
                            context.t('insForm.applicantInsuranceNumber'),
                          ),
                        ),
                        const Gap(8),
                        Expanded(
                          child: _field(
                            'applicantNationalId',
                            context.t('insForm.applicantNationalId'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(context.t('common.cancel')),
        ),
        OutlinedButton(
          onPressed: _busy ? null : () => _save(downloadPdf: false),
          child: Text(context.t('insForm.save')),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : () => _save(downloadPdf: true),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: Text(context.t('insForm.saveAndPdf')),
        ),
      ],
    );
  }
}

extension on String {
  String get sliceDate => length >= 10 ? substring(0, 10) : this;
}
