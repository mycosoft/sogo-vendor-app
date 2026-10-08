import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';
import '../../business/screens/business_screen.dart';
import '../../business/screens/inventory_screen.dart';
import '../../business/screens/invoices_screen.dart';
import '../../business/screens/orders_screen.dart';
import '../../business/screens/services_screen.dart';
import '../../messages/screens/chats_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../requests/screens/request_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _data;
  String? _error;
  bool _togglingOnline = false;
  bool _firstLoad = true;
  Timer? _timer;
  Timer? _locTimer;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  bool get _isOnline =>
      (_data?['provider'] as Map<String, dynamic>?)?['is_online'] == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // Auto-refresh so new jobs and status changes show up on their own.
    _timer =
        Timer.periodic(const Duration(seconds: 30), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed) _silentRefresh();
  }

  Future<Map<String, dynamic>> _fetchData() async {
    final me = await providerApi.me();

    List<Map<String, dynamic>> requests = const [];
    List<Map<String, dynamic>> available = const [];
    int unread = 0;

    try {
      requests = _items(await providerApi.requests());
    } catch (_) {}

    try {
      available = _items(await providerApi.availableJobs());
    } catch (_) {
      // Offline or unverified - no job pool, dashboard still loads.
    }

    try {
      final unreadRes = await notificationApi.unread();
      unread = ((unreadRes['count'] ?? 0) as num).toInt();
    } catch (_) {}

    return {
      'provider': me['data'] as Map<String, dynamic>,
      'requests': requests,
      'available': available,
      'unread': unread,
    };
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> res) {
    final data = res['data'];
    if (data is Map && data['items'] is List)
      return List<Map<String, dynamic>>.from(data['items'] as List);
    if (data is Map && data['data'] is List)
      return List<Map<String, dynamic>>.from(data['data'] as List);
    if (data is List) return List<Map<String, dynamic>>.from(data);
    return const [];
  }

  Future<void> _load() async {
    try {
      final data = await _fetchData();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _firstLoad = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _firstLoad = false;
      });
    }
  }

  /// Background refresh - no spinner, no flicker.
  Future<void> _silentRefresh() async {
    if (_lifecycle != AppLifecycleState.resumed) return;
    try {
      final data = await _fetchData();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (_) {
      // keep showing the last good data
    }
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => _togglingOnline = true);
    try {
      await providerApi.setOnline(value);

      // Going online: push GPS immediately so matching + tracking are
      // accurate from the first second, then keep pinging while online.
      if (value) {
        await _pushLocation();
        _locTimer ??= Timer.periodic(const Duration(seconds: 60), (_) {
          if (_isOnline && _lifecycle == AppLifecycleState.resumed) {
            _pushLocation();
          }
        });
      }

      await _silentRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value
                ? 'You are online - sharing live location'
                : 'You are offline'),
            backgroundColor: value ? SogoColors.primary : SogoColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _togglingOnline = false);
    }
  }

  /// Push the current GPS position to the backend (providers table +
  /// location_updates history for the admin tracking page).
  Future<void> _pushLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await providerApi.updateLocation(pos.latitude, pos.longitude);
    } catch (_) {
      // Location pings are best-effort - never block going online.
    }
  }

  String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'V';
    return parts.first[0].toUpperCase();
  }

  String _shortTime(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_firstLoad) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _data == null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 40, color: SogoColors.textMuted),
            const SizedBox(height: SogoSpacing.md),
            Text('Could not load dashboard',
                style: SogoText.bodyLg.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: SogoSpacing.sm),
            SogoButton(label: 'Try again', onPressed: _load, fullWidth: false),
          ],
        ),
      );
    } else {
      final d = _data!;
      final provider = d['provider'] as Map<String, dynamic>;
      final requests = d['requests'] as List<Map<String, dynamic>>;
      final available = d['available'] as List<Map<String, dynamic>>;
      final unread = ((d['unread'] as num?) ?? 0).toInt();
      final isOnline = provider['is_online'] == true;

      body = RefreshIndicator(
        onRefresh: _silentRefresh,
        child: ListView(
          padding: const EdgeInsets.all(SogoSpacing.lg),
          children: [
            _topBar(unread),
            const SizedBox(height: SogoSpacing.md),
            _heroCard(provider, isOnline),
            const SizedBox(height: SogoSpacing.lg),
            _statsGrid(requests, available),
            const SizedBox(height: SogoSpacing.xl),
            _hubGrid(),
            const SizedBox(height: SogoSpacing.xl),
            _sectionHeader('Available jobs', '${available.length}'),
            const SizedBox(height: SogoSpacing.md),
            if (available.isEmpty)
              _EmptyHint(
                icon: Icons.work_outline,
                text: isOnline
                    ? 'No new jobs right now. New requests in your area appear here automatically.'
                    : 'Go online to start receiving job requests.',
              )
            else
              ...available.take(3).map((job) => Padding(
                    padding: const EdgeInsets.only(bottom: SogoSpacing.md),
                    child: _jobCard(
                      job,
                      badge: 'Review',
                      badgeColor: SogoColors.primary,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => RequestDetailsScreen(
                              request: job, readOnly: false))),
                    ),
                  )),
            const SizedBox(height: SogoSpacing.xl),
            _sectionHeader('Active requests', '${requests.length}'),
            const SizedBox(height: SogoSpacing.md),
            if (requests.isEmpty)
              const _EmptyHint(
                  icon: Icons.receipt_long_outlined,
                  text: 'Accepted jobs will appear here.')
            else
              ...requests.take(3).map((request) => Padding(
                    padding: const EdgeInsets.only(bottom: SogoSpacing.md),
                    child: _jobCard(
                      request,
                      badge: '${request['status'] ?? ''}'.replaceAll('_', ' '),
                      badgeColor: SogoColors.secondary,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => RequestDetailsScreen(
                              request: request, readOnly: false))),
                    ),
                  )),
            const SizedBox(height: SogoSpacing.xxl),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      body: SafeArea(child: body),
    );
  }

  // -- Top bar with chat + bell --
  Widget _topBar(int unread) {
    return Row(
      children: [
        Text('SOGO',
            style: SogoText.headlineLg
                .copyWith(color: SogoColors.primary, letterSpacing: 1.2)),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ChatsScreen())),
          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 24),
        ),
        Stack(
          children: [
            IconButton(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const NotificationsScreen()));
                await _silentRefresh();
              },
              icon: const Icon(Icons.notifications_none_rounded, size: 26),
            ),
            if (unread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: SogoColors.danger, shape: BoxShape.circle),
                  child: Text('$unread',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // -- Hero: identity + presence + toggle --
  Widget _heroCard(Map<String, dynamic> provider, bool isOnline) {
    return Container(
      padding: const EdgeInsets.all(SogoSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOnline
              ? [SogoColors.primary, SogoColors.primaryDark]
              : [SogoColors.secondary, SogoColors.secondaryDark],
        ),
        borderRadius: BorderRadius.circular(SogoRadius.xl),
        boxShadow: const [SogoShadows.elevated],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: '${provider['logo_url'] ?? ''}'.isNotEmpty
                      ? Colors.transparent
                      : Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: '${provider['logo_url'] ?? ''}'.isNotEmpty
                    ? ClipOval(
                        child: Image.network('${provider['logo_url']}',
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Text(
                                _initials(provider['business_name'] as String?),
                                style: SogoText.headlineMd
                                    .copyWith(color: Colors.white))))
                    : Text(_initials(provider['business_name'] as String?),
                        style:
                            SogoText.headlineMd.copyWith(color: Colors.white)),
              ),
              const SizedBox(width: SogoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text('${provider['business_name'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                            style: SogoText.headlineMd
                                .copyWith(color: Colors.white)),
                      ),
                      if (provider['verification_status'] == 'approved') ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded,
                            color: Color(0xFF38BDF8), size: 20),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        // Presence dot
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color:
                                isOnline ? SogoColors.success : Colors.white38,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(isOnline ? 'Online' : 'Offline',
                            style: SogoText.bodySm
                                .copyWith(color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SogoSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  _togglingOnline ? null : () => _toggleOnline(!isOnline),
              icon: _togglingOnline
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(
                      isOnline
                          ? Icons.power_settings_new_rounded
                          : Icons.bolt_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
              label: Text(
                isOnline ? 'GO OFFLINE' : 'GO ONLINE',
                style: SogoText.button.copyWith(
                  fontSize: 14,
                  letterSpacing: 1.1,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                // Red reads as "switch off", green as "switch on".
                backgroundColor:
                    isOnline ? SogoColors.danger : SogoColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: SogoSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SogoRadius.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -- Stats (jobs only - wallet lives on its own screen, rating dropped) --
  Widget _statsGrid(List<Map<String, dynamic>> requests,
      List<Map<String, dynamic>> available) {
    final tiles = [
      (
        'New jobs',
        '${available.length}',
        Icons.work_outline,
        SogoColors.secondary
      ),
      (
        'Requests',
        '${requests.length}',
        Icons.receipt_long_outlined,
        SogoColors.primary
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: SogoSpacing.md,
      crossAxisSpacing: SogoSpacing.md,
      childAspectRatio: 2.0,
      children: [
        for (final t in tiles)
          Container(
            padding: const EdgeInsets.all(SogoSpacing.md),
            decoration: BoxDecoration(
              color: SogoColors.surface,
              borderRadius: BorderRadius.circular(SogoRadius.lg),
              boxShadow: const [SogoShadows.card],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: t.$4.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(SogoRadius.md),
                  ),
                  child: Icon(t.$3, color: t.$4, size: 20),
                ),
                const SizedBox(width: SogoSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SogoText.headlineMd.copyWith(height: 1.1)),
                      Text(t.$1,
                          style: SogoText.bodySm
                              .copyWith(color: SogoColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // -- Business hub tiles --
  Widget _hubGrid() {
    final tiles = [
      (
        'Services',
        'What you offer',
        Icons.handyman_outlined,
        SogoColors.primary,
        const ServicesScreen()
      ),
      (
        'Inventory',
        'Products & stock',
        Icons.inventory_2_outlined,
        SogoColors.info,
        const InventoryScreen()
      ),
      (
        'Orders',
        'Shop orders',
        Icons.shopping_bag_outlined,
        SogoColors.secondary,
        const OrdersScreen()
      ),
      (
        'Invoices',
        'Bill customers',
        Icons.description_outlined,
        SogoColors.tertiary,
        const InvoicesScreen()
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SogoSectionTitle('Business hub'),
        const SizedBox(height: SogoSpacing.md),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: SogoSpacing.md,
          crossAxisSpacing: SogoSpacing.md,
          childAspectRatio: 1.35,
          children: [
            for (final t in tiles)
              GestureDetector(
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => t.$5)),
                child: Container(
                  padding: const EdgeInsets.all(SogoSpacing.md),
                  decoration: BoxDecoration(
                    color: SogoColors.surface,
                    borderRadius: BorderRadius.circular(SogoRadius.lg),
                    boxShadow: const [SogoShadows.card],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: t.$4.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(SogoRadius.md),
                        ),
                        child: Icon(t.$3, color: t.$4, size: 20),
                      ),
                      const Spacer(),
                      Text(t.$1,
                          style: SogoText.bodyLg
                              .copyWith(fontWeight: FontWeight.w800)),
                      Text(t.$2,
                          style: SogoText.bodySm
                              .copyWith(color: SogoColors.textSecondary)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: SogoSpacing.sm),
        Center(
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BusinessScreen())),
            icon: const Icon(Icons.grid_view_rounded, size: 16),
            label: const Text('Open full business hub'),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, String count) {
    return Row(
      children: [
        Expanded(child: SogoSectionTitle(title)),
        Text(count,
            style: SogoText.bodySm.copyWith(color: SogoColors.textMuted)),
      ],
    );
  }

  Widget _jobCard(
    Map<String, dynamic> job, {
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: SogoColors.primaryLight,
                borderRadius: BorderRadius.circular(SogoRadius.md),
              ),
              child: const Icon(Icons.handyman_outlined,
                  color: SogoColors.primary),
            ),
            const SizedBox(width: SogoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${job['reference'] ?? ''}',
                      style: SogoText.bodySm
                          .copyWith(color: SogoColors.textMuted)),
                  const SizedBox(height: 2),
                  Text('${job['category']?['name'] ?? 'Service request'}',
                      style: SogoText.bodyLg
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${job['pickup_address'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SogoText.bodySm
                          .copyWith(color: SogoColors.textSecondary)),
                  if ('${job['scheduled_at'] ?? ''}'.isNotEmpty)
                    Text('Scheduled: ${_shortTime('${job['scheduled_at']}')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SogoText.bodySm.copyWith(
                            color: SogoColors.primary,
                            fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(width: SogoSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(SogoRadius.pill),
                  ),
                  child: Text(badge.toUpperCase(),
                      style: SogoText.labelMd
                          .copyWith(color: badgeColor, fontSize: 9)),
                ),
                const SizedBox(height: 6),
                const Icon(Icons.chevron_right_rounded,
                    color: SogoColors.textMuted, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
          Text(
            text,
            style: SogoText.bodySm.copyWith(color: SogoColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
