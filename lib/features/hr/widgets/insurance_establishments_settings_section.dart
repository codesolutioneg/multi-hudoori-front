import 'package:flutter/material.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/api_error_message.dart';
import '../../../core/widgets/sellix_card.dart';
import '../../../l10n/l10n_extension.dart';

class InsuranceEstablishmentsSettingsSection extends StatefulWidget {
  const InsuranceEstablishmentsSettingsSection({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<InsuranceEstablishmentsSettingsSection> createState() =>
      _InsuranceEstablishmentsSettingsSectionState();
}

class _InsuranceEstablishmentsSettingsSectionState
    extends State<InsuranceEstablishmentsSettingsSection> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await api.insuranceEstablishmentsList(activeOnly: false);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(friendlyApiError(context, e));
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openForm([Map<String, dynamic>? row]) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _EstablishmentFormDialog(row: row),
    );
    if (ok == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('set.estDelete')),
        content: Text(
          context.t('common.deleteQuestion', {'name': row['name']}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('common.delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.insuranceEstablishmentDelete(row['id']);
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack(friendlyApiError(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.embedded
                    ? context.t('set.estHint')
                    : context.t('set.est'),
                style: widget.embedded
                    ? const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      )
                    : const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: context.t('common.refresh'),
            ),
            FilledButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 16),
              label: Text(context.t('set.estNew')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_items.isEmpty)
          SellixCard(
            child: Column(
              children: [
                Text(context.t('set.estNone')),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _openForm(),
                  child: Text(context.t('set.estNew')),
                ),
              ],
            ),
          )
        else
          SellixCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _items.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    title: Text(
                      _items[i]['name']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      [
                        if ((_items[i]['insuranceNumber']?.toString() ?? '')
                            .isNotEmpty)
                          _items[i]['insuranceNumber'],
                        if ((_items[i]['office']?.toString() ?? '').isNotEmpty)
                          _items[i]['office'],
                        _items[i]['active'] == false
                            ? context.t('common.inactive')
                            : context.t('common.active'),
                      ].join(' • '),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _openForm(_items[i]),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () => _delete(_items[i]),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _EstablishmentFormDialog extends StatefulWidget {
  const _EstablishmentFormDialog({this.row});
  final Map<String, dynamic>? row;

  @override
  State<_EstablishmentFormDialog> createState() =>
      _EstablishmentFormDialogState();
}

class _EstablishmentFormDialogState extends State<_EstablishmentFormDialog> {
  final _name = TextEditingController();
  final _insuranceNumber = TextEditingController();
  final _office = TextEditingController();
  final _address = TextEditingController();
  final _buildingNumber = TextEditingController();
  final _street = TextEditingController();
  final _village = TextEditingController();
  final _district = TextEditingController();
  final _governorate = TextEditingController();
  final _establishmentType = TextEditingController();
  final _phone = TextEditingController();
  final _sequence = TextEditingController(text: '10');
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    if (row != null) {
      _name.text = row['name']?.toString() ?? '';
      _insuranceNumber.text = row['insuranceNumber']?.toString() ?? '';
      _office.text = row['office']?.toString() ?? '';
      _address.text = row['address']?.toString() ?? '';
      _buildingNumber.text = row['buildingNumber']?.toString() ?? '';
      _street.text = row['street']?.toString() ?? '';
      _village.text = row['village']?.toString() ?? '';
      _district.text = row['district']?.toString() ?? '';
      _governorate.text = row['governorate']?.toString() ?? '';
      _establishmentType.text = row['establishmentType']?.toString() ?? '';
      _phone.text = row['phone']?.toString() ?? '';
      _sequence.text = '${row['sequence'] ?? 10}';
      _active = row['active'] != false;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _insuranceNumber.dispose();
    _office.dispose();
    _address.dispose();
    _buildingNumber.dispose();
    _street.dispose();
    _village.dispose();
    _district.dispose();
    _governorate.dispose();
    _establishmentType.dispose();
    _phone.dispose();
    _sequence.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await api.insuranceEstablishmentSave({
        if (widget.row != null) 'id': widget.row!['id'],
        'name': _name.text.trim(),
        'insuranceNumber': _insuranceNumber.text.trim(),
        'office': _office.text.trim(),
        'address': _address.text.trim(),
        'buildingNumber': _buildingNumber.text.trim(),
        'street': _street.text.trim(),
        'village': _village.text.trim(),
        'district': _district.text.trim(),
        'governorate': _governorate.text.trim(),
        'establishmentType': _establishmentType.text.trim(),
        'phone': _phone.text.trim(),
        'sequence': int.tryParse(_sequence.text.trim()) ?? 10,
        'active': _active,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(context, e))),
        );
      }
    }
  }

  Widget _field(TextEditingController c, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.row == null ? context.t('set.estNewFull') : context.t('set.estEdit'),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_name, context.t('set.estName')),
              _field(_insuranceNumber, context.t('insForm.establishmentInsuranceNumber')),
              _field(_office, context.t('insForm.office')),
              _field(_address, context.t('insForm.establishmentAddress'), maxLines: 2),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _buildingNumber,
                      context.t('insForm.buildingNumber'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(_street, context.t('insForm.street')),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _field(_district, context.t('insForm.district')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      _governorate,
                      context.t('insForm.governorate'),
                    ),
                  ),
                ],
              ),
              _field(_establishmentType, context.t('insForm.establishmentType')),
              _field(_phone, context.t('insForm.phone')),
              TextField(
                controller: _sequence,
                decoration: InputDecoration(labelText: context.t('common.order')),
                keyboardType: TextInputType.number,
              ),
              SwitchListTile(
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: Text(
                  context.t('common.active'),
                  style: const TextStyle(fontSize: 14),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(context.t('common.save')),
        ),
      ],
    );
  }
}
