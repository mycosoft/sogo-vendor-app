import 'package:flutter/material.dart';
import 'core/app_services.dart';
import 'core/services/push_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/location_gate.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/pending_verification_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'shell/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SogoVendorApp());
}

class SogoVendorApp extends StatelessWidget {
  const SogoVendorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SOGO Vendor',
      navigatorKey: PushService.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildSogoTheme(),
      home: const LocationGate(child: _RootGate()),
    );
  }
}

/// Result of the startup bootstrap: token presence + vendor approval state.
class _BootState {
  final String? token;
  final bool pendingApproval;
  final String? phone;

  const _BootState(this.token, {this.pendingApproval = false, this.phone});
}

class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  late final Future<_BootState> _bootFuture = _bootstrap();

  /// A saved token means "logged in", but an unapproved vendor must stay
  /// on the pending-verification screen instead of the dashboard - on
  /// every launch until an admin approves the account.
  Future<_BootState> _bootstrap() async {
    final token = await apiClient.loadToken();
    if (token == null) return const _BootState(null);

    try {
      final me = await providerApi.me();
      final data = me['data'] as Map<String, dynamic>? ?? {};
      final status = '${data['verification_status'] ?? 'pending'}';
      final user = data['user'] as Map<String, dynamic>? ?? {};
      if (status != 'approved') {
        return _BootState(token,
            pendingApproval: true, phone: '${user['phone'] ?? ''}');
      }
    } catch (_) {
      // Status check failed (offline/server error) - don't lock the
      // vendor out; the backend still guards sensitive actions.
    }

    return _BootState(token);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootState>(
      future: _bootFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const SplashScreen();
        }
        final boot = snapshot.data ?? const _BootState(null);
        if (boot.token == null) return const LoginScreen();
        if (boot.pendingApproval) {
          return PendingVerificationScreen(phone: boot.phone ?? '');
        }
        return const AppShell();
      },
    );
  }
}
