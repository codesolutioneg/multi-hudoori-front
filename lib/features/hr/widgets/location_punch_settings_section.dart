import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/l10n_extension.dart';
import 'settings_accordion_section.dart';

/// HR: enable GPS punch per branch + lat/long/radius.
class LocationPunchSettingsSection extends StatefulWidget {
  const LocationPunchSettingsSection({
    super.key,
    required this.locations,
    required this.busy,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> locations;
  final bool busy;
  final VoidCallback onChanged;

  @override
  State<LocationPunchSettingsSection> createState() =>
      _LocationPunchSettingsSectionState();
}

class _LocationPunchSettingsSectionState
    extends State<LocationPunchSettingsSection> {
  final Map<String, TextEditingController> _lat = {};
  final Map<String, TextEditingController> _lng = {};
  final Map<String, TextEditingController> _radius = {};
  final Map<String, bool> _enabled = {};
  String? _savingId;

  @override
  void initState() {
    super.initState();
    _syncFromLocations();
  }

  @override
  void didUpdateWidget(covariant LocationPunchSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locations != widget.locations) {
      _syncFromLocations();
    }
  }

  void _syncFromLocations() {
    for (final location in widget.locations) {
      final id = location['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      _enabled[id] = location['locationPunchEnabled'] == true;
      _lat.putIfAbsent(
        id,
        () => TextEditingController(
          text: location['latitude']?.toString() ?? '',
        ),
      );
      _lng.putIfAbsent(
        id,
        () => TextEditingController(
          text: location['longitude']?.toString() ?? '',
        ),
      );
      _radius.putIfAbsent(
        id,
        () => TextEditingController(
          text: '${location['geofenceRadiusMeters'] ?? 200}',
        ),
      );
      _lat[id]!.text = location['latitude']?.toString() ?? _lat[id]!.text;
      _lng[id]!.text = location['longitude']?.toString() ?? _lng[id]!.text;
      _radius[id]!.text =
          '${location['geofenceRadiusMeters'] ?? _radius[id]!.text}';
      _enabled[id] = location['locationPunchEnabled'] == true;
    }
  }

  @override
  void dispose() {
    for (final c in _lat.values) {
      c.dispose();
    }
    for (final c in _lng.values) {
      c.dispose();
    }
    for (final c in _radius.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(String id) async {
    final isAr = context.l10n.isAr;
    setState(() => _savingId = id);
    try {
      final latText = _lat[id]?.text.trim() ?? '';
      final lngText = _lng[id]?.text.trim() ?? '';
      final radiusText = _radius[id]?.text.trim() ?? '';
      final enabled = _enabled[id] == true;
      final radius = int.tryParse(radiusText);
      if (enabled && (radius == null || radius < 1)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAr
                  ? 'أدخل نطاق البصمة بالمتر (مثلاً 10 أو 50) — أي رقم أكبر من صفر'
                  : 'Enter geofence radius in meters (e.g. 10 or 50) — any number greater than 0',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }
      await api.locationUpdate(id, {
        'locationPunchEnabled': enabled,
        'latitude': latText.isEmpty ? null : double.tryParse(latText),
        'longitude': lngText.isEmpty ? null : double.tryParse(lngText),
        if (radius != null) 'geofenceRadiusMeters': radius,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr ? 'تم حفظ إعدادات بصمة الموقع' : 'Location punch settings saved'),
        ),
      );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.l10n.isAr;
    return SettingsAccordionSection(
      title: isAr ? 'بصمة الموقع (الفروع)' : 'Location punch (branches)',
      subtitle: isAr
          ? 'فعّل الحضور/الانصراف عبر GPS لكل فرع، وحدّد lat/long ونطاق البصمة بالمتر كما تريد (10، 50، …)'
          : 'Enable GPS punch per branch and set lat/long plus any radius in meters (10, 50, …)',
      icon: Icons.my_location_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.locations.isEmpty)
            Text(isAr ? 'لا توجد فروع' : 'No branches')
          else
            ...widget.locations.map((location) {
              final id = location['id']?.toString() ?? '';
              final name = location['name']?.toString() ?? id;
              final active = location['active'] != false;
              final saving = _savingId == id;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('$name${active ? '' : (isAr ? ' (غير نشط)' : ' (inactive)')}'),
                        subtitle: Text(
                          isAr ? 'تفعيل بصمة الموقع لهذا الفرع' : 'Enable location punch for this branch',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        value: _enabled[id] == true,
                        onChanged: widget.busy || saving
                            ? null
                            : (v) => setState(() => _enabled[id] = v),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _lat[id],
                              decoration: InputDecoration(
                                labelText: isAr ? 'خط العرض (lat)' : 'Latitude',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _lng[id],
                              decoration: InputDecoration(
                                labelText: isAr ? 'خط الطول (long)' : 'Longitude',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _radius[id],
                        decoration: InputDecoration(
                          labelText: isAr ? 'نطاق البصمة (متر) — تتحكم فيه أنت' : 'Geofence radius (meters) — you control it',
                          hintText: isAr ? 'مثال: 10 أو 50 أو 200' : 'e.g. 10, 50, or 200',
                          helperText: isAr
                              ? 'ليس ثابتاً على 200 — اكتب أي عدد أكبر من صفر (متر)'
                              : 'Not fixed at 200 — enter any value greater than 0 (meters)',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final meters in const [10, 50, 100, 200, 500])
                            ActionChip(
                              label: Text('$meters ${isAr ? 'م' : 'm'}'),
                              onPressed: widget.busy || saving
                                  ? null
                                  : () => setState(() {
                                        _radius[id]?.text = '$meters';
                                      }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FilledButton.icon(
                          onPressed: widget.busy || saving ? null : () => _save(id),
                          icon: saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined, size: 18),
                          label: Text(isAr ? 'حفظ' : 'Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
