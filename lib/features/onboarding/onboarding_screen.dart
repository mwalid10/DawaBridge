import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n_extensions.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_gradient_button.dart';
import '../../l10n/app_localizations.dart';

class _Slide {
  final IconData icon;
  final IconData accentA;
  final IconData accentB;
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations) body;
  const _Slide(this.icon, this.accentA, this.accentB, this.title, this.body);
}

const _slides = [
  _Slide(
    Icons.inventory_2_rounded,
    Icons.schedule_rounded,
    Icons.trending_down_rounded,
    _slide1Title,
    _slide1Body,
  ),
  _Slide(
    Icons.swap_horiz_rounded,
    Icons.storefront_rounded,
    Icons.sell_rounded,
    _slide2Title,
    _slide2Body,
  ),
  _Slide(
    Icons.verified_user_rounded,
    Icons.local_pharmacy_rounded,
    Icons.shield_rounded,
    _slide3Title,
    _slide3Body,
  ),
];

String _slide1Title(AppLocalizations l10n) => l10n.onboardSlide1Title;
String _slide1Body(AppLocalizations l10n) => l10n.onboardSlide1Body;
String _slide2Title(AppLocalizations l10n) => l10n.onboardSlide2Title;
String _slide2Body(AppLocalizations l10n) => l10n.onboardSlide2Body;
String _slide3Title(AppLocalizations l10n) => l10n.onboardSlide3Title;
String _slide3Body(AppLocalizations l10n) => l10n.onboardSlide3Body;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isLast = _index == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 4),
                        width: 24,
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          color: i <= _index ? AppColors.primary : AppColors.divider,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text(l10n.onboardSkip),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _OnboardSlide(slide: _slides[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.all(4),
                  width: i == _index ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    gradient: i == _index ? AppGradients.cta : null,
                    color: i == _index ? null : AppColors.divider,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: AppGradientButton(
                onPressed: isLast
                    ? () => context.go('/login')
                    : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                        ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isLast ? l10n.onboardGetStarted : l10n.onboardNext),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardSlide extends StatelessWidget {
  const _OnboardSlide({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = slide.title(l10n);
    final body = slide.body(l10n);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        children: [
          Expanded(flex: 5, child: _HeroArt(slide: slide)),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ).animate(key: ValueKey('t$title')).fadeIn(duration: 350.ms).slideY(begin: 0.15, end: 0),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ).animate(key: ValueKey('b$title')).fadeIn(duration: 400.ms, delay: 80.ms),
        ],
      ),
    );
  }
}

/// A layered gradient "illustration" panel: a hero-gradient card with soft
/// translucent blobs and two small accent-icon badges framing a central
/// glass icon badge, so each slide reads as custom artwork rather than a
/// single flat icon.
class _HeroArt extends StatelessWidget {
  const _HeroArt({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: AppGradients.hero,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(top: -30, left: -30, child: _blob(120)),
          Positioned(bottom: -46, right: -26, child: _blob(170)),
          Positioned(top: 24, right: 24, child: _accentBadge(slide.accentA)),
          Positioned(bottom: 28, left: 24, child: _accentBadge(slide.accentB)),
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.32), width: 1.5),
            ),
            child: Icon(slide.icon, size: 56, color: Colors.white),
          ).animate(key: ValueKey('i${slide.icon.codePoint}')).fadeIn(duration: 350.ms).scale(begin: const Offset(0.85, 0.85)),
        ],
      ),
    );
  }

  Widget _blob(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
      );

  Widget _accentBadge(IconData icon) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.22)),
        child: Icon(icon, size: 18, color: Colors.white),
      );
}
