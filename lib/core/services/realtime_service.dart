import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

typedef RealtimeHandler = void Function(Map<String, dynamic> data);

class _Watch {
  _Watch(this.event, this.handler);
  final String event;
  final RealtimeHandler handler;
}

/// Pusher-protocol client for the Laravel Reverb socket.
///
/// This is strictly an *upgrade* over HTTP polling: if the socket cannot
/// connect (Reverb not running, wrong key, offline), every call returns
/// false and the screens keep their existing timers. Nothing breaks.
class RealtimeService {
  RealtimeService({required this.apiBaseUrl, required this.tokenProvider});

  final String apiBaseUrl;
  final Future<String?> Function() tokenProvider;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  String? _socketId;
  Completer<String>? _established;
  bool _connecting = false;
  final Map<String, List<_Watch>> _handlers = {};

  bool get isLive => _socketId != null;

  String get _appKey =>
      const String.fromEnvironment('SOGO_REVERB_KEY', defaultValue: '');

  String get _wsHost {
    const override =
        String.fromEnvironment('SOGO_REVERB_HOST', defaultValue: '');
    if (override.isNotEmpty) return override;
    return Uri.parse(apiBaseUrl).host;
  }

  int get _wsPort {
    const override =
        String.fromEnvironment('SOGO_REVERB_PORT', defaultValue: '');
    if (override.isNotEmpty) return int.tryParse(override) ?? 8080;
    final u = Uri.parse(apiBaseUrl);
    if (u.hasPort) return u.port;
    return u.scheme == 'https' ? 443 : 80;
  }

  String get _wsScheme {
    const override =
        String.fromEnvironment('SOGO_REVERB_SCHEME', defaultValue: '');
    if (override.isNotEmpty) return override;
    return Uri.parse(apiBaseUrl).scheme == 'https' ? 'wss' : 'ws';
  }

  String _name(String channel) => (channel.startsWith('private-') ||
          channel.startsWith('presence-'))
      ? channel
      : 'private-$channel';

  /// Subscribe to [event] on [channel]. Returns true when the socket is
  /// (now) live and the subscription was sent.
  Future<bool> subscribe(
      String channel, String event, RealtimeHandler handler) async {
    final name = _name(channel);
    (_handlers[name] ??= []).add(_Watch(event, handler));
    if (isLive) {
      await _sendSubscribe(name);
      return true;
    }
    final ok = await _connect();
    if (ok) await _sendSubscribe(name);
    return ok;
  }

  void unsubscribe(String channel, [String? event]) {
    final name = _name(channel);
    final list = _handlers[name];
    if (list == null) return;
    if (event == null) {
      list.clear();
    } else {
      list.removeWhere((w) => w.event == event);
    }
    if (list.isEmpty) {
      _handlers.remove(name);
      if (isLive) {
        try {
          _channel?.sink.add(jsonEncode({
            'event': 'pusher:unsubscribe',
            'data': {'channel': name},
          }));
        } catch (_) {}
      }
    }
  }

  Future<bool> _connect() async {
    if (isLive) return true;
    if (_connecting || _appKey.isEmpty) return false;
    _connecting = true;
    try {
      final token = await tokenProvider();
      if (token == null || token.isEmpty) return false;
      final uri = Uri.parse(
          '$_wsScheme://$_wsHost:$_wsPort/app/$_appKey?protocol=7&client=sogo-flutter&version=1.0.0');
      _channel = WebSocketChannel.connect(uri);
      _established = Completer<String>();
      _sub = _channel!.stream.listen(
        _onData,
        onError: (_) => _reset(),
        onDone: () => _reset(),
        cancelOnError: false,
      );
      final socketId =
          await _established!.future.timeout(const Duration(seconds: 10));
      _socketId = socketId;
      for (final name in _handlers.keys.toList()) {
        await _sendSubscribe(name);
      }
      return true;
    } catch (_) {
      _reset();
      return false;
    } finally {
      _connecting = false;
    }
  }

  Future<void> _sendSubscribe(String name) async {
    if (!isLive) return;
    try {
      final token = await tokenProvider();
      if (token == null || token.isEmpty) return;
      final res = await http
          .post(
            Uri.parse('$apiBaseUrl/broadcasting/auth'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(
                {'socket_id': _socketId, 'channel_name': name}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final auth = body['auth'] as String?;
      if (auth == null) return;
      _channel?.sink.add(jsonEncode({
        'event': 'pusher:subscribe',
        'data': {'channel': name, 'auth': auth},
      }));
    } catch (_) {}
  }

  void _onData(dynamic raw) {
    Map<String, dynamic>? msg;
    try {
      msg = jsonDecode('$raw') as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final event = msg['event'] as String?;
    if (event == 'pusher:connection_established') {
      try {
        final data = jsonDecode('${msg['data']}') as Map;
        if (!(_established?.isCompleted ?? true)) {
          _established?.complete('${data['socket_id']}');
        }
      } catch (_) {}
      return;
    }
    if (event == 'pusher:ping') {
      try {
        _channel?.sink
            .add(jsonEncode({'event': 'pusher:pong', 'data': {}}));
      } catch (_) {}
      return;
    }
    if (event == null || event.startsWith('pusher:')) return;
    final channel = msg['channel'] as String?;
    if (channel == null) return;
    final data = msg['data'];
    late Map<String, dynamic> payload;
    if (data is String) {
      try {
        payload = Map<String, dynamic>.from(jsonDecode(data) as Map);
      } catch (_) {
        return;
      }
    } else if (data is Map) {
      payload = Map<String, dynamic>.from(data);
    } else {
      return;
    }
    final list = _handlers[channel];
    if (list == null) return;
    for (final w in List<_Watch>.of(list)) {
      if (w.event == event) {
        try {
          w.handler(payload);
        } catch (_) {}
      }
    }
  }

  void _reset() {
    _socketId = null;
    try {
      _sub?.cancel();
    } catch (_) {}
    try {
      _channel?.sink.close();
    } catch (_) {}
    _sub = null;
    _channel = null;
    if (!(_established?.isCompleted ?? true)) {
      try {
        _established?.completeError(StateError('socket closed'));
      } catch (_) {}
    }
    _established = null;
  }
}
