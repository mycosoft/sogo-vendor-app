import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_services.dart';
import '../../../core/utils/app_time.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';
import '../../auth/screens/login_screen.dart';
import '../../messages/screens/chats_screen.dart';
import 'vendor_edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _future = providerApi.me();
  bool _updatingLocation = false;

  Future<void> _refresh() async {
    setState(() {
      _future = providerApi.me();
    });
    await _future;
  }

  Future<void> _updateLocation() async {
    setState(() => _updatingLocation = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await providerApi.updateLocation(pos.latitude, pos.longitude);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Location updated'),
              backgroundColor: SogoColors.primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _updatingLocation = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SogoRadius.lg)),
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to use the app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Stay')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out',
                style: TextStyle(color: SogoColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await authApi.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'V';
    final first = parts.first[0];
    final second = parts.length > 1 ? parts.last[0] : '';
    return (first + second).toUpperCase();
  }

  /// Business logo first, personal avatar as fallback.
  String _logoUrl(Map<String, dynamic> provider, Map<String, dynamic> user) {
    for (final v in [provider['logo_url'], user['avatar']]) {
      if ('$v'.isNotEmpty && '$v' != 'null') return '$v';
    }
    return '';
  }

  /// Business cover first, personal cover as fallback.
  String _coverBannerUrl(
      Map<String, dynamic> provider, Map<String, dynamic> user) {
    for (final v in [provider['cover_image_url'], user['cover_image_url']]) {
      if ('$v'.isNotEmpty && '$v' != 'null') return '$v';
    }
    return '';
  }

  (String, Color, Color) _verificationStyle(String? status) {
    switch (status) {
      case 'approved':
        return ('Verified', const Color(0xFFDCFCE7), const Color(0xFF166534));
      case 'pending':
        return (
          'Pending verification',
          const Color(0xFFFEF3C7),
          const Color(0xFF92400E)
        );
      case 'rejected':
        return ('Rejected', const Color(0xFFFEE2E2), const Color(0xFF991B1B));
      case 'suspended':
        return ('Suspended', const Color(0xFFFEE2E2), const Color(0xFF991B1B));
      default:
        return ('$status', SogoColors.surfaceMuted, SogoColors.textSecondary);
    }
  }

  String _formatDate(dynamic iso) => relativeServerDate(iso);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            return const Center(child: CircularProgressIndicator());
          }

          final provider = snapshot.data!['data'] as Map<String, dynamic>;
          final user = provider['user'] as Map<String, dynamic>? ?? const {};
          final services = List<Map<String, dynamic>>.from(
              (provider['services'] as List?) ?? const []);
          final (vLabel, vBg, vFg) =
              _verificationStyle(provider['verification_status'] as String?);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(SogoSpacing.lg),
              children: [
                // -- Business header: cover fills the whole card bg --
                // Photo priority: business logo/cover first, then the
                // personal avatar/cover, then gradient/initials.
                Container(
                  height: 230,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(SogoRadius.xl),
                    boxShadow: const [SogoShadows.elevated],
                    gradient: _coverBannerUrl(provider, user).isEmpty
                        ? const LinearGradient(colors: [
                            SogoColors.primary,
                            SogoColors.primaryDark
                          ])
                        : null,
                    color: _coverBannerUrl(provider, user).isNotEmpty
                        ? SogoColors.primaryDark
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(SogoRadius.xl),
                    child: Stack(fit: StackFit.expand, children: [
                      if (_coverBannerUrl(provider, user).isNotEmpty)
                        Image.network(_coverBannerUrl(provider, user),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink()),
                      // Legibility gradient for the overlaid identity.
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.05),
                                Colors.black.withOpacity(0.55),
                              ]),
                        ),
                      ),
                      Positioned(
                        left: SogoSpacing.xl,
                        right: SogoSpacing.xl,
                        bottom: SogoSpacing.lg,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _logoUrl(provider, user).isNotEmpty
                                    ? Colors.transparent
                                    : Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: _logoUrl(provider, user).isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                          _logoUrl(provider, user),
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Text(
                                                _initials(
                                                    provider['business_name']
                                                        as String?),
                                                style: SogoText.headlineLg
                                                    .copyWith(
                                                        color: Colors.white),
                                              )))
                                  : Text(
                                      _initials(
                                          provider['business_name'] as String?),
                                      style: SogoText.headlineLg
                                          .copyWith(color: Colors.white),
                                    ),
                            ),
                            const SizedBox(width: SogoSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(children: [
                                    Flexible(
                                      child: Text(
                                          '${provider['business_name'] ?? ''}',
                                          overflow: TextOverflow.ellipsis,
                                          style: SogoText.headlineMd
                                              .copyWith(color: Colors.white)),
                                    ),
                                    // Blue tick for verified vendors.
                                    if (provider['verification_status'] ==
                                        'approved') ...[
                                      const SizedBox(width: 6),
                                      const Icon(Icons.verified_rounded,
                                          color: Color(0xFF38BDF8), size: 20),
                                    ],
                                  ]),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${user['name'] ?? ''} - ${_typeLabel(provider['provider_type'])}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: SogoText.bodySm
                                          .copyWith(color: Colors.white70)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: SogoSpacing.md),
                // Presence + edit live below the header, on surface.
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: SogoColors.primaryLight,
                        borderRadius: BorderRadius.circular(SogoRadius.pill),
                      ),
                      child: Text(
                        provider['is_online'] == true ? 'Online' : 'Offline',
                        style: SogoText.labelMd
                            .copyWith(color: SogoColors.primary, fontSize: 11),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        final saved = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) =>
                                VendorEditProfileScreen(provider: provider),
                          ),
                        );
                        if (saved == true) _refresh();
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit profile'),
                    ),
                  ],
                ),

                const SizedBox(height: SogoSpacing.md),

                // -- Verification status (approved shows as the blue tick
                // on the name instead - banner only for pending/rejected) --
                if (provider['verification_status'] != 'approved')
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: SogoSpacing.lg, vertical: SogoSpacing.md),
                    decoration: BoxDecoration(
                      color: vBg,
                      borderRadius: BorderRadius.circular(SogoRadius.lg),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.verified_user_outlined,
                            color: vFg, size: 20),
                        const SizedBox(width: SogoSpacing.md),
                        Expanded(
                          child: Text(vLabel,
                              style: SogoText.bodyMd.copyWith(
                                  color: vFg, fontWeight: FontWeight.w700)),
                        ),
                        if (provider['verification_notes'] != null)
                          IconButton(
                            icon: const Icon(Icons.info_outline, size: 18),
                            color: vFg,
                            onPressed: () => _showNotes(
                                context, '${provider['verification_notes']}'),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: SogoSpacing.xl),

                // -- Performance --
                const SogoSectionTitle('Performance'),
                Row(
                  children: [
                    Expanded(
                        child: _statTile(
                            'Jobs done',
                            '${provider['total_completed'] ?? 0}',
                            Icons.task_alt_rounded,
                            SogoColors.success)),
                    const SizedBox(width: SogoSpacing.md),
                    Expanded(
                        child: _statTile(
                            'Total jobs',
                            '${provider['total_jobs'] ?? 0}',
                            Icons.work_outline,
                            SogoColors.info)),
                    const SizedBox(width: SogoSpacing.md),
                    Expanded(
                        child: _statTile(
                            'Experience',
                            '${provider['experience_years'] ?? 0} yrs',
                            Icons.history_rounded,
                            SogoColors.tertiary)),
                  ],
                ),

                const SizedBox(height: SogoSpacing.xl),

                // -- Contact & location --
                const SogoSectionTitle('Contact & location'),
                SogoCard(
                  child: Column(
                    children: [
                      _infoRow(Icons.phone_outlined, 'Phone',
                          '${user['phone'] ?? 'Not set'}'),
                      _divider(),
                      _infoRow(Icons.alternate_email, 'Email',
                          '${user['email'] ?? 'Not set'}'),
                      _divider(),
                      _infoRow(Icons.location_on_outlined, 'Address',
                          _address(provider)),
                      _divider(),
                      _infoRow(Icons.explore_outlined, 'Service radius',
                          '${provider['service_radius_km'] ?? 10} km'),
                      _divider(),
                      _infoRow(Icons.gps_fixed, 'Last GPS update',
                          _formatDate(provider['last_location_update'])),
                    ],
                  ),
                ),
                const SizedBox(height: SogoSpacing.md),
                SogoButton(
                  label: 'Update my live location',
                  icon: Icons.my_location_rounded,
                  onPressed: _updatingLocation ? null : _updateLocation,
                  loading: _updatingLocation,
                ),

                const SizedBox(height: SogoSpacing.xl),

                // -- Working hours (as customers see them) --
                const SogoSectionTitle('Working hours'),
                _HoursView(hours: provider['operating_hours']),

                const SizedBox(height: SogoSpacing.xl),

                // -- Rate & hours --
                const SogoSectionTitle('Rate'),
                SogoCard(
                  child: Column(
                    children: [
                      _infoRow(
                          Icons.payments_outlined,
                          'Hourly rate',
                          provider['hourly_rate'] != null
                              ? 'UGX ${provider['hourly_rate']}'
                              : 'Not set'),
                      _divider(),
                      _infoRow(Icons.badge_outlined, 'TIN number',
                          '${provider['tin_number'] ?? 'Not set'}'),
                      _divider(),
                      _infoRow(Icons.tag, 'ID number',
                          '${provider['id_number'] ?? 'Not set'}'),
                    ],
                  ),
                ),

                const SizedBox(height: SogoSpacing.xl),

                // -- Services offered --
                const SogoSectionTitle('Services offered'),
                if (services.isEmpty)
                  const _EmptyHint(
                      text: 'No services yet. Add them from the business hub.')
                else
                  SogoCard(
                    padding:
                        const EdgeInsets.symmetric(vertical: SogoSpacing.sm),
                    child: Column(
                      children: [
                        for (final s in services)
                          ListTile(
                            dense: true,
                            leading: Icon(
                              s['is_active'] == true
                                  ? Icons.check_circle
                                  : Icons.pause_circle_outline,
                              color: s['is_active'] == true
                                  ? SogoColors.success
                                  : SogoColors.textMuted,
                            ),
                            title: Text(
                                '${s['category']?['name'] ?? 'Service'}',
                                style: SogoText.bodyLg
                                    .copyWith(fontWeight: FontWeight.w600)),
                            trailing: s['price'] != null
                                ? Text('UGX ${s['price']}',
                                    style: SogoText.bodyMd
                                        .copyWith(fontWeight: FontWeight.w700))
                                : null,
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: SogoSpacing.xl),

                const SogoSectionTitle('My reviews'),
                _ReviewsSection(userId: (user['id'] as num?)?.toInt()),

                const SizedBox(height: SogoSpacing.xl),

                const SogoSectionTitle('My documents'),
                _DocumentsSection(documents: provider['documents']),

                const SizedBox(height: SogoSpacing.xl),

                const SogoSectionTitle('Messages'),
                SogoCard(
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ChatsScreen())),
                  padding: const EdgeInsets.symmetric(
                      horizontal: SogoSpacing.lg, vertical: SogoSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: SogoColors.primaryLight,
                          borderRadius: BorderRadius.circular(SogoRadius.md),
                        ),
                        child: const Icon(Icons.chat_bubble_outline_rounded,
                            color: SogoColors.primary),
                      ),
                      const SizedBox(width: SogoSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('My chats',
                                style: SogoText.bodyLg
                                    .copyWith(fontWeight: FontWeight.w700)),
                            Text('Customers and SOGO Support',
                                style: SogoText.bodySm
                                    .copyWith(color: SogoColors.textSecondary)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: SogoColors.textMuted),
                    ],
                  ),
                ),

                const SizedBox(height: SogoSpacing.xl),

                SogoButton(
                  label: 'Log out',
                  variant: SogoButtonVariant.danger,
                  icon: Icons.logout_rounded,
                  onPressed: _logout,
                ),
                const SizedBox(height: SogoSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }

  String _typeLabel(dynamic type) {
    final t = '$type'.replaceAll('_', ' ');
    return t.isEmpty || t == 'null'
        ? 'Vendor'
        : t[0].toUpperCase() + t.substring(1);
  }

  String _address(Map<String, dynamic> p) {
    final parts = [
      if (p['address'] != null && '${p['address']}'.isNotEmpty) p['address'],
      if (p['city'] != null && '${p['city']}'.isNotEmpty) p['city'],
      if (p['region'] != null && '${p['region']}'.isNotEmpty) p['region'],
    ].where((e) => '$e'.isNotEmpty && '$e' != 'null').toList();
    return parts.isEmpty ? 'Not set' : parts.join(', ');
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
          Text(value, style: SogoText.headlineMd),
          Text(label,
              style: SogoText.bodySm.copyWith(color: SogoColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SogoSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: SogoColors.textMuted),
          const SizedBox(width: SogoSpacing.md),
          SizedBox(
            width: 120,
            child: Text(label,
                style:
                    SogoText.bodySm.copyWith(color: SogoColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: SogoText.bodyMd.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, color: SogoColors.surfaceBorder);

  void _showNotes(BuildContext context, String notes) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SogoRadius.lg)),
        title: const Text('Verification notes'),
        content: Text(notes),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

/// Read-only working hours, exactly as customers see them.
class _HoursView extends StatelessWidget {
  const _HoursView({required this.hours});

  final dynamic hours;

  static const _days = [
    ('mon', 'Monday'),
    ('tue', 'Tuesday'),
    ('wed', 'Wednesday'),
    ('thu', 'Thursday'),
    ('fri', 'Friday'),
    ('sat', 'Saturday'),
    ('sun', 'Sunday'),
  ];

  String _range(Object? v) {
    if (v is Map) {
      final open = '${v['open'] ?? ''}';
      final close = '${v['close'] ?? ''}';
      if (open.isEmpty || close.isEmpty) return '';
      return '$open - $close';
    }
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    final map = hours is Map
        ? Map<String, dynamic>.from(hours as Map)
        : <String, dynamic>{};

    return SogoCard(
      padding: const EdgeInsets.symmetric(vertical: SogoSpacing.sm),
      child: Column(
        children: [
          for (final d in _days)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: SogoSpacing.lg, vertical: 6),
              child: Row(children: [
                SizedBox(
                    width: 92,
                    child: Text(d.$2,
                        style: SogoText.bodyMd
                            .copyWith(fontWeight: FontWeight.w700))),
                Expanded(
                    child: Text(
                        _range(map[d.$1] ??
                            map[d.$1.toUpperCase()] ??
                            map['${d.$1[0].toUpperCase()}${d.$1.substring(1)}'])
                            .isNotEmpty
                            ? _range(map[d.$1] ??
                                map[d.$1.toUpperCase()] ??
                                map['${d.$1[0].toUpperCase()}${d.$1.substring(1)}'])
                            : 'Closed',
                        style: SogoText.bodyMd.copyWith(
                            color: _range(map[d.$1] ??
                                    map[d.$1.toUpperCase()] ??
                                    map['${d.$1[0].toUpperCase()}${d.$1.substring(1)}'])
                                .isNotEmpty
                                ? SogoColors.primary
                                : SogoColors.textSecondary,
                            fontWeight: FontWeight.w600))),
              ]),
            ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SogoCard(
      child: Column(
        children: [
          const Icon(Icons.home_repair_service_outlined,
              size: 36, color: SogoColors.textMuted),
          const SizedBox(height: SogoSpacing.sm),
          Text(text,
              style: SogoText.bodySm.copyWith(color: SogoColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// KYC documents uploaded at registration (national ID, TIN, licenseâ€¦).
/// Vendors see exactly what SOGO has on file, with verification status.
class _DocumentsSection extends StatelessWidget {
  const _DocumentsSection({required this.documents});

  final dynamic documents;

  String _label(String type) {
    return switch (type) {
      'national_id' => 'National ID',
      'tin_certificate' => 'TIN certificate',
      'business_license_doc' => 'Business license',
      'business_license' => 'Business license',
      'id_front' => 'ID (front)',
      'id_back' => 'ID (back)',
      'selfie' => 'Selfie',
      'vehicle_registration' => 'Vehicle registration',
      'insurance' => 'Insurance',
      _ => type.replaceAll('_', ' '),
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'approved' => SogoColors.success,
      'rejected' => SogoColors.danger,
      _ => SogoColors.warning,
    };
  }

  Future<void> _view(BuildContext context, Map<String, dynamic> doc) async {
    final url = '${doc['url'] ?? ''}';
    if (url.isEmpty) return;
    final isPdf = url.toLowerCase().endsWith('.pdf') ||
        '${doc['original_name'] ?? ''}'.toLowerCase().endsWith('.pdf');
    if (isPdf) {
      final uri = Uri.parse(url);
      try {
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      } catch (_) {}
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SogoRadius.lg)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(SogoRadius.lg)),
            child: Image.network(url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(SogoSpacing.xl),
                    child: Text('Could not load image'))),
          ),
          Padding(
            padding: const EdgeInsets.all(SogoSpacing.md),
            child: Row(children: [
              Expanded(
                  child: Text(_label('${doc['type'] ?? ''}'),
                      style: SogoText.bodyMd
                          .copyWith(fontWeight: FontWeight.w700))),
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close')),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = (documents as List?) ?? [];
    if (docs.isEmpty) {
      return const _EmptyHint(
          text: 'No KYC documents on file. Contact support to add them.');
    }
    return SogoCard(
      padding: const EdgeInsets.symmetric(vertical: SogoSpacing.sm),
      child: Column(
        children: [
          for (final raw in docs)
            Builder(builder: (context) {
              final doc = raw as Map<String, dynamic>;
              final status = '${doc['status'] ?? 'pending'}';
              return ListTile(
                dense: true,
                leading: const Icon(Icons.description_outlined,
                    color: SogoColors.primary),
                title: Text(_label('${doc['type'] ?? 'document'}'),
                    style:
                        SogoText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text('${doc['original_name'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SogoText.bodySm
                        .copyWith(color: SogoColors.textSecondary)),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(SogoRadius.pill),
                  ),
                  child: Text(status.toUpperCase(),
                      style: SogoText.labelMd
                          .copyWith(color: _statusColor(status))),
                ),
                onTap: () => _view(context, doc),
              );
            }),
        ],
      ),
    );
  }
}

/// Reviews customers left for this vendor.
class _ReviewsSection extends StatefulWidget {
  const _ReviewsSection({required this.userId});

  final int? userId;

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  late final Future<Map<String, dynamic>?> _future = _load();

  Future<Map<String, dynamic>?> _load() async {
    if (widget.userId == null) return null;
    try {
      final res = await providerApi.reviewsFor(widget.userId!);
      return res['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SogoCard(
              child: Center(
                  child: Padding(
                      padding: EdgeInsets.all(SogoSpacing.lg),
                      child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2)))));
        }
        final data = snap.data;
        final summary = data?['summary'] as Map<String, dynamic>? ?? {};
        final reviews = (data?['reviews'] as List?) ?? [];
        final avg = (summary['average_rating'] as num?) ?? 0;
        final total = (summary['total_ratings'] as num?)?.toInt() ?? 0;

        return SogoCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(avg.toStringAsFixed(1),
                  style: SogoText.headlineLg
                      .copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(width: SogoSpacing.sm),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                    children: List.generate(
                        5,
                        (i) => Icon(
                            i < avg.round()
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 14,
                            color: SogoColors.warning))),
                Text('$total review${total == 1 ? '' : 's'}',
                    style: SogoText.labelMd
                        .copyWith(color: SogoColors.textSecondary)),
              ]),
            ]),
            if (reviews.isNotEmpty) ...[
              const Divider(height: SogoSpacing.xl),
              ...reviews.take(5).map((raw) {
                final r = raw as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: SogoSpacing.md),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Row(
                              children: List.generate(
                                  5,
                                  (i) => Icon(
                                      i < ((r['rating'] ?? 0) as num).round()
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: 12,
                                      color: SogoColors.warning))),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(
                                  '${(r['reviewer'] as Map<String, dynamic>?)?['name'] ?? r['reviewer_name'] ?? r['customer_name'] ?? 'Customer'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: SogoText.labelMd.copyWith(
                                      color: SogoColors.textSecondary))),
                        ]),
                        if ('${r['comment'] ?? r['review'] ?? ''}'.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text('${r['comment'] ?? r['review']}',
                                style: SogoText.bodySm),
                          ),
                      ]),
                );
              }),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: SogoSpacing.sm),
                child: Text(
                    'No reviews yet - they appear here after customers rate your jobs.',
                    style: SogoText.bodySm
                        .copyWith(color: SogoColors.textSecondary)),
              ),
          ]),
        );
      },
    );
  }
}
