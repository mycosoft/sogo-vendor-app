import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _categories = [];
  String? _error;
  bool _loading = true;
  String _search = '';

  int get _activeCount => _items.where((s) => s['is_active'] == true).length;
  int get _pausedCount => _items.where((s) => s['is_active'] != true).length;

  List<Map<String, dynamic>> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items
        .where(
            (s) => '${s['category']?['name'] ?? ''}'.toLowerCase().contains(q))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await providerApi.services();
      final data = res['data'] as Map<String, dynamic>;
      _items =
          List<Map<String, dynamic>>.from(data['items'] as List? ?? const []);
      _categories = List<Map<String, dynamic>>.from(
          data['categories'] as List? ?? const []);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() async => _load();

  Future<void> _addService() async {
    // Only offer categories the vendor doesn't already provide.
    final existingIds = _items.map((s) => s['service_category_id']).toSet();
    final available =
        _categories.where((c) => !existingIds.contains(c['id'])).toList();

    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('You already offer every available service category')));
      }
      return;
    }

    final priceCtl = TextEditingController();
    int? selectedId = available.first['id'] as int;

    final ok = await showModalBottomSheet<bool>(
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
              const Text('Add a service', style: SogoText.headlineLg),
              const SizedBox(height: SogoSpacing.sm),
              Text(
                  'Pick what you offer and your starting price. Customers '
                  'matching this service will find you.',
                  style: SogoText.bodySm
                      .copyWith(color: SogoColors.textSecondary)),
              const SizedBox(height: SogoSpacing.lg),
              DropdownButtonFormField<int>(
                initialValue: selectedId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Service category *',
                    border: OutlineInputBorder()),
                items: available
                    .map((c) => DropdownMenuItem(
                        value: c['id'] as int, child: Text('${c['name']}')))
                    .toList(),
                onChanged: (v) => setSheet(() => selectedId = v),
              ),
              const SizedBox(height: SogoSpacing.md),
              TextField(
                controller: priceCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Your price (UGX, 0 = quote on request)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: SogoSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Add service'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || selectedId == null) return;

    try {
      await providerApi.addService({
        'service_category_id': selectedId,
        'price': double.tryParse(priceCtl.text.trim()) ?? 0,
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Service added - customers can now book it'),
            backgroundColor: SogoColors.primary));
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
      appBar: AppBar(title: const Text('Services')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addService,
        icon: const Icon(Icons.add),
        label: const Text('Add service'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _items.isEmpty && _error == null
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Icon(Icons.handyman_outlined,
                            size: 48, color: SogoColors.textMuted),
                        SizedBox(height: SogoSpacing.md),
                        Center(
                          child: Text(
                            'No services yet.\nTap "Add service" to tell customers what you offer.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: SogoColors.textSecondary),
                          ),
                        ),
                      ],
                    )
                  : _error != null && _items.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Icon(Icons.cloud_off_rounded,
                                size: 48, color: SogoColors.textMuted),
                            SizedBox(height: SogoSpacing.md),
                            Center(
                              child: Text(
                                'Could not load services.\nPull down to retry.',
                                textAlign: TextAlign.center,
                                style:
                                    TextStyle(color: SogoColors.textSecondary),
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(SogoSpacing.lg,
                              SogoSpacing.md, SogoSpacing.lg, 88),
                          children: [
                            // -- Stats --
                            Row(
                              children: [
                                _statTile('Active', '$_activeCount',
                                    SogoColors.success),
                                const SizedBox(width: SogoSpacing.md),
                                _statTile('Paused', '$_pausedCount',
                                    SogoColors.warning),
                                const SizedBox(width: SogoSpacing.md),
                                _statTile('Total', '${_items.length}',
                                    SogoColors.primary),
                              ],
                            ),
                            const SizedBox(height: SogoSpacing.lg),

                            // -- Search --
                            TextField(
                              onChanged: (v) => setState(() => _search = v),
                              decoration: InputDecoration(
                                hintText: 'Search your services',
                                prefixIcon: const Icon(Icons.search_rounded),
                                filled: true,
                                fillColor: SogoColors.surface,
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(SogoRadius.md),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: SogoSpacing.lg),

                            // -- List --
                            if (_filtered.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(SogoSpacing.xl),
                                child: Center(
                                  child: Text('No services match "$_search"',
                                      style: SogoText.bodyMd.copyWith(
                                          color: SogoColors.textSecondary)),
                                ),
                              )
                            else
                              ..._filtered.map((s) => Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: SogoSpacing.md),
                                    child: _serviceCard(s),
                                  )),
                          ],
                        ),
            ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(SogoSpacing.md),
        decoration: BoxDecoration(
          color: SogoColors.surface,
          borderRadius: BorderRadius.circular(SogoRadius.lg),
          boxShadow: const [SogoShadows.card],
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: SogoSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: SogoText.headlineMd.copyWith(height: 1.1)),
                Text(label,
                    style: SogoText.bodySm
                        .copyWith(color: SogoColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPrice(Map<String, dynamic> s) async {
    final priceCtl = TextEditingController(text: '${s['price'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SogoRadius.lg)),
        title: Text('Price - ${s['category']?['name'] ?? 'Service'}'),
        content: TextField(
          controller: priceCtl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Price (UGX)',
            hintText: '0 = quote on request',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (double.tryParse(priceCtl.text.trim()) == null) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await providerApi.updateServicePrice(
          s['id'] as int, double.parse(priceCtl.text.trim()));
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Price updated'),
            backgroundColor: SogoColors.primary));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Widget _serviceCard(Map<String, dynamic> s) {
    final active = s['is_active'] == true;
    return Container(
      padding: const EdgeInsets.all(SogoSpacing.md),
      decoration: BoxDecoration(
        color: SogoColors.surface,
        borderRadius: BorderRadius.circular(SogoRadius.lg),
        boxShadow: const [SogoShadows.card],
        border: Border.all(
            color: active
                ? SogoColors.primary.withOpacity(0.2)
                : Colors.transparent,
            width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active ? SogoColors.primaryLight : SogoColors.surfaceMuted,
              borderRadius: BorderRadius.circular(SogoRadius.md),
            ),
            child: Icon(
              Icons.handyman_outlined,
              color: active ? SogoColors.primary : SogoColors.textMuted,
            ),
          ),
          const SizedBox(width: SogoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s['category']?['name'] ?? 'Service'}',
                    style:
                        SogoText.bodyLg.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  (s['price'] as num?) != null && s['price'] > 0
                      ? 'UGX ${s['price']}'
                      : 'Quote on request',
                  style:
                      SogoText.bodySm.copyWith(color: SogoColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(active ? 'Active' : 'Paused',
                  style: SogoText.labelMd.copyWith(
                      color: active ? SogoColors.success : SogoColors.textMuted,
                      fontSize: 10)),
              const SizedBox(height: 4),
              Switch(
                value: active,
                activeThumbColor: SogoColors.primary,
                onChanged: (_) async {
                  try {
                    await providerApi.toggleService(s['id'] as int);
                    await _load();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  }
                },
              ),
              IconButton(
                tooltip: 'Edit price',
                onPressed: () => _editPrice(s),
                icon: const Icon(Icons.edit_outlined,
                    color: SogoColors.primary, size: 20),
              ),
              IconButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(SogoRadius.lg)),
                      title: const Text('Remove service?'),
                      content: const Text(
                          'Customers will no longer find you for this service.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Keep')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Remove',
                                style: TextStyle(color: SogoColors.danger))),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  try {
                    await providerApi.deleteService(s['id'] as int);
                    await _load();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  }
                },
                icon: const Icon(Icons.delete_outline,
                    color: SogoColors.danger, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
