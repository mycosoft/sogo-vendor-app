import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';

/// First-launch walkthrough (same pattern as the Driver reference):
/// full-screen art pages, bottom title + subtitle, dots, circular
/// next button, top-right Skip. Shown once, then never again.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  static const flagKey = 'sogo_onboarding_done_v1';

  static Future<bool> isDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(flagKey) ?? false;
  }

  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(flagKey, true);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = const [
    (
      'assets/onboarding/walk1.png',
      'Get job requests',
      'Go online and receive bookings from customers near you.',
    ),
    (
      'assets/onboarding/walk2.png',
      'Run your whole shop',
      'Services, inventory, orders and invoices — one business hub, plus a wallet and earnings dashboard.',
    ),
    (
      'assets/onboarding/walk3.png',
      'Get paid fast',
      'Earnings land in your wallet. Withdraw to Mobile Money or bank anytime.',
    ),
  ];

  final _controller = PageController();
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    // Best-effort persist; navigation must never depend on storage.
    OnboardingScreen.markDone();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, i) {
              final page = _pages[i];
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(page.$1, fit: BoxFit.cover),
                  // Bottom scrim so white text reads on any photo.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.15),
                            Colors.black.withOpacity(0.72),
                          ],
                          stops: const [0.35, 0.62, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(_pages[_current].$2,
                    textAlign: TextAlign.center,
                    style: SogoText.displayMd.copyWith(color: Colors.white)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(_pages[_current].$3,
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: SogoText.bodyMd
                          .copyWith(color: Colors.white.withOpacity(0.9))),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _pages.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin:
                            const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _current ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _current
                              ? SogoColors.primary
                              : Colors.white.withOpacity(0.5),
                          borderRadius:
                              BorderRadius.circular(SogoRadius.pill),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: () {
                    if (_current >= _pages.length - 1) {
                      _finish();
                    } else {
                      _controller.nextPage(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: SogoColors.primary,
                        boxShadow: [SogoShadows.elevated]),
                    child: const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 28),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: TextButton(
              onPressed: _finish,
              child: Text('Skip',
                  style: SogoText.button.copyWith(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
