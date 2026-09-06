import '../../l10n/app_localizations.dart';

enum DisputeStatus {
  open,
  underReview,
  resolved;

  static DisputeStatus fromString(String value) => switch (value) {
        'open' => DisputeStatus.open,
        'under_review' => DisputeStatus.underReview,
        'resolved' => DisputeStatus.resolved,
        _ => throw ArgumentError('Unknown dispute status: $value'),
      };

  String label(AppLocalizations l10n) => switch (this) {
        DisputeStatus.open => l10n.disputeStatusOpen,
        DisputeStatus.underReview => l10n.disputeStatusUnderReview,
        DisputeStatus.resolved => l10n.disputeStatusResolved,
      };
}

/// Row shape returned by the `get_my_disputes` RPC — a security-definer
/// join of disputes + deals + listings + drugs + the counterpart
/// pharmacy's safe (name-only) columns, same contract as Deal/ListingSummary.
class Dispute {
  final String id;
  final String dealId;
  final String drugTradeName;
  final String reason;
  final DisputeStatus status;
  final bool raisedByMe;
  final String counterpartName;
  final DateTime createdAt;

  const Dispute({
    required this.id,
    required this.dealId,
    required this.drugTradeName,
    required this.reason,
    required this.status,
    required this.raisedByMe,
    required this.counterpartName,
    required this.createdAt,
  });

  factory Dispute.fromJson(Map<String, dynamic> json) {
    return Dispute(
      id: json['dispute_id'] as String,
      dealId: json['deal_id'] as String,
      drugTradeName: json['drug_trade_name'] as String,
      reason: json['reason'] as String,
      status: DisputeStatus.fromString(json['dispute_status'] as String),
      raisedByMe: json['raised_by_me'] as bool,
      counterpartName: json['counterpart_name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Raw `disputes` row shape (as opposed to [Dispute]'s RPC-joined shape) —
/// used by CurrentDisputeController, which watches one deal's most recent
/// dispute live via Realtime and doesn't need the counterpart-name join.
class DisputeRecord {
  final String id;
  final String reason;
  final DisputeStatus status;
  final bool raisedByMe;
  final DateTime createdAt;

  const DisputeRecord({
    required this.id,
    required this.reason,
    required this.status,
    required this.raisedByMe,
    required this.createdAt,
  });

  factory DisputeRecord.fromRow(Map<String, dynamic> json, String currentUserId) {
    return DisputeRecord(
      id: json['id'] as String,
      reason: json['reason'] as String,
      status: DisputeStatus.fromString(json['status'] as String),
      raisedByMe: json['raised_by'] as String == currentUserId,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

List<String> disputeReasons(AppLocalizations l10n) => [
      l10n.disputeReasonNotAsDescribed,
      l10n.disputeReasonNonDelivery,
      l10n.disputeReasonQuantityMismatch,
      l10n.disputeReasonPaymentIssue,
      l10n.disputeReasonOther,
    ];
