import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = messagesApi.threads();
  }

  void _reload() {
    setState(() => _future = messagesApi.threads());
  }

  void _openSupport() async {
    try {
      final res = await messagesApi.supportUser();
      final id = (res['data']?['user_id'] as num?)?.toInt();
      if (!mounted) return;
      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Support is not available right now')));
        return;
      }
      await _openChat(id, 'SOGO Support');
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _openChat(int userId, String name) {
    return Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(userId: userId, name: name)));
  }

  String _time(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: const Text('Messages')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'support_chat',
        backgroundColor: SogoColors.primary,
        foregroundColor: Colors.white,
        onPressed: _openSupport,
        icon: const Icon(Icons.support_agent_rounded),
        label: const Text('Support'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _future;
        },
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: [
                Padding(
                    padding: const EdgeInsets.all(SogoSpacing.xl),
                    child: Text('Could not load chats: ${snap.error}',
                        style: SogoText.bodyMd
                            .copyWith(color: SogoColors.danger))),
              ]);
            }
            final data = snap.data?['data'] as Map<String, dynamic>? ?? {};
            final threads = (data['threads'] as List?) ?? [];

            // Pinned support entry.
            final support = data['support'] as Map<String, dynamic>?;
            final children = <Widget>[
              if (support != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: SogoSpacing.md),
                  child: SogoCard(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(SogoRadius.md),
                      onTap: _openSupport,
                      child: Row(children: [
                        Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                                color: SogoColors.primary,
                                borderRadius:
                                    BorderRadius.circular(SogoRadius.md)),
                            child: const Icon(Icons.support_agent_rounded,
                                color: Colors.white)),
                        const SizedBox(width: SogoSpacing.md),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('SOGO Support',
                                  style: SogoText.bodyLg
                                      .copyWith(fontWeight: FontWeight.w700)),
                              Text('Official help & replies',
                                  style: SogoText.bodySm.copyWith(
                                      color: SogoColors.textSecondary)),
                            ])),
                        if (((support['unread'] ?? 0) as num).toInt() > 0)
                          Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                  color: SogoColors.danger,
                                  shape: BoxShape.circle),
                              child: Text(
                                  '${((support['unread'] ?? 0) as num).toInt()}',
                                  style: SogoText.labelMd
                                      .copyWith(color: Colors.white))),
                      ]),
                    ),
                  ),
                ),
            ];

            if (threads.isEmpty && support == null) {
              children.add(Padding(
                  padding: const EdgeInsets.all(SogoSpacing.xxl),
                  child: Column(children: [
                    const Icon(Icons.chat_bubble_outline_rounded,
                        size: 48, color: SogoColors.textMuted),
                    const SizedBox(height: SogoSpacing.md),
                    Text('No conversations yet',
                        style: SogoText.bodyLg
                            .copyWith(color: SogoColors.textSecondary)),
                    const SizedBox(height: SogoSpacing.sm),
                    Text(
                        'Chat with a provider about their service, or tap Support below.',
                        textAlign: TextAlign.center,
                        style: SogoText.bodySm
                            .copyWith(color: SogoColors.textMuted)),
                  ])));
            }

            for (final raw in threads) {
              final t = raw as Map<String, dynamic>;
              children.add(Padding(
                padding: const EdgeInsets.only(bottom: SogoSpacing.md),
                child: SogoCard(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(SogoRadius.md),
                    onTap: () async {
                      await _openChat(
                          (t['user_id'] as num).toInt(), '${t['name']}');
                      _reload();
                    },
                    child: Row(children: [
                      CircleAvatar(
                          radius: 23,
                          backgroundColor: SogoColors.primaryLight,
                          backgroundImage: t['avatar'] != null
                              ? NetworkImage('${t['avatar']}')
                              : null,
                          child: t['avatar'] == null
                              ? Text(
                                  '${t['name']}'.characters.first.toUpperCase(),
                                  style: SogoText.bodyLg
                                      .copyWith(color: SogoColors.primary))
                              : null),
                      const SizedBox(width: SogoSpacing.md),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('${t['name']}',
                                style: SogoText.bodyLg
                                    .copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                                '${t['last_from_me'] ? 'You: ' : ''}${t['last_body'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SogoText.bodySm
                                    .copyWith(color: SogoColors.textSecondary)),
                          ])),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_time(t['last_at'] as String?),
                                style: SogoText.labelMd
                                    .copyWith(color: SogoColors.textMuted)),
                            const SizedBox(height: 4),
                            if (((t['unread'] ?? 0) as num).toInt() > 0)
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: SogoColors.primary,
                                      borderRadius: BorderRadius.circular(
                                          SogoRadius.pill)),
                                  child: Text(
                                      '${((t['unread'] ?? 0) as num).toInt()}',
                                      style: SogoText.labelMd
                                          .copyWith(color: Colors.white))),
                          ]),
                    ]),
                  ),
                ),
              ));
            }

            return ListView(
              padding: const EdgeInsets.all(SogoSpacing.lg),
              children: children,
            );
          },
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.userId, required this.name});

  final int userId;
  final String name;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  String? _since;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  late final Timer _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _pollNew());
  }

  @override
  void dispose() {
    _poll.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await messagesApi.thread(widget.userId);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final msgs = (data['messages'] as List?) ?? [];
      setState(() {
        _messages = msgs.cast<Map<String, dynamic>>();
        _since =
            _messages.isNotEmpty ? '${_messages.last['created_at']}' : null;
        _loading = false;
        _error = null;
      });
      _jumpBottom();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pollNew() async {
    if (!mounted || _since == null) return;
    try {
      final res = await messagesApi.thread(widget.userId, since: _since);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final msgs = ((data['messages'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .where((m) => !_messages.any((e) => e['id'] == m['id']))
          .toList();
      if (msgs.isEmpty || !mounted) return;
      setState(() {
        _messages.addAll(msgs);
        _since = '${_messages.last['created_at']}';
      });
      _jumpBottom();
    } catch (_) {}
  }

  void _jumpBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    _input.clear();
    try {
      final res = await messagesApi.send(widget.userId, body);
      final m = res['data'] as Map<String, dynamic>?;
      if (m != null && mounted) {
        setState(() {
          _messages.add(m);
          _since = '${_messages.last['created_at']}';
        });
        _jumpBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: Text(widget.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!,
                        style:
                            SogoText.bodyMd.copyWith(color: SogoColors.danger)),
                    const SizedBox(height: SogoSpacing.md),
                    SogoButton(
                        label: 'Retry', fullWidth: false, onPressed: _load),
                  ],
                ))
              : Column(children: [
                  Expanded(
                    child: _messages.isEmpty
                        ? Center(
                            child: Text('Say hello - start the conversation',
                                style: SogoText.bodyMd
                                    .copyWith(color: SogoColors.textSecondary)))
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.all(SogoSpacing.lg),
                            itemCount: _messages.length,
                            itemBuilder: (context, i) {
                              final m = _messages[i];
                              final fromMe = m['from_me'] == true;
                              return Align(
                                alignment: fromMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(
                                      bottom: SogoSpacing.sm),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: SogoSpacing.md, vertical: 10),
                                  constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.75),
                                  decoration: BoxDecoration(
                                    color: fromMe
                                        ? SogoColors.primary
                                        : SogoColors.surface,
                                    borderRadius: BorderRadius.only(
                                      topLeft:
                                          const Radius.circular(SogoRadius.md),
                                      topRight:
                                          const Radius.circular(SogoRadius.md),
                                      bottomLeft: Radius.circular(
                                          fromMe ? SogoRadius.md : 4),
                                      bottomRight: Radius.circular(
                                          fromMe ? 4 : SogoRadius.md),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${m['body']}',
                                          style: SogoText.bodyMd.copyWith(
                                              color: fromMe
                                                  ? Colors.white
                                                  : SogoColors.textPrimary)),
                                      const SizedBox(height: 2),
                                      Text(
                                          '${(m['created_at'] ?? '').toString().substring(11, 16)}',
                                          style: SogoText.labelMd.copyWith(
                                              color: fromMe
                                                  ? Colors.white70
                                                  : SogoColors.textMuted)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: SogoSpacing.md, vertical: SogoSpacing.sm),
                      color: SogoColors.surface,
                      child: Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                                hintText: 'Type a message?',
                                border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(SogoRadius.pill)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: SogoSpacing.md, vertical: 10)),
                          ),
                        ),
                        const SizedBox(width: SogoSpacing.sm),
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: SogoColors.primary,
                          child: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send_rounded,
                                  color: Colors.white, size: 20),
                        ).wrapGesture(onTap: _send),
                      ]),
                    ),
                  ),
                ]),
    );
  }
}

extension _Gesture on Widget {
  Widget wrapGesture({required VoidCallback onTap}) =>
      GestureDetector(onTap: onTap, child: this);
}
