import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../api/push_api.dart';
import '../../features/messages/screens/chats_screen.dart';

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
      final n = message.notification;
      if (n != null) {
        _showBanner(n.title ?? 'SOGO', n.body ?? '',
            onOpen: message.data['type'] == 'chat'
                ? () => _openChat(message)
                : null);
      } else if (message.data['type'] == 'chat') {
        // Data-only chat push while foreground - still surface it.
        _showBanner('New message', '', onOpen: () => _openChat(message));
      }
    });

    // Taps on background/terminated notifications.
    FirebaseMessaging.onMessageOpenedApp.listen(_openChatIfChat);
    messaging.getInitialMessage().then((m) {
      if (m != null) _openChatIfChat(m);
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

  static void _openChatIfChat(RemoteMessage message) {
    if (message.data['type'] == 'chat') _openChat(message);
  }

  static void _openChat(RemoteMessage message) {
    final id = int.tryParse('${message.data['from_user_id'] ?? ''}');
    if (id == null) return;
    final name = '${message.data['from_name'] ?? 'Chat'}';
    navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => ChatScreen(userId: id, name: name)));
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
