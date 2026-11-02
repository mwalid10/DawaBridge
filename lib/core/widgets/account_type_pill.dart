import 'package:flutter/material.dart';

import '../account_type.dart';
import '../l10n_extensions.dart';
import '../theme.dart';

/// Small badge naming the account behind a listing, a deal or a chat.
///
/// Separate from [ListingTypePill] because the two sit side by side and
/// answer different questions — that one is "is this for sale or wanted",
/// this one is "who is offering it". Warehouse takes the cream accent so it
/// reads as the exception; pharmacy, which is the overwhelming majority of
/// accounts, stays neutral and recedes.
class AccountTypePill extends StatelessWidget {
  const AccountTypePill({super.key, required this.type, this.dense = false});

  final AccountType type;

  /// Icon-and-label without the horizontal padding, for dense rows like a
  /// listing card's title line.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (fg, bg) = switch (type) {
      AccountType.warehouse => (AppColors.warn, AppColors.warnBg),
      AccountType.pharmacy => (AppColors.inkSoft, AppColors.creamSoft),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? AppSpacing.sm : AppSpacing.md, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            type.label(l10n),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
