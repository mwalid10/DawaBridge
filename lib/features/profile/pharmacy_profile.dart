import '../../l10n/app_localizations.dart';

enum PlanStatus {
  trial,
  free,
  active;

  static PlanStatus fromString(String value) => PlanStatus.values.byName(value);

  String label(AppLocalizations l10n) => switch (this) {
        PlanStatus.trial => l10n.planTrial,
        PlanStatus.free => l10n.planFree,
        PlanStatus.active => l10n.planActive,
      };
}

/// The signed-in pharmacy's own row from `pharmacies` — readable in full
/// under the "pharmacies read/update own row" RLS policy from 0001_init.sql
/// (owner-only), so this is a direct table read, no RPC needed.
class PharmacyProfile {
  final String name;
  final String email;
  final String? phone;
  final String governorate;
  final String area;
  final String addressText;
  final PlanStatus plan;
  final DateTime? trialEndsAt;

  const PharmacyProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.governorate,
    required this.area,
    required this.addressText,
    required this.plan,
    required this.trialEndsAt,
  });

  factory PharmacyProfile.fromJson(Map<String, dynamic> json) {
    return PharmacyProfile(
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      governorate: json['governorate'] as String,
      area: json['area'] as String,
      addressText: json['address_text'] as String,
      plan: PlanStatus.fromString(json['plan'] as String),
      trialEndsAt: json['trial_ends_at'] == null ? null : DateTime.parse(json['trial_ends_at'] as String),
    );
  }
}
