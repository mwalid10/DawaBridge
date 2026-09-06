import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n_extensions.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_card.dart';
import 'kyc_controller.dart';

/// Verifies the email OTP Supabase Auth sends automatically on sign-up,
/// then writes the pharmacy row (status defaults to 'pending') and uploads
/// the license file. This is the point at which a Supabase Auth user
/// actually exists, so it's the earliest the license can be uploaded to a
/// user-scoped private Storage path.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _code = TextEditingController();
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final data = ref.read(kycControllerProvider);
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await supabase.auth.verifyOTP(
        type: OtpType.signup,
        email: data.email,
        token: _code.text.trim(),
      );

      final userId = supabase.auth.currentUser!.id;
      final ext = data.licenseFilePath!.split('.').last;
      final storagePath = '$userId/license.$ext';
      await supabase.storage.from('licenses').upload(storagePath, File(data.licenseFilePath!));

      await supabase.from('pharmacies').insert({
        'id': userId,
        'name': data.pharmacyName,
        'email': data.email,
        'governorate': data.governorate,
        'area': data.area,
        'address_text': data.addressText,
        'lat': data.pinLocation!.latitude,
        'lng': data.pinLocation!.longitude,
        'license_url': storagePath,
        'license_expiry': data.licenseExpiry!.toIso8601String(),
      });

      ref.read(kycControllerProvider.notifier).reset();
      if (mounted) context.go('/pending-approval');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final email = ref.watch(kycControllerProvider).email;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.kycVerifyEmailTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                  child: const Icon(Icons.mail_outline_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.kycOtpBody(email),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 8),
                  decoration: InputDecoration(labelText: l10n.kycOtpLabel, counterText: ''),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: _verifying ? null : _verify,
                  child: _verifying
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(l10n.kycVerifyAndSubmit),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
