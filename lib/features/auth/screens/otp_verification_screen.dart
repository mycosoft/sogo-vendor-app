import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';
import 'pending_verification_screen.dart';

/// Step 1 after vendor registration: verify the phone number with the
/// OTP that was SMS'd automatically at account creation.
/// On success -> [PendingVerificationScreen] (admin approval status).
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key, required this.phone});

  final String phone;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _code = TextEditingController();
  bool _verifying = false;
  bool _resending = false;
  int _resendIn = 0;
  Timer? _resendTimer;
  String? _error;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the 6-digit code from the SMS');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final res = await apiClient.post('/api/v1/auth/verify-otp', {
        'phone': widget.phone,
        'code': code,
        'purpose': 'phone_verification',
      });
      if (!mounted) return;
      if (res['success'] == true) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => PendingVerificationScreen(phone: widget.phone)));
      } else {
        setState(() => _error = res['message'] ?? 'Invalid or expired code');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resendIn > 0 || _resending) return;
    setState(() => _resending = true);
    try {
      await apiClient.post('/api/v1/auth/send-otp', {
        'phone': widget.phone,
        'purpose': 'phone_verification',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new code has been sent')));
      setState(() => _resendIn = 60);
      _resendTimer?.cancel();
      _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted || _resendIn <= 1) {
          t.cancel();
          if (mounted) setState(() => _resendIn = 0);
          return;
        }
        setState(() => _resendIn--);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: SogoColors.surfaceMuted,
        appBar: AppBar(
            title: const Text('Verify phone'),
            automaticallyImplyLeading: false,
            backgroundColor: SogoColors.primary,
            foregroundColor: Colors.white),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SogoSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: SogoSpacing.xl),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: SogoColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sms_outlined,
                      size: 40, color: SogoColors.primary),
                ),
                const SizedBox(height: SogoSpacing.lg),
                Text('Verify your number', style: SogoText.headlineLg),
                const SizedBox(height: SogoSpacing.sm),
                Text(
                  'We sent a 6-digit code by SMS to\n${widget.phone}',
                  textAlign: TextAlign.center,
                  style:
                      SogoText.bodyMd.copyWith(color: SogoColors.textSecondary),
                ),
                const SizedBox(height: SogoSpacing.xl),
                TextField(
                  controller: _code,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: SogoText.headlineLg.copyWith(letterSpacing: 8),
                  decoration: InputDecoration(
                    hintText: '------',
                    counterText: '',
                    errorText: _error,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(SogoRadius.md)),
                  ),
                  onSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: SogoSpacing.lg),
                SogoButton(
                    label: 'Verify & continue',
                    onPressed: _verifying ? null : _verify,
                    loading: _verifying),
                const SizedBox(height: SogoSpacing.md),
                TextButton(
                  onPressed: (_resendIn > 0 || _resending) ? null : _resend,
                  child: Text(
                      _resending
                          ? 'Sending...'
                          : _resendIn > 0
                              ? 'Resend code in ${_resendIn}s'
                              : 'Didn\'t get the code? Resend',
                      style: SogoText.bodySm.copyWith(
                          color: SogoColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
