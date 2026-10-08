import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';
import '../../requests/screens/my_requests_screen.dart';

class BookServiceScreen extends StatefulWidget {
  const BookServiceScreen({super.key});

  @override
  State<BookServiceScreen> createState() => _BookServiceScreenState();
}

class _BookServiceScreenState extends State<BookServiceScreen> {
  final _form = GlobalKey<FormState>();
  int? _selectedCategory;
  final _pickup = TextEditingController();
  final _description = TextEditingController();
  bool _loading = false;

  static const _categories = <_Category>[
    _Category('Mechanic repair', Icons.handyman_outlined, 0),
    _Category('Vehicle towing', Icons.local_shipping_outlined, 1),
    _Category('Tire change', Icons.tire_repair_outlined, 2),
    _Category('Car wash', Icons.local_car_wash_outlined, 3),
    _Category('Battery jump start', Icons.battery_charging_full_outlined, 4),
    _Category('Lubricant / oil', Icons.oil_barrel_outlined, 5),
    _Category('Spare parts', Icons.settings_outlined, 6),
    _Category('Vehicle inspection', Icons.fact_check_outlined, 7),
  ];

  void _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a service category')));
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: const Text('Book a service')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(SogoSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What do you need?', style: SogoText.headlineMd),
                      const SizedBox(height: SogoSpacing.md),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: SogoSpacing.md,
                        crossAxisSpacing: SogoSpacing.md,
                        childAspectRatio: 1.3,
                        children: _categories
                            .map((c) => _CategoryTile(
                                  label: c.label,
                                  icon: c.icon,
                                  selected: _selectedCategory == c.id,
                                  onTap: () =>
                                      setState(() => _selectedCategory = c.id),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: SogoSpacing.xl),
                      Text('Vehicle', style: SogoText.headlineMd),
                      const SizedBox(height: SogoSpacing.md),
                      const _VehicleSelector(),
                      const SizedBox(height: SogoSpacing.xl),
                      SogoTextField(
                        label: 'Pickup address',
                        hint: 'Where should we come?',
                        controller: _pickup,
                        prefixIcon: Icons.location_on_outlined,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: SogoSpacing.lg),
                      SogoTextField(
                        label: 'Describe the problem',
                        hint: 'e.g. car wont start, smoke from engine',
                        controller: _description,
                        maxLines: 4,
                        validator: (v) => v == null || v.length < 10
                            ? 'Add a bit more detail'
                            : null,
                      ),
                      const SizedBox(height: SogoSpacing.lg),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Add a photo (optional)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SogoColors.primary,
                          minimumSize: const Size(double.infinity, 48),
                          side: const BorderSide(
                              color: SogoColors.primary, width: 1.2),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(SogoRadius.md)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                color: SogoColors.surface,
                padding: const EdgeInsets.all(SogoSpacing.lg),
                child: SafeArea(
                  top: false,
                  child: SogoButton(
                    label: 'Find a service provider',
                    onPressed: _submit,
                    loading: _loading,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Category {
  const _Category(this.label, this.icon, this.id);
  final String label;
  final IconData icon;
  final int id;
}

class _VehicleSelector extends StatelessWidget {
  const _VehicleSelector();

  @override
  Widget build(BuildContext context) {
    return SogoCard(
      padding: const EdgeInsets.symmetric(
          horizontal: SogoSpacing.lg, vertical: SogoSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.directions_car, color: SogoColors.primary),
          const SizedBox(width: SogoSpacing.md),
          Expanded(
            child: Text('Toyota Harrier - UBJ 123K',
                style: SogoText.bodyLg.copyWith(fontWeight: FontWeight.w700)),
          ),
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.expand_more,
                  color: SogoColors.textSecondary)),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? SogoColors.primaryLight : SogoColors.surface,
          border: Border.all(
              color: selected ? SogoColors.primary : SogoColors.surfaceBorder,
              width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(SogoRadius.lg),
        ),
        padding: const EdgeInsets.all(SogoSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: selected ? SogoColors.primary : SogoColors.textSecondary,
                size: 28),
            const SizedBox(height: SogoSpacing.sm),
            Text(label,
                style: SogoText.bodyMd.copyWith(
                    fontWeight: FontWeight.w700,
                    color:
                        selected ? SogoColors.primary : SogoColors.textPrimary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
