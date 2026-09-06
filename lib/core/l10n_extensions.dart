import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

/// Shorthand for `AppLocalizations.of(context)!` — safe to force-unwrap
/// since [AppLocalizations.delegate] is always registered in main.dart, so
/// `of()` only returns null above the MaterialApp itself.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
