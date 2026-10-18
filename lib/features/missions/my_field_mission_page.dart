import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/utils/payroll_month.dart';
import '../../core/widgets/api_error_view.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/l10n_extension.dart';
import 'field_mission_common.dart';

/// «طلب مأمورية» — employee form (details + date range) and own request history.
class MyFieldMissionPage extends StatefulWidget {
  const MyFieldMissionPage({super.key});

  @override
  State<MyFieldMissionPage> createState() => _MyFieldMissionPageState();
}

class _MyFieldMissionPageState extends State<MyFieldMissionPage> {
  final _detailsCtrl = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;

  List<Map<String, dynamic>> _requests = const [];
  bool _loading = true;
  bool _submitting = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await api.fieldMissionRequestMine();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e; });
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now();
    final initial = (from ? _dateFrom : _dateTo) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _dateFrom = picked;
        if (_dateTo != null && _dateTo!.isBefore(picked)) _dateTo = picked;
      } else {
        _dateTo = picked;
        if (_dateFrom != null && _dateFrom!.isAfter(picked)) _dateFrom = picked;
      }
    });
  }

  Future<void> _submit() async {
    final details = _detailsCtrl.text.trim();
    if (details.isEmpty || _dateFrom == null || _dateTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('mission.formHint'))),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await api.fieldMissionRequestCreate(
        details: details,
        dateFrom: formatIsoDate(_dateFrom!),
        dateTo: formatIsoDate(_dateTo!),
      );
      _detailsCtrl.clear();
      setState(() {
        _dateFrom = null;
        _dateTo = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('mission.submitted'))),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiError(context, e))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancel(Map<String, dynamic> request) async {
    try {
      await api.fieldMissionRequestCancel(request['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('mission.cancelled'))),
        );
      }
      await _load();
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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ApiErrorView(error: _error!, onRetry: _load);

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      children: [
        PageHeader(
          title: context.t('mission.myTitle'),
          subtitle: context.t('mission.mySubtitle'),
          icon: Icons.flight_takeoff_outlined,
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceMd),
        _form(context),
        const SizedBox(height: AppDimensions.spaceMd),
        Text(
          context.t('mission.myRequests'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppDimensions.spaceSm),
        if (_requests.isEmpty)
          SellixCard(child: Text(context.t('mission.noRequests')))
        else
          ..._requests.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
              child: FieldMissionRequestCard(
                request: r,
                onCancel: isMissionPendingState(r['state']?.toString())
                    ? () => _cancel(r)
                    : null,
              ),
            ),
          ),
      ],
    );
  }

  Widget _form(BuildContext context) {
    return SellixCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('mission.new'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          TextField(
            controller: _detailsCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: context.t('mission.details'),
              hintText: context.t('mission.detailsHint'),
            ),
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(from: true),
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(
                    _dateFrom == null
                        ? context.t('mission.dateFrom')
                        : formatIsoDate(_dateFrom!),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spaceSm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(from: false),
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(
                    _dateTo == null
                        ? context.t('mission.dateTo')
                        : formatIsoDate(_dateTo!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceMd),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, size: 18),
              label: Text(context.t('mission.submit')),
            ),
          ),
        ],
      ),
    );
  }
}
