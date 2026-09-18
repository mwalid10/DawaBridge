import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error.dart';
import '../../core/l10n_extensions.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/step_progress_bar.dart';
import 'kyc_controller.dart';
import 'kyc_submission.dart';
import 'steps/address_step.dart';
import 'steps/license_step.dart';
import 'steps/password_step.dart';
import 'steps/pharmacy_details_step.dart';

class KycWizardScreen extends ConsumerStatefulWidget {
  const KycWizardScreen({super.key, this.recovery = false});

  /// Recovery mode: the auth account already exists (and is signed in) but
  /// has no `pharmacies` row — the orphaned-registration case described in
  /// `kyc_submission.dart`. The email/password steps are skipped because
  /// there's nothing left to sign up for; the wizard just re-collects the
  /// pharmacy details and licence and calls the same idempotent RPC.
  final bool recovery;

  @override
  ConsumerState<KycWizardScreen> createState() => _KycWizardScreenState();
}

class _KycWizardScreenState extends ConsumerState<KycWizardScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _submitting = false;
  String? _error;

  void _goTo(int step) {
    setState(() {
      _step = step;
      _error = null;
    });
    _pageController.animateToPage(step, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _signUp() async {
    final data = ref.read(kycControllerProvider);
    setState(() {
      _submitting = true;
      _error = null;
    });
    final l10n = context.l10n;
    try {
      // Supabase sends a "Confirm signup" email automatically on email
      // sign-up. By default that email only carries a magic link — for the
      // 6-digit code entry screen this wizard uses next, the project's
      // Authentication -> Email Templates -> "Confirm signup" template must
      // include {{ .Token }} (Supabase's email-OTP mechanism), not just
      // {{ .ConfirmationURL }}.
      await supabase.auth.signUp(email: data.email, password: data.password);
      if (mounted) context.push('/register/otp');
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(l10n, error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Recovery mode's terminal step — no sign-up, no OTP, straight to
  /// creating the pharmacy row for the session that already exists.
  Future<void> _submitRecovery() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final l10n = context.l10n;
    try {
      await submitPharmacyRegistration(ref.read(kycControllerProvider));
      if (!mounted) return;
      ref.read(kycControllerProvider.notifier).reset();
      // The router's redirect takes it from here based on the refreshed
      // session state ('pending' -> /account-status).
      context.go('/account-status');
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(l10n, error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stepLabels = widget.recovery
        ? [l10n.kycStepPharmacy, l10n.kycStepAddress, l10n.kycStepLicense]
        : [l10n.kycStepPharmacy, l10n.kycStepAddress, l10n.kycStepLicense, l10n.kycStepPassword];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recovery ? l10n.kycFinishSetupTitle : l10n.kycRegisterTitle),
        leading: _step == 0
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => _goTo(_step - 1)),
      ),
      body: Column(
        children: [
          if (widget.recovery)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warnBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                l10n.kycFinishSetupBody,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warn),
              ),
            ),
          StepProgressBar(labels: stepLabels, currentStep: _step),
          if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
            ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                PharmacyDetailsStep(onNext: () => _goTo(1), emailLocked: widget.recovery),
                AddressStep(onNext: () => _goTo(2), onBack: () => _goTo(0)),
                LicenseStep(
                  onNext: widget.recovery ? _submitRecovery : () => _goTo(3),
                  onBack: () => _goTo(1),
                  submitting: widget.recovery && _submitting,
                  isFinalStep: widget.recovery,
                ),
                if (!widget.recovery) PasswordStep(onBack: () => _goTo(2), onSubmit: _signUp),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
