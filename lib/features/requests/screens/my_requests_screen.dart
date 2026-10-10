import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';
import 'request_details_screen.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  late Future<List<Map<String, dynamic>>> _future = _load();
  String _filter = 'all';

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await providerApi.requests();
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

  bool _matches(Map<String, dynamic> r) {
    final status = '${r['status']}';
    switch (_filter) {
      case 'active':
        return ['accepted', 'en_route', 'arrived', 'in_progress']
            .contains(status);
      case 'pending':
        return status == 'pending' || status == 'matched';
      case 'completed':
        return status == 'completed';
      case 'cancelled':
        return status == 'cancelled';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('all', 'All'),
      ('pending', 'New'),
      ('active', 'Active'),
      ('completed', 'Done'),
      ('cancelled', 'Cancelled')
    ];

    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: const Text('Requests')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snapshot.data!;
          final filtered = requests.where(_matches).toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: SogoSpacing.lg, vertical: SogoSpacing.xs),
                    children: filters
                        .map((f) => Padding(
                              padding:
                                  const EdgeInsets.only(right: SogoSpacing.sm),
                              child: ChoiceChip(
                                label: Text(f.$2),
                                selected: _filter == f.$1,
                                selectedColor: SogoColors.primary,
                                labelStyle: SogoText.bodySm.copyWith(
                                  color: _filter == f.$1
                                      ? Colors.white
                                      : SogoColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                                onSelected: (_) =>
                                    setState(() => _filter = f.$1),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inbox_outlined,
                                  size: 44, color: SogoColors.textMuted),
                              const SizedBox(height: SogoSpacing.md),
                              Text('No requests here',
                                  style: SogoText.bodyLg
                                      .copyWith(fontWeight: FontWeight.w700)),
                              Text('Pull down to refresh',
                                  style: SogoText.bodySm.copyWith(
                                      color: SogoColors.textSecondary)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(SogoSpacing.lg),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: SogoSpacing.md),
                          itemBuilder: (context, i) {
                            final r = filtered[i];
                            return SogoCard(
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => RequestDetailsScreen(
                                          request: r, readOnly: false))),
                              child: _RequestCard(r),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard(this.request);

  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text('#${request['reference'] ?? ''}',
                    style:
                        SogoText.bodySm.copyWith(color: SogoColors.textMuted))),
            SogoBadge(label: '${request['status'] ?? ''}'.replaceAll('_', ' ')),
          ],
        ),
        const SizedBox(height: 6),
        Text('${request['category']?['name'] ?? 'Service request'}',
            style: SogoText.headlineMd),
        const SizedBox(height: 4),
        Text('${request['pickup_address'] ?? ''}',
            style: SogoText.bodySm.copyWith(color: SogoColors.textSecondary)),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.payments_outlined,
                size: 14, color: SogoColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              request['final_price'] != null
                  ? 'UGX ${request['final_price']}'
                  : request['estimated_price'] != null
                      ? 'Est. UGX ${request['estimated_price']}'
                      : 'Price on completion',
              style: SogoText.bodySm.copyWith(color: SogoColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}
