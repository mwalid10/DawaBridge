import 'package:flutter/material.dart';

import 'kyc_wizard_screen.dart';

/// `/register/complete` — the way back for an account that has a confirmed
/// auth user but no `pharmacies` row.
///
/// This happens when the old registration flow died between verifying the
/// OTP and inserting the pharmacy (see `kyc_submission.dart` for why that
/// was possible). Such an account previously had no route out at all: the
/// splash sent it to `/home`, where everything keyed on the pharmacy row
/// threw, and signing up again was rejected as an existing user.
///
/// It's the same wizard, in recovery mode — no point maintaining a second
/// copy of the address picker and licence upload.
class CompleteRegistrationScreen extends StatelessWidget {
  const CompleteRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) => const KycWizardScreen(recovery: true);
}
