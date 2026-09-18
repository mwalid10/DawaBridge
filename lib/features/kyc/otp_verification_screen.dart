import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../core/l10n_extensions.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_card.dart';
import 'kyc_controller.dart';
import 'kyc_submission.dart';

/// Verifies the email OTP Supabase Auth sends on sign-up, then creates the
/// pharmacy row.
///
/// The original version ran verify -> upload licence -> insert pharmacy as
/// three bare awaits with no rollback and no retry story, so a failure in
/// either of the last two steps stranded a confirmed auth account with no
/// pharmacy and no way back into the app (see `kyc_submission.dart`). The
/// work now lives in `submitPharmacyRegistration`, which is idempotent, and
/// this screen keeps the OTP verification separate from it so a failure
/// *after* the code was accepted doesn't ask the user for a code that has
/// already been consumed — it just retries the profile creation.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _code = TextEditingController();
  bool _verifying = false;
  bool _resending = false;

  /// True once verifyOTP has succeeded. A one-way latch: the code is spent,
  /// so any retry from here must skip straight to profile creation.
  bool _codeAccepted = false;
  String? _error;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    final data = ref.read(kycControllerProvider);
    final l10n = context.l10n;
    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      if (!_codeAccepted) {
        await supabase.auth.verifyOTP(
          type: OtpType.signup,
          email: data.email,
          token: _code.text.trim(),
        );
        _codeAccepted = true;
      }

      await submitPharmacyRegistration(data);

      if (!mounted) return;
      ref.read(kycControllerProvider.notifier).reset();
      context.go('/account-status');
    } catch (error) {
      // Was `_error = e.toString()`, which put raw PostgrestException /
      // StorageException text — untranslated, with internal detail — in
      // front of the pharmacist.
      if (mounted) setState(() => _error = AppError.message(l10n, error));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// There was no way to ask for another code. If the first email didn't
  /// arrive the screen was a dead end — the account existed but couldn't be
  /// confirmed, and starting over hit "User already registered".
  Future<void> _resend() async {
    final data = ref.read(kycControllerProvider);
    final l10n = context.l10n;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await supabase.auth.resend(type: OtpType.signup, email: data.email);
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.kycOtpResent)));
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(l10n, error));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final email = ref.watch(kycControllerProvider).email;
    final canResend = !_resending && !_verifying && _resendCooldown == 0;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.kycVerifyEmailTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                  child: const Icon(Icons.mail_outline_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.kycOtpBody(email), style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  enabled: !_codeAccepted,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 8),
                  decoration: InputDecoration(labelText: l10n.kycOtpLabel, counterText: ''),
                ),
                if (_codeAccepted) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.kycOtpAcceptedRetry,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warn),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
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
                ],
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: _verifying ? null : _verify,
                  child: _verifying
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_codeAccepted ? l10n.commonRetry : l10n.kycVerifyAndSubmit),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: canResend ? _resend : null,
                  child: Text(
                    _resendCooldown > 0 ? l10n.kycOtpResendIn(_resendCooldown) : l10n.kycOtpResend,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
