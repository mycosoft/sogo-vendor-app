import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_time.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/sogo_widgets.dart';

/// Earnings dashboard: revenue hero, week/average tiles, source
/// breakdown, 7-day chart.
///
/// Combines completed jobs + delivered shop orders + paid invoices.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  late Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() async {
    List<Map<String, dynamic>> requests = const [];
    List<Map<String, dynamic>> orders = const [];
    List<Map<String, dynamic>> invoices = const [];
    try {
      requests = _items(await providerApi.requests());
    } catch (_) {}
    try {
      orders = _items(await providerApi.orders());
    } catch (_) {}
    try {
      invoices = _items(await providerApi.invoices());
    } catch (_) {}
    return {'requests': requests, 'orders': orders, 'invoices': invoices};
  }

  /// Lenient list parsing: skips nulls and non-maps instead of throwing
  /// "type 'Null' is not a subtype" on unexpected API shapes.
  List<Map<String, dynamic>> _items(Map<String, dynamic> res) {
    final data = res['data'];
    List<dynamic>? raw;
    if (data is Map && data['items'] is List) {
      raw = data['items'] as List;
    } else if (data is Map && data['data'] is List) {
      raw = data['data'] as List;
    } else if (data is List) {
      raw = data;
    }
    if (raw == null) return [];
    return [
      for (final e in raw)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  List<Map<String, dynamic>> _list(dynamic v) {
    if (v is List) {
      return [
        for (final e in v)
          if (e is Map) Map<String, dynamic>.from(e),
      ];
    }
    return [];
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  num _amount(Map<String, dynamic> r) =>
      num.tryParse('${r['final_price'] ?? r['estimated_price'] ?? 0}') ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: const Text('Earnings')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            if (snap.hasError) {
              return Center(child: Text('${snap.error}'));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final requests = _list(snap.data!['requests']);
          final orders = _list(snap.data!['orders']);
          final invoices = _list(snap.data!['invoices']);

          final completed =
              requests.where((r) => '${r['status']}' == 'completed').toList();
          final deliveredOrders = orders
              .where((o) => '${o['status']}' == 'delivered')
              .toList();
          final paidInvoices = invoices
              .where((v) => '${v['status']}' == 'paid')
              .toList();

          final jobsGross =
              completed.fold<num>(0, (sum, r) => sum + _amount(r));
          final ordersGross = deliveredOrders.fold<num>(
              0, (sum, o) => sum + (num.tryParse('${o['total'] ?? 0}') ?? 0));
          final invoicesGross = paidInvoices.fold<num>(0,
              (sum, v) => sum + (num.tryParse('${v['grand_total'] ?? 0}') ?? 0));
          final grossAll = jobsGross + ordersGross + invoicesGross;
          final eventCount =
              completed.length + deliveredOrders.length + paidInvoices.length;
          final avgEarning = eventCount == 0 ? 0 : grossAll / eventCount;

          // Unified earning events for the weekly chart.
          final events = <(num, DateTime?)>[
            for (final r in completed)
              (_amount(r),
                  parseServerDate(r['completed_at'] ?? r['updated_at'] ?? r['created_at'])),
            for (final o in deliveredOrders)
              ((num.tryParse('${o['total'] ?? 0}') ?? 0),
                  parseServerDate(o['delivered_at'] ?? o['updated_at'] ?? o['created_at'])),
            for (final v in paidInvoices)
              ((num.tryParse('${v['grand_total'] ?? 0}') ?? 0),
                  parseServerDate(v['updated_at'] ?? v['created_at'])),
          ];

          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final days = List.generate(
              7, (i) => today.subtract(Duration(days: 6 - i)));
          final dayTotals = List<num>.filled(7, 0);
          for (final e in events) {
            final d = e.$2;
            if (d == null) continue;
            final day = DateTime(d.year, d.month, d.day);
            final idx = day.difference(days.first).inDays;
            if (idx >= 0 && idx < 7) {
              dayTotals[idx] += e.$1;
            }
          }
          final weekGross = dayTotals.fold<num>(0, (a, b) => a + b);

          const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
          final maxDay = dayTotals.fold<num>(0, (a, b) => a > b ? a : b);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(SogoSpacing.lg),
              children: [
                // Hero: lifetime gross.
                Container(
                  padding: const EdgeInsets.all(SogoSpacing.xl),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      SogoColors.primary,
                      SogoColors.primaryDark
                    ]),
                    borderRadius: BorderRadius.circular(SogoRadius.xl),
                    boxShadow: const [SogoShadows.elevated],
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lifetime revenue',
                            style: SogoText.bodySm
                                .copyWith(color: Colors.white70)),
                        Text(ugx(grossAll),
                            style: SogoText.displayMd
                                .copyWith(color: Colors.white)),
                      ]),
                ),
                const SizedBox(height: SogoSpacing.md),
                Row(children: [
                  Expanded(
                      child: _statTile(
                          'This week',
                          ugx(weekGross),
                          Icons.date_range_outlined,
                          SogoColors.secondary)),
                  const SizedBox(width: SogoSpacing.md),
                  Expanded(
                      child: _statTile(
                          'Avg earning',
                          ugx(avgEarning),
                          Icons.receipt_long_outlined,
                          SogoColors.tertiary)),
                ]),
                const SizedBox(height: SogoSpacing.md),
                SogoCard(
                  child: Column(children: [
                    _sourceRow(
                        Icons.build_rounded,
                        SogoColors.primary,
                        'Jobs',
                        '${completed.length} completed',
                        ugx(jobsGross)),
                    const Divider(height: SogoSpacing.lg),
                    _sourceRow(
                        Icons.shopping_bag_outlined,
                        SogoColors.secondary,
                        'Orders',
                        '${deliveredOrders.length} delivered',
                        ugx(ordersGross)),
                    const Divider(height: SogoSpacing.lg),
                    _sourceRow(
                        Icons.description_outlined,
                        SogoColors.tertiary,
                        'Invoices',
                        '${paidInvoices.length} paid',
                        ugx(invoicesGross)),
                  ]),
                ),
                const SizedBox(height: SogoSpacing.xl),
                const SogoSectionTitle('Last 7 days'),
                const SizedBox(height: SogoSpacing.md),
                SogoCard(
                  child: SizedBox(
                    height: 170,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < 7; i++)
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (dayTotals[i] > 0)
                                  Text(_shortMoney(dayTotals[i]),
                                      style: SogoText.labelMd.copyWith(
                                          fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Container(
                                  height: maxDay <= 0
                                      ? 4
                                      : 8 +
                                          110 *
                                              (dayTotals[i] / maxDay),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: i == 6
                                        ? SogoColors.primary
                                        : SogoColors.primary
                                            .withOpacity(0.35),
                                    borderRadius: BorderRadius.circular(
                                        SogoRadius.sm),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(dayLabels[days[i].weekday - 1],
                                    style: SogoText.labelMd.copyWith(
                                        color: SogoColors.textSecondary,
                                        fontWeight: i == 6
                                            ? FontWeight.w800
                                            : FontWeight.w400)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _shortMoney(num v) {
    if (v >= 1000000) {
      final m = v / 1000000;
      return '${m.toStringAsFixed(m >= 10 ? 0 : 1)}M';
    }
    if (v >= 1000) {
      final k = v / 1000;
      return '${k.toStringAsFixed(k >= 100 ? 0 : 1)}k';
    }
    return '$v';
  }

  Widget _sourceRow(
      IconData icon, Color color, String label, String count, String amount) {
    return Row(children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(SogoRadius.md),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: SogoSpacing.md),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: SogoText.bodyLg.copyWith(fontWeight: FontWeight.w700)),
          Text(count,
              style: SogoText.bodySm
                  .copyWith(color: SogoColors.textSecondary)),
        ]),
      ),
      Text(amount,
          style: SogoText.bodyLg.copyWith(fontWeight: FontWeight.w800)),
    ]);
  }

  Widget _statTile(
      String label, String value, IconData icon, Color color) {
    return SogoCard(
      padding: const EdgeInsets.all(SogoSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(SogoRadius.md),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: SogoSpacing.sm),
        Text(value,
            style: SogoText.headlineMd.copyWith(fontWeight: FontWeight.w800)),
        Text(label,
            style:
                SogoText.bodySm.copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
