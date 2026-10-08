import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';

/// Blocks the app until location access is granted.
///
/// SOGO needs location to find nearby providers and dispatch jobs, so the
/// gate explains why, walks the user through the native prompts, and offers
/// deep links to system settings when permission was permanently denied or
/// location services are switched off. Re-checks automatically when the
/// user returns from settings.
class LocationGate extends StatefulWidget {
  const LocationGate({super.key, required this.child});

  final Widget child;

  @override
  State<LocationGate> createState() => _LocationGateState();
}

class _LocationGateState extends State<LocationGate>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _serviceOn = true;
  bool _unavailable = false;
  LocationPermission _permission = LocationPermission.denied;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      var permission = await Geolocator.checkPermission();
      if (serviceOn && permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      setState(() {
        _serviceOn = serviceOn;
        _permission = permission;
        _checking = false;
      });
    } on MissingPluginException {
      // Plugin unavailable (e.g. widget tests) - don't brick the app.
      if (!mounted) return;
      setState(() => _checking = false);
      _unavailable = true;
    }
  }

  bool get _granted =>
      _unavailable ||
      (_serviceOn &&
          (_permission == LocationPermission.whileInUse ||
              _permission == LocationPermission.always));

  @override
  Widget build(BuildContext context) {
    if (_checking) return const SplashScreenBridge();
    if (_granted) return widget.child;
    return _GateScreen(
      serviceOn: _serviceOn,
      deniedForever: _permission == LocationPermission.deniedForever,
      onRetry: _check,
    );
  }
}

class SplashScreenBridge extends StatelessWidget {
  const SplashScreenBridge({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: SogoColors.secondaryDark,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

class _GateScreen extends StatelessWidget {
  const _GateScreen({
    required this.serviceOn,
    required this.deniedForever,
    required this.onRetry,
  });

  final bool serviceOn;
  final bool deniedForever;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (title, message, buttonLabel, onPressed) = serviceOn
        ? deniedForever
            ? (
                'Location permission needed',
                'SOGO uses your location to find verified providers near you. '
                    'Permission was permanently declined - please enable it '
                    'in Settings to continue.',
                'Open settings',
                () => Geolocator.openAppSettings(),
              )
            : (
                'Location permission needed',
                'SOGO uses your location to find verified providers near you '
                    'and get help fast. Allow location access to continue.',
                'Allow location',
                onRetry,
              )
        : (
            'Location is turned off',
            'Your device location services are off. SOGO needs location to '
                'find providers near you. Turn it on to continue.',
            'Open location settings',
            () => Geolocator.openLocationSettings(),
          );

    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SogoSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [SogoColors.primary, SogoColors.primaryDark]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on_rounded,
                    color: Colors.white, size: 44),
              ),
              const SizedBox(height: SogoSpacing.xl),
              Text(title,
                  style: SogoText.headlineLg, textAlign: TextAlign.center),
              const SizedBox(height: SogoSpacing.sm),
              Text(message,
                  style:
                      SogoText.bodyMd.copyWith(color: SogoColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: SogoSpacing.xl),
              ElevatedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.my_location_outlined, size: 18),
                label: Text(buttonLabel),
              ),
              const SizedBox(height: SogoSpacing.sm),
              TextButton(
                onPressed: onRetry,
                child: Text('Check again',
                    style: SogoText.bodyMd.copyWith(
                        color: SogoColors.primary,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
