import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/l10n_extensions.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_pill.dart';

/// Blocks access until an admin approves the KYC row. Realtime-subscribed
/// to `pharmacies.status` so approval (done today via Supabase Studio,
/// later via the admin dashboard) flips this screen automatically —
/// no polling, no manual refresh.
class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  String _status = 'pending';
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    _channel = supabase
        .channel('pharmacy-status-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'pharmacies',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: userId),
          callback: (payload) {
            final status = payload.newRecord['status'] as String?;
            if (status != null && mounted) {
              setState(() => _status = status);
              if (status == 'approved') context.go('/home');
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rejected = _status == 'rejected';
    final badgeColor = rejected ? AppColors.danger : AppColors.primary;
    final badgeBg = rejected ? AppColors.dangerBg : AppColors.primarySoft;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
                child: Icon(
                  rejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
                  size: 56,
                  color: badgeColor,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              StatusPill(
                kind: rejected ? StatusPillKind.rejected : StatusPillKind.pending,
                label: rejected ? l10n.kycRejectedLabel : l10n.kycPendingReview,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                rejected ? l10n.kycApplicationRejected : l10n.kycVerificationInProgress,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                rejected ? l10n.kycRejectedBody : l10n.kycPendingBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
