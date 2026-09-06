import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n_extensions.dart';
import '../../core/success_screen.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_gradient_button.dart';
import '../../core/widgets/map_pin.dart';
import '../../core/widgets/star_picker.dart';
import '../deals/deal.dart';
import '../deals/deals_controller.dart';
import '../disputes/dispute.dart';
import '../disputes/disputes_controller.dart';
import '../listings/listing_summary.dart';
import '../profile/profile_controller.dart';
import '../ratings/ratings_controller.dart';
import 'message.dart';
import 'messages_controller.dart';

enum _AttachChoice { camera, gallery, pdf, location }

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.dealId});

  final String dealId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _actingOnDeal = false;
  bool _rating = false;
  bool _reporting = false;
  bool _attaching = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// With the message list rendered `reverse: true` (see build()), the
  /// latest message sits at scroll offset 0 rather than maxScrollExtent —
  /// that's what keeps a short thread anchored to the bottom of the screen
  /// instead of stacking from the top with empty space underneath.
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  Future<void> _send() async {
    final body = _inputController.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    final l10n = context.l10n;
    try {
      await ref.read(messagesControllerProvider(widget.dealId).notifier).send(body);
      _inputController.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.chatCouldntSend(error))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Shared upload step for both the camera and gallery flows — swallows
  /// its own error (shown as a snackbar) rather than rethrowing, so a
  /// failure partway through a multi-photo batch doesn't abort the rest.
  Future<void> _uploadPhoto(String localPath) async {
    final l10n = context.l10n;
    try {
      await ref.read(messagesControllerProvider(widget.dealId).notifier).sendAttachment(localPath);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.chatCouldntSendAttachment(error))));
      }
    }
  }

  Future<void> _takePhoto() async {
    if (_attaching) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (file == null) return;
    setState(() => _attaching = true);
    try {
      await _uploadPhoto(file.path);
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  /// Sends each picked photo as its own message, one upload at a time —
  /// sequential (not Future.wait) so the storage path's timestamp suffix
  /// (microsecondsSinceEpoch) can't collide between two near-simultaneous
  /// uploads, and so messages land in the thread in the order picked.
  Future<void> _pickAndSendGalleryPhotos() async {
    if (_attaching) return;
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    setState(() => _attaching = true);
    try {
      for (final file in files) {
        await _uploadPhoto(file.path);
      }
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  /// Reuses the exact same generic `sendAttachment` upload path as photos —
  /// the storage bucket has no MIME restriction, so a PDF is just another
  /// object at a deal-scoped path. Only the picker and the bubble's
  /// rendering (see _AttachmentThumbnail) differ by extension.
  Future<void> _sendPdfAttachment() async {
    final l10n = context.l10n;
    final result = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);
    final path = result?.path;
    if (path == null || _attaching) return;
    setState(() => _attaching = true);
    try {
      await ref.read(messagesControllerProvider(widget.dealId).notifier).sendAttachment(path);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.chatCouldntSendAttachment(error))));
      }
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  Future<bool> _ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  Future<void> _shareLocation() async {
    final l10n = context.l10n;
    if (_attaching) return;
    setState(() => _attaching = true);
    try {
      final allowed = await _ensureLocationPermission();
      if (!allowed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.chatLocationPermissionDenied)));
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      await ref.read(messagesControllerProvider(widget.dealId).notifier).sendLocation(lat: position.latitude, lng: position.longitude);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.chatCouldntShareLocation(error))));
      }
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  Future<void> _openAttachSheet() async {
    final l10n = context.l10n;
    final choice = await showModalBottomSheet<_AttachChoice>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: Text(l10n.chatTakePhoto),
              onTap: () => Navigator.of(sheetContext).pop(_AttachChoice.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: Text(l10n.chatChoosePhotos),
              onTap: () => Navigator.of(sheetContext).pop(_AttachChoice.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary),
              title: Text(l10n.chatAttachPdf),
              onTap: () => Navigator.of(sheetContext).pop(_AttachChoice.pdf),
            ),
            ListTile(
              leading: const Icon(Icons.location_on_rounded, color: AppColors.primary),
              title: Text(l10n.chatShareLocation),
              onTap: () => Navigator.of(sheetContext).pop(_AttachChoice.location),
            ),
          ],
        ),
      ),
    );
    switch (choice) {
      case _AttachChoice.camera:
        await _takePhoto();
      case _AttachChoice.gallery:
        await _pickAndSendGalleryPhotos();
      case _AttachChoice.pdf:
        await _sendPdfAttachment();
      case _AttachChoice.location:
        await _shareLocation();
      case null:
        break;
    }
  }

  Future<void> _act(String action, {required String confirmTitle, required String confirmBody}) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(confirmTitle),
        content: Text(confirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.commonBack)),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l10n.commonConfirm)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _actingOnDeal = true);
    try {
      await respondToDeal(widget.dealId, action);
      ref.invalidate(dealDetailControllerProvider(widget.dealId));
      ref.invalidate(dealsControllerProvider);
      if (action == 'complete' && mounted) {
        context.push(
          '/success',
          extra: SuccessArgs(
            title: l10n.chatDealCompletedTitle,
            message: l10n.chatDealCompletedBody,
            ctaLabel: l10n.commonDone,
            onCta: () => context.pop(),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.chatCouldntUpdateDeal(error))));
      }
    } finally {
      if (mounted) setState(() => _actingOnDeal = false);
    }
  }

  Future<void> _openRateSheet() async {
    final l10n = context.l10n;
    int stars = 0;
    int credibility = 0;
    int responsiveness = 0;
    int packaging = 0;

    final submit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.chatRateThisPharmacy, style: Theme.of(sheetContext).textTheme.headlineMedium),
                  const SizedBox(height: AppSpacing.lg),
                  Text(l10n.chatOverall, style: Theme.of(sheetContext).textTheme.bodyMedium),
                  StarPicker(value: stars, onChanged: (v) => setSheetState(() => stars = v)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.chatCredibility, style: Theme.of(sheetContext).textTheme.bodyMedium),
                  StarPicker(value: credibility, size: 24, onChanged: (v) => setSheetState(() => credibility = v)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.chatResponsiveness, style: Theme.of(sheetContext).textTheme.bodyMedium),
                  StarPicker(value: responsiveness, size: 24, onChanged: (v) => setSheetState(() => responsiveness = v)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.chatPackaging, style: Theme.of(sheetContext).textTheme.bodyMedium),
                  StarPicker(value: packaging, size: 24, onChanged: (v) => setSheetState(() => packaging = v)),
                  const SizedBox(height: AppSpacing.xl),
                  AppGradientButton(
                    onPressed: stars == 0 ? null : () => Navigator.of(sheetContext).pop(true),
                    child: Text(l10n.chatSubmitRating),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (submit != true || !mounted || stars == 0) return;

    setState(() => _rating = true);
    try {
      await submitRating(
        widget.dealId,
        stars: stars,
        credibility: credibility == 0 ? null : credibility,
        responsiveness: responsiveness == 0 ? null : responsiveness,
        packaging: packaging == 0 ? null : packaging,
      );
      ref.invalidate(hasRatedControllerProvider(widget.dealId));
      ref.invalidate(ratingSummaryControllerProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.chatRatingSubmitted)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.chatCouldntSubmitRating(error))));
      }
    } finally {
      if (mounted) setState(() => _rating = false);
    }
  }

  Future<void> _openReportSheet() async {
    final l10n = context.l10n;
    final reasons = disputeReasons(l10n);
    String reason = reasons.first;
    final descriptionController = TextEditingController();
    String? photoPath;

    final submit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.chatReportIssue, style: Theme.of(sheetContext).textTheme.headlineMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.chatReportBody,
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  DropdownButtonFormField<String>(
                    initialValue: reason,
                    decoration: InputDecoration(labelText: l10n.fieldReason),
                    items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => setSheetState(() => reason = v ?? reason),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: l10n.chatDetailsOptional),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                      if (file != null) setSheetState(() => photoPath = file.path);
                    },
                    icon: Icon(photoPath == null ? Icons.attach_file_rounded : Icons.check_circle_rounded, size: 18),
                    label: Text(photoPath == null ? l10n.chatAttachEvidence : l10n.chatPhotoAttached),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppGradientButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    child: Text(l10n.chatSubmitReport),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (submit != true || !mounted) return;

    setState(() => _reporting = true);
    try {
      await raiseDispute(
        widget.dealId,
        reason: reason,
        description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
        evidencePhotoPath: photoPath,
      );
      ref.invalidate(currentDisputeControllerProvider(widget.dealId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.chatReportSubmitted)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.chatCouldntSubmitReport(error))));
      }
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dealAsync = ref.watch(dealDetailControllerProvider(widget.dealId));
    final messagesAsync = ref.watch(messagesControllerProvider(widget.dealId));
    final hasRated = ref.watch(hasRatedControllerProvider(widget.dealId)).value ?? false;
    final currentDispute = ref.watch(currentDisputeControllerProvider(widget.dealId)).value;
    final canReport = currentDispute == null || currentDispute.status == DisputeStatus.resolved;
    final uid = supabase.auth.currentUser?.id;

    ref.listen(messagesControllerProvider(widget.dealId), (_, _) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: dealAsync.when(
          data: (deal) => Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  deal.counterpartName.isEmpty ? '?' : deal.counterpartName[0].toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primaryDark),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(deal.counterpartName, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                    Text(
                      '${deal.drugTradeName} · ${deal.listingType.label(l10n)}',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          loading: () => Text(l10n.chatHeaderFallback),
          error: (_, _) => Text(l10n.chatHeaderFallback),
        ),
        actions: [
          if (canReport)
            IconButton(
              tooltip: l10n.chatReportTooltip,
              icon: const Icon(Icons.flag_rounded),
              onPressed: _reporting ? null : _openReportSheet,
            ),
        ],
      ),
      body: Column(
        children: [
          dealAsync.maybeWhen(data: (deal) => _DealStatusBar(deal: deal), orElse: () => const SizedBox.shrink()),
          if (currentDispute != null) _DisputeBanner(dispute: currentDispute),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(l10n.chatCouldntLoadMessages, style: Theme.of(context).textTheme.titleMedium),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Text(l10n.chatNoMessagesYet, style: Theme.of(context).textTheme.bodyMedium),
                  );
                }
                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final message = messages[messages.length - 1 - i];
                    return _MessageBubble(message: message, isMine: message.senderId == uid);
                  },
                );
              },
            ),
          ),
          dealAsync.maybeWhen(
            data: (deal) => _ActionBar(
              deal: deal,
              inputController: _inputController,
              sending: _sending,
              actingOnDeal: _actingOnDeal,
              hasRated: hasRated,
              rating: _rating,
              attaching: _attaching,
              onSend: _send,
              onAttach: _openAttachSheet,
              onComplete: () => _act(
                'complete',
                confirmTitle: l10n.chatMarkCompleteConfirmTitle,
                confirmBody: l10n.chatMarkCompleteConfirmBody,
              ),
              onCancel: () => _act(
                'cancel',
                confirmTitle: l10n.chatCancelConfirmTitle,
                confirmBody: l10n.chatCancelConfirmBody,
              ),
              onRate: _openRateSheet,
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _DealStatusBar extends StatelessWidget {
  const _DealStatusBar({required this.deal});

  final DealDetail deal;

  @override
  Widget build(BuildContext context) {
    if (deal.state == ListingState.reserved) return const SizedBox.shrink();
    final l10n = context.l10n;
    final (fg, bg, label) = switch (deal.state) {
      ListingState.completed => (AppColors.good, AppColors.goodBg, l10n.chatDealCompletedBar),
      ListingState.cancelled => (AppColors.danger, AppColors.dangerBg, l10n.chatDealCancelledBar),
      _ => (AppColors.inkFaint, AppColors.background, ''),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.lg),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
    );
  }
}

class _DisputeBanner extends StatelessWidget {
  const _DisputeBanner({required this.dispute});

  final DisputeRecord dispute;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (fg, bg) = switch (dispute.status) {
      DisputeStatus.open => (AppColors.danger, AppColors.dangerBg),
      DisputeStatus.underReview => (AppColors.warn, AppColors.warnBg),
      DisputeStatus.resolved => (AppColors.good, AppColors.goodBg),
    };
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Icon(Icons.flag_rounded, size: 16, color: fg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${dispute.status.label(l10n)}: ${dispute.reason}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          gradient: isMine ? AppGradients.cta : null,
          color: isMine ? null : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.lg),
            topRight: const Radius.circular(AppRadius.lg),
            bottomLeft: Radius.circular(isMine ? AppRadius.lg : AppRadius.xs),
            bottomRight: Radius.circular(isMine ? AppRadius.xs : AppRadius.lg),
          ),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.isLocation)
              _LocationPreview(lat: message.locationLat!, lng: message.locationLng!, isMine: isMine)
            else if (message.attachmentPath != null)
              _AttachmentThumbnail(path: message.attachmentPath!, isMine: isMine)
            else
              Text(message.body, style: textTheme.bodyLarge?.copyWith(color: isMine ? Colors.white : AppColors.ink)),
            const SizedBox(height: 2),
            Text(
              DateFormat.jm().format(message.createdAt),
              style: textTheme.labelSmall?.copyWith(color: isMine ? Colors.white70 : AppColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat attachments live in the private chat-attachments bucket, so there's
/// no public URL to embed — resolve a short-lived signed URL only when the
/// bubble is tapped, rather than eagerly for every message on every rebuild.
/// Branches on the file extension for PDFs vs images — the bucket/RLS/send
/// path is identical for both, only how the bubble renders and what "open"
/// means differs (in-app image viewer vs handing the PDF to an external app).
class _AttachmentThumbnail extends StatelessWidget {
  const _AttachmentThumbnail({required this.path, required this.isMine});

  final String path;
  final bool isMine;

  bool get _isPdf => path.toLowerCase().endsWith('.pdf');

  Future<void> _open(BuildContext context) async {
    final l10n = context.l10n;
    try {
      final signedUrl = await supabase.storage.from('chat-attachments').createSignedUrl(path, 3600);
      if (!context.mounted) return;
      if (_isPdf) {
        await launchUrl(Uri.parse(signedUrl), mode: LaunchMode.externalApplication);
        return;
      }
      showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: InteractiveViewer(child: Image.network(signedUrl)),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.chatCouldntOpenAttachment(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 160,
        height: 110,
        decoration: BoxDecoration(
          color: isMine ? Colors.white.withValues(alpha: 0.16) : AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
              size: 28,
              color: isMine ? Colors.white : AppColors.primary,
            ),
            const SizedBox(height: 4),
            Text(
              _isPdf ? l10n.chatTapToOpenPdf : l10n.chatTapToViewPhoto,
              style: TextStyle(fontSize: 12, color: isMine ? Colors.white : AppColors.primaryDark, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable static-looking map preview for a shared-location message —
/// interaction is disabled (it's just a snapshot inside a chat bubble, not
/// a scrollable map competing with the message list's own scroll), and
/// tapping hands off to the device's maps app for real navigation rather
/// than reimplementing directions in-app.
class _LocationPreview extends StatelessWidget {
  const _LocationPreview({required this.lat, required this.lng, required this.isMine});

  final double lat;
  final double lng;
  final bool isMine;

  Future<void> _openInMaps(BuildContext context) async {
    final l10n = context.l10n;
    try {
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.chatCouldntOpenAttachment(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final point = LatLng(lat, lng);
    return InkWell(
      onTap: () => _openInMaps(context),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          width: 200,
          height: 130,
          child: IgnorePointer(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: 14,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.pharmaexchangeegypt.app',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: point,
                        width: AppMapPin.footprint(30),
                        height: AppMapPin.footprint(30),
                        alignment: Alignment.bottomCenter,
                        child: const AppMapPin(size: 30),
                      ),
                    ]),
                  ],
                ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      gradient: AppGradients.hero,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.directions_rounded, size: 13, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          l10n.chatOpenInMaps,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.deal,
    required this.inputController,
    required this.sending,
    required this.actingOnDeal,
    required this.hasRated,
    required this.rating,
    required this.attaching,
    required this.onSend,
    required this.onAttach,
    required this.onComplete,
    required this.onCancel,
    required this.onRate,
  });

  final DealDetail deal;
  final TextEditingController inputController;
  final bool sending;
  final bool actingOnDeal;
  final bool hasRated;
  final bool rating;
  final bool attaching;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final VoidCallback onRate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final closed = deal.state != ListingState.reserved;
    final canRate = deal.state == ListingState.completed && !hasRated;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!closed)
              Row(
                children: [
                  if (deal.isSeller)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: actingOnDeal ? null : onComplete,
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text(l10n.chatMarkComplete),
                      ),
                    ),
                  if (deal.isSeller) const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: actingOnDeal ? null : onCancel,
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text(deal.isSeller ? l10n.chatDeclineCancel : l10n.chatCancelRequest),
                    ),
                  ),
                ],
              ),
            if (!closed) const SizedBox(height: AppSpacing.sm),
            if (canRate)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppGradientButton(
                  isLoading: rating,
                  onPressed: rating ? null : onRate,
                  child: Text(l10n.chatRateThisPharmacy),
                ),
              )
            else if (closed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  deal.state == ListingState.completed ? l10n.chatDealClosedRated : l10n.chatDealClosed,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6FBF8),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.divider),
                      ),
                      padding: const EdgeInsets.only(left: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: l10n.chatAttach,
                            onPressed: attaching ? null : onAttach,
                            icon: attaching
                                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.attach_file_rounded, color: AppColors.inkSoft),
                          ),
                          Expanded(
                            child: TextField(
                              controller: inputController,
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => onSend(),
                              decoration: InputDecoration(
                                hintText: l10n.chatTypeMessage,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Ink(
                    decoration: const BoxDecoration(gradient: AppGradients.cta, shape: BoxShape.circle),
                    child: IconButton(
                      onPressed: sending ? null : onSend,
                      icon: sending
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
