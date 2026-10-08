import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';
import 'forgot_password_screen.dart';
import 'pending_verification_screen.dart';
import 'vendor_register_screen.dart';
import '../../../shell/app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await authApi.login(email: _email.text.trim(), password: _password.text);
      if (!mounted) return;

      // Unapproved vendors stay on the pending-verification screen.
      Widget destination = const AppShell();
      try {
        final me = await providerApi.me();
        final data = me['data'] as Map<String, dynamic>? ?? {};
        if ('${data['verification_status'] ?? 'pending'}' != 'approved') {
          final user = data['user'] as Map<String, dynamic>? ?? {};
          destination = PendingVerificationScreen(
              phone: '${user['phone'] ?? _email.text.trim()}');
        }
      } catch (_) {
        // Status check failed - let them in; backend still guards.
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => destination),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: SogoColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SogoSpacing.xl),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: SogoSpacing.md),
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: SogoColors.primary,
                      borderRadius: BorderRadius.circular(SogoRadius.xl),
                      boxShadow: const [SogoShadows.elevated],
                    ),
                    child: const Icon(Icons.handyman_outlined,
                        size: 44, color: Colors.white),
                  ),
                ),
                const SizedBox(height: SogoSpacing.lg),
                const Center(
                  child: Text('SOGO Vendor', style: SogoText.displayLg),
                ),
                const SizedBox(height: SogoSpacing.xl),
                const Text('Welcome back', style: SogoText.headlineLg),
                const SizedBox(height: 4),
                Text('Sign in to manage your business',
                    style: SogoText.bodyMd
                        .copyWith(color: SogoColors.textSecondary)),
                const SizedBox(height: SogoSpacing.xl),
                SogoTextField(
                  label: 'Email or phone',
                  hint: 'you@example.com',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.person_outline,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: SogoSpacing.lg),
                SogoTextField(
                  label: 'Password',
                  hint: 'Enter your password',
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
                  validator: (v) => (v == null || v.length < 6)
                      ? 'At least 6 characters'
                      : null,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: SogoSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen())),
                    child: Text('Forgot password?',
                        style: SogoText.bodyMd.copyWith(
                            color: SogoColors.primary,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: SogoSpacing.md),
                SogoButton(
                    label: 'Sign in', onPressed: _submit, loading: _loading),
                const SizedBox(height: SogoSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('New to SOGO? ',
                        style: SogoText.bodyMd
                            .copyWith(color: SogoColors.textSecondary)),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const VendorRegisterScreen())),
                      child: Text('Create account',
                          style: SogoText.bodyMd.copyWith(
                              color: SogoColors.primary,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
