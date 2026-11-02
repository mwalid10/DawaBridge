import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// What kind of business an account is — `pharmacies.account_type` in the
/// database (migration 0045).
///
/// The marketplace launched pharmacy-only, which is why the table, the
/// foreign keys and half the RPC parameter names still say "pharmacy": a
/// warehouse is a second kind of account on the same row shape, not a
/// separate entity. Both register, get approved, list, deal, chat and are
/// rated identically; the type only changes wording and gives search
/// something to filter on.
enum AccountType {
  pharmacy,
  warehouse;

  /// Tolerant by design, unlike the other enums parsed off an RPC row.
  ///
  /// Rows cached offline before 0045 shipped have no `account_type` key at
  /// all, and `byName(null)` on one of those would throw inside
  /// `fromJson` — turning a stale cache entry into a broken screen. Every
  /// account that predates the column is a pharmacy, so that's the fallback.
  static AccountType fromString(String? value) => switch (value) {
        'warehouse' => AccountType.warehouse,
        _ => AccountType.pharmacy,
      };

  String label(AppLocalizations l10n) => switch (this) {
        AccountType.pharmacy => l10n.accountTypePharmacy,
        AccountType.warehouse => l10n.accountTypeWarehouse,
      };

  IconData get icon => switch (this) {
        AccountType.pharmacy => Icons.storefront_rounded,
        AccountType.warehouse => Icons.warehouse_rounded,
      };

  bool get isWarehouse => this == AccountType.warehouse;
}
