import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import 'dispute.dart';

/// All disputes the signed-in pharmacy is a party to (raised by them or
/// against them), newest first — backs the "My disputes" screen.
class DisputesController extends AsyncNotifier<List<Dispute>> {
  @override
  Future<List<Dispute>> build() async {
    final rows = await supabase.rpc('get_my_disputes');
    return (rows as List<dynamic>).map((row) => Dispute.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final disputesControllerProvider = AsyncNotifierProvider<DisputesController, List<Dispute>>(DisputesController.new);

/// The most recent dispute on a deal, kept live via Realtime (same
/// `onPostgresChanges` pattern as pending_approval_screen.dart /
/// messages_controller.dart) so a status change an admin makes in
/// Supabase Studio shows up without a manual refresh. The disputes select
/// policy (0009_disputes_rpc.sql) allows either participant to read, so
/// this is a direct table query, not an RPC.
class CurrentDisputeController extends AsyncNotifier<DisputeRecord?> {
  CurrentDisputeController(this.dealId);

  final String dealId;
  RealtimeChannel? _channel;

  @override
  Future<DisputeRecord?> build() async {
    ref.onDispose(() => _channel?.unsubscribe());

    final uid = supabase.auth.currentUser!.id;
    final rows = await supabase
        .from('disputes')
        .select()
        .eq('deal_id', dealId)
        .order('created_at', ascending: false)
        .limit(1);
    _subscribe(uid);

    final list = rows as List<dynamic>;
    return list.isEmpty ? null : DisputeRecord.fromRow(list.first as Map<String, dynamic>, uid);
  }

  void _subscribe(String uid) {
    _channel = supabase
        .channel('disputes-$dealId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'disputes',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'deal_id', value: dealId),
          callback: (payload) {
            state = AsyncValue.data(
              payload.eventType == PostgresChangeEvent.delete
                  ? null
                  : DisputeRecord.fromRow(payload.newRecord, uid),
            );
          },
        )
        .subscribe();
  }
}

final currentDisputeControllerProvider =
    AsyncNotifierProvider.autoDispose.family<CurrentDisputeController, DisputeRecord?, String>(
  (id) => CurrentDisputeController(id),
);

/// Raises a dispute via the raise_dispute RPC (participant check happens
/// server-side — see 0009_disputes_rpc.sql). Uploads the optional evidence
/// photo first to the private chat-attachments bucket, storing just the
/// storage path (not a public URL) — same convention as license_url from
/// the KYC upload in otp_verification_screen.dart, since this bucket is
/// private too.
///
/// Path is deal-scoped (`<dealId>/dispute-<uid>-...`), not uid-scoped —
/// 0014_messages_attachments.sql re-scoped the chat-attachments bucket's
/// RLS to is_deal_participant() so both sides of a deal can read shared
/// evidence/attachments; a uid-scoped path would no longer match that policy.
Future<void> raiseDispute(
  String dealId, {
  required String reason,
  String? description,
  String? evidencePhotoPath,
}) async {
  final uid = supabase.auth.currentUser!.id;
  final evidenceUrls = <String>[];

  if (evidencePhotoPath != null) {
    final ext = evidencePhotoPath.split('.').last;
    final path = '$dealId/dispute-$uid-${DateTime.now().microsecondsSinceEpoch}.$ext';
    await supabase.storage.from('chat-attachments').upload(path, File(evidencePhotoPath));
    evidenceUrls.add(path);
  }

  await supabase.rpc('raise_dispute', params: {
    'p_deal_id': dealId,
    'p_reason': reason,
    'p_description': description,
    'p_evidence_urls': evidenceUrls,
  });
}
