import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n_extensions.dart';
import '../../../core/theme.dart';
import '../kyc_controller.dart';
import '../widgets/kyc_step_header.dart';

class PasswordStep extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final Future<void> Function() onSubmit;
  const PasswordStep({super.key, required this.onBack, required this.onSubmit});

  @override
  ConsumerState<PasswordStep> createState() => _PasswordStepState();
}

class _PasswordStepState extends ConsumerState<PasswordStep> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    ref.read(kycControllerProvider.notifier).updatePassword(_password.text);
    if (!ref.read(kycControllerProvider).passwordValid(_confirm.text)) {
      setState(() => _error = l10n.kycPasswordMismatch);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        KycStepHeader(
          icon: Icons.lock_rounded,
          title: l10n.kycSetPassword,
          subtitle: l10n.kycPasswordSubtitle,
        ),
        const SizedBox(height: AppSpacing.xl),
        TextFormField(
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(labelText: l10n.fieldPassword),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _confirm,
          obscureText: true,
          decoration: InputDecoration(labelText: l10n.fieldConfirmPassword),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Text(_error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger)),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: _submitting ? null : widget.onBack, child: Text(l10n.commonBack))),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(l10n.kycSubmitForReview),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
