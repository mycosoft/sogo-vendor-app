import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/sogo_widgets.dart';
import '../../messages/screens/chats_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> _items = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await providerApi.orders();
      final data = res['data'] as Map<String, dynamic>;
      _items =
          List<Map<String, dynamic>>.from(data['items'] as List? ?? const []);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() async => _load();

  (Color, Color) _statusStyle(String status) {
    switch (status) {
      case 'delivered':
        return (const Color(0xFFDCFCE7), const Color(0xFF166534));
      case 'cancelled':
        return (const Color(0xFFFEE2E2), const Color(0xFF991B1B));
      case 'out_for_delivery':
        return (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8));
      case 'packed':
        return (const Color(0xFFEDE9FE), const Color(0xFF6D28D9));
      default:
        return (const Color(0xFFFEF3C7), const Color(0xFF92400E));
    }
  }

  Future<void> _openOrder(Map<String, dynamic> order) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(SogoRadius.xl)),
      ),
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(
        future: providerApi.orderShow(order['id'] as int),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final o = snap.data!['data'] as Map<String, dynamic>;
          final items =
              List<Map<String, dynamic>>.from(o['items'] as List? ?? const []);
          final customer = o['customer'] as Map<String, dynamic>? ?? const {};
          final paid = '${o['payment_status'] ?? ''}' == 'paid';

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            builder: (ctx, controller) => Padding(
              padding: const EdgeInsets.all(SogoSpacing.xl),
              child: ListView(
                controller: controller,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('#${o['reference'] ?? ''}',
                            style: SogoText.headlineLg),
                      ),
                      _statusChip('${o['status'] ?? ''}'),
                    ],
                  ),
                  const SizedBox(height: SogoSpacing.sm),
                  // Customer card with call + chat.
                  SogoCard(
                    child: Row(children: [
                      CircleAvatar(
                          radius: 22,
                          backgroundColor: SogoColors.primaryLight,
                          child: Text(
                              '${customer['name'] ?? 'C'}'
                                  .characters
                                  .first
                                  .toUpperCase(),
                              style: SogoText.bodyLg
                                  .copyWith(color: SogoColors.primary))),
                      const SizedBox(width: SogoSpacing.md),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('${customer['name'] ?? '-'}',
                                style: SogoText.bodyLg
                                    .copyWith(fontWeight: FontWeight.w700)),
                            Text('${customer['phone'] ?? ''}',
                                style: SogoText.bodySm
                                    .copyWith(color: SogoColors.textSecondary)),
                          ])),
                      IconButton.filled(
                          tooltip: 'Call customer',
                          onPressed: () => _call('${customer['phone'] ?? ''}'),
                          style: IconButton.styleFrom(
                              backgroundColor: SogoColors.primary),
                          icon: const Icon(Icons.call_rounded,
                              color: Colors.white, size: 20)),
                      IconButton.filledTonal(
                          tooltip: 'Chat',
                          onPressed: customer['id'] == null
                              ? null
                              : () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                      userId: (customer['id'] as num).toInt(),
                                      name:
                                          '${customer['name'] ?? 'Customer'}'))),
                          icon: const Icon(Icons.chat_bubble_outline_rounded,
                              size: 20)),
                    ]),
                  ),
                  const SizedBox(height: SogoSpacing.md),
                  Text('Items (${items.length})', style: SogoText.headlineMd),
                  const SizedBox(height: SogoSpacing.sm),
                  ...items.map((it) => Padding(
                        padding: const EdgeInsets.only(bottom: SogoSpacing.sm),
                        child: Row(
                          children: [
                            Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                    color: SogoColors.surfaceMuted,
                                    borderRadius:
                                        BorderRadius.circular(SogoRadius.sm)),
                                child: '${it['product_image'] ?? ''}'.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                            SogoRadius.sm),
                                        child: Image.network(
                                            '${it['product_image']}',
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                    Icons.inventory_2_outlined,
                                                    size: 20,
                                                    color:
                                                        SogoColors.textMuted)),
                                      )
                                    : const Icon(Icons.inventory_2_outlined,
                                        size: 20, color: SogoColors.textMuted)),
                            const SizedBox(width: SogoSpacing.md),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      '${it['product_name'] ?? 'Item'} x ${it['quantity'] ?? 0}',
                                      style: SogoText.bodyMd.copyWith(
                                          fontWeight: FontWeight.w600)),
                                  if ('${it['product_sku'] ?? ''}'.isNotEmpty)
                                    Text('${it['product_sku']}',
                                        style: SogoText.labelMd.copyWith(
                                            color: SogoColors.textSecondary)),
                                ])),
                            Text(ugx(num.tryParse('${it['total'] ?? 0}')),
                                style: SogoText.bodyMd
                                    .copyWith(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      )),
                  const Divider(),
                  _orderRow(
                      'Subtotal', ugx(num.tryParse('${o['subtotal'] ?? 0}'))),
                  _orderRow('Delivery',
                      ugx(num.tryParse('${o['delivery_fee'] ?? 0}'))),
                  _orderRow('Total', ugx(num.tryParse('${o['total'] ?? 0}')),
                      bold: true),
                  const SizedBox(height: SogoSpacing.md),
                  if ('${o['delivery_address'] ?? ''}'.isNotEmpty)
                    _orderRow('Deliver to', '${o['delivery_address']}'),
                  if ('${o['customer_notes'] ?? ''}'.isNotEmpty)
                    _orderRow('Notes', '${o['customer_notes']}'),
                  _orderRow(
                      'Payment',
                      paid
                          ? 'Paid'
                          : 'Unpaid${'${o['payment_status'] ?? ''}'.isNotEmpty && '${o['payment_status']}' != 'unpaid' ? ' (${o['payment_status']})' : ''}'),
                  // Cash on delivery / pickup: record it when the money
                  // is in hand. Notifies the customer + books it.
                  if (!paid) ...[
                    const SizedBox(height: SogoSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _markPaid(
                            o['id'] as int, '${o['reference'] ?? ''}', ctx),
                        icon: const Icon(Icons.payments_outlined, size: 18),
                        label: const Text('Record cash payment'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SogoColors.primary,
                          side: const BorderSide(
                              color: SogoColors.primary, width: 1.2),
                          padding: const EdgeInsets.symmetric(
                              vertical: SogoSpacing.md),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: SogoSpacing.xl),
                  Text('Update status', style: SogoText.headlineMd),
                  const SizedBox(height: SogoSpacing.sm),
                  Text('The customer is notified at every step.',
                      style: SogoText.bodySm
                          .copyWith(color: SogoColors.textSecondary)),
                  const SizedBox(height: SogoSpacing.md),
                  Wrap(
                    spacing: SogoSpacing.sm,
                    runSpacing: SogoSpacing.sm,
                    children: [
                      for (final s in [
                        'confirmed',
                        'packed',
                        'out_for_delivery',
                        'delivered',
                        'cancelled'
                      ])
                        ActionChip(
                          label: Text(_statusLabel(s)),
                          onPressed: s == o['status']
                              ? null
                              : () => _changeStatus(o['id'] as int, s, ctx),
                        ),
                    ],
                  ),
                  const SizedBox(height: SogoSpacing.xl),
                ],
              ),
            ),
          );
        },
      ),
    );
    _load();
  }

  String _statusLabel(String s) => s.replaceAll('_', ' ');

  Widget _orderRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style:
                    SogoText.bodyMd.copyWith(color: SogoColors.textSecondary))),
        Text(value,
            style: SogoText.bodyMd.copyWith(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
      ]),
    );
  }

  Future<void> _call(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri.parse('tel:$cleaned');
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (_) {}
  }

  Future<void> _markPaid(
      int id, String reference, BuildContext sheetCtx) async {
    final confirmed = await showDialog<bool>(
      context: sheetCtx,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SogoRadius.lg)),
        title: const Text('Record cash payment?'),
        content: Text(
            'Confirm the customer paid $reference in cash. It will be marked paid and the customer notified.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not yet')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cash received',
                style: TextStyle(color: SogoColors.primary)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await providerApi.markOrderPaid(id);
      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Cash payment recorded'),
            backgroundColor: SogoColors.primary));
      }
      _load();
    } catch (e) {
      if (sheetCtx.mounted) {
        ScaffoldMessenger.of(sheetCtx)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _changeStatus(
      int id, String status, BuildContext sheetCtx) async {
    try {
      await providerApi.updateOrderStatus(id, status);
      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Order marked as ${_statusLabel(status)}'),
          backgroundColor: SogoColors.primary,
        ));
      }
    } catch (e) {
      if (sheetCtx.mounted) {
        ScaffoldMessenger.of(sheetCtx)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Widget _statusChip(String status) {
    final (bg, fg) = _statusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SogoRadius.pill),
      ),
      child: Text(_statusLabel(status).toUpperCase(),
          style: SogoText.labelMd.copyWith(color: fg, fontSize: 10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: const Text('Orders')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _items.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Icon(
                          _error != null
                              ? Icons.cloud_off_rounded
                              : Icons.shopping_bag_outlined,
                          size: 48,
                          color: SogoColors.textMuted,
                        ),
                        const SizedBox(height: SogoSpacing.md),
                        Center(
                          child: Text(
                            _error != null
                                ? 'Could not load orders.\nPull down to retry.'
                                : 'No orders yet.\nCustomer orders from your shop appear here.',
                            textAlign: TextAlign.center,
                            style: SogoText.bodyMd
                                .copyWith(color: SogoColors.textSecondary),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(SogoSpacing.lg),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: SogoSpacing.md),
                      itemBuilder: (context, i) {
                        final o = _items[i];
                        return GestureDetector(
                          onTap: () => _openOrder(o),
                          child: Container(
                            padding: const EdgeInsets.all(SogoSpacing.md),
                            decoration: BoxDecoration(
                              color: SogoColors.surface,
                              borderRadius:
                                  BorderRadius.circular(SogoRadius.lg),
                              boxShadow: const [SogoShadows.card],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: SogoColors.primaryLight,
                                    borderRadius:
                                        BorderRadius.circular(SogoRadius.md),
                                  ),
                                  child: const Icon(Icons.shopping_bag_outlined,
                                      color: SogoColors.primary),
                                ),
                                const SizedBox(width: SogoSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${o['reference'] ?? ''}',
                                          style: SogoText.bodyLg.copyWith(
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${o['customer']?['name'] ?? '-'} - ${(o['item_count'] as num?) ?? 0} items',
                                        style: SogoText.bodySm.copyWith(
                                            color: SogoColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('UGX ${o['total'] ?? 0}',
                                        style: SogoText.bodyLg.copyWith(
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    _statusChip('${o['status'] ?? ''}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
