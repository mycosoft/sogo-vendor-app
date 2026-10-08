import 'package:flutter/material.dart';
import '../core/services/push_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';
import '../core/theme/app_theme.dart';
import '../features/home/screens/home_screen.dart';
import '../features/requests/screens/my_requests_screen.dart';
import '../features/jobs/screens/jobs_screen.dart';
import '../features/payments/screens/payments_screen.dart';
import '../features/profile/screens/profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final _jobsKey = GlobalKey<JobsScreenState>();

  @override
  void initState() {
    super.initState();
    // Authenticated - register this phone for push notifications.
    PushService.init(app: 'vendor');
  }

  late final List<Widget> _pages = <Widget>[
    HomeScreen(),
    MyRequestsScreen(),
    JobsScreen(key: _jobsKey),
    PaymentsScreen(),
    ProfileScreen(),
  ];

  static const _items = <BottomNavItem>[
    BottomNavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: 'Home'),
    BottomNavItem(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
        label: 'Requests'),
    BottomNavItem(
        icon: Icons.work_outline,
        activeIcon: Icons.work_rounded,
        label: 'Jobs'),
    BottomNavItem(
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet,
        label: 'Wallet'),
    BottomNavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profile'),
  ];

  void _onTap(int i) {
    setState(() => _index = i);
    // Jobs tab reflects your current online status every time you open it.
    if (i == 2) _jobsKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar:
          SogoBottomNav(items: _items, currentIndex: _index, onTap: _onTap),
    );
  }
}

class BottomNavItem {
  const BottomNavItem(
      {required this.icon, required this.activeIcon, required this.label});
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class SogoBottomNav extends StatelessWidget {
  const SogoBottomNav(
      {super.key,
      required this.items,
      required this.currentIndex,
      required this.onTap});

  final List<BottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: SogoColors.surface,
          boxShadow: [SogoShadows.card],
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(SogoRadius.lg),
              topRight: Radius.circular(SogoRadius.lg)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: SizedBox(
          height: 68,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final selected = i == currentIndex;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(SogoRadius.md),
                  onTap: () => onTap(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(selected ? item.activeIcon : item.icon,
                            color: selected
                                ? SogoColors.primary
                                : SogoColors.textMuted,
                            size: 22),
                        const SizedBox(height: 4),
                        Text(item.label,
                            style: TextStyle(
                                fontFamily: SogoText.fontFamily,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? SogoColors.primary
                                    : SogoColors.textMuted)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
