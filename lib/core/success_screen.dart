import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'l10n_extensions.dart';
import 'theme.dart';
import 'widgets/app_gradient_button.dart';

/// Args for [SuccessScreen], passed via `GoRouterState.extra`
/// (`context.push('/success', extra: SuccessArgs(...))`).
class SuccessArgs {
  final String? title;
  final String? message;
  final String? ctaLabel;

  /// Null means "just go home" — see [SuccessArgs.generic].
  final VoidCallback? onCta;

  const SuccessArgs({this.title, this.message, this.ctaLabel, this.onCta});

  /// Fallback for when `/success` is reached without live `extra`: a deep
  /// link, or Android rebuilding the route after the process was killed.
  /// The router used to hard-cast `state.extra as SuccessArgs`, which threw
  /// a TypeError on exactly those paths instead of showing a screen.
  const SuccessArgs.generic()
      : title = null,
        message = null,
        ctaLabel = null,
        onCta = null;
}

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({super.key, required this.args});

  final SuccessArgs args;

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {
  late final _confettiController = ConfettiController(duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle_rounded, size: 48, color: AppColors.primary),
                  ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.85, 0.85)),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    widget.args.title ?? context.l10n.successGenericTitle,
                    style: Theme.of(context).textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.args.message ?? context.l10n.successGenericBody,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  AppGradientButton(
                    onPressed: widget.args.onCta ?? () => context.go('/home'),
                    child: Text(widget.args.ctaLabel ?? context.l10n.successGenericCta),
                  ),
                ],
              ),
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [AppColors.primary, AppColors.primaryLight, AppColors.creamDark, AppColors.cream],
          ),
        ],
      ),
    );
  }
}
