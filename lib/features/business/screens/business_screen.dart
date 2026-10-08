import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';
import 'services_screen.dart';
import 'inventory_screen.dart';
import 'orders_screen.dart';
import 'invoices_screen.dart';

class BusinessScreen extends StatelessWidget {
  const BusinessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: const Text('Business')),
      body: ListView(
        padding: const EdgeInsets.all(SogoSpacing.lg),
        children: [
          const SogoSectionTitle('Manage your shop'),
          _Tile(
              'Services',
              'Pricing and active services',
              Icons.handyman_outlined,
              () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ServicesScreen()))),
          _Tile(
              'Inventory',
              'Products and stock',
              Icons.inventory_2_outlined,
              () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InventoryScreen()))),
          _Tile(
              'Orders',
              'Customer orders and status',
              Icons.shopping_bag_outlined,
              () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OrdersScreen()))),
          _Tile(
              'Invoices',
              'Create and track invoices',
              Icons.description_outlined,
              () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InvoicesScreen()))),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.title, this.subtitle, this.icon, this.onTap);

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SogoSpacing.md),
      child: SogoCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: SogoColors.primaryLight,
                    borderRadius: BorderRadius.circular(SogoRadius.md)),
                child: Icon(icon, color: SogoColors.primary)),
            const SizedBox(width: SogoSpacing.md),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title, style: SogoText.headlineMd),
                  Text(subtitle,
                      style: SogoText.bodySm
                          .copyWith(color: SogoColors.textSecondary))
                ])),
            const Icon(Icons.chevron_right, color: SogoColors.textMuted),
          ],
        ),
      ),
    );
  }
}
