import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_services.dart';
import '../../../core/utils/app_time.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late Future<Map<String, dynamic>> _future = _load();
  final _money = NumberFormat.decimalPattern();
  int _tab = 0; // 0 = transactions, 1 = wallet ledger, 2 = withdrawals

  Future<Map<String, dynamic>> _load() async {
    final wallet = await paymentApi.wallet();

    // History endpoints fail independently - one bad call must not
    // blank the whole wallet screen.
    List<Map<String, dynamic>> txns = const [];
    List<Map<String, dynamic>> withdrawals = const [];
    List<Map<String, dynamic>> ledger = const [];
    try {
      txns = _list(await paymentApi.transactions());
    } catch (_) {}
    try {
      withdrawals = _list(await paymentApi.withdrawals());
    } catch (_) {}
    try {
      ledger = _list(await paymentApi.ledger());
    } catch (_) {}

    return {
      'wallet': wallet['data'] as Map<String, dynamic>,
      'transactions': txns,
      'withdrawals': withdrawals,
      'ledger': ledger,
    };
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic> res) {
    final data = res['data'];
    if (data is Map && data['items'] is List) {
      return List<Map<String, dynamic>>.from(data['items'] as List);
    }
    if (data is Map && data['data'] is List) {
      return List<Map<String, dynamic>>.from(data['data'] as List);
    }
    if (data is List) return List<Map<String, dynamic>>.from(data);
    return const [];
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  String _ugx(num? value) =>
      'UGX ${_money.format(double.tryParse('${value ?? 0}') ?? 0)}';

  Future<void> _showWithdrawSheet(num balance) async {
    final amountCtl = TextEditingController();
    final accountCtl = TextEditingController();
    final nameCtl = TextEditingController();
    String destination = 'mobile_money';

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(SogoRadius.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: SogoSpacing.xl,
            right: SogoSpacing.xl,
            top: SogoSpacing.xl,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + SogoSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Request withdrawal', style: SogoText.headlineLg),
              const SizedBox(height: SogoSpacing.sm),
              Text('Available: ${_ugx(balance)}',
                  style: SogoText.bodySm
                      .copyWith(color: SogoColors.textSecondary)),
              const SizedBox(height: SogoSpacing.lg),
              TextField(
                controller: amountCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (UGX, min 5,000)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: SogoSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: destination,
                decoration: const InputDecoration(
                  labelText: 'Destination',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'mobile_money', child: Text('Mobile money')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank account')),
                ],
                onChanged: (v) =>
                    setSheet(() => destination = v ?? 'mobile_money'),
              ),
              const SizedBox(height: SogoSpacing.md),
              TextField(
                controller: accountCtl,
                decoration: InputDecoration(
                  labelText: destination == 'mobile_money'
                      ? 'Mobile money number'
                      : 'Account number',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: SogoSpacing.md),
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(
                  labelText: 'Account holder name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: SogoSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final amount = double.tryParse(amountCtl.text.trim());
                    if (amount == null ||
                        amount < 5000 ||
                        accountCtl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text(
                              'Enter a valid amount (min 5,000) and account')));
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Submit request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (submitted != true) return;

    try {
      await paymentApi.withdraw({
        'amount': double.tryParse(amountCtl.text.trim()),
        'destination_type': destination,
        'destination_account': accountCtl.text.trim(),
        'destination_name': nameCtl.text.trim(),
        if (destination == 'bank') 'destination_bank_name': 'Bank',
      });
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Withdrawal requested ??" it will be processed shortly'),
          backgroundColor: SogoColors.primary,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: const Text('Wallet')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            return const Center(child: CircularProgressIndicator());
          }

          final wallet = snapshot.data!['wallet'] as Map<String, dynamic>;
          final txns =
              snapshot.data!['transactions'] as List<Map<String, dynamic>>;
          final ledger = snapshot.data!['ledger'] as List<Map<String, dynamic>>;
          final withdrawals =
              snapshot.data!['withdrawals'] as List<Map<String, dynamic>>;
          final balance = (wallet['balance'] as num?) ?? 0;
          final pending = (wallet['pending_balance'] as num?) ?? 0;
          final lifetime = (wallet['lifetime_earnings'] as num?) ?? 0;
          final withdrawn = (wallet['total_withdrawn'] as num?) ?? 0;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(SogoSpacing.lg),
              children: [
                // -- Balance hero --
                Container(
                  padding: const EdgeInsets.all(SogoSpacing.xl),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      SogoColors.secondary,
                      SogoColors.secondaryDark
                    ]),
                    borderRadius: BorderRadius.circular(SogoRadius.xl),
                    boxShadow: const [SogoShadows.elevated],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius:
                                  BorderRadius.circular(SogoRadius.md),
                            ),
                            child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Colors.white,
                                size: 20),
                          ),
                          const SizedBox(width: SogoSpacing.md),
                          Text('Available balance',
                              style: SogoText.bodyMd
                                  .copyWith(color: Colors.white70)),
                        ],
                      ),
                      const SizedBox(height: SogoSpacing.lg),
                      Text(_ugx(balance),
                          style:
                              SogoText.displayLg.copyWith(color: Colors.white)),
                      const SizedBox(height: SogoSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          // Always visible & tappable - the sheet explains
                          // the minimum if the balance is too low.
                          onPressed: () => _showWithdrawSheet(balance),
                          icon: const Icon(Icons.upload_rounded, size: 18),
                          label: const Text('Request withdrawal'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: SogoColors.secondaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // -- Earnings stats --
                const SizedBox(height: SogoSpacing.lg),
                Row(
                  children: [
                    Expanded(
                        child: _statTile('Pending', _ugx(pending),
                            Icons.hourglass_top_rounded, SogoColors.warning)),
                    const SizedBox(width: SogoSpacing.md),
                    Expanded(
                        child: _statTile('Lifetime', _ugx(lifetime),
                            Icons.trending_up_rounded, SogoColors.success)),
                  ],
                ),
                const SizedBox(height: SogoSpacing.md),
                Row(
                  children: [
                    Expanded(
                        child: _statTile('Withdrawn', _ugx(withdrawn),
                            Icons.account_balance_rounded, SogoColors.info)),
                    const SizedBox(width: SogoSpacing.md),
                    Expanded(
                        child: _statTile('Transactions', '${txns.length}',
                            Icons.receipt_long_rounded, SogoColors.primary)),
                  ],
                ),

                // -- Tabs --
                const SizedBox(height: SogoSpacing.xl),
                Container(
                  decoration: BoxDecoration(
                    color: SogoColors.surface,
                    borderRadius: BorderRadius.circular(SogoRadius.md),
                    boxShadow: const [SogoShadows.card],
                  ),
                  child: Row(
                    children: [
                      _tabButton('Transactions', 0),
                      _tabButton('Wallet', 1),
                      _tabButton('Withdrawals', 2),
                    ],
                  ),
                ),
                const SizedBox(height: SogoSpacing.md),

                if (_tab == 0)
                  if (txns.isEmpty)
                    const _EmptyHint(
                        icon: Icons.receipt_long_outlined,
                        text: 'Earnings from completed jobs will appear here.')
                  else
                    ...txns.map((txn) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: SogoSpacing.md),
                          child: GestureDetector(
                            onTap: () => _openTransaction(txn),
                            child: _TransactionTile(txn: txn, money: _ugx),
                          ),
                        ))
                else if (_tab == 1)
                  if (ledger.isEmpty)
                    const _EmptyHint(
                        icon: Icons.account_balance_wallet_outlined,
                        text:
                            'Every movement in and out of your wallet shows here with the running balance.')
                  else
                    ...ledger.map((e) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: SogoSpacing.md),
                          child: _LedgerTile(entry: e, money: _ugx),
                        ))
                else if (withdrawals.isEmpty)
                  const _EmptyHint(
                      icon: Icons.account_balance_rounded,
                      text: 'Your withdrawal requests will appear here.')
                else
                  ...withdrawals.map((w) => Padding(
                        padding: const EdgeInsets.only(bottom: SogoSpacing.md),
                        child: _WithdrawalTile(w: w, money: _ugx),
                      )),

                const SizedBox(height: SogoSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: SogoSpacing.md),
          decoration: BoxDecoration(
            color: selected ? SogoColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(SogoRadius.md),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: SogoText.bodyMd.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : SogoColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(SogoSpacing.md),
      decoration: BoxDecoration(
        color: SogoColors.surface,
        borderRadius: BorderRadius.circular(SogoRadius.lg),
        boxShadow: const [SogoShadows.card],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: SogoSpacing.sm),
          Text(value, style: SogoText.headlineMd.copyWith(fontSize: 15)),
          Text(label,
              style: SogoText.bodySm.copyWith(color: SogoColors.textSecondary)),
        ],
      ),
    );
  }

  Future<void> _openTransaction(Map<String, dynamic> txn) async {
    final request = txn['service_request'] as Map<String, dynamic>?;
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
            Row(children: [
              Expanded(
                  child: Text(
                      request?['reference'] ??
                          '${txn['reference'] ?? 'Payment'}',
                      style: SogoText.headlineLg)),
              _statusPill('${txn['status'] ?? ''}'),
            ]),
            const SizedBox(height: SogoSpacing.md),
            _detailRow('Amount', _ugx((txn['amount'] as num?) ?? 0)),
            _detailRow('Fee', _ugx((txn['fee'] as num?) ?? 0)),
            _detailRow('Net', _ugx((txn['net_amount'] as num?) ?? 0)),
            _detailRow('Method',
                '${txn['payment_method'] ?? '-'}'.replaceAll('_', ' ')),
            if ('${txn['payment_channel'] ?? ''}'.isNotEmpty)
              _detailRow('Channel', '${txn['payment_channel']}'),
            if (request != null)
              _detailRow('Job', '#${request['reference'] ?? request['id']}'),
            if (txn['paid_at'] != null)
              _detailRow('Paid', _date(txn['paid_at'])),
            _detailRow('Recorded', _date(txn['created_at'])),
            if ('${txn['failure_reason'] ?? ''}'.isNotEmpty)
              _detailRow('Reason', '${txn['failure_reason']}'),
            const SizedBox(height: SogoSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String status) {
    final (bg, fg) = switch (status) {
      'successful' => (
          const Color(0xFFDCFCE7),
          const Color(0xFF166534),
        ),
      'pending' => (
          const Color(0xFFFEF3C7),
          const Color(0xFF92400E),
        ),
      _ => (
          const Color(0xFFFEE2E2),
          const Color(0xFF991B1B),
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(SogoRadius.pill)),
      child: Text(status.toUpperCase(),
          style: SogoText.labelMd.copyWith(color: fg, fontSize: 10)),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SogoSpacing.sm),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style:
                    SogoText.bodyMd.copyWith(color: SogoColors.textSecondary))),
        Text(value,
            style: SogoText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.txn, required this.money});

  final Map<String, dynamic> txn;
  final String Function(num?) money;

  (Color, Color, IconData) _style(String? status) {
    switch (status) {
      case 'successful':
        return (
          const Color(0xFFDCFCE7),
          const Color(0xFF166534),
          Icons.check_circle_outline
        );
      case 'pending':
        return (
          const Color(0xFFFEF3C7),
          const Color(0xFF92400E),
          Icons.hourglass_top_rounded
        );
      case 'failed':
        return (
          const Color(0xFFFEE2E2),
          const Color(0xFF991B1B),
          Icons.error_outline
        );
      default:
        return (
          SogoColors.surfaceMuted,
          SogoColors.textSecondary,
          Icons.receipt_long_outlined
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = '${txn['status'] ?? 'unknown'}';
    final (bg, fg, icon) = _style(status);
    final request = txn['service_request'] as Map<String, dynamic>?;

    return Container(
      padding: const EdgeInsets.all(SogoSpacing.md),
      decoration: BoxDecoration(
        color: SogoColors.surface,
        borderRadius: BorderRadius.circular(SogoRadius.lg),
        boxShadow: const [SogoShadows.card],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(SogoRadius.md)),
            child: Icon(icon, color: fg, size: 22),
          ),
          const SizedBox(width: SogoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    request?['reference'] ?? '${txn['reference'] ?? 'Payment'}',
                    style:
                        SogoText.bodyLg.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  txn['paid_at'] != null ? _date(txn['paid_at']) : status,
                  style:
                      SogoText.bodySm.copyWith(color: SogoColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(money((txn['amount'] as num?) ?? 0),
                  style: SogoText.bodyLg.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(SogoRadius.pill)),
                child: Text(status.toUpperCase(),
                    style: SogoText.labelMd.copyWith(color: fg, fontSize: 9)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.entry, required this.money});

  final Map<String, dynamic> entry;
  final String Function(num?) money;

  (Color, Color, IconData, String) _style(String type) {
    return switch (type) {
      'credit' => (
          const Color(0xFFDCFCE7),
          const Color(0xFF166534),
          Icons.arrow_downward_rounded,
          '+'
        ),
      'commission' => (
          const Color(0xFFFEF3C7),
          const Color(0xFF92400E),
          Icons.percent_rounded,
          '-'
        ),
      'withdrawal' || 'debit' => (
          const Color(0xFFFEE2E2),
          const Color(0xFF991B1B),
          Icons.arrow_upward_rounded,
          '-'
        ),
      'refund' => (
          const Color(0xFFDBEAFE),
          const Color(0xFF1D4ED8),
          Icons.undo_rounded,
          '+'
        ),
      _ => (
          SogoColors.surfaceMuted,
          SogoColors.textSecondary,
          Icons.receipt_long_outlined,
          ''
        ),
    };
  }

  String _label(String type) {
    return switch (type) {
      'credit' => 'Money in',
      'commission' => 'Commission owed',
      'withdrawal' => 'Withdrawal',
      'debit' => 'Money out',
      'refund' => 'Refund',
      _ => type.replaceAll('_', ' '),
    };
  }

  @override
  Widget build(BuildContext context) {
    final type = '${entry['type'] ?? ''}';
    final (bg, fg, icon, sign) = _style(type);
    return Container(
      padding: const EdgeInsets.all(SogoSpacing.md),
      decoration: BoxDecoration(
        color: SogoColors.surface,
        borderRadius: BorderRadius.circular(SogoRadius.lg),
        boxShadow: const [SogoShadows.card],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(SogoRadius.md)),
            child: Icon(icon, color: fg, size: 22),
          ),
          const SizedBox(width: SogoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${entry['description'] ?? _label(type)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        SogoText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${_label(type)}${entry['transaction_reference'] != null ? ' - ${entry['transaction_reference']}' : ''}',
                  style:
                      SogoText.bodySm.copyWith(color: SogoColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$sign${money((entry['amount'] as num?) ?? 0)}',
                  style: SogoText.bodyLg
                      .copyWith(fontWeight: FontWeight.w800, color: fg)),
              const SizedBox(height: 2),
              Text('Bal ${money((entry['balance_after'] as num?) ?? 0)}',
                  style: SogoText.labelMd
                      .copyWith(color: SogoColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _WithdrawalTile extends StatelessWidget {
  const _WithdrawalTile({required this.w, required this.money});

  final Map<String, dynamic> w;
  final String Function(num?) money;

  (Color, IconData) _style(String? status) {
    switch (status) {
      case 'completed':
      case 'paid':
        return (const Color(0xFFDCFCE7), Icons.check_circle_outline);
      case 'pending':
      case 'processing':
        return (const Color(0xFFFEF3C7), Icons.hourglass_top_rounded);
      case 'rejected':
      case 'failed':
        return (const Color(0xFFFEE2E2), Icons.cancel_outlined);
      default:
        return (SogoColors.surfaceMuted, Icons.account_balance_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = '${w['status'] ?? 'pending'}';
    final (bg, icon) = _style(status);

    return Container(
      padding: const EdgeInsets.all(SogoSpacing.md),
      decoration: BoxDecoration(
        color: SogoColors.surface,
        borderRadius: BorderRadius.circular(SogoRadius.lg),
        boxShadow: const [SogoShadows.card],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(SogoRadius.md)),
            child: Icon(icon, size: 22, color: SogoColors.secondary),
          ),
          const SizedBox(width: SogoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${w['reference'] ?? 'Withdrawal'}',
                    style:
                        SogoText.bodyLg.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${w['destination_type'] ?? ''} ?- ${w['destination_account'] ?? ''}',
                  style:
                      SogoText.bodySm.copyWith(color: SogoColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(money((w['amount'] as num?) ?? 0),
                  style: SogoText.bodyLg.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(status.toUpperCase(),
                  style: SogoText.labelMd
                      .copyWith(fontSize: 9, color: SogoColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

String _date(dynamic iso) => formatServerDate(iso);

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SogoCard(
      child: Column(
        children: [
          Icon(icon, size: 36, color: SogoColors.textMuted),
          const SizedBox(height: SogoSpacing.sm),
          Text(text,
              style: SogoText.bodySm.copyWith(color: SogoColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
