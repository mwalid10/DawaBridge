import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/egypt_governorates.dart';
import '../../core/l10n_extensions.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_gradient_button.dart';
import 'pharmacy_profile.dart';
import 'profile_controller.dart';

/// Lets a pharmacy edit the profile fields they own (name/phone/address) —
/// deliberately excludes email (the auth login identity) and the map pin /
/// license, which stay as verified at KYC time.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _areaController;
  late final TextEditingController _addressController;
  String? _governorate;
  bool _saving = false;
  String? _error;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _areaController = TextEditingController();
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate() || _governorate == null) {
      setState(() => _error = l10n.editProfileFillRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uid = supabase.auth.currentUser!.id;
      await supabase.from('pharmacies').update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'governorate': _governorate,
        'area': _areaController.text.trim(),
        'address_text': _addressController.text.trim(),
      }).eq('id', uid);
      await ref.read(pharmacyProfileControllerProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _error = l10n.editProfileCouldntSave);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _initFieldsOnce(PharmacyProfile? pharmacy) {
    if (pharmacy == null || _initialized) return;
    _initialized = true;
    _nameController.text = pharmacy.name;
    _phoneController.text = pharmacy.phone ?? '';
    _areaController.text = pharmacy.area;
    _addressController.text = pharmacy.addressText;
    // Case-insensitive match against the canonical list rather than using
    // pharmacy.governorate verbatim — DropdownButtonFormField's initialValue
    // must be reference-equal to one of its items' values, and a stored
    // governorate that differs only in case (e.g. admin-edited) would
    // otherwise crash the dropdown instead of just failing to preselect.
    _governorate = egyptGovernorates.where((g) => g.toLowerCase() == pharmacy.governorate.toLowerCase()).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = ref.watch(pharmacyProfileControllerProvider);
    ref.listen(pharmacyProfileControllerProvider, (previous, next) => _initFieldsOnce(next.value));
    _initFieldsOnce(profile.value);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editProfileTitle)),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(l10n.editProfileCouldntLoad, style: Theme.of(context).textTheme.bodyMedium),
        ),
        data: (_) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: l10n.fieldPharmacyName, prefixIcon: const Icon(Icons.storefront_rounded)),
                validator: (v) => (v == null || v.trim().length < 3) ? l10n.editProfileNameValidator : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: l10n.fieldPhoneNumber, prefixIcon: const Icon(Icons.call_rounded)),
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: _governorate,
                decoration: InputDecoration(labelText: l10n.fieldGovernorate, prefixIcon: const Icon(Icons.map_rounded)),
                items: egyptGovernorates.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() => _governorate = v),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _areaController,
                decoration: InputDecoration(labelText: l10n.fieldArea, prefixIcon: const Icon(Icons.location_on_rounded)),
                validator: (v) => (v == null || v.trim().isEmpty) ? l10n.editProfileAreaValidator : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(labelText: l10n.fieldDetailedAddress, prefixIcon: const Icon(Icons.home_rounded)),
                maxLines: 2,
                validator: (v) => (v == null || v.trim().isEmpty) ? l10n.editProfileAddressValidator : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Text(_error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger)),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              AppGradientButton(
                onPressed: _saving ? null : _save,
                isLoading: _saving,
                child: Text(l10n.editProfileSaveChanges),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
