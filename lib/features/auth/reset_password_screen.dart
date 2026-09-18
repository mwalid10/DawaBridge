import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../core/l10n_extensions.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_gradient_button.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_hero_background.dart';
import '../../l10n/app_localizations.dart';

/// Where the "reset your password" email lands.
///
/// Password reset was previously broken end to end on mobile:
/// `resetPasswordForEmail` was called with no `redirectTo`, so the link in
/// the email pointed at the project's Supabase Site URL (a web address, by
/// default localhost) rather than back into the app — and even if it had
/// pointed at the app, nothing listened for `AuthChangeEvent
/// .passwordRecovery` and there was no screen to set a new password on. A
/// user who forgot their password had no way to recover their account.
///
/// `main.dart` now listens for the recovery event and routes here; the deep
/// link itself is registered in AndroidManifest.xml and Info.plist.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await supabase.auth.updateUser(UserAttributes(password: _password.text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.resetPasswordDone)));
      // The recovery session is a real session; the router's redirect will
      // place them correctly once it re-resolves.
      context.go('/');
    } catch (error) {
      if (mounted) setState(() => _error = AppError.message(l10n, error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasSession = supabase.auth.currentSession != null;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GradientHeroBackground(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 72),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.32), width: 1.5),
                        ),
                        child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        l10n.resetPasswordTitle,
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(l10n.resetPasswordSubtitle, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GlassCard(
                  blurred: true,
                  child: !hasSession
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(l10n.resetPasswordLinkExpired, style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: AppSpacing.lg),
                            AppGradientButton(
                              onPressed: () => context.go('/login'),
                              child: Text(l10n.resetPasswordBackToSignIn),
                            ),
                          ],
                        )
                      : Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _password,
                                obscureText: _obscure,
                                decoration: InputDecoration(
                                  labelText: l10n.resetPasswordNew,
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                validator: (v) => _validatePassword(v, l10n),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              TextFormField(
                                controller: _confirm,
                                obscureText: _obscure,
                                decoration: InputDecoration(
                                  labelText: l10n.resetPasswordConfirm,
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                ),
                                validator: (v) =>
                                    v != _password.text ? l10n.resetPasswordMismatch : null,
                              ),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.danger),
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.lg),
                              AppGradientButton(
                                onPressed: _saving ? null : _save,
                                isLoading: _saving,
                                child: Text(l10n.resetPasswordSave),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Same rule the registration wizard applies (see `KycData.passwordValid`)
  /// so a password accepted here can't be weaker than one accepted there.
  String? _validatePassword(String? value, AppLocalizations l10n) {
    final v = value ?? '';
    final ok = v.length >= 8 &&
        v.contains(RegExp(r'[A-Z]')) &&
        v.contains(RegExp(r'[0-9]')) &&
        v.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    return ok ? null : l10n.resetPasswordRule;
  }
}
