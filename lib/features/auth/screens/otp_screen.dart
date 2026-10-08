import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';
import '../../../shell/app_shell.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phone});
  final String phone;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focus = List.generate(6, (_) => FocusNode());
  Timer? _timer;
  int _seconds = 30;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _seconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_seconds <= 1) t.cancel();
      setState(() => _seconds--);
    });
  }

  void _onChanged(int i, String value) {
    if (value.isNotEmpty && i < 5) {
      _focus[i + 1].requestFocus();
    } else if (value.isEmpty && i > 0) {
      _focus[i - 1].requestFocus();
    }
    if (_controllers.every((c) => c.text.isNotEmpty)) {
      _verify();
    }
  }

  void _verify() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focus) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SogoSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: SogoSpacing.xl),
              const Icon(Icons.sms_outlined,
                  size: 64, color: SogoColors.primary),
              const SizedBox(height: SogoSpacing.lg),
              Text('Verify your phone', style: SogoText.displayMd),
              const SizedBox(height: 6),
              Text(
                  'Enter the 6-digit code we sent to ${widget.phone.isEmpty ? 'your phone' : widget.phone}',
                  style: SogoText.bodyMd
                      .copyWith(color: SogoColors.textSecondary)),
              const SizedBox(height: SogoSpacing.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _otpBox(i)),
              ),
              const SizedBox(height: SogoSpacing.xl),
              SogoButton(label: 'Verify', onPressed: _verify),
              const SizedBox(height: SogoSpacing.md),
              Center(
                child: _seconds > 0
                    ? Text('Resend in ${_seconds}s',
                        style: SogoText.bodySm
                            .copyWith(color: SogoColors.textMuted))
                    : TextButton(
                        onPressed: _startTimer,
                        child: Text('Resend code',
                            style: SogoText.bodyMd.copyWith(
                                color: SogoColors.primary,
                                fontWeight: FontWeight.w700))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int i) {
    return SizedBox(
      width: 44,
      child: TextField(
        controller: _controllers[i],
        focusNode: _focus[i],
        maxLength: 1,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: SogoText.headlineLg,
        onChanged: (v) => _onChanged(i, v),
        decoration: InputDecoration(
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(vertical: 12)),
      ),
    );
  }
}
