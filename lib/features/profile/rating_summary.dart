/// Row shape returned by the `get_my_rating_summary` RPC. Always exactly
/// one row — averages are null and count is 0 when the caller has no
/// ratings yet, rather than the RPC returning no rows at all.
class RatingSummary {
  final double? avgStars;
  final int count;
  final double? avgCredibility;
  final double? avgResponsiveness;
  final double? avgPackaging;

  const RatingSummary({
    required this.avgStars,
    required this.count,
    required this.avgCredibility,
    required this.avgResponsiveness,
    required this.avgPackaging,
  });

  factory RatingSummary.fromJson(Map<String, dynamic> json) {
    return RatingSummary(
      avgStars: (json['avg_stars'] as num?)?.toDouble(),
      count: json['rating_count'] as int,
      avgCredibility: (json['avg_credibility'] as num?)?.toDouble(),
      avgResponsiveness: (json['avg_responsiveness'] as num?)?.toDouble(),
      avgPackaging: (json['avg_packaging'] as num?)?.toDouble(),
    );
  }
}
