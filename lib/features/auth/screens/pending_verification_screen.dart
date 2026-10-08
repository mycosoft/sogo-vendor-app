import 'package:flutter/material.dart';
import '../../../core/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sogo_widgets.dart';
import '../../../shell/app_shell.dart';

/// Step 2 after vendor registration (phone already verified on the
/// previous screen): shows the admin-approval status and unlocks the
/// dashboard the moment the account is approved.
class PendingVerificationScreen extends StatefulWidget {
  const PendingVerificationScreen({super.key, required this.phone});

  final String phone;

  @override
  State<PendingVerificationScreen> createState() =>
      _PendingVerificationScreenState();
}

class _PendingVerificationScreenState extends State<PendingVerificationScreen> {
  bool _checking = false;
  String? _verificationStatus;
  String? _businessName;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _checking = true);
    try {
      final me = await providerApi.me();
      final data = me['data'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _verificationStatus = '${data['verification_status'] ?? 'pending'}';
        _businessName = '${data['business_name'] ?? ''}';
      });
      if (_verificationStatus == 'approved' && mounted) {
        // AppShell owns the bottom navigation - never push HomeScreen alone.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AppShell()),
          (_) => false,
        );
      }
    } catch (_) {
      // keep the screen usable even if the status fetch fails
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _logout() async {
    await authApi.logout();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Logged out. Sign in after your account is approved.')));
  }

  @override
  Widget build(BuildContext context) {
    final rejected = _verificationStatus == 'rejected';

    return WillPopScope(
      onWillPop: () async => false, // must stay until approved
      child: Scaffold(
        backgroundColor: SogoColors.surfaceMuted,
        appBar: AppBar(
            title: const Text('Account status'),
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
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: rejected
                        ? SogoColors.danger.withOpacity(0.12)
                        : SogoColors.warning.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: _checking
                      ? const Center(
                          child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                      : Icon(
                          rejected
                              ? Icons.cancel_rounded
                              : Icons.hourglass_top_rounded,
                          size: 44,
                          color: rejected
                              ? SogoColors.danger
                              : SogoColors.warning),
                ),
                const SizedBox(height: SogoSpacing.lg),
                Text(
                    rejected ? 'Verification declined' : 'Pending verification',
                    style: SogoText.headlineLg),
                const SizedBox(height: SogoSpacing.sm),
                Text(
                  _businessName == null || _businessName!.isEmpty
                      ? 'Your vendor account has been created.'
                      : 'Your vendor account "$_businessName" has been created.',
                  textAlign: TextAlign.center,
                  style:
                      SogoText.bodyMd.copyWith(color: SogoColors.textSecondary),
                ),
                const SizedBox(height: SogoSpacing.md),
                // Phone already verified on the previous screen.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_rounded,
                        size: 18, color: SogoColors.success),
                    const SizedBox(width: 6),
                    Text('Phone verified: ${widget.phone}',
                        style: SogoText.bodySm
                            .copyWith(color: SogoColors.success)),
                  ],
                ),
                const SizedBox(height: SogoSpacing.md),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: rejected
                        ? SogoColors.danger.withOpacity(0.12)
                        : SogoColors.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(SogoRadius.pill),
                  ),
                  child: Text(
                      rejected
                          ? 'NOT APPROVED - CONTACT SUPPORT'
                          : 'AWAITING ADMIN APPROVAL',
                      style: SogoText.labelMd.copyWith(
                          color:
                              rejected ? SogoColors.danger : SogoColors.warning,
                          fontSize: 11)),
                ),
                const SizedBox(height: SogoSpacing.sm),
                Text(
                  rejected
                      ? 'Your account was declined. An admin may add notes - contact SOGO support for details.'
                      : 'You will get an SMS and notification the moment an admin approves your account.',
                  textAlign: TextAlign.center,
                  style:
                      SogoText.bodySm.copyWith(color: SogoColors.textSecondary),
                ),
                const SizedBox(height: SogoSpacing.xl),

                SogoButton(
                    label: 'Check approval status',
                    icon: Icons.refresh_rounded,
                    onPressed: _checking ? null : _loadStatus,
                    loading: _checking),
                const SizedBox(height: SogoSpacing.md),
                TextButton(
                    onPressed: _logout,
                    child: Text('Log out',
                        style: SogoText.bodySm.copyWith(
                            color: SogoColors.textSecondary,
                            fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
