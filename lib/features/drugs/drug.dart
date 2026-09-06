/// Reference drug data — public read-only table, seeded via migration.
class Drug {
  final String id;
  final String tradeName;
  final String? activeIngredient;
  final String? concentration;
  final String? company;
  final String? pharmaceuticalForm;
  final bool isControlled;

  const Drug({
    required this.id,
    required this.tradeName,
    this.activeIngredient,
    this.concentration,
    this.company,
    this.pharmaceuticalForm,
    required this.isControlled,
  });

  factory Drug.fromJson(Map<String, dynamic> json) {
    return Drug(
      id: json['id'] as String,
      tradeName: json['trade_name'] as String,
      activeIngredient: json['active_ingredient'] as String?,
      concentration: json['concentration'] as String?,
      company: json['company'] as String?,
      pharmaceuticalForm: json['pharmaceutical_form'] as String?,
      isControlled: json['is_controlled'] as bool,
    );
  }
}
