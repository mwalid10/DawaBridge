import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_extensions.dart';
import '../../core/supabase_client.dart';
import '../../core/widgets/step_progress_bar.dart';
import 'kyc_controller.dart';
import 'steps/address_step.dart';
import 'steps/license_step.dart';
import 'steps/password_step.dart';
import 'steps/pharmacy_details_step.dart';

class KycWizardScreen extends ConsumerStatefulWidget {
  const KycWizardScreen({super.key});

  @override
  ConsumerState<KycWizardScreen> createState() => _KycWizardScreenState();
}

class _KycWizardScreenState extends ConsumerState<KycWizardScreen> {
  final _pageController = PageController();
  int _step = 0;

  void _goTo(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(step, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _submitRegistration() async {
    final data = ref.read(kycControllerProvider);
    // Supabase sends a "Confirm signup" email automatically on email
    // sign-up. By default that email only carries a magic link — for the
    // 6-digit code entry screen this wizard uses next, the project's
    // Authentication -> Email Templates -> "Confirm signup" template must
    // include {{ .Token }} (Supabase's email-OTP mechanism), not just
    // {{ .ConfirmationURL }}.
    await supabase.auth.signUp(email: data.email, password: data.password);
    if (mounted) context.push('/register/otp');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stepLabels = [l10n.kycStepPharmacy, l10n.kycStepAddress, l10n.kycStepLicense, l10n.kycStepPassword];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.kycRegisterTitle),
        leading: _step == 0
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => _goTo(_step - 1)),
      ),
      body: Column(
        children: [
          StepProgressBar(labels: stepLabels, currentStep: _step),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                PharmacyDetailsStep(onNext: () => _goTo(1)),
                AddressStep(onNext: () => _goTo(2), onBack: () => _goTo(0)),
                LicenseStep(onNext: () => _goTo(3), onBack: () => _goTo(1)),
                PasswordStep(onBack: () => _goTo(2), onSubmit: _submitRegistration),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
