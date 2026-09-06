/// Row shape for `global_price_alerts` joined to `drugs` — admin-curated,
/// market-wide price increases (not derived from any pharmacy's own
/// listing history). Drives the Home screen's "Price increased" row.
class PriceIncreasedListing {
  final String id;
  final String tradeName;
  final String? concentration;
  final double oldPrice;
  final double newPrice;
  final double pctIncrease;
  final String? note;

  const PriceIncreasedListing({
    required this.id,
    required this.tradeName,
    required this.concentration,
    required this.oldPrice,
    required this.newPrice,
    required this.pctIncrease,
    required this.note,
  });

  factory PriceIncreasedListing.fromJson(Map<String, dynamic> json) {
    final oldPrice = (json['old_price'] as num).toDouble();
    final newPrice = (json['new_price'] as num).toDouble();
    return PriceIncreasedListing(
      id: json['id'] as String,
      tradeName: (json['drugs'] as Map<String, dynamic>)['trade_name'] as String,
      concentration: (json['drugs'] as Map<String, dynamic>)['concentration'] as String?,
      oldPrice: oldPrice,
      newPrice: newPrice,
      pctIncrease: ((newPrice - oldPrice) / oldPrice) * 100,
      note: json['note'] as String?,
    );
  }
}
