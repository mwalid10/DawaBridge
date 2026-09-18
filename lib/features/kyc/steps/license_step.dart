import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n_extensions.dart';
import '../../../core/theme.dart';
import '../kyc_controller.dart';
import '../widgets/kyc_step_header.dart';

/// License step — captures both the license file *and* its expiry date.
/// The original spec only ever asked for the file; without an expiry date
/// there is no way to prompt re-verification before a license lapses.
class LicenseStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  /// In recovery mode (see [KycWizardScreen.recovery]) this is the last
  /// step, so the button reads Submit and shows a spinner while the
  /// registration RPC is in flight.
  final bool isFinalStep;
  final bool submitting;

  const LicenseStep({
    super.key,
    required this.onNext,
    required this.onBack,
    this.isFinalStep = false,
    this.submitting = false,
  });

  @override
  ConsumerState<LicenseStep> createState() => _LicenseStepState();
}

class _LicenseStepState extends ConsumerState<LicenseStep> {
  String? _filePath;
  DateTime? _expiry;
  String? _error;

  @override
  void initState() {
    super.initState();
    final data = ref.read(kycControllerProvider);
    _filePath = data.licenseFilePath;
    _expiry = data.licenseExpiry;
  }

  Future<void> _pickFile() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final sizeBytes = await file.length();
    if (sizeBytes > 5 * 1024 * 1024) {
      setState(() => _error = context.l10n.kycFileTooLarge);
      return;
    }
    setState(() {
      _filePath = file.path;
      _error = null;
    });
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: context.l10n.kycLicenseExpiryDate,
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  void _submit() {
    final l10n = context.l10n;
    if (_filePath == null) {
      setState(() => _error = l10n.kycUploadLicense);
      return;
    }
    if (_expiry == null || !_expiry!.isAfter(DateTime.now())) {
      setState(() => _error = l10n.kycSelectValidExpiry);
      return;
    }
    ref.read(kycControllerProvider.notifier).updateLicense(filePath: _filePath!, expiry: _expiry!);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        KycStepHeader(
          icon: Icons.verified_rounded,
          title: l10n.kycLicenseTitle,
          subtitle: l10n.kycLicenseSubtitle,
        ),
        const SizedBox(height: AppSpacing.xl),
        InkWell(
          onTap: _pickFile,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              color: AppColors.primarySoft.withValues(alpha: 0.4),
            ),
            child: _filePath == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.cloud_upload_outlined, size: 26, color: AppColors.primary),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(l10n.kycTapToUpload, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: const BoxDecoration(color: AppColors.goodBg, shape: BoxShape.circle),
                          child: const Icon(Icons.check_circle_rounded, color: AppColors.good, size: 26),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _filePath!.split(Platform.pathSeparator).last,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        ListTile(
          title: Text(_expiry == null ? l10n.kycLicenseExpiryDate : DateFormat.yMMMd().format(_expiry!)),
          leading: const Icon(Icons.event_outlined, color: AppColors.primary),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: _pickExpiry,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: const BorderSide(color: AppColors.divider),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Text(_error!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger)),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.submitting ? null : widget.onBack,
                child: Text(l10n.commonBack),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: widget.submitting ? null : _submit,
                child: widget.submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(widget.isFinalStep ? l10n.commonSubmit : l10n.commonContinue),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
