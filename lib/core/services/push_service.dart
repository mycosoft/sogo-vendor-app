import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../api/push_api.dart';
import '../../features/messages/screens/chats_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/business/screens/orders_screen.dart';
import '../../features/business/screens/invoices_screen.dart';
import '../../features/payments/screens/payments_screen.dart';
import '../../features/requests/screens/request_details_screen.dart';

/// Firebase Cloud Messaging wrapper.
///
/// - Initializes Firebase and requests notification permission.
/// - Registers (and re-registers on rotation) the device token with the
///   SOGO backend so server-side events reach this phone.
/// - Shows an in-app banner for messages received while the app is open
///   (the OS handles notifications while the app is backgrounded).
///
/// Firebase requires `android/app/google-services.json` before building -
/// without it, init fails and everything degrades silently.
class PushService {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final PushApi _api = PushApi(apiClient);
  static bool _initialized = false;

  static Future<void> init({required String app}) async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
    } catch (_) {
      return;
    }
    _initialized = true;

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data = Map<String, dynamic>.from(message.data);
      final n = message.notification;
      if (n != null) {
        _showBanner(n.title ?? '${data['title'] ?? 'SOGO'}', n.body ?? '',
            onOpen: () => _openFromData(data));
      } else {
        // Data-only push while foreground - still surface it.
        _showBanner('${data['title'] ?? 'SOGO'}', '',
            onOpen: () => _openFromData(data));
      }
    });

    // Taps on background/terminated notifications.
    FirebaseMessaging.onMessageOpenedApp
        .listen((m) => _openFromData(Map<String, dynamic>.from(m.data)));
    messaging.getInitialMessage().then((m) {
      if (m != null) _openFromData(Map<String, dynamic>.from(m.data));
    });

    final token = await messaging.getToken();
    if (token != null) await _register(token, app);

    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      _register(t, app);
    });
  }

  static Future<void> _register(String token, String app) async {
    try {
      await _api.register(token: token, app: app);
    } catch (_) {
      // Registration is best-effort; the next app start retries.
    }
  }

  /// Routes every push to its screen: chat thread, job workspace, orders,
  /// invoices, wallet, or the notifications hub as fallback. Server sends
  /// {type, title, url}; job urls already point at the right audience.
  static void _openFromData(Map<String, dynamic> data) {
    if ('${data['type']}' == 'chat') {
      final id = int.tryParse('${data['from_user_id'] ?? ''}');
      if (id == null) return;
      _push(ChatScreen(
          userId: id, name: '${data['from_name'] ?? 'Chat'}'));
      return;
    }
    final job = RegExp(r'/vendor/service-requests/(\d+)')
        .firstMatch('${data['url'] ?? ''}');
    if (job != null) {
      _openJob(int.parse(job.group(1)!));
      return;
    }
    final title = '${data['title'] ?? ''}'.toLowerCase();
    if (title.contains('order')) {
      _push(const OrdersScreen());
      return;
    }
    if (title.contains('invoice')) {
      _push(const InvoicesScreen());
      return;
    }
    if (title.contains('withdraw') ||
        title.contains('wallet') ||
        title.contains('payout') ||
        title.contains('refund') ||
        title.contains('payment')) {
      _push(const PaymentsScreen());
      return;
    }
    _push(const NotificationsScreen());
  }

  static Future<void> _openJob(int id) async {
    try {
      final res = await providerApi.jobShow(id);
      final request = res['data'] as Map<String, dynamic>?;
      if (request == null) return;
      _push(RequestDetailsScreen(request: request, readOnly: false));
    } catch (_) {
      _push(const NotificationsScreen());
    }
  }

  static void _push(Widget screen) {
    navigatorKey.currentState
        ?.push(MaterialPageRoute(builder: (_) => screen));
  }

  static void _showBanner(String title, String body, {VoidCallback? onOpen}) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        action: onOpen == null
            ? null
            : SnackBarAction(
                label: 'OPEN', textColor: Colors.white, onPressed: onOpen),
      ),
    );
  }
}
