/// Row shape returned by the `get_my_home_stats` RPC — the header stat
/// chips (active listings, completed exchanges) on the Home dashboard.
class HomeStats {
  final int activeListings;
  final int completedExchanges;

  const HomeStats({required this.activeListings, required this.completedExchanges});

  factory HomeStats.fromJson(Map<String, dynamic> json) {
    return HomeStats(
      activeListings: json['active_listings'] as int,
      completedExchanges: json['completed_exchanges'] as int,
    );
  }
}
