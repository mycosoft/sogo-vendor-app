import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() async {
    final res = await notificationApi.list();
    final data = res['data'] as Map<String, dynamic>? ?? const {};
    return {
      'items':
          List<Map<String, dynamic>>.from(data['items'] as List? ?? const []),
      'unread': (data['unread'] as num?) ?? 0,
    };
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _markAll() async {
    try {
      await notificationApi.markAllRead();
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _markRead(Map<String, dynamic> n) async {
    if (n['read_at'] != null) return;
    try {
      await notificationApi.markRead(n['id'] as int);
      if (mounted) setState(() => _future = _load());
    } catch (_) {}
  }

  IconData _icon(String? type) {
    switch (type) {
      case 'success':
        return Icons.check_circle_outline;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'alert':
      case 'danger':
        return Icons.error_outline;
      default:
        return Icons.info_outline;
    }
  }

  Color _color(String? type) {
    switch (type) {
      case 'success':
        return SogoColors.success;
      case 'warning':
        return SogoColors.warning;
      case 'alert':
      case 'danger':
        return SogoColors.danger;
      default:
        return SogoColors.info;
    }
  }

  String _timeAgo(String? iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _markAll,
            child: Text('Mark all read',
                style: SogoText.bodySm.copyWith(
                    color: SogoColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!['items'] as List<Map<String, dynamic>>;

          if (items.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 140),
                Icon(Icons.notifications_none_rounded,
                    size: 56, color: SogoColors.textMuted),
                SizedBox(height: SogoSpacing.md),
                Center(
                  child: Text(
                    'No notifications yet',
                    style: TextStyle(color: SogoColors.textSecondary),
                  ),
                ),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(SogoSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: SogoSpacing.md),
              itemBuilder: (context, i) {
                final n = items[i];
                final unread = n['read_at'] == null;
                final color = _color(n['type'] as String?);

                return GestureDetector(
                  onTap: () => _markRead(n),
                  child: Container(
                    padding: const EdgeInsets.all(SogoSpacing.md),
                    decoration: BoxDecoration(
                      color:
                          unread ? SogoColors.primaryLight : SogoColors.surface,
                      borderRadius: BorderRadius.circular(SogoRadius.lg),
                      boxShadow: const [SogoShadows.card],
                      border: unread
                          ? Border.all(
                              color: SogoColors.primary.withOpacity(0.3))
                          : null,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(_icon(n['type'] as String?),
                            color: color, size: 22),
                        const SizedBox(width: SogoSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text('${n['title'] ?? ''}',
                                        style: SogoText.bodyLg.copyWith(
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  if (unread)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                          color: SogoColors.primary,
                                          shape: BoxShape.circle),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('${n['message'] ?? ''}',
                                  style: SogoText.bodySm.copyWith(
                                      color: SogoColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text(_timeAgo(n['created_at'] as String?),
                                  style: SogoText.labelMd.copyWith(
                                      color: SogoColors.textMuted,
                                      fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
