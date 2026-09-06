import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/egypt_governorates.dart';
import '../../../core/l10n_extensions.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/map_controls.dart';
import '../../../core/widgets/map_pin.dart';
import '../kyc_controller.dart';
import '../widgets/kyc_step_header.dart';

/// Address step — deliberately captures a verified map pin alongside the
/// free-text fields. Free-text Egyptian addresses geocode unreliably, and
/// the proximity search in the marketplace depends on an accurate point,
/// so the pin is required to proceed, not optional.
class AddressStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const AddressStep({super.key, required this.onNext, required this.onBack});

  @override
  ConsumerState<AddressStep> createState() => _AddressStepState();
}

class _AddressStepState extends ConsumerState<AddressStep> {
  static const _cairo = LatLng(30.0444, 31.2357);

  String? _governorate;
  late final TextEditingController _areaController;
  late final TextEditingController _addressController;
  LatLng? _pin;
  bool _locating = false;
  bool _dragging = false;
  String? _error;

  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    final data = ref.read(kycControllerProvider);
    _governorate = data.governorate.isEmpty ? null : data.governorate;
    _areaController = TextEditingController(text: data.area);
    _addressController = TextEditingController(text: data.addressText);
    _pin = data.pinLocation;
  }

  @override
  void dispose() {
    _areaController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final l10n = context.l10n;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _error = l10n.kycLocationDenied);
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _pin = point;
        _error = null;
      });
      _mapController.move(point, 15);
    } catch (_) {
      setState(() => _error = l10n.kycLocationError);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _submit() {
    final l10n = context.l10n;
    if (_governorate == null || _areaController.text.trim().isEmpty || _addressController.text.trim().isEmpty) {
      setState(() => _error = l10n.kycFillRequiredFields);
      return;
    }
    if (_pin == null) {
      setState(() => _error = l10n.kycDropPin);
      return;
    }
    ref.read(kycControllerProvider.notifier).updateAddress(
          governorate: _governorate!,
          area: _areaController.text.trim(),
          addressText: _addressController.text.trim(),
          pinLocation: _pin!,
        );
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        KycStepHeader(
          icon: Icons.location_on_rounded,
          title: l10n.kycAddressTitle,
          subtitle: l10n.kycAddressSubtitle,
        ),
        const SizedBox(height: AppSpacing.xl),
        DropdownButtonFormField<String>(
          initialValue: _governorate,
          decoration: InputDecoration(labelText: l10n.fieldGovernorate),
          items: egyptGovernorates.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (v) => setState(() => _governorate = v),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(controller: _areaController, decoration: InputDecoration(labelText: l10n.fieldArea)),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _addressController,
          decoration: InputDecoration(labelText: l10n.fieldDetailedAddress),
          maxLines: 2,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(l10n.kycPinYourPharmacy, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Container(
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _pin ?? _cairo,
                    initialZoom: _pin != null ? 15 : 6,
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture) {
                        if (!_dragging) setState(() => _dragging = true);
                        _pin = camera.center;
                      } else if (_dragging) {
                        setState(() => _dragging = false);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.pharmaexchangeegypt.app',
                    ),
                  ],
                ),
                // Pin stays fixed at the map's optical center — the map
                // pans underneath it (Google Maps / Careem address-pin
                // pattern), which is far more precise on a phone than
                // tapping a small target. It lifts a little while
                // dragging and drops back down on release for feedback.
                IgnorePointer(
                  // Shift up so the pin's tip — not its icon's bounding-box
                  // center — lands on the map's true center, which is what
                  // camera.center (the value actually saved) points at.
                  child: Transform.translate(
                    offset: Offset(0, -AppMapPin.tipOffset(44)),
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      offset: _dragging ? const Offset(0, -0.08) : Offset.zero,
                      child: AppMapPin(
                        size: 44,
                        gradient: _pin == null ? AppGradients.cream : AppGradients.hero,
                        icon: Icons.local_pharmacy_rounded,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: Column(
                    children: [
                      MapRoundButton(
                        icon: Icons.my_location_rounded,
                        loading: _locating,
                        onPressed: _useCurrentLocation,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      MapZoomControls(mapController: _mapController),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _pin == null ? l10n.kycTapToDropPin : l10n.kycPinSet(_pin!.latitude.toStringAsFixed(5), _pin!.longitude.toStringAsFixed(5)),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _pin == null ? AppColors.inkFaint : AppColors.good,
              ),
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
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: widget.onBack, child: Text(l10n.commonBack))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: _submit, child: Text(l10n.commonContinue))),
          ],
        ),
      ],
    );
  }
}
