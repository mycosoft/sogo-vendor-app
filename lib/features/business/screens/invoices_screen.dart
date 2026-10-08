import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/sogo_widgets.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
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
      final res = await providerApi.invoices();
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
      case 'paid':
        return (const Color(0xFFDCFCE7), const Color(0xFF166534));
      case 'overdue':
        return (const Color(0xFFFEE2E2), const Color(0xFF991B1B));
      default:
        return (const Color(0xFFFEF3C7), const Color(0xFF92400E));
    }
  }

  double _pctOf(num? base, num? pct) => (base ?? 0) * (pct ?? 0) / 100;

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style:
                    SogoText.bodySm.copyWith(color: SogoColors.textSecondary))),
        Text(value,
            style: SogoText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _statusChip(String status) {
    final (bg, fg) = _statusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SogoRadius.pill),
      ),
      child: Text(status.toUpperCase(),
          style: SogoText.labelMd.copyWith(color: fg, fontSize: 10)),
    );
  }

  // -- Flutterwave payment link --

  Future<void> _getPaymentLink(int invoiceId) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    Map<String, dynamic>? data;
    String? error;
    try {
      final res = await providerApi.invoicePaymentLink(invoiceId);
      data = res['data'] as Map<String, dynamic>?;
    } catch (e) {
      error = e.toString();
    }
    if (mounted) Navigator.pop(context); // close spinner

    if (error != null || data == null || data['link'] == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error ?? 'Could not create payment link')));
      }
      return;
    }

    final link = '${data['link']}';
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(SogoRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(SogoSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Flutterwave payment link', style: SogoText.headlineLg),
            const SizedBox(height: SogoSpacing.sm),
            Text(
                'Share this link with the customer. When they pay, the invoice '
                'is marked paid automatically and you get a notification.',
                style:
                    SogoText.bodySm.copyWith(color: SogoColors.textSecondary)),
            const SizedBox(height: SogoSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SogoSpacing.md),
              decoration: BoxDecoration(
                color: SogoColors.surfaceMuted,
                borderRadius: BorderRadius.circular(SogoRadius.md),
              ),
              child: Text(link,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SogoText.bodySm),
            ),
            const SizedBox(height: SogoSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copied')));
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: SogoSpacing.md),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Share.share('Pay your SOGO invoice here: $link');
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -- Create invoice --

  Future<void> _createInvoice() async {
    final customersRes = await providerApi.customers();
    final customers = List<Map<String, dynamic>>.from(
        ((customersRes['data'] as Map<String, dynamic>)['items'] as List?) ??
            const []);
    if (customers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No customers yet - customers appear once they register')));
      }
      return;
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(SogoRadius.xl)),
      ),
      builder: (ctx) => _CreateInvoiceSheet(customers: customers),
    );
    if (ok != true) return;

    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Invoice created'),
          backgroundColor: SogoColors.primary));
    }
  }

  Future<void> _openInvoice(Map<String, dynamic> invoice) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(SogoRadius.xl)),
      ),
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(
        future: providerApi.invoiceShow(invoice['id'] as int),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const SizedBox(
                height: 220, child: Center(child: CircularProgressIndicator()));
          }
          final inv = snap.data!['data'] as Map<String, dynamic>;
          final items = List<Map<String, dynamic>>.from(
              inv['items'] as List? ?? const []);
          final customer = inv['customer'] as Map<String, dynamic>? ?? const {};
          final isPaid = inv['status'] == 'paid';

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            builder: (ctx, controller) => Padding(
              padding: const EdgeInsets.all(SogoSpacing.xl),
              child: ListView(
                controller: controller,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text('${inv['invoice_number'] ?? ''}',
                              style: SogoText.headlineLg)),
                      _statusChip('${inv['status'] ?? ''}'),
                    ],
                  ),
                  const SizedBox(height: SogoSpacing.sm),
                  Text(
                      'Customer: ${customer['name'] ?? '-'} - ${customer['phone'] ?? ''}',
                      style: SogoText.bodySm
                          .copyWith(color: SogoColors.textSecondary)),
                  const SizedBox(height: SogoSpacing.md),
                  Text('Items', style: SogoText.headlineMd),
                  const SizedBox(height: SogoSpacing.sm),
                  ...items.map((it) => Padding(
                        padding: const EdgeInsets.only(bottom: SogoSpacing.sm),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(
                                    '${it['description'] ?? ''} x ${it['quantity'] ?? 0}',
                                    style: SogoText.bodyMd)),
                            Text(
                                ugx(num.tryParse('${it['total_amount'] ?? 0}')),
                                style: SogoText.bodyMd
                                    .copyWith(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      )),
                  const Divider(),
                  _detailRow('Subtotal',
                      ugx(num.tryParse('${inv['subtotal'] ?? ''}'))),
                  _detailRow('Discount (${inv['discount_percent'] ?? 0}%)',
                      '- ${ugx(_pctOf(num.tryParse('${inv['subtotal'] ?? ''}'), num.tryParse('${inv['discount_percent'] ?? ''}')))}'),
                  _detailRow(
                      'Tax (${inv['tax_percent'] ?? 0}%)',
                      ugx(_pctOf(
                          (num.tryParse('${inv['subtotal'] ?? ''}') ?? 0) -
                              _pctOf(
                                  num.tryParse('${inv['subtotal'] ?? ''}'),
                                  num.tryParse(
                                      '${inv['discount_percent'] ?? ''}')),
                          num.tryParse('${inv['tax_percent'] ?? ''}')))),
                  Row(
                    children: [
                      const Expanded(
                          child:
                              Text('Grand total', style: SogoText.headlineMd)),
                      Text(ugx(num.tryParse('${inv['grand_total'] ?? 0}')),
                          style: SogoText.headlineMd
                              .copyWith(color: SogoColors.primary)),
                    ],
                  ),
                  const SizedBox(height: SogoSpacing.lg),
                  if (!isPaid)
                    SogoButton(
                      label: 'Get Flutterwave payment link',
                      icon: Icons.link_rounded,
                      onPressed: () {
                        Navigator.pop(ctx);
                        _getPaymentLink(inv['id'] as int);
                      },
                    ),
                  if (!isPaid) const SizedBox(height: SogoSpacing.md),
                  // Vendors may only move between pending/overdue. "Paid" must
                  // arrive via a verified Flutterwave payment (webhook or
                  // return page) - a manual tap would fake payment with no
                  // money moved and no wallet credit. Cash goes through
                  // "Record cash payment" so the books + commission stay right.
                  Wrap(
                    spacing: SogoSpacing.sm,
                    runSpacing: SogoSpacing.sm,
                    children: [
                      for (final s in ['pending', 'overdue'])
                        ActionChip(
                          label: Text(s.toUpperCase()),
                          onPressed: s == inv['status']
                              ? null
                              : () => _changeStatus(inv['id'] as int, s, ctx),
                        ),
                    ],
                  ),
                  if (!isPaid) ...[
                    const SizedBox(height: SogoSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _recordCash(inv['id'] as int,
                            '${inv['invoice_number'] ?? ''}', ctx),
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
                ],
              ),
            ),
          );
        },
      ),
    );
    _load();
  }

  Future<void> _recordCash(
      int id, String invoiceNumber, BuildContext sheetCtx) async {
    final confirmed = await showDialog<bool>(
      context: sheetCtx,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SogoRadius.lg)),
        title: const Text('Record cash payment?'),
        content: Text(
            'Confirm the customer paid $invoiceNumber in cash.\n\nThe invoice will be marked paid, the cash recorded in the books, and the SOGO commission booked against your wallet.'),
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
      await providerApi.recordCashPayment(id);
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
      await providerApi.updateInvoiceStatus(id, status);
      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Invoice marked as $status'),
            backgroundColor: SogoColors.primary));
      }
    } catch (e) {
      if (sheetCtx.mounted) {
        ScaffoldMessenger.of(sheetCtx)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: const Text('Invoices')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createInvoice,
        icon: const Icon(Icons.add),
        label: const Text('New invoice'),
      ),
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
                              : Icons.description_outlined,
                          size: 48,
                          color: SogoColors.textMuted,
                        ),
                        const SizedBox(height: SogoSpacing.md),
                        Center(
                          child: Text(
                            _error != null
                                ? 'Could not load invoices.\nPull down to retry.'
                                : 'No invoices yet.\nTap "New invoice" to bill a customer.',
                            textAlign: TextAlign.center,
                            style: SogoText.bodyMd
                                .copyWith(color: SogoColors.textSecondary),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          SogoSpacing.lg, SogoSpacing.lg, SogoSpacing.lg, 88),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: SogoSpacing.md),
                      itemBuilder: (context, i) {
                        final inv = _items[i];
                        return GestureDetector(
                          onTap: () => _openInvoice(inv),
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
                                  child: const Icon(Icons.description_outlined,
                                      color: SogoColors.primary),
                                ),
                                const SizedBox(width: SogoSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${inv['invoice_number'] ?? ''}',
                                          style: SogoText.bodyLg.copyWith(
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(
                                          '${inv['customer']?['name'] ?? '-'} - ${(inv['items_count'] as num?) ?? 0} items',
                                          style: SogoText.bodySm.copyWith(
                                              color: SogoColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                        ugx(num.tryParse(
                                            '${inv['grand_total'] ?? 0}')),
                                        style: SogoText.bodyLg.copyWith(
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    _statusChip('${inv['status'] ?? ''}'),
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

// -- Create-invoice sheet --

class _CreateInvoiceSheet extends StatefulWidget {
  const _CreateInvoiceSheet({required this.customers});

  final List<Map<String, dynamic>> customers;

  @override
  State<_CreateInvoiceSheet> createState() => _CreateInvoiceSheetState();
}

class _CreateInvoiceSheetState extends State<_CreateInvoiceSheet> {
  int? _customerId;
  String _paymentMethod = 'mobile_money';
  final _tax = TextEditingController(text: '0');
  final _discount = TextEditingController(text: '0');
  final _notes = TextEditingController();
  final _items = <_ItemRow>[_ItemRow()];

  double get _subtotal => _items.fold(0, (sum, it) => sum + it.total);
  double get _taxPct => double.tryParse(_tax.text.trim()) ?? 0;
  double get _discountPct => double.tryParse(_discount.text.trim()) ?? 0;

  /// Backend math (Invoice::updateTotals): discount off the subtotal first,
  /// then tax on the discounted amount.
  double get _discountAmt => _subtotal * _discountPct / 100;
  double get _taxAmt => (_subtotal - _discountAmt) * _taxPct / 100;
  double get _grandTotal => _subtotal - _discountAmt + _taxAmt;

  @override
  void dispose() {
    _tax.dispose();
    _discount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Widget _totalsCard() {
    String pct(double v) =>
        v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SogoSpacing.md),
      decoration: BoxDecoration(
        color: SogoColors.primaryLight,
        borderRadius: BorderRadius.circular(SogoRadius.md),
      ),
      child: Column(children: [
        _totalRow('Subtotal', ugx(_subtotal)),
        _totalRow('Discount (${pct(_discountPct)}%)', '- ${ugx(_discountAmt)}'),
        _totalRow('Tax (${pct(_taxPct)}%)', ugx(_taxAmt)),
        const Divider(height: SogoSpacing.md),
        _totalRow('Grand total', ugx(_grandTotal), bold: true),
      ]),
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: SogoText.bodySm.copyWith(
                    color: SogoColors.primaryDark,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600))),
        Text(value,
            style: (bold ? SogoText.bodyLg : SogoText.bodyMd).copyWith(
                fontWeight: FontWeight.w800, color: SogoColors.primaryDark)),
      ]),
    );
  }

  Future<void> _submit() async {
    final validItems = _items
        .where((it) =>
            it.description.text.trim().isNotEmpty &&
            (int.tryParse(it.quantity.text.trim()) ?? 0) > 0 &&
            (double.tryParse(it.unitPrice.text.trim()) ?? -1) >= 0)
        .toList();
    if (_customerId == null || validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Select a customer and add at least one item')));
      return;
    }

    final now = DateTime.now();
    try {
      await providerApi.addInvoice({
        'customer_id': _customerId,
        'issued_at': now.toIso8601String(),
        'due_at': now.add(const Duration(days: 7)).toIso8601String(),
        'payment_method': _paymentMethod,
        'tax_percent': double.tryParse(_tax.text.trim()) ?? 0,
        'discount_percent': double.tryParse(_discount.text.trim()) ?? 0,
        'notes': _notes.text.trim(),
        'items': [
          for (final it in validItems)
            {
              'description': it.description.text.trim(),
              'quantity': int.tryParse(it.quantity.text.trim()),
              'unit_price': double.tryParse(it.unitPrice.text.trim()),
            }
        ],
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: SogoSpacing.xl,
        right: SogoSpacing.xl,
        top: SogoSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + SogoSpacing.xl,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New invoice', style: SogoText.headlineLg),
            const SizedBox(height: SogoSpacing.lg),
            Expanded(
              child: ListView(
                children: [
                  DropdownButtonFormField<int>(
                    value: _customerId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Customer *', border: OutlineInputBorder()),
                    items: widget.customers
                        .map((c) => DropdownMenuItem(
                              value: c['id'] as int,
                              child: Text('${c['name']}'
                                  '${c['is_past_customer'] == true ? ' ' : ''}'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _customerId = v),
                  ),
                  const SizedBox(height: SogoSpacing.md),
                  DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Payment method',
                        border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(
                          value: 'mobile_money', child: Text('Mobile money')),
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'bank', child: Text('Bank')),
                    ],
                    onChanged: (v) =>
                        setState(() => _paymentMethod = v ?? 'mobile_money'),
                  ),
                  const SizedBox(height: SogoSpacing.md),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              controller: _tax,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                  labelText: 'Tax %',
                                  border: OutlineInputBorder()))),
                      const SizedBox(width: SogoSpacing.md),
                      Expanded(
                          child: TextField(
                              controller: _discount,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                  labelText: 'Discount %',
                                  border: OutlineInputBorder()))),
                    ],
                  ),
                  const SizedBox(height: SogoSpacing.md),
                  // Live totals: discount off subtotal first, then tax.
                  _totalsCard(),
                  const SizedBox(height: SogoSpacing.lg),
                  Text('Items', style: SogoText.headlineMd),
                  const SizedBox(height: SogoSpacing.sm),
                  ..._items.map((it) => _itemEditor(it)),
                  TextButton.icon(
                    onPressed: () => setState(() => _items.add(_ItemRow())),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add item'),
                  ),
                  const SizedBox(height: SogoSpacing.md),
                  TextField(
                      controller: _notes,
                      decoration: const InputDecoration(
                          labelText: 'Notes', border: OutlineInputBorder())),
                ],
              ),
            ),
            const SizedBox(height: SogoSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: _submit, child: const Text('Create invoice')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemEditor(_ItemRow it) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SogoSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(SogoSpacing.md),
        decoration: BoxDecoration(
          color: SogoColors.surfaceMuted,
          borderRadius: BorderRadius.circular(SogoRadius.md),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                      controller: it.description,
                      decoration: const InputDecoration(
                          hintText: 'Service / item description',
                          border: OutlineInputBorder())),
                ),
                IconButton(
                    onPressed: _items.length <= 1
                        ? null
                        : () => setState(() => _items.remove(it)),
                    icon: const Icon(Icons.close_rounded,
                        color: SogoColors.textMuted)),
              ],
            ),
            const SizedBox(height: SogoSpacing.sm),
            Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: it.quantity,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            labelText: 'Qty', border: OutlineInputBorder()))),
                const SizedBox(width: SogoSpacing.sm),
                Expanded(
                    child: TextField(
                        controller: it.unitPrice,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            labelText: 'Unit price',
                            border: OutlineInputBorder()))),
              ],
            ),
            if ((double.tryParse(it.unitPrice.text.trim()) ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                      'Line total: ${ugx((int.tryParse(it.quantity.text.trim()) ?? 0) * (double.tryParse(it.unitPrice.text.trim()) ?? 0))}',
                      style: SogoText.bodySm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: SogoColors.primaryDark)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow {
  final description = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final unitPrice = TextEditingController();

  double get total =>
      (int.tryParse(quantity.text) ?? 0) *
      (double.tryParse(unitPrice.text) ?? 0);
}
