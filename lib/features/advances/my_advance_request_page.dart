import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/utils/api_error_message.dart';
import '../../core/widgets/api_error_view.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/l10n_extension.dart';
import 'advance_request_common.dart';

/// «طلب سلفة» — what an employee sees: their entitlement, the request form,
/// and the history of what they've asked for.
class MyAdvanceRequestPage extends StatefulWidget {
  const MyAdvanceRequestPage({super.key});

  @override
  State<MyAdvanceRequestPage> createState() => _MyAdvanceRequestPageState();
}

class _MyAdvanceRequestPageState extends State<MyAdvanceRequestPage> {
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  Map<String, dynamic>? _eligibility;
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
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final eligibility = await api.advanceRequestEligibility();
      final requests = await api.advanceRequestMine();
      if (!mounted) return;
      setState(() {
        _eligibility = eligibility;
        _requests = requests;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e; });
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim().replaceAll(',', ''));
    final reason = _reasonCtrl.text.trim();
    if (amount == null || amount <= 0 || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('advReq.reasonHint'))),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await api.advanceRequestCreate(amount: amount, reason: reason);
      _amountCtrl.clear();
      _reasonCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('advReq.submitted'))),
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
      await api.advanceRequestCancel(request['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('advReq.cancelled'))),
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

    final eligibility = _eligibility ?? const <String, dynamic>{};
    final eligible = eligibility['isEligible'] == true;
    final available = asNum(eligibility['availableAmount']);

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      children: [
        PageHeader(
          title: context.t('advReq.myTitle'),
          subtitle: context.t('advReq.mySubtitle'),
          icon: Icons.request_quote_outlined,
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceMd),
        EligibilityCard(eligibility: eligibility),
        const SizedBox(height: AppDimensions.spaceMd),
        if (eligible && available > 0) _form(context),
        const SizedBox(height: AppDimensions.spaceMd),
        Text(
          context.t('advReq.myRequests'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppDimensions.spaceSm),
        if (_requests.isEmpty)
          SellixCard(child: Text(context.t('advReq.noRequests')))
        else
          ..._requests.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
              child: AdvanceRequestCard(
                request: r,
                // Only the requester's own pending rows can still be withdrawn.
                onCancel: isPendingState(r['state']?.toString()) ? () => _cancel(r) : null,
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
            context.t('advReq.new'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.t('advReq.amount'),
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: AppDimensions.spaceSm),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: context.t('advReq.reason'),
              hintText: context.t('advReq.reasonHint'),
            ),
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
              label: Text(context.t('advReq.submit')),
            ),
          ),
        ],
      ),
    );
  }
}
