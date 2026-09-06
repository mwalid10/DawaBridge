import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n_extensions.dart';
import '../../../core/theme.dart';
import '../kyc_controller.dart';
import '../widgets/kyc_step_header.dart';

class PharmacyDetailsStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  const PharmacyDetailsStep({super.key, required this.onNext});

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
    _emailController = TextEditingController(text: data.email);
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
            decoration: InputDecoration(labelText: l10n.fieldEmailAddress, hintText: l10n.kycEmailHint),
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
