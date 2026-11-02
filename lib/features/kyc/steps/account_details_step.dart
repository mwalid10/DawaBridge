import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/account_type.dart';
import '../../../core/l10n_extensions.dart';
import '../../../core/supabase_client.dart';
import '../../../core/theme.dart';
import '../kyc_controller.dart';
import '../widgets/kyc_step_header.dart';

/// First wizard step: what kind of account this is, then its name and email.
///
/// The type comes first because everything after it is worded from it — the
/// wizard's own title and step labels, the name field, the map pin's
/// instructions, the licence prompt. It is committed to the controller on tap
/// rather than on Continue so all of that updates as soon as it's picked,
/// instead of one step later.
class AccountDetailsStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  /// Recovery mode: the email belongs to an auth account that already
  /// exists, so it is shown for confirmation but can't be edited.
  final bool emailLocked;

  const AccountDetailsStep({super.key, required this.onNext, this.emailLocked = false});

  @override
  ConsumerState<AccountDetailsStep> createState() => _AccountDetailsStepState();
}

class _AccountDetailsStepState extends ConsumerState<AccountDetailsStep> {
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
    final accountType = ref.watch(kycControllerProvider).accountType;
    final isWarehouse = accountType.isWarehouse;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          KycStepHeader(
            icon: accountType.icon,
            title: isWarehouse ? l10n.kycWarehouseDetailsTitle : l10n.kycPharmacyDetailsTitle,
            subtitle: l10n.kycPharmacyDetailsSubtitle,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.kycAccountTypeLabel,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final type in AccountType.values) ...[
            _AccountTypeOption(
              type: type,
              selected: type == accountType,
              blurb: switch (type) {
                AccountType.pharmacy => l10n.kycAccountTypePharmacyBlurb,
                AccountType.warehouse => l10n.kycAccountTypeWarehouseBlurb,
              },
              onTap: () => ref.read(kycControllerProvider.notifier).setAccountType(type),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: isWarehouse ? l10n.fieldWarehouseName : l10n.fieldPharmacyName,
            ),
            validator: (v) => (v == null || v.trim().length < 3)
                ? (isWarehouse ? l10n.kycWarehouseNameValidator : l10n.kycPharmacyNameValidator)
                : null,
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

/// One full-width tile in the account-type picker. Stacked rather than
/// side-by-side: the two blurbs don't fit a half-width card at Arabic text
/// metrics, and a Row of icon-then-text mirrors itself in RTL for free.
class _AccountTypeOption extends StatelessWidget {
  const _AccountTypeOption({
    required this.type,
    required this.selected,
    required this.blurb,
    required this.onTap,
  });

  final AccountType type;
  final bool selected;
  final String blurb;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: selected ? AppGradients.cream : null,
          color: selected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? AppShadows.card : null,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(type.icon, color: selected ? Colors.white : AppColors.primary, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.label(l10n),
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.ink,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  Text(blurb, style: textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.primary : AppColors.inkFaint,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
