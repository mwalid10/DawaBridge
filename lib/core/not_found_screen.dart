import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'l10n_extensions.dart';
import 'theme.dart';
import 'widgets/app_gradient_button.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(color: AppColors.creamSoft, shape: BoxShape.circle),
                child: const Icon(Icons.explore_off_outlined, size: 48, color: AppColors.primaryDark),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(l10n.notFoundTitle, style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.notFoundBody,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              AppGradientButton(onPressed: () => context.go('/home'), child: Text(l10n.notFoundGoHome)),
            ],
          ),
        ),
      ),
    );
  }
}
