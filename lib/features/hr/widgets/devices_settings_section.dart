import 'package:flutter/material.dart';
import '../../../l10n/l10n_extension.dart';

import '../../../core/config/api_config.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/sellix_card.dart';

class DevicesSettingsSection extends StatefulWidget {
  const DevicesSettingsSection({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<DevicesSettingsSection> createState() => _DevicesSettingsSectionState();
}

class _DevicesSettingsSectionState extends State<DevicesSettingsSection> {
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (ApiConfig.showDevicesInSettings) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        api.devicesList(),
        api.locationsList(activeOnly: false),
      ]);
      if (!mounted) return;
      setState(() {
        _devices = results[0];
        _locations = results[1];
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

  Future<void> _setLocation(Map<String, dynamic> device, String? locationId) async {
    try {
      await api.deviceUpdate(device['id'], locationId: locationId);
      _snack(context.t('set.deviceLocationUpdated'));
      _load();
    } catch (e) {
      _snack(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.showDevicesInSettings) {
      return const SizedBox.shrink();
    }

    if (_loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) ...[
          Text(context.t('set.devices'), style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
        ],
        Text(
          context.t('set.devicesHint'),
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        if (_devices.isEmpty)
          SellixCard(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(context.t('set.devicesNone')),
            ),
          )
        else
          ..._devices.map((d) {
            final locId = d['locationId']?.toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SellixCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                          if ((d['alias']?.toString() ?? '').isNotEmpty)
                            Text(d['alias'].toString(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: locId != null && locId.isNotEmpty ? locId : null,
                        decoration: InputDecoration(
                          labelText: context.t('set.location'),
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem<String?>(value: null, child: Text(context.t('set.noLocation'))),
                          for (final loc in _locations)
                            DropdownMenuItem<String?>(
                              value: loc['id']?.toString(),
                              child: Text(loc['name']?.toString() ?? ''),
                            ),
                        ],
                        onChanged: (v) => _setLocation(d, v),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
