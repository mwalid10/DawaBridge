import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import 'price_increased_listing.dart';

/// Admin-curated, market-wide drug price increases (`global_price_alerts`)
/// for the Home screen's "Price increased" row — independent of any
/// pharmacy's own listings. Small, unpaginated — same one-shot fetch shape
/// as DrugsController.
class PriceIncreasedController extends AsyncNotifier<List<PriceIncreasedListing>> {
  @override
  Future<List<PriceIncreasedListing>> build() async {
    final rows = await supabase
        .from('global_price_alerts')
        .select('id, old_price, new_price, note, drugs(trade_name, concentration)')
        .eq('is_active', true)
        .order('effective_date', ascending: false)
        .limit(10);
    return (rows as List<dynamic>)
        .map((row) => PriceIncreasedListing.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}

final priceIncreasedControllerProvider =
    AsyncNotifierProvider<PriceIncreasedController, List<PriceIncreasedListing>>(PriceIncreasedController.new);
