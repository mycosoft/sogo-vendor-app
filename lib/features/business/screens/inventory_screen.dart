import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/sogo_widgets.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _categories = [];
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
      final res = await providerApi.inventory();
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

  Future<void> _openForm({Map<String, dynamic>? product}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(SogoRadius.xl)),
      ),
      builder: (ctx) =>
          _ProductFormSheet(product: product, categories: _categories),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SogoRadius.lg)),
        title: const Text('Delete product?'),
        content: Text(
            '${p['name']} will be removed. Products on existing orders are deactivated instead, keeping history intact.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: SogoColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await providerApi.deleteProduct(p['id'] as int);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(res['message'] ?? 'Product deleted'),
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
      appBar: AppBar(title: const Text('Inventory')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
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
                              : Icons.inventory_2_outlined,
                          size: 48,
                          color: SogoColors.textMuted,
                        ),
                        const SizedBox(height: SogoSpacing.md),
                        Center(
                          child: Text(
                            _error != null
                                ? 'Could not load inventory.\nPull down to retry.'
                                : 'No products yet.\nTap "Add product" to create your first one.',
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
                        final p = _items[i];
                        final stock = (p['stock_quantity'] as num?) ?? 0;
                        final lowAt = (p['low_stock_threshold'] as num?) ?? 0;
                        final out = stock <= 0;
                        final low = !out && stock <= lowAt;
                        final inactive = p['is_active'] != true;
                        final (badge, badgeBg, badgeFg) = inactive
                            ? (
                                'HIDDEN',
                                const Color(0xFFF1F5F9),
                                const Color(0xFF64748B)
                              )
                            : out
                                ? (
                                    'OUT OF STOCK',
                                    const Color(0xFFFEE2E2),
                                    const Color(0xFF991B1B)
                                  )
                                : low
                                    ? (
                                        'LOW STOCK',
                                        const Color(0xFFFEF3C7),
                                        const Color(0xFF92400E)
                                      )
                                    : (
                                        'IN STOCK',
                                        const Color(0xFFDCFCE7),
                                        const Color(0xFF166534)
                                      );
                        return Container(
                          padding: const EdgeInsets.all(SogoSpacing.md),
                          decoration: BoxDecoration(
                            color: SogoColors.surface,
                            borderRadius: BorderRadius.circular(SogoRadius.lg),
                            boxShadow: const [SogoShadows.card],
                          ),
                          child: Column(children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(SogoRadius.md),
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    color: SogoColors.primaryLight,
                                    child: '${p['main_image_url'] ?? ''}'
                                            .isNotEmpty
                                        ? Image.network(
                                            '${p['main_image_url']}',
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                    Icons.inventory_2_outlined,
                                                    color: SogoColors.primary),
                                          )
                                        : const Icon(Icons.inventory_2_outlined,
                                            color: SogoColors.primary),
                                  ),
                                ),
                                const SizedBox(width: SogoSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${p['name'] ?? ''}',
                                          style: SogoText.bodyLg.copyWith(
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(
                                        'SKU ${p['sku'] ?? '-'} - Stock: $stock',
                                        style: SogoText.bodySm.copyWith(
                                            color: SogoColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                        ugx(num.tryParse('${p['price'] ?? 0}')),
                                        style: SogoText.bodyLg.copyWith(
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(
                                            SogoRadius.pill),
                                      ),
                                      child: Text(badge,
                                          style: SogoText.labelMd.copyWith(
                                              color: badgeFg, fontSize: 9)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: SogoSpacing.sm),
                            Row(children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                    onPressed: () => _openForm(product: p),
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 16),
                                    label: const Text('Edit'),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: SogoColors.primary,
                                        side: const BorderSide(
                                            color: SogoColors.primary,
                                            width: 1.2))),
                              ),
                              const SizedBox(width: SogoSpacing.sm),
                              Expanded(
                                child: OutlinedButton.icon(
                                    onPressed: () => _confirmDelete(p),
                                    icon: const Icon(Icons.delete_outline,
                                        size: 16),
                                    label: const Text('Delete'),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: SogoColors.danger,
                                        side: const BorderSide(
                                            color: SogoColors.danger,
                                            width: 1.2))),
                              ),
                            ]),
                          ]),
                        );
                      },
                    ),
            ),
    );
  }
}

