import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/layout/app_page_scaffold.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../core/widgets/alert_banner.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/searchable_select_field.dart';
import '../../core/widgets/sellix_card.dart';
import '../../l10n/l10n_extension.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';

class PushNotificationsPage extends StatefulWidget {
  const PushNotificationsPage({super.key});

  @override
  State<PushNotificationsPage> createState() => _PushNotificationsPageState();
}

class _PushNotificationsPageState extends State<PushNotificationsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  final _broadcastTitle = TextEditingController();
  final _broadcastBody = TextEditingController();
  final _broadcastImage = TextEditingController();

  final _directTitle = TextEditingController();
  final _directBody = TextEditingController();
  final _directImage = TextEditingController();
  final Map<String, String> _selectedEmployees = {};

  List<Map<String, dynamic>> _employees = [];
  bool _employeesLoading = false;
  bool _broadcastSending = false;
  bool _directSending = false;

  List<Map<String, dynamic>> _log = [];
  bool _logLoading = true;
  List<Map<String, dynamic>> _companies = [];
  bool _companiesLoading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (_tabs.index == 2 && _tabs.indexIsChanging == false && _log.isEmpty) {
        _loadLog();
      }
    });
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthCubit>().state;
    if (auth.isPlatformAdmin) {
      await _loadCompanies();
    }
    if (!_hasCompanyContext(auth)) return;
    await _loadEmployees();
    await _loadLog();
  }

  bool _hasCompanyContext(AuthState auth) {
    final id = auth.activeCompanyId;
    return id != null && id.isNotEmpty;
  }

  Future<void> _loadCompanies() async {
    setState(() => _companiesLoading = true);
    try {
      final data = await api.adminCompaniesList();
      if (!mounted) return;
      final list = ((data['companies'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        _companies = list;
        _companiesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _companiesLoading = false);
    }
  }

  Future<void> _onCompanyPicked(String? companyId) async {
    if (companyId == null || companyId.isEmpty) return;
    final row = _companies.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c?['id']?.toString() == companyId,
          orElse: () => null,
        );
    await context.read<AuthCubit>().setActiveCompany(
          id: companyId,
          name: row?['name']?.toString(),
          code: row?['code']?.toString(),
        );
    if (!mounted) return;
    setState(() => _selectedEmployees.clear());
    await _loadEmployees();
    await _loadLog();
  }

  void _onAuthCompanyChanged() {
    setState(() => _selectedEmployees.clear());
    _loadEmployees();
    _loadLog();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _broadcastTitle.dispose();
    _broadcastBody.dispose();
    _broadcastImage.dispose();
    _directTitle.dispose();
    _directBody.dispose();
    _directImage.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() => _employeesLoading = true);
    try {
      final page = await api.employeesList(limit: 500, offset: 0, active: true);
      if (!mounted) return;
      setState(() {
        _employees = page.items.where((e) {
          final uid = e['userId'];
          if (uid == null || uid == false) return false;
          return uid.toString().trim().isNotEmpty;
        }).toList();
        _employeesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _employeesLoading = false);
    }
  }

  Future<void> _loadLog() async {
    setState(() => _logLoading = true);
    try {
      final data = await api.pushNotificationsAdminList(limit: 60);
      if (!mounted) return;
      setState(() {
        _log = ((data['items'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _logLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _logLoading = false);
    }
  }

  Future<void> _sendBroadcast() async {
    final title = _broadcastTitle.text.trim();
    final body = _broadcastBody.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _toast(context.t('pushNotif.validationTitleBody'));
      return;
    }
    setState(() => _broadcastSending = true);
    try {
      final r = await api.pushNotificationsBroadcast(
        title: title,
        body: body,
        imageUrl: _broadcastImage.text.trim().isEmpty
            ? null
            : _broadcastImage.text.trim(),
      );
      if (!mounted) return;
      final n = (r['recipientCount'] as num?)?.toInt() ?? 0;
      _toast(context.t('pushNotif.broadcastOk', {'count': '$n'}));
      _broadcastTitle.clear();
      _broadcastBody.clear();
      _broadcastImage.clear();
      await _loadLog();
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _broadcastSending = false);
    }
  }

  Future<void> _sendDirect() async {
    final title = _directTitle.text.trim();
    final body = _directBody.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _toast(context.t('pushNotif.validationTitleBody'));
      return;
    }
    if (_selectedEmployees.isEmpty) {
      _toast(context.t('pushNotif.pickEmployee'));
      return;
    }
    setState(() => _directSending = true);
    try {
      final r = await api.pushNotificationsSend(
        employeeIds: _selectedEmployees.keys.toList(),
        title: title,
        body: body,
        imageUrl: _directImage.text.trim().isEmpty
            ? null
            : _directImage.text.trim(),
      );
      if (!mounted) return;
      final n = (r['sentCount'] as num?)?.toInt() ?? 0;
      _toast(context.t('pushNotif.directOk', {'count': '$n'}));
      _directTitle.clear();
      _directBody.clear();
      _directImage.clear();
      setState(() => _selectedEmployees.clear());
      await _loadLog();
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _directSending = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickEmployee() async {
    if (_employeesLoading) return;
    var picked = '';
    final id = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(context.t('pushNotif.addRecipient')),
          content: SizedBox(
            width: 420,
            child: _employees.isEmpty
                ? Text(
                    context.t('pushNotif.directHint'),
                    style: AppThemeV2.caption,
                  )
                : SearchableSelectField<String>(
                    label: context.t('pushNotif.employee'),
                    value: picked.isEmpty ? null : picked,
                    options: _employees
                        .map(
                          (e) => SearchableSelectOption(
                            value: e['id']?.toString() ?? '',
                            label:
                                '${e['name'] ?? e['displayName'] ?? ''} (${e['code'] ?? ''})',
                          ),
                        )
                        .where((o) => o.value.isNotEmpty)
                        .toList(),
                    onChanged: (v) => setLocal(() => picked = v ?? ''),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.t('common.cancel')),
            ),
            FilledButton(
              onPressed: picked.isEmpty ? null : () => Navigator.pop(ctx, picked),
              child: Text(context.t('common.add')),
            ),
          ],
        ),
      ),
    );
    if (id == null || id.isEmpty || !mounted) return;
    final emp = _employees.cast<Map<String, dynamic>?>().firstWhere(
          (e) => e?['id']?.toString() == id,
          orElse: () => null,
        );
    if (emp == null) return;
    final name =
        emp['name']?.toString() ?? emp['displayName']?.toString() ?? id;
    setState(() => _selectedEmployees[id] = name);
  }

  Widget _imageField(TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: context.t('pushNotif.imageUrl'),
        helperText: context.t('pushNotif.imageUrlHint'),
      ),
    );
  }

  Widget _companyContextBar(AuthState auth) {
    if (!auth.isPlatformAdmin) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SellixCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('pushNotif.adminCompanyHint'), style: AppThemeV2.caption),
            const SizedBox(height: 10),
            if (_companiesLoading)
              const LinearProgressIndicator(minHeight: 2)
            else
              SearchableSelectField<String>(
                label: context.t('pushNotif.adminCompany'),
                value: auth.activeCompanyId,
                options: _companies
                    .map(
                      (c) => SearchableSelectOption(
                        value: c['id']?.toString() ?? '',
                        label:
                            '${c['name'] ?? ''} (${c['code'] ?? ''})'.trim(),
                      ),
                    )
                    .where((o) => o.value.isNotEmpty)
                    .toList(),
                onChanged: _onCompanyPicked,
              ),
          ],
        ),
      ),
    );
  }

  Widget _noCompanyBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AlertBanner(
          tone: AlertBannerTone.warning,
          message: context.t('pushNotif.companyContextRequired'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (a, b) => a.activeCompanyId != b.activeCompanyId,
      listener: (_, __) => _onAuthCompanyChanged(),
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, auth) {
          final hasCompany = _hasCompanyContext(auth);
          return AppPageScaffold(
            scrollable: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: context.t('pushNotif.title'),
                  subtitle: context.t('pushNotif.subtitle'),
                ),
                _companyContextBar(auth),
                if (!hasCompany)
                  Expanded(child: _noCompanyBody())
                else ...[
                  TabBar(
                    controller: _tabs,
                    tabs: [
                      Tab(text: context.t('pushNotif.tabBroadcast')),
                      Tab(text: context.t('pushNotif.tabDirect')),
                      Tab(text: context.t('pushNotif.tabLog')),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        _broadcastTab(),
                        _directTab(),
                        _logTab(),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _broadcastTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: SellixCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('pushNotif.broadcastHint'), style: AppThemeV2.caption),
            const SizedBox(height: 16),
            TextField(
              controller: _broadcastTitle,
              decoration: InputDecoration(labelText: context.t('pushNotif.fieldTitle')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _broadcastBody,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(labelText: context.t('pushNotif.fieldBody')),
            ),
            const SizedBox(height: 12),
            _imageField(_broadcastImage),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _broadcastSending ? null : _sendBroadcast,
              icon: _broadcastSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.campaign_outlined),
              label: Text(context.t('pushNotif.sendBroadcast')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _directTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: SellixCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('pushNotif.directHint'), style: AppThemeV2.caption),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._selectedEmployees.entries.map(
                  (e) => InputChip(
                    label: Text(e.value),
                    onDeleted: () =>
                        setState(() => _selectedEmployees.remove(e.key)),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.person_add_outlined, size: 18),
                  label: Text(context.t('pushNotif.addRecipient')),
                  onPressed: _pickEmployee,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _directTitle,
              decoration: InputDecoration(labelText: context.t('pushNotif.fieldTitle')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _directBody,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(labelText: context.t('pushNotif.fieldBody')),
            ),
            const SizedBox(height: 12),
            _imageField(_directImage),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _directSending ? null : _sendDirect,
              icon: _directSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(context.t('pushNotif.sendDirect')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logTab() {
    if (_logLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_log.isEmpty) {
      return Center(child: Text(context.t('pushNotif.logEmpty')));
    }
    return RefreshIndicator(
      onRefresh: _loadLog,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _log.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final row = _log[i];
          final type = row['type']?.toString() ?? '';
          final typeLabel = type == 'company_broadcast'
              ? context.t('pushNotif.typeBroadcast')
              : context.t('pushNotif.typeDirect');
          final recipient = row['recipientName']?.toString() ?? '—';
          final created = row['createdAt']?.toString() ?? '';
          return SellixCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row['title']?.toString() ?? '',
                        style: AppThemeV2.cardTitle(),
                      ),
                    ),
                    Text(typeLabel, style: AppThemeV2.caption),
                  ],
                ),
                const SizedBox(height: 6),
                Text(row['body']?.toString() ?? '', style: AppThemeV2.caption),
                const SizedBox(height: 8),
                Text(
                  '${context.t('pushNotif.recipient')}: $recipient · $created',
                  style: AppThemeV2.caption,
                ),
                if ((row['imageUrl']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      row['imageUrl'].toString(),
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
