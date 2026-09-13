import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/injection.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/theme/app_theme_v2.dart';
import '../../l10n/l10n_extension.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';

class HelpAssistantOverlay extends StatefulWidget {
  const HelpAssistantOverlay({super.key});

  @override
  State<HelpAssistantOverlay> createState() => _HelpAssistantOverlayState();
}

class _Msg {
  const _Msg({required this.role, required this.content});
  final String role;
  final String content;
}

class _HelpAssistantOverlayState extends State<HelpAssistantOverlay> {
  static const _suggestions = [
    'assistant.q.shiftGrid',
    'assistant.q.employeeSheet',
    'assistant.q.advanceSheet',
    'assistant.q.punchSync',
    'assistant.q.shiftVsGrid',
    'assistant.q.splitDeduction',
  ];

  bool _open = false;
  bool _loading = false;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late List<_Msg> _messages;

  @override
  void initState() {
    super.initState();
    _messages = [_Msg(role: 'assistant', content: tr('assistant.greeting'))];
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final q = (text ?? _input.text).trim();
    if (q.isEmpty || _loading) return;
    setState(() {
      _messages = [..._messages, _Msg(role: 'user', content: q)];
      _loading = true;
      _input.clear();
    });
    _jumpBottom();
    try {
      final history = _messages
          .skip(1)
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .take(_messages.length - 1)
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();
      // Drop the just-appended user message from history (API adds it as message).
      if (history.isNotEmpty && history.last['content'] == q) {
        history.removeLast();
      }
      final page = GoRouterState.of(context).uri.path;
      final data = await api.assistantChat(
        message: q,
        history: history,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        _messages = [
          ..._messages,
          _Msg(role: 'assistant', content: data['reply']?.toString() ?? ''),
        ];
        _loading = false;
      });
      _jumpBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages = [
          ..._messages,
          _Msg(role: 'assistant', content: e.toString()),
        ];
        _loading = false;
      });
    }
  }

  void _jumpBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, auth) {
        if (!auth.canViewAssistant) return const SizedBox.shrink();
        final mobile = isMobile(context);
        // Physical bottom-left (شمال الشاشة) — independent of RTL text direction.
        final fabBottom = mobile ? 88.0 : 24.0;
        final fabLeft = mobile ? 16.0 : 24.0;
        final panelWidth = mobile ? MediaQuery.sizeOf(context).width - 24 : 400.0;
        final panelHeight = MediaQuery.sizeOf(context).height * (mobile ? 0.55 : 0.68);
        return Positioned(
          left: fabLeft,
          bottom: fabBottom,
          width: _open ? panelWidth : 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_open)
                Material(
                  elevation: 12,
                  borderRadius: BorderRadius.circular(18),
                  color: AppThemeV2.surface,
                  child: SizedBox(
                    width: panelWidth,
                    height: panelHeight,
                    child: Column(
                      children: [
                        _header(),
                        Expanded(child: _transcript()),
                        if (_messages.length <= 3 && !_loading) _chips(),
                        _composer(),
                      ],
                    ),
                  ),
                ),
              if (_open) const SizedBox(height: 10),
              FloatingActionButton(
                heroTag: 'hudoori-help-assistant',
                backgroundColor: AppThemeV2.primary,
                foregroundColor: Colors.white,
                tooltip: _open
                    ? context.t('assistant.close')
                    : context.t('assistant.open'),
                onPressed: () => setState(() => _open = !_open),
                child: Icon(
                  _open ? Icons.close : Icons.chat,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppThemeV2.primarySoft,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              gradient: AppThemeV2.primaryGradient,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('assistant.title'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                Text(
                  context.t('assistant.subtitle'),
                  style: TextStyle(fontSize: 11, color: AppThemeV2.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _open = false),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _transcript() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length + (_loading ? 1 : 0),
      itemBuilder: (context, i) {
        if (_loading && i == _messages.length) {
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppThemeV2.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(context.t('assistant.thinking')),
                ],
              ),
            ),
          );
        }
        final m = _messages[i];
        final mine = m.role == 'user';
        return Align(
          alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.85,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: mine ? AppThemeV2.primary : AppThemeV2.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              m.content,
              style: TextStyle(
                color: mine ? Colors.white : AppThemeV2.textPrimary,
                height: 1.45,
                fontSize: 13.5,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final s in _suggestions)
            ActionChip(
              label: Text(context.t(s), style: const TextStyle(fontSize: 11)),
              onPressed: _loading ? null : () => _send(context.t(s)),
            ),
        ],
      ),
    );
  }

  Widget _composer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: context.t('assistant.hint'),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _loading ? null : () => _send(),
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}
