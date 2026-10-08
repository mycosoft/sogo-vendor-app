import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';
import '../../../core/app_services.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _codeFocus = List.generate(6, (_) => FocusNode());
  final _codeControllers = List.generate(6, (_) => TextEditingController());

  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _codeSent = false;
  int _step = 1;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    for (final c in _codeControllers) {
      c.dispose();
    }
    for (final f in _codeFocus) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _codeControllers.map((c) => c.text).join();

  Future<void> _sendOtp() async {
    if (_phone.text.trim().isEmpty) {
      _showMessage('Please enter your phone number', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await authApi.forgotPassword(phone: _phone.text.trim());
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _codeSent = true;
          _step = 2;
        });
        _showMessage(res['message']?.toString() ?? 'OTP sent to your phone');
      } else {
        _showMessage(res['message']?.toString() ?? 'Failed to send OTP',
            isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final code = _otpCode;
    if (code.length < 6) {
      _showMessage('Enter the 6-digit code', isError: true);
      return;
    }
    if (_password.text.length < 8) {
      _showMessage('Password must be at least 8 characters', isError: true);
      return;
    }
    if (_password.text != _confirm.text) {
      _showMessage('Passwords do not match', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await authApi.resetPassword(
        phone: _phone.text.trim(),
        code: code,
        password: _password.text,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() => _step = 3);
      } else {
        _showMessage(
            res['message']?.toString() ?? 'Reset failed. Check the code.',
            isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? SogoColors.danger : null,
      ),
    );
  }

  void _onCodeChanged(int i, String value) {
    if (value.isNotEmpty && i < 5) {
      _codeFocus[i + 1].requestFocus();
    } else if (value.isEmpty && i > 0) {
      _codeFocus[i - 1].requestFocus();
    }
    setState(() {});
  }

  void _backToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(
        title: const Text('Reset password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SogoSpacing.xl),
          child: _buildStep(),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 1:
        return _phoneStep();
      case 2:
        return _resetStep();
      default:
        return _successStep();
    }
  }

  Widget _phoneStep() {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: SogoSpacing.xl),
          const Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: SogoColors.primaryLight,
              child: Icon(Icons.lock_reset_outlined,
                  size: 40, color: SogoColors.primary),
            ),
          ),
          const SizedBox(height: SogoSpacing.xl),
          const Text('Forgot password?', style: SogoText.displayMd),
          const SizedBox(height: 6),
          Text(
            'Enter the phone number linked to your account and we will send you a verification code.',
            style: SogoText.bodyMd.copyWith(color: SogoColors.textSecondary),
          ),
          const SizedBox(height: SogoSpacing.xxl),
          SogoTextField(
            label: 'Phone number',
            hint: '+256 7XX XXX XXX',
            controller: _phone,
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _sendOtp(),
          ),
          const SizedBox(height: SogoSpacing.xl),
          SogoButton(
            label: 'Send verification code',
            onPressed: _sendOtp,
            loading: _loading,
            icon: Icons.sms_outlined,
          ),
        ],
      ),
    );
  }

  Widget _resetStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: SogoSpacing.xl),
        const Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: SogoColors.primaryLight,
            child:
                Icon(Icons.sms_outlined, size: 40, color: SogoColors.primary),
          ),
        ),
        const SizedBox(height: SogoSpacing.xl),
        const Text('Enter the code', style: SogoText.displayMd),
        const SizedBox(height: 6),
        Text(
          'We sent a 6-digit code to ${_phone.text.trim()}. Enter it below and choose a new password.',
          style: SogoText.bodyMd.copyWith(color: SogoColors.textSecondary),
        ),
        const SizedBox(height: SogoSpacing.xxl),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => _otpBox(i)),
        ),
        const SizedBox(height: SogoSpacing.xl),
        SogoTextField(
          label: 'New password',
          hint: 'At least 8 characters',
          controller: _password,
          obscureText: _obscure,
          prefixIcon: Icons.lock_outline,
          suffixIcon: IconButton(
            icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: SogoColors.textMuted),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        const SizedBox(height: SogoSpacing.lg),
        SogoTextField(
          label: 'Confirm new password',
          hint: 'Re-enter your new password',
          controller: _confirm,
          obscureText: _obscureConfirm,
          prefixIcon: Icons.lock_outline,
          suffixIcon: IconButton(
            icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: SogoColors.textMuted),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
          onSubmitted: (_) => _resetPassword(),
        ),
        const SizedBox(height: SogoSpacing.xl),
        SogoButton(
          label: 'Reset password',
          onPressed: _resetPassword,
          loading: _loading,
        ),
        const SizedBox(height: SogoSpacing.md),
        Center(
          child: TextButton(
            onPressed: _codeSent ? _sendOtp : null,
            child: Text('Resend code',
                style: SogoText.bodyMd.copyWith(
                    color: SogoColors.primary, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _successStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: SogoSpacing.xxl),
        const Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: SogoColors.primaryLight,
            child: Icon(Icons.check_circle_outline,
                size: 44, color: SogoColors.primary),
          ),
        ),
        const SizedBox(height: SogoSpacing.xl),
        const Center(child: Text('Password reset!', style: SogoText.displayMd)),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Your password has been changed successfully. Sign in with your new password.',
            textAlign: TextAlign.center,
            style: SogoText.bodyMd.copyWith(color: SogoColors.textSecondary),
          ),
        ),
        const SizedBox(height: SogoSpacing.xxl),
        SogoButton(
          label: 'Back to sign in',
          onPressed: _backToLogin,
          icon: Icons.arrow_back,
        ),
      ],
    );
  }

  Widget _otpBox(int i) {
    return SizedBox(
      width: 44,
      child: TextField(
        controller: _codeControllers[i],
        focusNode: _codeFocus[i],
        maxLength: 1,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: SogoText.headlineLg,
        onChanged: (v) => _onCodeChanged(i, v),
        decoration: const InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.symmetric(vertical: 12)),
      ),
    );
  }
}
