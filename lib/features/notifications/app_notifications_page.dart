import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/di/injection.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../l10n/l10n_extension.dart';
import '../mobile/mobile_ui.dart';

class AppNotificationsPage extends StatefulWidget {
  const AppNotificationsPage({super.key});

  @override
  State<AppNotificationsPage> createState() => _AppNotificationsPageState();
}

class _AppNotificationsPageState extends State<AppNotificationsPage> {
  final _items = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _loadingMore = false;
  int _offset = 0;
  int _total = 0;
  int _unread = 0;
  static const _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _offset = 0;
    });
    try {
      final data = await api.appNotificationsList(limit: _pageSize, offset: 0);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(
            ((data['items'] as List?) ?? [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e)),
          );
        _total = (data['total'] as num?)?.toInt() ?? _items.length;
        _unread = (data['unreadCount'] as num?)?.toInt() ?? 0;
        _offset = _items.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _items.length >= _total) return;
    setState(() => _loadingMore = true);
    try {
      final data = await api.appNotificationsList(limit: _pageSize, offset: _offset);
      if (!mounted) return;
      final batch = ((data['items'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        _items.addAll(batch);
        _offset = _items.length;
        _total = (data['total'] as num?)?.toInt() ?? _total;
        _unread = (data['unreadCount'] as num?)?.toInt() ?? _unread;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _markAllRead() async {
    await api.appNotificationsRead(all: true);
    await _reload();
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    if (id == null || item['read'] == true) return;
    await api.appNotificationsRead(ids: [id]);
    if (!mounted) return;
    setState(() {
      item['read'] = true;
      item['readAt'] = DateTime.now().toIso8601String();
      if (_unread > 0) _unread -= 1;
    });
  }

  void _previewImage(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return DateFormat.yMMMd().add_Hm().format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: Text(context.t('notif.title')),
        actions: [
          if (_unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(context.t('notif.markAllRead')),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: _items.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
                        Center(
                          child: Text(
                            context.t('notif.empty'),
                            style: AppThemeV2.cardSubtitle,
                          ),
                        ),
                      ],
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                          _loadMore();
                        }
                        return false;
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _items.length + (_loadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index >= _items.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final item = _items[index];
                          final read = item['read'] == true;
                          final imageUrl = item['imageUrl']?.toString() ?? '';
                          return Material(
                            color: read ? Colors.white : MobileUi.primarySoft,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                await _markRead(item);
                                if (!context.mounted) return;
                                if (imageUrl.isNotEmpty) {
                                  _previewImage(imageUrl);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (imageUrl.isNotEmpty) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          imageUrl,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const SizedBox(width: 56, height: 56),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['title']?.toString() ?? '',
                                            style: AppThemeV2.body.copyWith(
                                              fontWeight: read ? FontWeight.w600 : FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item['body']?.toString() ?? '',
                                            style: AppThemeV2.cardSubtitle,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _formatTime(item['createdAt']?.toString()),
                                            style: AppThemeV2.caption,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!read)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(top: 6),
                                        decoration: const BoxDecoration(
                                          color: MobileUi.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
    );
  }
}
