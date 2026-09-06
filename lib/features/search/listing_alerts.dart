import '../../core/supabase_client.dart';

/// "Notify me when available" — inserts directly into `listing_alerts`
/// under its owner-scoped RLS policy (0013_notify_me_subscriptions.sql),
/// same direct-insert convention as messages. Matching against future
/// listings happens server-side via a trigger.
Future<void> subscribeToListingAlert({
  required String tradeName,
  String? activeIngredient,
  String? governorate,
}) async {
  await supabase.from('listing_alerts').insert({
    'pharmacy_id': supabase.auth.currentUser!.id,
    'trade_name': tradeName,
    'active_ingredient': activeIngredient,
    'governorate': governorate,
  });
}
