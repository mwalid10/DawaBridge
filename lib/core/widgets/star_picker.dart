import 'package:flutter/material.dart';

import '../theme.dart';

/// Interactive 1-5 star picker (tap a star to set the value). Used by the
/// post-deal rating sheet; see [StarDisplay] for the read-only variant.
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onChanged, this.size = 32});

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < value;
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: size + 8, height: size + 8),
          icon: Icon(filled ? Icons.star_rounded : Icons.star_border_rounded, size: size, color: AppColors.creamDark),
          onPressed: () => onChanged(i + 1),
        );
      }),
    );
  }
}

/// Read-only star row for showing an average rating (rounds to the
/// nearest whole star; a fractional icon isn't worth the complexity here).
class StarDisplay extends StatelessWidget {
  const StarDisplay({super.key, required this.value, this.size = 18});

  final double value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final rounded = value.round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rounded ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: AppColors.creamDark,
        ),
      ),
    );
  }
}
