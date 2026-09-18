import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_error.dart';
import '../../core/l10n_extensions.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_gradient_button.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_hero_background.dart';

const _rememberedEmailKey = 'remembered_email';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _rememberMe = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_rememberedEmailKey);
    if (saved != null && mounted) {
      setState(() {
        _email.text = saved;
        _rememberMe = true;
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final l10n = context.l10n;

    // Both fields went unchecked, so tapping Sign in with an empty form
    // made a pointless round trip and came back with the same opaque
    // "couldn't sign in" as a wrong password.
    final email = _email.text.trim();
    if (email.isEmpty || !_emailPattern.hasMatch(email)) {
      setState(() => _error = l10n.loginInvalidEmail);
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = l10n.loginPasswordRequired);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await supabase.auth.signInWithPassword(email: email, password: _password.text);
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString(_rememberedEmailKey, email);
      } else {
        await prefs.remove(_rememberedEmailKey);
      }
      // Where to go next is the router's call now — it resolves the
      // session's role and KYC status first. Sending everyone straight to
      // /home here is what let unapproved pharmacies into the marketplace.
    } catch (error) {
      // Every failure used to collapse into one generic string, so "email
      // not confirmed", "rate limited" and "no internet" were
      // indistinguishable to the user and to support.
      if (mounted) setState(() => _error = AppError.message(l10n, error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final l10n = context.l10n;
    final emailController = TextEditingController(text: _email.text.trim());
    try {
      final sent = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.loginResetTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.loginResetBody),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.fieldEmailAddress),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.commonCancel)),
            // The enabled state used to be computed once, at build time,
            // from `emailController.text`. Nothing rebuilt the dialog when
            // the user typed — so opening this without an email already
            // filled in on the login screen left Send permanently greyed
            // out no matter what was entered. ValueListenableBuilder makes
            // it track the field.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: emailController,
              builder: (context, value, _) => FilledButton(
                onPressed: _emailPattern.hasMatch(value.text.trim())
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: Text(l10n.loginSendLink),
              ),
            ),
          ],
        ),
      );
      if (sent != true || !mounted) return;

      final target = emailController.text.trim();
      await supabase.auth.resetPasswordForEmail(
        target,
        // Without this the link in the email goes to the project's Site URL
        // — a web address, localhost by default — so the reset simply never
        // reached the app. The scheme is registered in AndroidManifest.xml
        // and Info.plist.
        redirectTo: 'io.pharmaexchange.egypt://reset-password',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.loginResetSent(target))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppError.message(l10n, error))),
      );
    } finally {
      // Was never disposed — one leaked controller per tap of "Forgot
      // password".
      emailController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                      // Solid white, not the translucent badge that held the
                      // old generic pharmacy glyph — the DawaBridge mark is
                      // a green gradient and disappears against the green
                      // hero unless it sits on its own light ground.
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: const [
                            BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Image.asset('assets/branding/logo.png', width: 64, fit: BoxFit.contain),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        l10n.loginWelcomeBack,
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.loginSubtitle,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 300.ms),
            Transform.translate(
              offset: const Offset(0, -44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GlassCard(
                  blurred: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: l10n.fieldEmailAddress,
                          prefixIcon: const Icon(Icons.mail_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: l10n.fieldPassword,
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 4,
                        children: [
                          InkWell(
                            onTap: () => setState(() => _rememberMe = !_rememberMe),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _rememberMe,
                                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(l10n.loginRememberMe, style: Theme.of(context).textTheme.bodyMedium),
                                ],
                              ),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _forgotPassword,
                            child: Text(l10n.loginForgotPassword),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.sm),
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
                      AppGradientButton(
                        onPressed: _loading ? null : _signIn,
                        isLoading: _loading,
                        child: Text(l10n.loginSignIn),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: () => context.push('/register'),
                        child: Text(l10n.loginRegisterCta),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
