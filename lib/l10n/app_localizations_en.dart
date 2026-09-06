// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonBack => 'Back';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonDone => 'Done';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonAll => 'All';

  @override
  String get commonView => 'View';

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navChat => 'Chat';

  @override
  String get navNews => 'News';

  @override
  String get navProfile => 'Profile';

  @override
  String get listingTypeSell => 'Sell';

  @override
  String get listingTypeBuy => 'Buy';

  @override
  String get listingTypeExchange => 'Exchange';

  @override
  String get listingStateAvailable => 'Available';

  @override
  String get listingStateReserved => 'Reserved';

  @override
  String get listingStateCompleted => 'Completed';

  @override
  String get listingStateCancelled => 'Cancelled';

  @override
  String get disputeStatusOpen => 'Open';

  @override
  String get disputeStatusUnderReview => 'Under review';

  @override
  String get disputeStatusResolved => 'Resolved';

  @override
  String get newsCategoryRegulatory => 'Regulatory';

  @override
  String get newsCategoryMarketPricing => 'Market Pricing';

  @override
  String get newsCategoryCompanyNews => 'Company News';

  @override
  String get newsCategoryRecallsSafety => 'Recalls & Safety';

  @override
  String get newsCategoryIndustryEvents => 'Industry Events';

  @override
  String get newsCategoryEducation => 'Education';

  @override
  String get planTrial => 'Trial';

  @override
  String get planFree => 'Free';

  @override
  String get planActive => 'Active';

  @override
  String get disputeReasonNotAsDescribed => 'Item not as described';

  @override
  String get disputeReasonNonDelivery => 'Non-delivery';

  @override
  String get disputeReasonQuantityMismatch => 'Quantity mismatch';

  @override
  String get disputeReasonPaymentIssue => 'Payment issue';

  @override
  String get disputeReasonOther => 'Other';

  @override
  String get onboardSkip => 'Skip';

  @override
  String get onboardSlide1Title => 'Move near-expiry stock';

  @override
  String get onboardSlide1Body =>
      'List surplus medication before it expires instead of writing it off.';

  @override
  String get onboardSlide2Title => 'Barter, sell, or buy';

  @override
  String get onboardSlide2Body =>
      'Trade directly with licensed pharmacies nearby — no wholesaler in between.';

  @override
  String get onboardSlide3Title => 'Licensed pharmacies only';

  @override
  String get onboardSlide3Body =>
      'Every account is KYC-verified before it can list or trade.';

  @override
  String get onboardGetStarted => 'Get started';

  @override
  String get onboardNext => 'Next';

  @override
  String get loginWelcomeBack => 'Welcome back';

  @override
  String get loginSubtitle => 'Sign in to trade with pharmacies across Egypt';

  @override
  String get loginEmailLabel => 'Email address';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginRememberMe => 'Remember me';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginSignIn => 'Sign in';

  @override
  String get loginRegisterCta => 'Register your pharmacy';

  @override
  String get loginResetTitle => 'Reset your password';

  @override
  String get loginResetBody =>
      'We\'ll email you a link to reset your password.';

  @override
  String get loginSendLink => 'Send link';

  @override
  String loginResetSent(Object email) {
    return 'Password reset link sent to $email';
  }

  @override
  String get loginResetError => 'Couldn\'t send the reset link — try again.';

  @override
  String get loginError => 'Could not sign in — check your email and password.';

  @override
  String get kycStepPharmacy => 'Pharmacy';

  @override
  String get kycStepAddress => 'Address';

  @override
  String get kycStepLicense => 'License';

  @override
  String get kycStepPassword => 'Password';

  @override
  String get kycRegisterTitle => 'Register your pharmacy';

  @override
  String get kycPharmacyDetailsTitle => 'Pharmacy details';

  @override
  String get kycPharmacyDetailsSubtitle =>
      'Must match the name on your physical license.';

  @override
  String get fieldPharmacyName => 'Pharmacy name';

  @override
  String get kycPharmacyNameValidator => 'Enter the full pharmacy name';

  @override
  String get fieldEmailAddress => 'Email address';

  @override
  String get kycEmailHint => 'pharmacy@example.com';

  @override
  String get kycEmailValidator => 'Enter a valid email address';

  @override
  String get kycAddressTitle => 'Address & location';

  @override
  String get kycAddressSubtitle =>
      'The pin sets your exact position for proximity search — it does not have to match the text below word-for-word.';

  @override
  String get fieldGovernorate => 'Governorate';

  @override
  String get fieldArea => 'Area';

  @override
  String get fieldDetailedAddress => 'Detailed street address';

  @override
  String get kycPinYourPharmacy => 'Pin your pharmacy';

  @override
  String get kycUseCurrentLocation => 'Use current location';

  @override
  String get kycTapToDropPin =>
      'Drag the map to move the pin to your pharmacy.';

  @override
  String kycPinSet(Object lat, Object lng) {
    return 'Pin set: $lat, $lng';
  }

  @override
  String get kycLocationDenied =>
      'Location permission denied — drop the pin manually instead.';

  @override
  String get kycLocationError =>
      'Could not get your location — drop the pin manually instead.';

  @override
  String get kycFillRequiredFields => 'Fill in governorate, area, and address.';

  @override
  String get kycDropPin =>
      'Drop a pin on the map at your pharmacy\'s exact location.';

  @override
  String get kycLicenseTitle => 'License verification';

  @override
  String get kycLicenseSubtitle => 'JPG, PNG or PDF, up to 5MB.';

  @override
  String get kycFileTooLarge =>
      'File is over the 5MB limit — pick a smaller image.';

  @override
  String get kycTapToUpload => 'Tap to upload license';

  @override
  String get kycLicenseExpiryDate => 'License expiry date';

  @override
  String get kycUploadLicense =>
      'Upload a photo or PDF of your pharmacy license.';

  @override
  String get kycSelectValidExpiry =>
      'Select a valid, non-expired license expiry date.';

  @override
  String get kycSetPassword => 'Set a password';

  @override
  String get kycPasswordSubtitle =>
      '8+ characters, 1 uppercase, 1 number, 1 special character.';

  @override
  String get fieldPassword => 'Password';

  @override
  String get fieldConfirmPassword => 'Confirm password';

  @override
  String get kycPasswordMismatch =>
      'Min 8 characters, with an uppercase letter, a number, and a special character. Passwords must match.';

  @override
  String get kycSubmitForReview => 'Submit for review';

  @override
  String get kycVerifyEmailTitle => 'Verify your email';

  @override
  String kycOtpBody(Object email) {
    return 'Enter the 6-digit code sent to $email. It expires in 2 minutes.';
  }

  @override
  String get kycOtpLabel => 'OTP code';

  @override
  String get kycVerifyAndSubmit => 'Verify & submit for review';

  @override
  String get kycPendingReview => 'Pending review';

  @override
  String get kycRejectedLabel => 'Rejected';

  @override
  String get kycVerificationInProgress => 'Verification in progress';

  @override
  String get kycApplicationRejected => 'Application rejected';

  @override
  String get kycRejectedBody =>
      'Your license could not be verified. Contact support to resubmit.';

  @override
  String get kycPendingBody =>
      'Our team is reviewing your license. This usually takes up to 24 hours — this screen updates automatically once a decision is made.';

  @override
  String get homeWelcomeBack => 'Welcome back,';

  @override
  String get homeStatActiveListings => 'Active Listings';

  @override
  String get homeStatExchanges => 'Exchanges';

  @override
  String get homeStatRating => 'Rating';

  @override
  String get homeQuickSearch => 'Search';

  @override
  String get homeQuickAdd => 'Add';

  @override
  String get homeQuickChat => 'Chat';

  @override
  String get homePriceIncreased => 'Price Increased';

  @override
  String get homeNoPriceAlerts =>
      'No market price alerts right now — check back later.';

  @override
  String get homeSeeAll => 'See all';

  @override
  String get homeLatestMedicines => 'Latest Medicines';

  @override
  String get homeViewAll => 'View All';

  @override
  String get homeNoListingsNearby => 'No listings near you yet';

  @override
  String get homeAddFirstMedicine =>
      'Tap the Add tab below to list your first medicine.';

  @override
  String get homeCouldntLoadListings => 'Couldn\'t load listings';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchListView => 'List view';

  @override
  String get searchMapViewTooltip => 'Map view';

  @override
  String get searchHint => 'Search by drug name...';

  @override
  String get searchNearest => 'Nearest';

  @override
  String get searchCouldntSearch => 'Couldn\'t search listings';

  @override
  String get searchLoadMore => 'Load more';

  @override
  String get searchLoadMoreError => 'Couldn\'t load more listings — try again.';

  @override
  String get searchNoMatches => 'No listings match your filters';

  @override
  String get searchTryDifferent =>
      'Try a different drug name, type, or governorate.';

  @override
  String get searchNotifyMeSet => 'We\'ll notify you when it\'s available.';

  @override
  String get searchNotifyMeBody =>
      'We\'ll let you know when a matching listing appears.';

  @override
  String get searchNotifyMeCta => 'Notify me when available';

  @override
  String searchNotifyMeError(Object error) {
    return 'Couldn\'t set up the alert: $error';
  }

  @override
  String get searchFilters => 'Filters';

  @override
  String get fieldType => 'Type';

  @override
  String get searchAllTypes => 'All types';

  @override
  String get searchAllGovernorates => 'All';

  @override
  String get fieldConcentration => 'Concentration';

  @override
  String get searchAnyConcentration => 'Any concentration';

  @override
  String get searchConcentrationHint => 'e.g. 500mg';

  @override
  String searchUseConcentration(Object value) {
    return 'Use \"$value\"';
  }

  @override
  String get searchExpiryBefore => 'Expiry before';

  @override
  String get searchClear => 'Clear';

  @override
  String get searchApply => 'Apply';

  @override
  String get mapViewButtonView => 'View';

  @override
  String mapPinnedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pharmacies',
      one: '1 pharmacy',
    );
    return '$_temp0';
  }

  @override
  String listingQtyLabel(Object quantity) {
    return 'Qty $quantity';
  }

  @override
  String get listingEditPrice => 'Edit price';

  @override
  String get fieldPriceEgp => 'Price (EGP)';

  @override
  String get listingPriceValidator => 'Enter a valid price';

  @override
  String get fieldDiscountPriceOptional => 'Discount price (optional)';

  @override
  String get listingDiscountExceedsPrice => 'Can\'t exceed the price';

  @override
  String get listingSavePrice => 'Save price';

  @override
  String listingCouldntUpdatePrice(Object error) {
    return 'Couldn\'t update price: $error';
  }

  @override
  String get listingMessageSeller => 'Message the seller';

  @override
  String get listingMessageSellerBody =>
      'Optional — say what you need. A default greeting is sent if you leave this blank.';

  @override
  String get listingSendRequest => 'Send request';

  @override
  String listingCouldntSendRequest(Object error) {
    return 'Could not send request: $error';
  }

  @override
  String get listingCouldntLoad => 'Couldn\'t load this listing';

  @override
  String get listingControlledSubstance => 'Controlled substance';

  @override
  String get fieldTypeLabel => 'Type';

  @override
  String get fieldConcentrationLabel => 'Concentration';

  @override
  String get fieldQuantityLabel => 'Quantity';

  @override
  String get fieldExpiryDateLabel => 'Expiry Date';

  @override
  String get listingSetPrice => 'Set a price';

  @override
  String get listingEditPriceLink => 'Edit price';

  @override
  String get listingAcceptedAlternatives => 'Accepted alternatives';

  @override
  String listingDistanceAway(Object distance) {
    return '$distance km away';
  }

  @override
  String listingExpires(Object date) {
    return 'Expires $date';
  }

  @override
  String get listingYourOwn => 'This is your own listing.';

  @override
  String get listingNoLongerAvailable =>
      'This listing is no longer available to request.';

  @override
  String get listingContact => 'Contact';

  @override
  String get listingBuyNow => 'Buy now';

  @override
  String get listingExchange => 'Exchange';

  @override
  String get listingGreetingInterested =>
      'Hi, I\'m interested in this listing.';

  @override
  String get listingGreetingGoAhead =>
      'Hi, I\'d like to go ahead with this listing.';

  @override
  String listingPercentOff(Object pct) {
    return '-$pct% OFF';
  }

  @override
  String get listingFavoriteTooltip => 'Add to favorites';

  @override
  String get listingUnfavoriteTooltip => 'Remove from favorites';

  @override
  String listingCouldntToggleFavorite(Object error) {
    return 'Couldn\'t update favorites: $error';
  }

  @override
  String get chatTitle => 'Chat';

  @override
  String get chatCouldntLoad => 'Couldn\'t load conversations';

  @override
  String get chatEmpty => 'No conversations yet';

  @override
  String get chatEmptyBody =>
      'Request a listing from Search or Home to start a chat with its seller.';

  @override
  String get chatNoMessagesYet => 'No messages yet';

  @override
  String chatCouldntSend(Object error) {
    return 'Couldn\'t send: $error';
  }

  @override
  String chatCouldntSendAttachment(Object error) {
    return 'Couldn\'t send attachment: $error';
  }

  @override
  String chatCouldntUpdateDeal(Object error) {
    return 'Couldn\'t update deal: $error';
  }

  @override
  String get chatDealCompletedTitle => 'Deal completed';

  @override
  String get chatDealCompletedBody =>
      'The exchange is confirmed. You can rate this pharmacy from the chat.';

  @override
  String get chatRateThisPharmacy => 'Rate this pharmacy';

  @override
  String get chatOverall => 'Overall';

  @override
  String get chatCredibility => 'Credibility';

  @override
  String get chatResponsiveness => 'Responsiveness';

  @override
  String get chatPackaging => 'Packaging';

  @override
  String get chatSubmitRating => 'Submit rating';

  @override
  String get chatRatingSubmitted => 'Rating submitted — thank you.';

  @override
  String chatCouldntSubmitRating(Object error) {
    return 'Couldn\'t submit rating: $error';
  }

  @override
  String get chatReportIssue => 'Report an issue';

  @override
  String get chatReportBody =>
      'This notifies the other pharmacy and stays visible until it\'s resolved.';

  @override
  String get fieldReason => 'Reason';

  @override
  String get chatDetailsOptional => 'Details (optional)';

  @override
  String get chatAttachEvidence => 'Attach evidence photo (optional)';

  @override
  String get chatPhotoAttached => 'Photo attached';

  @override
  String get chatSubmitReport => 'Submit report';

  @override
  String get chatReportSubmitted => 'Report submitted.';

  @override
  String chatCouldntSubmitReport(Object error) {
    return 'Couldn\'t submit report: $error';
  }

  @override
  String get chatHeaderFallback => 'Chat';

  @override
  String get chatReportTooltip => 'Report an issue';

  @override
  String get chatCouldntLoadMessages => 'Couldn\'t load messages';

  @override
  String get chatMarkComplete => 'Mark complete';

  @override
  String get chatDeclineCancel => 'Decline / cancel';

  @override
  String get chatCancelRequest => 'Cancel request';

  @override
  String get chatDealClosedRated => 'Deal closed — thanks for rating.';

  @override
  String get chatDealClosed => 'This deal is closed.';

  @override
  String get chatTypeMessage => 'Type a message...';

  @override
  String get chatAttach => 'Attach';

  @override
  String get chatTakePhoto => 'Take photo';

  @override
  String get chatChoosePhotos => 'Choose photos';

  @override
  String get chatAttachPdf => 'PDF document';

  @override
  String get chatShareLocation => 'Share location';

  @override
  String get chatTapToViewPhoto => 'Tap to view photo';

  @override
  String get chatTapToOpenPdf => 'Tap to open PDF';

  @override
  String get chatOpenInMaps => 'Open in Maps';

  @override
  String get chatLocationPermissionDenied => 'Location permission denied';

  @override
  String chatCouldntShareLocation(Object error) {
    return 'Couldn\'t share location: $error';
  }

  @override
  String chatCouldntOpenAttachment(Object error) {
    return 'Couldn\'t open attachment: $error';
  }

  @override
  String get chatMarkCompleteConfirmTitle => 'Mark deal complete?';

  @override
  String get chatMarkCompleteConfirmBody =>
      'This confirms the exchange happened and closes the listing.';

  @override
  String get chatCancelConfirmTitle => 'Cancel this deal?';

  @override
  String get chatCancelConfirmBody =>
      'The listing goes back to available for other pharmacies.';

  @override
  String get chatDealCompletedBar => 'Deal completed';

  @override
  String get chatDealCancelledBar => 'Deal cancelled';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileAccountSettingsTooltip => 'Account settings';

  @override
  String get profileCouldntLoad => 'Couldn\'t load profile';

  @override
  String get profileStatRating => 'Rating';

  @override
  String get profileStatExchanges => 'Exchanges';

  @override
  String get profileStatActive => 'Active';

  @override
  String get profileNoRatingsYet =>
      'No ratings yet — they show up here after your first completed deal.';

  @override
  String get profileRatingsReviews => 'Ratings & reviews';

  @override
  String profileRatingCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '($count ratings)',
      one: '(1 rating)',
    );
    return '$_temp0';
  }

  @override
  String get profileCredibility => 'Credibility';

  @override
  String get profileResponsiveness => 'Responsiveness';

  @override
  String get profilePackaging => 'Packaging';

  @override
  String get profileMyListings => 'My Listings';

  @override
  String get profileMyFavorites => 'My Favorites';

  @override
  String get profileDisputes => 'Disputes';

  @override
  String get profileLanguage => 'Language';

  @override
  String get accountSettingsTitle => 'Account settings';

  @override
  String get accountCouldntLoad => 'Couldn\'t load account details';

  @override
  String get accountEditProfile => 'Edit profile';

  @override
  String get accountEditProfileSubtitle => 'Name, phone, and address';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String accountPlanSuffix(Object plan) {
    return '$plan plan';
  }

  @override
  String get accountNoTrialCountdown => 'No trial countdown for this plan.';

  @override
  String get accountTrialEnded => 'Your trial has ended.';

  @override
  String accountTrialDaysLeft(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left in your trial.',
      one: '1 day left in your trial.',
    );
    return '$_temp0';
  }

  @override
  String get editProfileTitle => 'Edit profile';

  @override
  String get editProfileFillRequired => 'Fill in all required fields.';

  @override
  String get editProfileCouldntSave =>
      'Couldn\'t save your changes — try again.';

  @override
  String get editProfileCouldntLoad => 'Couldn\'t load your profile';

  @override
  String get editProfileNameValidator => 'Enter the full pharmacy name';

  @override
  String get fieldPhoneNumber => 'Phone number';

  @override
  String get editProfileAreaValidator => 'Enter your area';

  @override
  String get editProfileAddressValidator => 'Enter your address';

  @override
  String get editProfileSaveChanges => 'Save changes';

  @override
  String get disputesTitle => 'Disputes';

  @override
  String get disputesCouldntLoad => 'Couldn\'t load disputes';

  @override
  String get disputesEmpty => 'No disputes';

  @override
  String get disputesEmptyBody =>
      'You can report an issue with a deal from that deal\'s chat thread.';

  @override
  String get disputeRaisedByYou => 'You reported';

  @override
  String disputeRaisedByOther(Object name) {
    return '$name reported';
  }

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsCouldntLoad => 'Couldn\'t load notifications';

  @override
  String get notificationsEmpty => 'No notifications yet';

  @override
  String get notificationsDeleteError => 'Couldn\'t delete — try again.';

  @override
  String get newsTitle => 'News';

  @override
  String get newsAll => 'All';

  @override
  String get newsCouldntLoad => 'Couldn\'t load news';

  @override
  String get newsEmptyCategory => 'No articles in this category yet';

  @override
  String get newsDetailCouldntLoad => 'Couldn\'t load this article';

  @override
  String get priceAlertsTitle => 'Price Increased';

  @override
  String get priceAlertsCouldntLoad => 'Couldn\'t load price alerts';

  @override
  String get priceAlertsEmpty => 'No market price alerts right now';

  @override
  String get notFoundTitle => 'Page not found';

  @override
  String get notFoundBody =>
      'The page you\'re looking for doesn\'t exist or has moved.';

  @override
  String get notFoundGoHome => 'Go home';

  @override
  String get addMedicineTitle => 'Add medicine';

  @override
  String get addMedicineHeading => 'List a medicine';

  @override
  String get addMedicineSubtitle =>
      'Sell, request, or barter surplus stock with nearby pharmacies.';

  @override
  String get fieldMedicine => 'Medicine';

  @override
  String get addMedicineTapToSearch => 'Tap to search or type a medicine name';

  @override
  String get fieldManufacturer => 'Manufacturer';

  @override
  String get fieldForm => 'Form';

  @override
  String get addMedicineControlledTitle =>
      'Controlled substance — can\'t be listed here';

  @override
  String addMedicineControlledBody(Object name) {
    return '$name is a controlled substance. Pharma Exchange Egypt doesn\'t support self-service listing of controlled substances yet — contact support if you believe this is an error.';
  }

  @override
  String get addMedicineChooseDifferent => 'Choose a different medicine';

  @override
  String get fieldListingType => 'Listing type';

  @override
  String get fieldQuantity => 'Quantity';

  @override
  String get addMedicineQuantityValidator => 'Enter a valid quantity';

  @override
  String get fieldDiscountPrice => 'Discount price';

  @override
  String get addMedicineDiscountExceeds => 'Can\'t exceed price';

  @override
  String get fieldDescription => 'Description';

  @override
  String get addMedicineDescriptionHint =>
      'Optional — packaging, condition, or anything else buyers should know.';

  @override
  String get fieldExpiryDate => 'Expiry date';

  @override
  String get addMedicineExpiryHint => 'Must be a future date';

  @override
  String get addMedicineAddAlternative => 'Add alternative';

  @override
  String get addMedicineAddPhoto => 'Add a photo (optional)';

  @override
  String get addMedicinePhotoAttached => 'Photo attached — tap to replace';

  @override
  String get addMedicineCouldntCreate =>
      'Couldn\'t create listing — try again.';

  @override
  String get addMedicineCreateListing => 'Create listing';

  @override
  String get addMedicineMissingFields =>
      'Choose a medicine, listing type, and expiry date.';

  @override
  String get addMedicineSuccessTitle => 'Listing created';

  @override
  String get addMedicineSuccessBody =>
      'Your medicine is now visible to nearby pharmacies.';

  @override
  String get addMedicineSearchHint => 'Search or type a medicine name…';

  @override
  String get addMedicineSearchPrompt =>
      'Start typing to search ~23,600 medicines';

  @override
  String addMedicineUseCustom(Object name) {
    return 'Use \"$name\"';
  }

  @override
  String get addMedicineNotInCatalog =>
      'Not in the catalog — list it under this name';

  @override
  String get addMedicineNoMatches =>
      'No catalog matches — you can still use the option above.';

  @override
  String get addMedicineCouldntSelect =>
      'Couldn\'t select that medicine — try again.';

  @override
  String get myListingsTitle => 'My Listings';

  @override
  String get myListingsCouldntLoad => 'Couldn\'t load your listings';

  @override
  String get myListingsEmpty => 'No listings yet';

  @override
  String myListingsEmptyFiltered(Object state) {
    return 'No $state listings';
  }

  @override
  String get myListingsEmptyBody => 'Medicines you list will show up here.';

  @override
  String get favoritesTitle => 'My Favorites';

  @override
  String get favoritesCouldntLoad => 'Couldn\'t load your favorites';

  @override
  String get favoritesEmpty => 'No favorites yet';

  @override
  String get favoritesEmptyBody =>
      'Tap the heart on a listing to save it here.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';
}
