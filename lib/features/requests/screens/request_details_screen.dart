import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/sogo_widgets.dart';

class RequestDetailsScreen extends StatefulWidget {
  const RequestDetailsScreen(
      {super.key, required this.request, this.readOnly = true});

  final Map<String, dynamic> request;
  final bool readOnly;

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  late Map<String, dynamic> _request = widget.request;
  bool _busy = false;
  Timer? _pollTimer;
  StreamSubscription<Position>? _posSub;
  LatLng? _me;
  DateTime? _lastPush;

  String get _status => '${_request['status'] ?? 'pending'}';
  bool get _canAccept => _status == 'pending' || _status == 'matched';
  bool get _inProgress =>
      ['accepted', 'en_route', 'arrived', 'in_progress'].contains(_status);
  bool get _live => _canAccept || _inProgress;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
    if (_live && !widget.readOnly) _startTracking();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _posSub?.cancel();
    try {
      final id = _request['id'] as int;
      realtime.unsubscribe('private-requests.$id', 'request.updated');
    } catch (_) {}
    super.dispose();
  }

  /// Live socket upgrade: customer cancels and status changes refresh
  /// instantly instead of waiting for the 10s poll. The poll stays as
  /// fallback.
  Future<void> _subscribeRealtime() async {
    try {
      final id = _request['id'] as int;
      await realtime.subscribe('private-requests.$id', 'request.updated',
          (_) {
        if (mounted) _refresh();
      });
    } catch (_) {}
  }

  /// Refresh the job (status moves, customer cancels, etc.).
  Future<void> _refresh() async {
    try {
      final res = await providerApi.jobShow(_request['id'] as int);
      if (!mounted) return;
      final data = res['data'] as Map<String, dynamic>?;
      if (data != null) setState(() => _request = data);
    } catch (_) {}
  }

  /// Stream my own position for the live map + push it to the backend
  /// (throttled) so the customer + admin maps move in real time.
  Future<void> _startTracking() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      await _posSub?.cancel();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((p) {
        if (!mounted || (p.latitude == 0 && p.longitude == 0)) return;
        setState(() => _me = LatLng(p.latitude, p.longitude));
        final last = _lastPush;
        if (last == null || DateTime.now().difference(last).inSeconds >= 15) {
          _lastPush = DateTime.now();
          providerApi
              .updateLocation(p.latitude, p.longitude)
              .catchError((_) => <String, dynamic>{});
        }
      });
    } catch (_) {}
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() => _run(() async {
        await providerApi.acceptJob(_request['id'] as int);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Job accepted - customer notified'),
              backgroundColor: SogoColors.primary));
        }
      });

  Future<void> _decline() => _run(() async {
        await providerApi.declineJob(_request['id'] as int);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Passed - the job goes to another provider'),
              backgroundColor: SogoColors.secondary));
          Navigator.of(context).pop(true);
        }
      });

  Future<void> _setStatus(String status, {double? finalPrice}) =>
      _run(() async {
        await providerApi.updateStatus(_request['id'] as int,
            status: status, finalPrice: finalPrice);
      });

  Future<void> _completeDialog() async {
    final priceCtl = TextEditingController(
      text: '${_request['final_price'] ?? _request['estimated_price'] ?? ''}',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SogoRadius.lg)),
        title: const Text('Complete job'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the final price the customer paid:'),
            const SizedBox(height: SogoSpacing.md),
            TextField(
              controller: priceCtl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Final price (UGX)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final price = double.tryParse(priceCtl.text.trim());
              if (price == null || price < 0) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _setStatus('completed',
        finalPrice: double.tryParse(priceCtl.text.trim()));
  }

  Future<void> _callCustomer() async {
    final phone = '${_request['customer']?['phone'] ?? ''}'
        .replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  String _fmtTime(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '-';
    return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String status) {
    return switch (status) {
      'completed' => SogoColors.success,
      'cancelled' || 'rejected' || 'expired' => SogoColors.danger,
      'pending' => SogoColors.warning,
      _ => SogoColors.primary,
    };
  }

  // -- Map: customer pickup pin + my live pin --
  Widget _liveMap() {
    final pickup = _pickup;
    if (pickup == null) return const SizedBox.shrink();
    final points = <LatLng>[pickup, if (_me != null) _me!];

    return ClipRRect(
      borderRadius: BorderRadius.circular(SogoRadius.lg),
      child: SizedBox(
        height: 230,
        child: Stack(children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: pickup,
              initialZoom: 14,
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'co.sogo.vendor',
              ),
              MarkerLayer(markers: [
                Marker(
                    point: pickup,
                    width: 46,
                    height: 46,
                    child: const Icon(Icons.location_on_rounded,
                        color: SogoColors.primary, size: 44)),
                if (_me != null)
                  Marker(
                      point: _me!,
                      width: 46,
                      height: 46,
                      child: Container(
                          decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [SogoShadows.card]),
                          child: const Icon(Icons.build_circle_rounded,
                              color: SogoColors.warning, size: 40))),
              ]),
            ],
          ),
          if (points.length >= 2)
            Positioned(
              right: SogoSpacing.md,
              bottom: SogoSpacing.md,
              child: FloatingActionButton.small(
                heroTag: 'fit_vendor',
                backgroundColor: Colors.white,
                onPressed: () {},
                child: const Icon(Icons.center_focus_strong_rounded,
                    color: SogoColors.primary),
              ),
            ),
          Positioned(
              left: SogoSpacing.md,
              bottom: SogoSpacing.md,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(SogoRadius.pill),
                      boxShadow: const [SogoShadows.card]),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.location_on_rounded,
                        size: 12, color: SogoColors.primary),
                    const SizedBox(width: 4),
                    Text('Customer',
                        style: SogoText.labelMd
                            .copyWith(fontWeight: FontWeight.w700)),
                    if (_me != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.build_circle_rounded,
                          size: 12, color: SogoColors.warning),
                      const SizedBox(width: 4),
                      Text('You',
                          style: SogoText.labelMd
                              .copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ]))),
        ]),
      ),
    );
  }

  LatLng? get _pickup {
    final lat = (_request['pickup_lat'] as num?);
    final lng = (_request['pickup_lng'] as num?);
    if (lat == null || lng == null) return null;
    return LatLng(lat.toDouble(), lng.toDouble());
  }

  // -- Timeline --
  Widget _timeline() {
    final status = _status;
    final logs = (_request['status_history'] as List?) ?? const [];

    String at(Object? key) {
      final v = _request[key];
      return _fmtTime(v == null ? null : '$v');
    }

    final stages = <(_Step, String)>[
      (const _Step('Requested', Icons.receipt_long_rounded), at('created_at')),
      (const _Step('Matched to you', Icons.handshake_rounded), at('matched_at')),
      (const _Step('Accepted', Icons.thumb_up_alt_outlined), at('accepted_at')),
      (const _Step('Heading out', Icons.directions_car_rounded), at('arrived_at')),
      (const _Step('Working', Icons.build_rounded), at('started_at')),
      (const _Step('Completed', Icons.task_alt_rounded), at('completed_at')),
    ];

    const order = [
      'pending',
      'matched',
      'accepted',
      'en_route',
      'arrived',
      'in_progress',
      'completed'
    ];
    final currentIdx = order.indexOf(status);
    final isCancelled = {'cancelled', 'rejected', 'expired'}.contains(status);

    return SogoCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Progress', style: SogoText.headlineMd),
        const SizedBox(height: SogoSpacing.md),
        ...stages.asMap().entries.map((entry) {
          final i = entry.key;
          final stage = entry.value.$1;
          final time = entry.value.$2;
          final done = time != '-' || (currentIdx >= 0 && i < currentIdx);
          final active =
              !done && !isCancelled && currentIdx >= 0 && i == currentIdx;
          final color = done
              ? SogoColors.success
              : active
                  ? SogoColors.primary
                  : SogoColors.textMuted;
          final isLast = i == stages.length - 1;

          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: done || active
                      ? color.withOpacity(0.14)
                      : SogoColors.surfaceMuted,
                  shape: BoxShape.circle,
                  border: active ? Border.all(color: color, width: 2) : null,
                ),
                child: Icon(
                    done
                        ? Icons.check_rounded
                        : (active ? Icons.sync_rounded : stage.icon),
                    size: 18,
                    color: color),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 18,
                  color: done
                      ? SogoColors.success.withOpacity(0.6)
                      : SogoColors.surfaceBorder,
                ),
            ]),
            const SizedBox(width: SogoSpacing.md),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stage.label,
                          style: SogoText.bodyMd.copyWith(
                              fontWeight: FontWeight.w700,
                              color: done || active
                                  ? SogoColors.textPrimary
                                  : SogoColors.textMuted)),
                      if (time != '-')
                        Text(time,
                            style: SogoText.labelMd
                                .copyWith(color: SogoColors.textSecondary)),
                    ]),
              ),
            ),
          ]);
        }),
        if (isCancelled) ...[
          const SizedBox(height: SogoSpacing.sm),
          Container(
            padding: const EdgeInsets.all(SogoSpacing.md),
            decoration: BoxDecoration(
              color: SogoColors.danger.withOpacity(0.08),
              borderRadius: BorderRadius.circular(SogoRadius.md),
              border: Border.all(color: SogoColors.danger.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.cancel_outlined,
                  color: SogoColors.danger, size: 20),
              const SizedBox(width: SogoSpacing.sm),
              Expanded(
                child: Text(
                    'Job ${status.replaceAll('_', ' ')} - ${_fmtTime('${_request['cancelled_at'] ?? ''}')}',
                    style: SogoText.bodySm.copyWith(color: SogoColors.danger)),
              ),
            ]),
          ),
        ],
        if (logs.isNotEmpty) ...[
          const SizedBox(height: SogoSpacing.md),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Full activity log (${logs.length})',
                  style: SogoText.bodySm
                      .copyWith(color: SogoColors.textSecondary)),
              children: logs.whereType<Map<String, dynamic>>().map((l) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    const Icon(Icons.flag_rounded,
                        size: 14, color: SogoColors.textMuted),
                    const SizedBox(width: SogoSpacing.sm),
                    Expanded(
                        child: Text('${l['status'] ?? ''}'.replaceAll('_', ' '),
                            style: SogoText.bodySm)),
                    Text(_fmtTime('${l['changed_at'] ?? ''}'),
                        style: SogoText.labelMd
                            .copyWith(color: SogoColors.textMuted)),
                  ]),
                );
              }).toList(),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 96,
            child: Text(label,
                style:
                    SogoText.bodySm.copyWith(color: SogoColors.textSecondary))),
        Expanded(
            child: Text(value,
                style: SogoText.bodySm.copyWith(fontWeight: FontWeight.w600))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estimated = _request['estimated_price'];
    final finalPrice = _request['final_price'];
    final customer = _request['customer'] as Map<String, dynamic>? ?? const {};
    final vehicle = _request['vehicle'] as Map<String, dynamic>? ?? const {};

    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(title: Text('Job #${_request['reference'] ?? ''}')),
      body: ListView(
        padding: const EdgeInsets.all(SogoSpacing.lg),
        children: [
          // -- Status header --
          SogoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: _statusColor(_status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(SogoRadius.pill)),
                      child: Text(_status.replaceAll('_', ' ').toUpperCase(),
                          style: SogoText.labelMd
                              .copyWith(color: _statusColor(_status)))),
                  const Spacer(),
                  Text(
                      finalPrice != null
                          ? ugx(num.tryParse('$finalPrice'))
                          : estimated != null
                              ? 'Est. ${ugx(num.tryParse('$estimated'))}'
                              : '',
                      style: SogoText.headlineMd),
                ]),
                const SizedBox(height: SogoSpacing.md),
                Text('${_request['category']?['name'] ?? 'Service request'}',
                    style: SogoText.headlineLg),
                const SizedBox(height: 4),
                Text('${_request['description'] ?? ''}',
                    style: SogoText.bodyMd
                        .copyWith(color: SogoColors.textSecondary)),
                const Divider(height: SogoSpacing.xl),
                _infoRow('Pickup', '${_request['pickup_address'] ?? '-'}'),
                if ('${_request['scheduled_at'] ?? ''}'.isNotEmpty)
                  _infoRow(
                      'Scheduled', _fmtTime('${_request['scheduled_at']}')),
                if ('${_request['destination_address'] ?? ''}'.isNotEmpty)
                  _infoRow('Drop-off', '${_request['destination_address']}'),
                _infoRow('Booked', _fmtTime('${_request['created_at'] ?? ''}')),
              ],
            ),
          ),
          const SizedBox(height: SogoSpacing.lg),

          // -- Live map --
          _liveMap(),
          if (_live) const SizedBox(height: SogoSpacing.lg),

          // -- Customer --
          SogoCard(
            child: Row(children: [
              CircleAvatar(
                  radius: 24,
                  backgroundColor: SogoColors.primaryLight,
                  child: Text(
                      '${customer['name'] ?? 'C'}'
                          .characters
                          .first
                          .toUpperCase(),
                      style:
                          SogoText.bodyLg.copyWith(color: SogoColors.primary))),
              const SizedBox(width: SogoSpacing.md),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('${customer['name'] ?? 'Customer'}',
                        style: SogoText.bodyLg
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${customer['phone'] ?? 'Phone not shared'}',
                        style: SogoText.bodySm
                            .copyWith(color: SogoColors.textSecondary)),
                    if (vehicle.isNotEmpty)
                      Text(
                          '${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''} - ${vehicle['plate_number'] ?? ''}',
                          style: SogoText.bodySm
                              .copyWith(color: SogoColors.textSecondary)),
                  ])),
              if (!widget.readOnly)
                IconButton.filled(
                    onPressed: _callCustomer,
                    style: IconButton.styleFrom(
                        backgroundColor: SogoColors.primary),
                    icon: const Icon(Icons.call_rounded, color: Colors.white)),
            ]),
          ),
          const SizedBox(height: SogoSpacing.lg),

          _timeline(),
          const SizedBox(height: SogoSpacing.lg),

          // -- Actions (one button per stage, no duplicates) --
          if (!widget.readOnly) ...[
            if (_canAccept) ...[
              SogoButton(
                  label: 'Accept job',
                  icon: Icons.thumb_up_alt_outlined,
                  onPressed: _busy ? null : _accept,
                  loading: _busy),
              const SizedBox(height: SogoSpacing.md),
              SogoButton(
                  label: 'Decline (pass to another provider)',
                  icon: Icons.thumb_down_alt_outlined,
                  variant: SogoButtonVariant.outline,
                  onPressed: _busy ? null : _decline),
            ] else if (_status == 'accepted' || _status == 'matched')
              SogoButton(
                  label: 'Start journey (en route)',
                  icon: Icons.directions_car_rounded,
                  onPressed: _busy ? null : () => _setStatus('en_route'),
                  loading: _busy)
            else if (_status == 'en_route')
              SogoButton(
                  label: 'I have arrived',
                  icon: Icons.pin_drop_rounded,
                  onPressed: _busy ? null : () => _setStatus('arrived'),
                  loading: _busy)
            else if (_status == 'arrived')
              SogoButton(
                  label: 'Start working',
                  icon: Icons.build_rounded,
                  onPressed: _busy ? null : () => _setStatus('in_progress'),
                  loading: _busy)
            else if (_status == 'in_progress')
              SogoButton(
                  label: 'Mark completed',
                  icon: Icons.task_alt_rounded,
                  onPressed: _busy ? null : _completeDialog,
                  loading: _busy),
            const SizedBox(height: SogoSpacing.xl),
          ],
        ],
      ),
    );
  }
}

class _Step {
  const _Step(this.label, this.icon);

  final String label;
  final IconData icon;
}
