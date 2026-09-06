/// One row from the `drug_catalog` reference table (~23,600 entries,
/// imported from Egypt's public drug registry) — search-only, never
/// fetched in full. Distinct from [Drug]: this is catalog lookup data, not
/// yet a real listable product until [AddMedicineController.selectCatalogEntry]
/// resolves it to a `drugs` row via `find_or_create_drug`.
class DrugCatalogEntry {
  final String id;
  final String tradeName;
  final String? concentration;
  final String? company;
  final String? pharmaceuticalForm;
  final String displayName;

  const DrugCatalogEntry({
    required this.id,
    required this.tradeName,
    this.concentration,
    this.company,
    this.pharmaceuticalForm,
    required this.displayName,
  });

  factory DrugCatalogEntry.fromJson(Map<String, dynamic> json) {
    return DrugCatalogEntry(
      id: json['id'] as String,
      tradeName: json['trade_name'] as String,
      concentration: json['concentration'] as String?,
      company: json['company'] as String?,
      pharmaceuticalForm: json['pharmaceutical_form'] as String?,
      displayName: json['display_name'] as String,
    );
  }
}
