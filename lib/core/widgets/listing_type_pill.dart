import 'package:flutter/material.dart';

import '../l10n_extensions.dart';
import '../theme.dart';

enum ListingTypePillKind { sell, buy, barter }

/// Small badge for a listing's sell/buy/barter type. Kept separate from
/// [StatusPill] — that widget's pending/approved/rejected kinds encode KYC
/// status semantics with a warn/good/danger scheme that doesn't map onto
/// listing types.
class ListingTypePill extends StatelessWidget {
  const ListingTypePill({super.key, required this.kind});

  final ListingTypePillKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, fg, bg) = switch (kind) {
      ListingTypePillKind.sell => (l10n.listingTypeSell, AppColors.primaryDark, AppColors.primarySoft),
      ListingTypePillKind.buy => (l10n.listingTypeBuy, AppColors.ink, AppColors.creamSoft),
      ListingTypePillKind.barter => (l10n.listingTypeExchange, AppColors.warn, AppColors.warnBg),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
