import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n_extensions.dart';
import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../kyc_controller.dart';
import '../widgets/kyc_step_header.dart';

class PharmacyDetailsStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  /// Recovery mode: the email belongs to an auth account that already
  /// exists, so it is shown for confirmation but can't be edited.
  final bool emailLocked;

  const PharmacyDetailsStep({super.key, required this.onNext, this.emailLocked = false});

  @override
  ConsumerState<PharmacyDetailsStep> createState() => _PharmacyDetailsStepState();
}

class _PharmacyDetailsStepState extends ConsumerState<PharmacyDetailsStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final data = ref.read(kycControllerProvider);
    _nameController = TextEditingController(text: data.pharmacyName);
    // In recovery mode the authoritative email is the signed-in auth
    // user's, not whatever is left in the wizard's transient state.
    _emailController = TextEditingController(
      text: widget.emailLocked ? (supabase.auth.currentUser?.email ?? data.email) : data.email,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(kycControllerProvider.notifier).updatePharmacyDetails(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
        );
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          KycStepHeader(
            icon: Icons.storefront_rounded,
            title: l10n.kycPharmacyDetailsTitle,
            subtitle: l10n.kycPharmacyDetailsSubtitle,
          ),
          const SizedBox(height: AppSpacing.xxl),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(labelText: l10n.fieldPharmacyName),
            validator: (v) => (v == null || v.trim().length < 3) ? l10n.kycPharmacyNameValidator : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            readOnly: widget.emailLocked,
            enabled: !widget.emailLocked,
            decoration: InputDecoration(
              labelText: l10n.fieldEmailAddress,
              hintText: widget.emailLocked ? null : l10n.kycEmailHint,
            ),
            validator: (v) {
              if (v == null || !v.contains('@') || !v.contains('.')) {
                return l10n.kycEmailValidator;
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.xxxl),
          ElevatedButton(onPressed: _submit, child: Text(l10n.commonContinue)),
        ],
      ),
    );
  }
}
