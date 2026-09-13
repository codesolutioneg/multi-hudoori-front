import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/router/app_router.dart';
import '../../data/api/biotime_api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/egyptian_national_id.dart';
import '../../core/utils/english_text.dart';
import '../../core/utils/file_download.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/l10n_extension.dart';
import '../auth/auth_cubit.dart';

class HiringAppointmentCreatePage extends StatefulWidget {
  const HiringAppointmentCreatePage({super.key});

  @override
  State<HiringAppointmentCreatePage> createState() => _HiringAppointmentCreatePageState();
}

class _HiringAppointmentCreatePageState extends State<HiringAppointmentCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _nationalId = TextEditingController();
  final _job = TextEditingController();
  final _code = TextEditingController();
  String? _locationId;
  List<Map<String, dynamic>> _locations = [];
  DateTime _appointmentDate = DateTime.now();
  DateTime _firstWorkingDay = DateTime.now().add(const Duration(days: 1));
  bool _loading = true;
  bool _saving = false;
  bool _skipNationalId = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _nationalId.dispose();
    _job.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final scoped = context.read<AuthCubit>().state.scopedLocationId;
    try {
      final locations = await api.locationsList(activeOnly: true);
      if (!mounted) return;
      setState(() {
        _locations = locations;
        _locationId = scoped != null && scoped.isNotEmpty ? scoped : null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      _snack(e.toString());
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool appointment) async {
    final current = appointment ? _appointmentDate : _firstWorkingDay;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (appointment) {
        _appointmentDate = picked;
      } else {
        _firstWorkingDay = picked;
      }
    });
  }

  Map<String, dynamic> _createBody() {
    return {
      'appointmentDate': _iso(_appointmentDate),
      'employeeName': _name.text.trim(),
      'mobilePhone': _phone.text.trim(),
      'nationalId': _skipNationalId ? '' : _nationalId.text.trim(),
      'skipNationalId': _skipNationalId,
      'jobTitle': _job.text.trim(),
      'fingerprintCode': _code.text.trim(),
      'firstWorkingDay': _iso(_firstWorkingDay),
      if (_locationId != null) 'locationId': _locationId,
    };
  }

  Future<void> _showExistingAppointmentDialog(Map<String, dynamic> existing) async {
    final name = existing['employeeName']?.toString() ?? '';
    final code = existing['fingerprintCode']?.toString() ?? _code.text.trim();
    final job = existing['jobTitle']?.toString() ?? '';
    final branch = existing['locationName']?.toString() ?? '';
    final status = existing['status']?.toString() ?? '';
    final id = existing['id']?.toString() ?? '';
    final open = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('hire.existsInAppointments')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('hire.existsInAppointmentsBody')),
            const SizedBox(height: 12),
            if (name.isNotEmpty) Text(context.t('hire.fieldName', {'value': name})),
            if (code.isNotEmpty) Text(context.t('hire.fieldCode', {'value': code})),
            if (job.isNotEmpty) Text(context.t('hire.fieldJob', {'value': job})),
            if (branch.isNotEmpty) Text(context.t('hire.fieldBranch', {'value': branch})),
            if (status.isNotEmpty) Text(context.t('hire.fieldStatus', {'value': status})),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('common.cancel')),
          ),
          FilledButton(
            onPressed: id.isEmpty ? null : () => Navigator.pop(ctx, true),
            child: Text(context.t('hire.openAppointment')),
          ),
        ],
      ),
    );
    if (open == true && mounted) {
      context.go('${AppRoutes.hrHiringAppointments}?highlight=$id');
    }
  }

  Future<void> _showExistingEmployeeDialog(Map<String, dynamic> existing) async {
    final name = existing['name']?.toString() ?? '';
    final code = existing['code']?.toString() ?? _code.text.trim();
    final job = existing['jobTitle']?.toString() ?? '';
    final branch = existing['locationName']?.toString() ?? '';
    final id = existing['id']?.toString() ?? '';
    final open = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('hire.existsOnEmployee')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('hire.existsOnEmployeeBody')),
            const SizedBox(height: 12),
            if (name.isNotEmpty) Text(context.t('hire.fieldName', {'value': name})),
            if (code.isNotEmpty) Text(context.t('hire.fieldCode', {'value': code})),
            if (job.isNotEmpty) Text(context.t('hire.fieldJob', {'value': job})),
            if (branch.isNotEmpty) Text(context.t('hire.fieldBranch', {'value': branch})),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('common.cancel')),
          ),
          FilledButton(
            onPressed: id.isEmpty ? null : () => Navigator.pop(ctx, true),
            child: Text(context.t('hire.openEmployee')),
          ),
        ],
      ),
    );
    if (open == true && mounted && id.isNotEmpty) {
      context.go(AppRoutes.hrEmployeeDetail(id));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_skipNationalId) {
      final nidErr = validateEgyptianNationalId(context, _nationalId.text);
      if (nidErr != null) {
        _snack(nidErr);
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final result = await api.hiringAppointmentCreate(_createBody());
      if (!mounted) return;
      final appointment = result['appointment'] as Map?;
      final id = appointment?['id']?.toString();
      _snack(result['message']?.toString() ?? context.t('hire.created'));
      if (id != null && id.isNotEmpty) {
        try {
          final pdf = await api.hiringAppointmentPdf(id);
          downloadBase64File(
            pdf['base64']?.toString() ?? '',
            pdf['filename']?.toString() ?? 'hiring.pdf',
            'application/pdf',
          );
        } catch (_) {}
      }
      if (!mounted) return;
      context.go(AppRoutes.hrHiringAppointments);
    } on BioTimeApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (e.code == 'EXISTING_APPOINTMENT') {
        final existing = e.data['existingAppointment'];
        await _showExistingAppointmentDialog(
          existing is Map ? Map<String, dynamic>.from(existing) : <String, dynamic>{},
        );
        return;
      }
      if (e.code == 'EXISTING_EMPLOYEE') {
        final existing = e.data['existingEmployee'];
        await _showExistingEmployeeDialog(
          existing is Map ? Map<String, dynamic>.from(existing) : <String, dynamic>{},
        );
        return;
      }
      _snack(e.toString());
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final locationLocked = context.read<AuthCubit>().state.isLocationScoped;
    final nidInfo = parseEgyptianNationalId(_nationalId.text);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.t('hiring.createTitle'),
            subtitle: context.t('hiring.createSubtitle'),
            icon: Icons.person_add_alt_1_rounded,
            onBack: () => context.go(AppRoutes.hrHiringAppointments),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: SellixCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.t('common.date')),
                        subtitle: Text(_iso(_appointmentDate)),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => _pickDate(true),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _name,
                        decoration: InputDecoration(labelText: context.t('hire.nameReq')),
                        validator: (v) => (v?.trim().length ?? 0) < 2 ? context.t('hire.nameRequired') : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(labelText: context.t('hire.mobileReq')),
                        validator: (v) => (v?.trim().length ?? 0) < 8 ? context.t('hire.phoneRequired') : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nationalId,
                        enabled: !_skipNationalId,
                        keyboardType: TextInputType.number,
                        maxLength: 14,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: _skipNationalId ? context.t('hire.idSkipped') : context.t('hire.idNumberReq'),
                          counterText: '',
                          errorText: _skipNationalId || _nationalId.text.isEmpty
                              ? null
                              : validateEgyptianNationalId(context, _nationalId.text),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _skipNationalId,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(context.t('hire.skipNid')),
                        subtitle: Text(context.t('hire.skipNidHint')),
                        onChanged: (v) {
                          setState(() {
                            _skipNationalId = v == true;
                            if (_skipNationalId) _nationalId.clear();
                          });
                        },
                      ),
                      if (!_skipNationalId && nidInfo.birthDate != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          context.t('emp.birthAndAge', {'date': formatBirthDateIso(nidInfo.birthDate!), 'age': nidInfo.age ?? '—'}),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _job,
                        decoration: InputDecoration(labelText: context.t('hire.jobReq')),
                        validator: (v) => (v?.trim().isEmpty ?? true) ? context.t('hire.jobRequired') : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        value: _locationId,
                        decoration: InputDecoration(labelText: context.t('hire.branchReq')),
                        items: [
                          for (final l in _locations)
                            DropdownMenuItem(value: l['id']?.toString(), child: Text(l['name']?.toString() ?? '')),
                        ],
                        onChanged: locationLocked ? null : (v) => setState(() => _locationId = v),
                        validator: (v) => v == null || v.isEmpty ? context.t('hire.pickBranch') : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _code,
                        decoration: InputDecoration(
                          labelText: context.t('hire.codeReq'),
                          hintText: 'English / numbers',
                          helperText: context.t('hire.codeCharset'),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
                        ],
                        validator: (v) => validateEnglishCode(context, v),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.t('hire.firstDayReq')),
                        subtitle: Text(_iso(_firstWorkingDay)),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => _pickDate(false),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(_saving ? context.t('common.saving') : context.t('hire.saveAndPdf')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