class _ProductFormSheet extends StatefulWidget {
  const _ProductFormSheet({required this.categories, this.product});

  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic>? product;

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _form = GlobalKey<FormState>();
  late final _name =
      TextEditingController(text: '${widget.product?['name'] ?? ''}');
  late final _price =
      TextEditingController(text: '${widget.product?['price'] ?? ''}');
  late final _stock =
      TextEditingController(text: '${widget.product?['stock_quantity'] ?? 0}');
  late final _threshold = TextEditingController(
      text: '${widget.product?['low_stock_threshold'] ?? 3}');
  late final _sku =
      TextEditingController(text: '${widget.product?['sku'] ?? ''}');
  late final _brand =
      TextEditingController(text: '${widget.product?['brand'] ?? ''}');
  late final _description =
      TextEditingController(text: '${widget.product?['description'] ?? ''}');
  int? _categoryId;
  bool _active = true;
  String? _imagePath;
  bool _freeDelivery = true;
  late final _deliveryFee =
      TextEditingController(text: '${widget.product?['delivery_fee'] ?? ''}');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final cid = widget.product?['category']?['id'] ??
        widget.product?['product_category_id'];
    _categoryId = cid == null ? null : (cid as num).toInt();
    _active = widget.product?['is_active'] != false;
    _freeDelivery = widget.product?['free_delivery'] != false;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _stock.dispose();
    _threshold.dispose();
    _sku.dispose();
    _brand.dispose();
    _description.dispose();
    _deliveryFee.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 82);
    if (x == null) return;
    setState(() => _imagePath = x.path);
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'price': double.tryParse(_price.text.trim()),
      'stock_quantity': int.tryParse(_stock.text.trim()) ?? 0,
      'low_stock_threshold': int.tryParse(_threshold.text.trim()) ?? 3,
      'free_delivery': _freeDelivery,
      'delivery_fee':
          _freeDelivery ? 0 : (double.tryParse(_deliveryFee.text.trim()) ?? 0),
      'product_category_id': _categoryId,
      if (_sku.text.trim().isNotEmpty) 'sku': _sku.text.trim(),
      if (_brand.text.trim().isNotEmpty) 'brand': _brand.text.trim(),
      if (_description.text.trim().isNotEmpty)
        'description': _description.text.trim(),
      if (widget.product != null) 'is_active': _active,
    };
    try {
      print('[DEBUG] Saving product, payload: $payload, imagePath: $_imagePath');
      if (widget.product == null) {
        await providerApi.addProduct(payload, imagePath: _imagePath);
      } else {
        await providerApi.updateProduct(widget.product!['id'] as int, payload,
            imagePath: _imagePath);
      }
      print('[DEBUG] Product saved successfully');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      print('[DEBUG] Save error: $e');
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('422') || msg.contains('validation') || msg.contains('Validation')) {
          msg = msg.replaceAll('Exception: ', '');
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 6)));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingImage = '${widget.product?['main_image_url'] ?? ''}';
    return Padding(
      padding: EdgeInsets.only(
        left: SogoSpacing.xl,
        right: SogoSpacing.xl,
        top: SogoSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + SogoSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.product == null ? 'Add product' : 'Edit product',
                    style: SogoText.headlineLg),
                const SizedBox(height: SogoSpacing.lg),
                // Photo.
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 130,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: SogoColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(SogoRadius.md),
                      border: Border.all(color: SogoColors.surfaceBorder),
                    ),
                    child: _imagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(SogoRadius.md),
                            child: Image.file(File(_imagePath!),
                                fit: BoxFit.cover),
                          )
                        : existingImage.isNotEmpty
                            ? ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(SogoRadius.md),
                                child: Image.network(existingImage,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.add_photo_alternate_outlined)),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined,
                                      color: SogoColors.textMuted),
                                  SizedBox(height: 6),
                                  Text('Add product photo',
                                      style: SogoText.bodySm),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: SogoSpacing.md),
                SogoTextField(
                    label: 'Product name *',
                    hint: 'e.g. Brake pads - Toyota',
                    controller: _name,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null),
                const SizedBox(height: SogoSpacing.md),
                Row(
                  children: [
                    Expanded(
                        child: SogoTextField(
                            label: 'Price (UGX) *',
                            hint: '0',
                            controller: _price,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (v) => double.tryParse(v ?? '') == null
                                ? 'Invalid'
                                : null)),
                    const SizedBox(width: SogoSpacing.md),
                    Expanded(
                        child: SogoTextField(
                            label: 'Stock *',
                            hint: '0',
                            controller: _stock,
                            keyboardType: TextInputType.number,
                            validator: (v) => int.tryParse(v ?? '') == null
                                ? 'Invalid'
                                : null)),
                  ],
                ),
                const SizedBox(height: SogoSpacing.sm),
                SwitchListTile(
                  value: _freeDelivery,
                  onChanged: (v) => setState(() => _freeDelivery = v),
                  title: const Text('Free delivery'),
                  subtitle: const Text('Turn off to charge a delivery fee'),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: SogoColors.primary,
                ),
                if (!_freeDelivery)
                  SogoTextField(
                      label: 'Delivery fee (UGX)',
                      hint: '0',
                      controller: _deliveryFee,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: SogoSpacing.sm),
                Row(
                  children: [
                    Expanded(
                        child: SogoTextField(
                            label: 'Low stock alert at',
                            hint: '3',
                            controller: _threshold,
                            keyboardType: TextInputType.number)),
                    const SizedBox(width: SogoSpacing.md),
                    Expanded(
                        child: SogoTextField(
                            label: 'SKU (auto)',
                            hint: 'Leave empty',
                            controller: _sku)),
                  ],
                ),
                const SizedBox(height: SogoSpacing.md),
                DropdownButtonFormField<int>(
                  initialValue: _categoryId,
                  decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SogoRadius.md))),
                  items: [
                    const DropdownMenuItem<int>(
                        value: null, child: Text('No category')),
                    ...widget.categories.map((c) => DropdownMenuItem<int>(
                        value: (c['id'] as num).toInt(),
                        child: Text('${c['name']}',
                            overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                const SizedBox(height: SogoSpacing.md),
                SogoTextField(
                    label: 'Brand', hint: 'e.g. Toyota', controller: _brand),
                const SizedBox(height: SogoSpacing.md),
                SogoTextField(
                    label: 'Description',
                    hint: 'Details, compatibility...',
                    controller: _description,
                    maxLines: 3),
                if (widget.product != null) ...[
                  const SizedBox(height: SogoSpacing.md),
                  SwitchListTile(
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                    title: const Text('Visible in shop'),
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: SogoColors.primary,
                  ),
                ],
                const SizedBox(height: SogoSpacing.lg),
                SogoButton(
                    label:
                        widget.product == null ? 'Add product' : 'Save changes',
                    onPressed: _saving ? null : _save,
                    loading: _saving),
              ]),
        ),
      ),
    );
  }
}
