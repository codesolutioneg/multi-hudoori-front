import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/egyptian_national_id.dart';
import '../../core/utils/english_text.dart';
import '../../core/utils/file_download.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/l10n_extension.dart';
import '../auth/auth_cubit.dart';

class HiringAppointmentsPage extends StatefulWidget {
  const HiringAppointmentsPage({super.key});

  @override
  State<HiringAppointmentsPage> createState() => _HiringAppointmentsPageState();
}

class _HiringAppointmentsPageState extends State<HiringAppointmentsPage> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final isHr = context.read<AuthCubit>().state.roles.isHrStaff;
      if (isHr) {
        await api.hiringAppointmentsMarkSeen();
      }
      final items = await api.hiringAppointmentsList();
      List<Map<String, dynamic>> locations = [];
      if (isHr) {
        locations = await api.locationsList(activeOnly: true);
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _locations = locations;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _downloadPdf(String id) async {
    try {
      final file = await api.hiringAppointmentPdf(id);
      downloadBase64File(
        file['base64']?.toString() ?? '',
        file['filename']?.toString() ?? 'hiring.pdf',
        'application/pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _editAppointment(Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final name = TextEditingController(text: row['employeeName']?.toString() ?? '');
    final phone = TextEditingController(text: row['mobilePhone']?.toString() ?? '');
    final nationalId = TextEditingController(text: row['nationalId']?.toString() ?? '');
    final job = TextEditingController(text: row['jobTitle']?.toString() ?? '');
    final code = TextEditingController(text: row['fingerprintCode']?.toString() ?? '');
    String? locationId = row['locationId']?.toString();
    if (locationId != null && locationId.isEmpty) locationId = null;

    final status = row['status']?.toString() ?? 'pending';
    var appointmentDate = _parseDate(row['appointmentDate']?.toString()) ?? DateTime.now();
    var firstWorkingDay = _parseDate(row['firstWorkingDay']?.toString()) ?? DateTime.now();
    var selectedStatus = status;
    final statusNote = TextEditingController(text: row['statusNote']?.toString() ?? '');
    var saving = false;

    final auth = context.read<AuthCubit>().state;
    final locationLocked = auth.isLocationScoped;

    // Keep current branch selectable even if not in active locations list
    // (otherwise DropdownButtonFormField throws and Save appears to do nothing).
    final locationItems = <DropdownMenuItem<String?>>[
      for (final l in _locations)
        DropdownMenuItem(
          value: l['id']?.toString(),
          child: Text(l['name']?.toString() ?? ''),
        ),
    ];
    if (locationId != null &&
        locationItems.every((i) => i.value != locationId)) {
      locationItems.insert(
        0,
        DropdownMenuItem(
          value: locationId,
          child: Text(row['locationName']?.toString() ?? locationId),
        ),
      );
    }

    final saved = await showDialog<String?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickDate(bool appointment) async {
            final current = appointment ? appointmentDate : firstWorkingDay;
            final picked = await showDatePicker(
              context: ctx,
              initialDate: current,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked == null) return;
            setDialogState(() {
              if (appointment) {
                appointmentDate = picked;
              } else {
                firstWorkingDay = picked;
              }
            });
          }

          return AlertDialog(
            title: Text(context.t('hire.editTitle')),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.t('common.date')),
                      subtitle: Text(_iso(appointmentDate)),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () => pickDate(true),
                      ),
                    ),
                    TextField(
                      controller: name,
                      decoration: InputDecoration(labelText: context.t('hire.name')),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(labelText: context.t('hire.mobile')),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nationalId,
                      keyboardType: TextInputType.number,
                      maxLength: 14,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: context.t('hire.idNumber'),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: job,
                      decoration: InputDecoration(labelText: context.t('hire.job')),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      value: locationId,
                      decoration: InputDecoration(labelText: context.t('hire.branch')),
                      items: locationItems,
                      onChanged: locationLocked ? null : (v) => setDialogState(() => locationId = v),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: code,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
                      ],
                      decoration: InputDecoration(
                        labelText: context.t('hire.code'),
                        helperText: context.t('hire.codeCharset'),
                      ),
                    ),
                    SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.t('hire.firstDay')),
                      subtitle: Text(_iso(firstWorkingDay)),
                      trailing: IconButton(
                        icon: Icon(Icons.calendar_today),
                        onPressed: () => pickDate(false),
                      ),
                    ),
                    if (status == 'pending') ...[
                      SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: InputDecoration(labelText: context.t('common.status')),
                        items: [
                          DropdownMenuItem(value: 'pending', child: Text(context.t('hire.pending'))),
                          DropdownMenuItem(value: 'approved', child: Text(context.t('hire.approved'))),
                          DropdownMenuItem(value: 'rejected', child: Text(context.t('hire.rejected'))),
                          DropdownMenuItem(value: 'cancelled', child: Text(context.t('hire.cancelled'))),
                        ],
                        onChanged: (v) => setDialogState(() => selectedStatus = v ?? 'pending'),
                      ),
                      if (selectedStatus == 'cancelled') ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: statusNote,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: context.t('hiring.cancel.note'),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: Text(context.t('common.cancel'))),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (name.text.trim().length < 2) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(context.t('hire.nameRequired'))));
                          return;
                        }
                        if (job.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(context.t('hire.jobRequired'))));
                          return;
                        }
                        final codeErr = validateEnglishCode(ctx, code.text);
                        if (codeErr != null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(codeErr)));
                          return;
                        }
                        final nidErr = validateEgyptianNationalId(ctx, nationalId.text);
                        if (nidErr != null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(nidErr)));
                          return;
                        }
                        if (status == 'pending' && selectedStatus == 'cancelled' && statusNote.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(context.t('hiring.cancel.note'))),
                          );
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          final result = await api.hiringAppointmentUpdate({
                            'appointmentId': id,
                            'appointmentDate': _iso(appointmentDate),
                            'employeeName': name.text.trim(),
                            'mobilePhone': phone.text.trim(),
                            'nationalId': nationalId.text.trim(),
                            'jobTitle': job.text.trim(),
                            'fingerprintCode': code.text.trim(),
                            'firstWorkingDay': _iso(firstWorkingDay),
                            if (locationId != null) 'locationId': locationId,
                            if (status == 'pending' && selectedStatus != status) 'status': selectedStatus,
                            if (status == 'pending' && selectedStatus == 'cancelled')
                              'statusNote': statusNote.text.trim(),
                          });
                          if (ctx.mounted) {
                            Navigator.pop(ctx, result['message']?.toString());
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
                            setDialogState(() => saving = false);
                          }
                        }
                      },
                child: Text(saving ? context.t('common.saving') : context.t('common.save')),
              ),
            ],
          );
        },
      ),
    );

    name.dispose();
    phone.dispose();
    nationalId.dispose();
    job.dispose();
    code.dispose();
    statusNote.dispose();

    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(saved)));
      await _load();
    }
  }

  Future<void> _cancelWithNote(Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final noteCtrl = TextEditingController();
    var saving = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(context.t('hiring.cancel.title')),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${row['employeeName'] ?? ''}'),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.t('hiring.cancel.note'),
                    hintText: context.t('hire.cancelReason'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(ctx, false), child: Text(context.t('common.back'))),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (noteCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(context.t('hiring.cancel.note'))),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await api.hiringAppointmentUpdate({
                          'appointmentId': id,
                          'status': 'cancelled',
                          'statusNote': noteCtrl.text.trim(),
                        });
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? context.t('hire.cancelling') : context.t('hiring.cancel.confirm')),
            ),
          ],
        ),
      ),
    );

    noteCtrl.dispose();
    if (ok != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('hire.cancelled2'))));
    await _load();
  }

  Future<void> _resend(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('hiring.resend')),
        content: Text(context.t('hiring.resend.confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('common.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.t('hiring.resend'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final result = await api.hiringAppointmentUpdate({
        'appointmentId': row['id'],
        'status': 'pending',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? context.t('hire.resent'))),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  bool _canEditAppointment(bool isHr, bool isBranchManager, String status) {
    if (isHr) return status != 'approved';
    if (isBranchManager) {
      return status == 'pending' || status == 'cancelled' || status == 'rejected';
    }
    return false;
  }

  bool _canActOnPending(bool isHr, bool isBranchManager, String status) {
    return status == 'pending' && (isBranchManager || isHr);
  }

  bool _canResend(bool isHr, bool isBranchManager, String status) {
    return (status == 'cancelled' || status == 'rejected') && (isBranchManager || isHr);
  }

  Widget _buildAppointmentActions({
    required BuildContext context,
    required Map<String, dynamic> row,
    required String status,
    required bool isHr,
    required bool isBranchManager,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Chip(
          label: Text(_statusLabel(context, status), style: const TextStyle(fontSize: 11)),
          backgroundColor: _statusColor(status).withValues(alpha: 0.12),
          side: BorderSide(color: _statusColor(status).withValues(alpha: 0.4)),
        ),
        if (_canActOnPending(isHr, isBranchManager, status))
          PopupMenuButton<String>(
            tooltip: context.t('common.actions'),
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (action) {
              switch (action) {
                case 'approve':
                  _setStatus(row, 'approved');
                case 'cancel':
                  _cancelWithNote(row);
                case 'reject':
                  _setStatus(row, 'rejected');
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'approve',
                child: Row(children: [
                  Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(context.t('hire.approve')),
                ]),
              ),
              PopupMenuItem(
                value: 'cancel',
                child: Row(children: [
                  Icon(Icons.block, color: Colors.blueGrey.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(context.t('hiring.status.cancelled')),
                ]),
              ),
              PopupMenuItem(
                value: 'reject',
                child: Row(children: [
                  Icon(Icons.cancel_outlined, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(context.t('hire.reject')),
                ]),
              ),
            ],
          ),
        if (_canResend(isHr, isBranchManager, status))
          IconButton(
            tooltip: context.t('hiring.resend'),
            icon: const Icon(Icons.send_outlined, size: 20),
            onPressed: () => _resend(row),
          ),
        if (_canEditAppointment(isHr, isBranchManager, status))
          IconButton(
            tooltip: context.t('common.edit'),
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _editAppointment(row),
          ),
        IconButton(
          tooltip: context.t('hire.downloadPdf'),
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
          onPressed: () => _downloadPdf(row['id']?.toString() ?? ''),
        ),
      ],
    );
  }

  Future<void> _setStatus(Map<String, dynamic> row, String newStatus) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final label = newStatus == 'approved' ? context.t('hire.approval') : context.t('hire.rejection');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('hire.confirmLabel', {'label': label})),
        content: Text(context.t('hire.confirmBody', {'action': label, 'name': row['employeeName'] ?? ''})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('common.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(label)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final result = await api.hiringAppointmentUpdate({
        'appointmentId': id,
        'status': newStatus,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? context.t('hire.updated'))),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.blueGrey;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(BuildContext context, String status) {
    switch (status) {
      case 'approved':
        return context.t('hiring.status.approved');
      case 'rejected':
        return context.t('hiring.status.rejected');
      case 'cancelled':
        return context.t('hiring.status.cancelled');
      default:
        return context.t('hiring.status.pending');
    }
  }

  String _subtitle(Map<String, dynamic> row) {
    final base =
        '${row['jobTitle'] ?? ''}  •  ${row['locationName'] ?? ''}\n'
        '${context.t('hire.dateLine', {
          'date': row['appointmentDate'] ?? '',
          'firstDay': row['firstWorkingDay'] ?? '',
        })}';
    final note = row['statusNote']?.toString().trim();
    if (note != null && note.isNotEmpty) {
      return context.t('hire.withNote', {'base': base, 'note': note});
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final roles = context.watch<AuthCubit>().state.roles;
    final isHr = roles.isHrStaff;
    final isBranchManager = roles.isBranchManager;
    final locationName = context.watch<AuthCubit>().state.user?.locationName;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: context.t('hiring.title'),
            subtitle: isHr
                ? context.t('hiring.subtitleHr')
                : context.t('hiring.subtitleBranch', {'location': locationName ?? '—'}),
            icon: Icons.assignment_ind_outlined,
            actions: [
              if (isHr)
                FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.hrHiringAppointmentCreate),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.t('hiring.add')),
                ),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? SellixCard(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(child: Text(context.t('hiring.empty'))),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final row = _items[i];
                          final status = row['status']?.toString() ?? 'pending';
                          return SellixCard(
                            child: ListTile(
                              title: Text(row['employeeName']?.toString() ?? ''),
                              subtitle: Text(_subtitle(row)),
                              isThreeLine: true,
                              trailing: _buildAppointmentActions(
                                context: context,
                                row: row,
                                status: status,
                                isHr: isHr,
                                isBranchManager: isBranchManager,
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
