import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get commonView;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navNews.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get navNews;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @listingTypeSell.
  ///
  /// In en, this message translates to:
  /// **'Sell'**
  String get listingTypeSell;

  /// No description provided for @listingTypeBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get listingTypeBuy;

  /// No description provided for @listingTypeExchange.
  ///
  /// In en, this message translates to:
  /// **'Exchange'**
  String get listingTypeExchange;

  /// No description provided for @listingStateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get listingStateAvailable;

  /// No description provided for @listingStateReserved.
  ///
  /// In en, this message translates to:
  /// **'Reserved'**
  String get listingStateReserved;

  /// No description provided for @listingStateCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get listingStateCompleted;

  /// No description provided for @listingStateCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get listingStateCancelled;

  /// No description provided for @disputeStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get disputeStatusOpen;

  /// No description provided for @disputeStatusUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get disputeStatusUnderReview;

  /// No description provided for @disputeStatusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get disputeStatusResolved;

  /// No description provided for @newsCategoryRegulatory.
  ///
  /// In en, this message translates to:
  /// **'Regulatory'**
  String get newsCategoryRegulatory;

  /// No description provided for @newsCategoryMarketPricing.
  ///
  /// In en, this message translates to:
  /// **'Market Pricing'**
  String get newsCategoryMarketPricing;

  /// No description provided for @newsCategoryCompanyNews.
  ///
  /// In en, this message translates to:
  /// **'Company News'**
  String get newsCategoryCompanyNews;

  /// No description provided for @newsCategoryRecallsSafety.
  ///
  /// In en, this message translates to:
  /// **'Recalls & Safety'**
  String get newsCategoryRecallsSafety;

  /// No description provided for @newsCategoryIndustryEvents.
  ///
  /// In en, this message translates to:
  /// **'Industry Events'**
  String get newsCategoryIndustryEvents;

  /// No description provided for @newsCategoryEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get newsCategoryEducation;

  /// No description provided for @planTrial.
  ///
  /// In en, this message translates to:
  /// **'Trial'**
  String get planTrial;

  /// No description provided for @planFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get planFree;

  /// No description provided for @planActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get planActive;

  /// No description provided for @disputeReasonNotAsDescribed.
  ///
  /// In en, this message translates to:
  /// **'Item not as described'**
  String get disputeReasonNotAsDescribed;

  /// No description provided for @disputeReasonNonDelivery.
  ///
  /// In en, this message translates to:
  /// **'Non-delivery'**
  String get disputeReasonNonDelivery;

  /// No description provided for @disputeReasonQuantityMismatch.
  ///
  /// In en, this message translates to:
  /// **'Quantity mismatch'**
  String get disputeReasonQuantityMismatch;

  /// No description provided for @disputeReasonPaymentIssue.
  ///
  /// In en, this message translates to:
  /// **'Payment issue'**
  String get disputeReasonPaymentIssue;

  /// No description provided for @disputeReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get disputeReasonOther;

  /// No description provided for @onboardSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardSkip;

  /// No description provided for @onboardSlide1Title.
  ///
  /// In en, this message translates to:
  /// **'Move near-expiry stock'**
  String get onboardSlide1Title;

  /// No description provided for @onboardSlide1Body.
  ///
  /// In en, this message translates to:
  /// **'List surplus medication before it expires instead of writing it off.'**
  String get onboardSlide1Body;

  /// No description provided for @onboardSlide2Title.
  ///
  /// In en, this message translates to:
  /// **'Barter, sell, or buy'**
  String get onboardSlide2Title;

  /// No description provided for @onboardSlide2Body.
  ///
  /// In en, this message translates to:
  /// **'Trade directly with licensed pharmacies nearby — no wholesaler in between.'**
  String get onboardSlide2Body;

  /// No description provided for @onboardSlide3Title.
  ///
  /// In en, this message translates to:
  /// **'Licensed pharmacies only'**
  String get onboardSlide3Title;

  /// No description provided for @onboardSlide3Body.
  ///
  /// In en, this message translates to:
  /// **'Every account is KYC-verified before it can list or trade.'**
  String get onboardSlide3Body;

  /// No description provided for @onboardGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardGetStarted;

  /// No description provided for @onboardNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardNext;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginWelcomeBack;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to trade with pharmacies across Egypt'**
  String get loginSubtitle;

  /// No description provided for @loginEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get loginEmailLabel;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordLabel;

  /// No description provided for @loginRememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get loginRememberMe;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @loginSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginSignIn;

  /// No description provided for @loginRegisterCta.
  ///
  /// In en, this message translates to:
  /// **'Register your pharmacy'**
  String get loginRegisterCta;

  /// No description provided for @loginResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get loginResetTitle;

  /// No description provided for @loginResetBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll email you a link to reset your password.'**
  String get loginResetBody;

  /// No description provided for @loginSendLink.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get loginSendLink;

  /// No description provided for @loginResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent to {email}'**
  String loginResetSent(Object email);

  /// No description provided for @loginResetError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the reset link — try again.'**
  String get loginResetError;

  /// No description provided for @loginError.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in — check your email and password.'**
  String get loginError;

  /// No description provided for @kycStepPharmacy.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get kycStepPharmacy;

  /// No description provided for @kycStepAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get kycStepAddress;

  /// No description provided for @kycStepLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get kycStepLicense;

  /// No description provided for @kycStepPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get kycStepPassword;

  /// No description provided for @kycRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Register your pharmacy'**
  String get kycRegisterTitle;

  /// No description provided for @kycPharmacyDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy details'**
  String get kycPharmacyDetailsTitle;

  /// No description provided for @kycPharmacyDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Must match the name on your physical license.'**
  String get kycPharmacyDetailsSubtitle;

  /// No description provided for @fieldPharmacyName.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy name'**
  String get fieldPharmacyName;

  /// No description provided for @kycPharmacyNameValidator.
  ///
  /// In en, this message translates to:
  /// **'Enter the full pharmacy name'**
  String get kycPharmacyNameValidator;

  /// No description provided for @fieldEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get fieldEmailAddress;

  /// No description provided for @kycEmailHint.
  ///
  /// In en, this message translates to:
  /// **'pharmacy@example.com'**
  String get kycEmailHint;

  /// No description provided for @kycEmailValidator.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get kycEmailValidator;

  /// No description provided for @kycAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Address & location'**
  String get kycAddressTitle;

  /// No description provided for @kycAddressSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The pin sets your exact position for proximity search — it does not have to match the text below word-for-word.'**
  String get kycAddressSubtitle;

  /// No description provided for @fieldGovernorate.
  ///
  /// In en, this message translates to:
  /// **'Governorate'**
  String get fieldGovernorate;

  /// No description provided for @fieldArea.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get fieldArea;

  /// No description provided for @fieldDetailedAddress.
  ///
  /// In en, this message translates to:
  /// **'Detailed street address'**
  String get fieldDetailedAddress;

  /// No description provided for @kycPinYourPharmacy.
  ///
  /// In en, this message translates to:
  /// **'Pin your pharmacy'**
  String get kycPinYourPharmacy;

  /// No description provided for @kycUseCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get kycUseCurrentLocation;

  /// No description provided for @kycTapToDropPin.
  ///
  /// In en, this message translates to:
  /// **'Drag the map to move the pin to your pharmacy.'**
  String get kycTapToDropPin;

  /// No description provided for @kycPinSet.
  ///
  /// In en, this message translates to:
  /// **'Pin set: {lat}, {lng}'**
  String kycPinSet(Object lat, Object lng);

  /// No description provided for @kycLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied — drop the pin manually instead.'**
  String get kycLocationDenied;

  /// No description provided for @kycLocationError.
  ///
  /// In en, this message translates to:
  /// **'Could not get your location — drop the pin manually instead.'**
  String get kycLocationError;

  /// No description provided for @kycFillRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Fill in governorate, area, and address.'**
  String get kycFillRequiredFields;

  /// No description provided for @kycDropPin.
  ///
  /// In en, this message translates to:
  /// **'Drop a pin on the map at your pharmacy\'s exact location.'**
  String get kycDropPin;

  /// No description provided for @kycLicenseTitle.
  ///
  /// In en, this message translates to:
  /// **'License verification'**
  String get kycLicenseTitle;

  /// No description provided for @kycLicenseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'JPG, PNG or PDF, up to 5MB.'**
  String get kycLicenseSubtitle;

  /// No description provided for @kycFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File is over the 5MB limit — pick a smaller image.'**
  String get kycFileTooLarge;

  /// No description provided for @kycTapToUpload.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload license'**
  String get kycTapToUpload;

  /// No description provided for @kycLicenseExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'License expiry date'**
  String get kycLicenseExpiryDate;

  /// No description provided for @kycUploadLicense.
  ///
  /// In en, this message translates to:
  /// **'Upload a photo or PDF of your pharmacy license.'**
  String get kycUploadLicense;

  /// No description provided for @kycSelectValidExpiry.
  ///
  /// In en, this message translates to:
  /// **'Select a valid, non-expired license expiry date.'**
  String get kycSelectValidExpiry;

  /// No description provided for @kycSetPassword.
  ///
  /// In en, this message translates to:
  /// **'Set a password'**
  String get kycSetPassword;

  /// No description provided for @kycPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'8+ characters, 1 uppercase, 1 number, 1 special character.'**
  String get kycPasswordSubtitle;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @fieldConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get fieldConfirmPassword;

  /// No description provided for @kycPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Min 8 characters, with an uppercase letter, a number, and a special character. Passwords must match.'**
  String get kycPasswordMismatch;

  /// No description provided for @kycSubmitForReview.
  ///
  /// In en, this message translates to:
  /// **'Submit for review'**
  String get kycSubmitForReview;

  /// No description provided for @kycVerifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get kycVerifyEmailTitle;

  /// No description provided for @kycOtpBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to {email}. It expires in 2 minutes.'**
  String kycOtpBody(Object email);

  /// No description provided for @kycOtpLabel.
  ///
  /// In en, this message translates to:
  /// **'OTP code'**
  String get kycOtpLabel;

  /// No description provided for @kycVerifyAndSubmit.
  ///
  /// In en, this message translates to:
  /// **'Verify & submit for review'**
  String get kycVerifyAndSubmit;

  /// No description provided for @kycPendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get kycPendingReview;

  /// No description provided for @kycRejectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get kycRejectedLabel;

  /// No description provided for @kycVerificationInProgress.
  ///
  /// In en, this message translates to:
  /// **'Verification in progress'**
  String get kycVerificationInProgress;

  /// No description provided for @kycApplicationRejected.
  ///
  /// In en, this message translates to:
  /// **'Application rejected'**
  String get kycApplicationRejected;

  /// No description provided for @kycRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Your license could not be verified. Contact support to resubmit.'**
  String get kycRejectedBody;

  /// No description provided for @kycPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Our team is reviewing your license. This usually takes up to 24 hours — this screen updates automatically once a decision is made.'**
  String get kycPendingBody;

  /// No description provided for @homeWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back,'**
  String get homeWelcomeBack;

  /// No description provided for @homeStatActiveListings.
  ///
  /// In en, this message translates to:
  /// **'Active Listings'**
  String get homeStatActiveListings;

  /// No description provided for @homeStatExchanges.
  ///
  /// In en, this message translates to:
  /// **'Exchanges'**
  String get homeStatExchanges;

  /// No description provided for @homeStatRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get homeStatRating;

  /// No description provided for @homeQuickSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get homeQuickSearch;

  /// No description provided for @homeQuickAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get homeQuickAdd;

  /// No description provided for @homeQuickChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get homeQuickChat;

  /// No description provided for @homePriceIncreased.
  ///
  /// In en, this message translates to:
  /// **'Price Increased'**
  String get homePriceIncreased;

  /// No description provided for @homeNoPriceAlerts.
  ///
  /// In en, this message translates to:
  /// **'No market price alerts right now — check back later.'**
  String get homeNoPriceAlerts;

  /// No description provided for @homeSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get homeSeeAll;

  /// No description provided for @homeLatestMedicines.
  ///
  /// In en, this message translates to:
  /// **'Latest Medicines'**
  String get homeLatestMedicines;

  /// No description provided for @homeViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get homeViewAll;

  /// No description provided for @homeNoListingsNearby.
  ///
  /// In en, this message translates to:
  /// **'No listings near you yet'**
  String get homeNoListingsNearby;

  /// No description provided for @homeAddFirstMedicine.
  ///
  /// In en, this message translates to:
  /// **'Tap the Add tab below to list your first medicine.'**
  String get homeAddFirstMedicine;

  /// No description provided for @homeCouldntLoadListings.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load listings'**
  String get homeCouldntLoadListings;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @searchListView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get searchListView;

  /// No description provided for @searchMapViewTooltip.
  ///
  /// In en, this message translates to:
  /// **'Map view'**
  String get searchMapViewTooltip;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by drug name...'**
  String get searchHint;

  /// No description provided for @searchNearest.
  ///
  /// In en, this message translates to:
  /// **'Nearest'**
  String get searchNearest;

  /// No description provided for @searchCouldntSearch.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t search listings'**
  String get searchCouldntSearch;

  /// No description provided for @searchLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get searchLoadMore;

  /// No description provided for @searchLoadMoreError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more listings — try again.'**
  String get searchLoadMoreError;

  /// No description provided for @searchNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No listings match your filters'**
  String get searchNoMatches;

  /// No description provided for @searchTryDifferent.
  ///
  /// In en, this message translates to:
  /// **'Try a different drug name, type, or governorate.'**
  String get searchTryDifferent;

  /// No description provided for @searchNotifyMeSet.
  ///
  /// In en, this message translates to:
  /// **'We\'ll notify you when it\'s available.'**
  String get searchNotifyMeSet;

  /// No description provided for @searchNotifyMeBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll let you know when a matching listing appears.'**
  String get searchNotifyMeBody;

  /// No description provided for @searchNotifyMeCta.
  ///
  /// In en, this message translates to:
  /// **'Notify me when available'**
  String get searchNotifyMeCta;

  /// No description provided for @searchNotifyMeError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t set up the alert: {error}'**
  String searchNotifyMeError(Object error);

  /// No description provided for @searchFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get searchFilters;

  /// No description provided for @fieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get fieldType;

  /// No description provided for @searchAllTypes.
  ///
  /// In en, this message translates to:
  /// **'All types'**
  String get searchAllTypes;

  /// No description provided for @searchAllGovernorates.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchAllGovernorates;

  /// No description provided for @fieldConcentration.
  ///
  /// In en, this message translates to:
  /// **'Concentration'**
  String get fieldConcentration;

  /// No description provided for @searchAnyConcentration.
  ///
  /// In en, this message translates to:
  /// **'Any concentration'**
  String get searchAnyConcentration;

  /// No description provided for @searchConcentrationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 500mg'**
  String get searchConcentrationHint;

  /// No description provided for @searchUseConcentration.
  ///
  /// In en, this message translates to:
  /// **'Use \"{value}\"'**
  String searchUseConcentration(Object value);

  /// No description provided for @searchExpiryBefore.
  ///
  /// In en, this message translates to:
  /// **'Expiry before'**
  String get searchExpiryBefore;

  /// No description provided for @searchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchClear;

  /// No description provided for @searchApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get searchApply;

  /// No description provided for @mapViewButtonView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get mapViewButtonView;

  /// No description provided for @mapPinnedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 pharmacy} other{{count} pharmacies}}'**
  String mapPinnedCount(num count);

  /// No description provided for @listingQtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Qty {quantity}'**
  String listingQtyLabel(Object quantity);

  /// No description provided for @fieldPriceEgp.
  ///
  /// In en, this message translates to:
  /// **'Price (EGP)'**
  String get fieldPriceEgp;

  /// No description provided for @listingPriceValidator.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price'**
  String get listingPriceValidator;

  /// No description provided for @fieldDiscountPriceOptional.
  ///
  /// In en, this message translates to:
  /// **'Discount price (optional)'**
  String get fieldDiscountPriceOptional;

  /// No description provided for @listingDiscountExceedsPrice.
  ///
  /// In en, this message translates to:
  /// **'Can\'t exceed the price'**
  String get listingDiscountExceedsPrice;

  /// No description provided for @listingMessageSeller.
  ///
  /// In en, this message translates to:
  /// **'Message the seller'**
  String get listingMessageSeller;

  /// No description provided for @listingMessageSellerBody.
  ///
  /// In en, this message translates to:
  /// **'Optional — say what you need. A default greeting is sent if you leave this blank.'**
  String get listingMessageSellerBody;

  /// No description provided for @listingSendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get listingSendRequest;

  /// No description provided for @listingCouldntSendRequest.
  ///
  /// In en, this message translates to:
  /// **'Could not send request: {error}'**
  String listingCouldntSendRequest(Object error);

  /// No description provided for @listingCouldntLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this listing'**
  String get listingCouldntLoad;

  /// No description provided for @listingControlledSubstance.
  ///
  /// In en, this message translates to:
  /// **'Controlled substance'**
  String get listingControlledSubstance;

  /// No description provided for @fieldTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get fieldTypeLabel;

  /// No description provided for @fieldConcentrationLabel.
  ///
  /// In en, this message translates to:
  /// **'Concentration'**
  String get fieldConcentrationLabel;

  /// No description provided for @fieldQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get fieldQuantityLabel;

  /// No description provided for @fieldExpiryDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date'**
  String get fieldExpiryDateLabel;

  /// No description provided for @listingSetPrice.
  ///
  /// In en, this message translates to:
  /// **'Set a price'**
  String get listingSetPrice;

  /// No description provided for @listingAcceptedAlternatives.
  ///
  /// In en, this message translates to:
  /// **'Accepted alternatives'**
  String get listingAcceptedAlternatives;

  /// No description provided for @listingDistanceAway.
  ///
  /// In en, this message translates to:
  /// **'{distance} km away'**
  String listingDistanceAway(Object distance);

  /// No description provided for @listingExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String listingExpires(Object date);

  /// No description provided for @listingYourOwn.
  ///
  /// In en, this message translates to:
  /// **'This is your own listing.'**
  String get listingYourOwn;

  /// No description provided for @listingNoLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'This listing is no longer available to request.'**
  String get listingNoLongerAvailable;

  /// No description provided for @listingContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get listingContact;

  /// No description provided for @listingBuyNow.
  ///
  /// In en, this message translates to:
  /// **'Buy now'**
  String get listingBuyNow;

  /// No description provided for @listingExchange.
  ///
  /// In en, this message translates to:
  /// **'Exchange'**
  String get listingExchange;

  /// No description provided for @listingGreetingInterested.
  ///
  /// In en, this message translates to:
  /// **'Hi, I\'m interested in this listing.'**
  String get listingGreetingInterested;

  /// No description provided for @listingGreetingGoAhead.
  ///
  /// In en, this message translates to:
  /// **'Hi, I\'d like to go ahead with this listing.'**
  String get listingGreetingGoAhead;

  /// No description provided for @listingPercentOff.
  ///
  /// In en, this message translates to:
  /// **'-{pct}% OFF'**
  String listingPercentOff(Object pct);

  /// No description provided for @listingFavoriteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get listingFavoriteTooltip;

  /// No description provided for @listingUnfavoriteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get listingUnfavoriteTooltip;

  /// No description provided for @listingCouldntToggleFavorite.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update favorites: {error}'**
  String listingCouldntToggleFavorite(Object error);

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTitle;

  /// No description provided for @chatCouldntLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load conversations'**
  String get chatCouldntLoad;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get chatEmpty;

  /// No description provided for @chatEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Request a listing from Search or Home to start a chat with its seller.'**
  String get chatEmptyBody;

  /// No description provided for @chatNoMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get chatNoMessagesYet;

  /// No description provided for @chatCouldntSend.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send: {error}'**
  String chatCouldntSend(Object error);

  /// No description provided for @chatCouldntSendAttachment.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send attachment: {error}'**
  String chatCouldntSendAttachment(Object error);

  /// No description provided for @chatCouldntUpdateDeal.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update deal: {error}'**
  String chatCouldntUpdateDeal(Object error);

  /// No description provided for @chatDealCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Deal completed'**
  String get chatDealCompletedTitle;

  /// No description provided for @chatDealCompletedBody.
  ///
  /// In en, this message translates to:
  /// **'The exchange is confirmed. You can rate this pharmacy from the chat.'**
  String get chatDealCompletedBody;

  /// No description provided for @chatRateThisPharmacy.
  ///
  /// In en, this message translates to:
  /// **'Rate this pharmacy'**
  String get chatRateThisPharmacy;

  /// No description provided for @chatOverall.
  ///
  /// In en, this message translates to:
  /// **'Overall'**
  String get chatOverall;

  /// No description provided for @chatCredibility.
  ///
  /// In en, this message translates to:
  /// **'Credibility'**
  String get chatCredibility;

  /// No description provided for @chatResponsiveness.
  ///
  /// In en, this message translates to:
  /// **'Responsiveness'**
  String get chatResponsiveness;

  /// No description provided for @chatPackaging.
  ///
  /// In en, this message translates to:
  /// **'Packaging'**
  String get chatPackaging;

  /// No description provided for @chatSubmitRating.
  ///
  /// In en, this message translates to:
  /// **'Submit rating'**
  String get chatSubmitRating;

  /// No description provided for @chatRatingSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Rating submitted — thank you.'**
  String get chatRatingSubmitted;

  /// No description provided for @chatCouldntSubmitRating.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit rating: {error}'**
  String chatCouldntSubmitRating(Object error);

  /// No description provided for @chatReportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report an issue'**
  String get chatReportIssue;

  /// No description provided for @chatReportBody.
  ///
  /// In en, this message translates to:
  /// **'This notifies the other pharmacy and stays visible until it\'s resolved.'**
  String get chatReportBody;

  /// No description provided for @fieldReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get fieldReason;

  /// No description provided for @chatDetailsOptional.
  ///
  /// In en, this message translates to:
  /// **'Details (optional)'**
  String get chatDetailsOptional;

  /// No description provided for @chatAttachEvidence.
  ///
  /// In en, this message translates to:
  /// **'Attach evidence photo (optional)'**
  String get chatAttachEvidence;

  /// No description provided for @chatPhotoAttached.
  ///
  /// In en, this message translates to:
  /// **'Photo attached'**
  String get chatPhotoAttached;

  /// No description provided for @chatSubmitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get chatSubmitReport;

  /// No description provided for @chatReportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report submitted.'**
  String get chatReportSubmitted;

  /// No description provided for @chatCouldntSubmitReport.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit report: {error}'**
  String chatCouldntSubmitReport(Object error);

  /// No description provided for @chatHeaderFallback.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatHeaderFallback;

  /// No description provided for @chatReportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Report an issue'**
  String get chatReportTooltip;

  /// No description provided for @chatCouldntLoadMessages.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load messages'**
  String get chatCouldntLoadMessages;

  /// No description provided for @chatMarkComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark complete'**
  String get chatMarkComplete;

  /// No description provided for @chatDeclineCancel.
  ///
  /// In en, this message translates to:
  /// **'Decline / cancel'**
  String get chatDeclineCancel;

  /// No description provided for @chatCancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get chatCancelRequest;

  /// No description provided for @chatDealClosedRated.
  ///
  /// In en, this message translates to:
  /// **'Deal closed — thanks for rating.'**
  String get chatDealClosedRated;

  /// No description provided for @chatDealClosed.
  ///
  /// In en, this message translates to:
  /// **'This deal is closed.'**
  String get chatDealClosed;

  /// No description provided for @chatTypeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get chatTypeMessage;

  /// No description provided for @chatAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get chatAttach;

  /// No description provided for @chatTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get chatTakePhoto;

  /// No description provided for @chatChoosePhotos.
  ///
  /// In en, this message translates to:
  /// **'Choose photos'**
  String get chatChoosePhotos;

  /// No description provided for @chatAttachPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF document'**
  String get chatAttachPdf;

  /// No description provided for @chatShareLocation.
  ///
  /// In en, this message translates to:
  /// **'Share location'**
  String get chatShareLocation;

  /// No description provided for @chatTapToViewPhoto.
  ///
  /// In en, this message translates to:
  /// **'Tap to view photo'**
  String get chatTapToViewPhoto;

  /// No description provided for @chatTapToOpenPdf.
  ///
  /// In en, this message translates to:
  /// **'Tap to open PDF'**
  String get chatTapToOpenPdf;

  /// No description provided for @chatOpenInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Maps'**
  String get chatOpenInMaps;

  /// No description provided for @chatLocationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get chatLocationPermissionDenied;

  /// No description provided for @chatCouldntShareLocation.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t share location: {error}'**
  String chatCouldntShareLocation(Object error);

  /// No description provided for @chatCouldntOpenAttachment.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open attachment: {error}'**
  String chatCouldntOpenAttachment(Object error);

  /// No description provided for @chatMarkCompleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark deal complete?'**
  String get chatMarkCompleteConfirmTitle;

  /// No description provided for @chatMarkCompleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This confirms the exchange happened and closes the listing.'**
  String get chatMarkCompleteConfirmBody;

  /// No description provided for @chatCancelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this deal?'**
  String get chatCancelConfirmTitle;

  /// No description provided for @chatCancelConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The listing goes back to available for other pharmacies.'**
  String get chatCancelConfirmBody;

  /// No description provided for @chatDealCompletedBar.
  ///
  /// In en, this message translates to:
  /// **'Deal completed'**
  String get chatDealCompletedBar;

  /// No description provided for @chatDealCancelledBar.
  ///
  /// In en, this message translates to:
  /// **'Deal cancelled'**
  String get chatDealCancelledBar;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileAccountSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Account settings'**
  String get profileAccountSettingsTooltip;

  /// No description provided for @profileCouldntLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load profile'**
  String get profileCouldntLoad;

  /// No description provided for @profileStatRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get profileStatRating;

  /// No description provided for @profileStatExchanges.
  ///
  /// In en, this message translates to:
  /// **'Exchanges'**
  String get profileStatExchanges;

  /// No description provided for @profileStatActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get profileStatActive;

  /// No description provided for @profileNoRatingsYet.
  ///
  /// In en, this message translates to:
  /// **'No ratings yet — they show up here after your first completed deal.'**
  String get profileNoRatingsYet;

  /// No description provided for @profileRatingsReviews.
  ///
  /// In en, this message translates to:
  /// **'Ratings & reviews'**
  String get profileRatingsReviews;

  /// No description provided for @profileRatingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{(1 rating)} other{({count} ratings)}}'**
  String profileRatingCount(num count);

  /// No description provided for @profileCredibility.
  ///
  /// In en, this message translates to:
  /// **'Credibility'**
  String get profileCredibility;

  /// No description provided for @profileResponsiveness.
  ///
  /// In en, this message translates to:
  /// **'Responsiveness'**
  String get profileResponsiveness;

  /// No description provided for @profilePackaging.
  ///
  /// In en, this message translates to:
  /// **'Packaging'**
  String get profilePackaging;

  /// No description provided for @profileMyListings.
  ///
  /// In en, this message translates to:
  /// **'My Listings'**
  String get profileMyListings;

  /// No description provided for @profileMyFavorites.
  ///
  /// In en, this message translates to:
  /// **'My Favorites'**
  String get profileMyFavorites;

  /// No description provided for @profileDisputes.
  ///
  /// In en, this message translates to:
  /// **'Disputes'**
  String get profileDisputes;

  /// No description provided for @profileLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguage;

  /// No description provided for @accountSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Account settings'**
  String get accountSettingsTitle;

  /// No description provided for @accountCouldntLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load account details'**
  String get accountCouldntLoad;

  /// No description provided for @accountEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get accountEditProfile;

  /// No description provided for @accountEditProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Name, phone, and address'**
  String get accountEditProfileSubtitle;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @accountPlanSuffix.
  ///
  /// In en, this message translates to:
  /// **'{plan} plan'**
  String accountPlanSuffix(Object plan);

  /// No description provided for @accountNoTrialCountdown.
  ///
  /// In en, this message translates to:
  /// **'No trial countdown for this plan.'**
  String get accountNoTrialCountdown;

  /// No description provided for @accountTrialEnded.
  ///
  /// In en, this message translates to:
  /// **'Your trial has ended.'**
  String get accountTrialEnded;

  /// No description provided for @accountTrialDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, one{1 day left in your trial.} other{{days} days left in your trial.}}'**
  String accountTrialDaysLeft(num days);

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfileTitle;

  /// No description provided for @editProfileFillRequired.
  ///
  /// In en, this message translates to:
  /// **'Fill in all required fields.'**
  String get editProfileFillRequired;

  /// No description provided for @editProfileCouldntSave.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your changes — try again.'**
  String get editProfileCouldntSave;

  /// No description provided for @editProfileCouldntLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your profile'**
  String get editProfileCouldntLoad;

  /// No description provided for @editProfileNameValidator.
  ///
  /// In en, this message translates to:
  /// **'Enter the full pharmacy name'**
  String get editProfileNameValidator;

  /// No description provided for @fieldPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get fieldPhoneNumber;

  /// No description provided for @editProfileAreaValidator.
  ///
  /// In en, this message translates to:
  /// **'Enter your area'**
  String get editProfileAreaValidator;

  /// No description provided for @editProfileAddressValidator.
  ///
  /// In en, this message translates to:
  /// **'Enter your address'**
  String get editProfileAddressValidator;

  /// No description provided for @editProfileSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get editProfileSaveChanges;

  /// No description provided for @disputesTitle.
  ///
  /// In en, this message translates to:
  /// **'Disputes'**
  String get disputesTitle;

  /// No description provided for @disputesCouldntLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load disputes'**
  String get disputesCouldntLoad;

  /// No description provided for @disputesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No disputes'**
  String get disputesEmpty;

  /// No description provided for @disputesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'You can report an issue with a deal from that deal\'s chat thread.'**
  String get disputesEmptyBody;

  /// No description provided for @disputeRaisedByYou.
  ///
  /// In en, this message translates to:
  /// **'You reported'**
  String get disputeRaisedByYou;

  /// No description provided for @disputeRaisedByOther.
  ///
  /// In en, this message translates to:
  /// **'{name} reported'**
  String disputeRaisedByOther(Object name);

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsCouldntLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load notifications'**
  String get notificationsCouldntLoad;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsEmpty;

  /// No description provided for @notificationsDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete — try again.'**
  String get notificationsDeleteError;

  /// No description provided for @newsTitle.
  ///
  /// In en, this message translates to:
  /// **'News'**
  String get newsTitle;

  /// No description provided for @newsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get newsAll;

  /// No description provided for @newsCouldntLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load news'**
  String get newsCouldntLoad;

  /// No description provided for @newsEmptyCategory.
  ///
  /// In en, this message translates to:
  /// **'No articles in this category yet'**
  String get newsEmptyCategory;

  /// No description provided for @newsDetailCouldntLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this article'**
  String get newsDetailCouldntLoad;

  /// No description provided for @priceAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Price Increased'**
  String get priceAlertsTitle;

  /// No description provided for @priceAlertsCouldntLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load price alerts'**
  String get priceAlertsCouldntLoad;

  /// No description provided for @priceAlertsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No market price alerts right now'**
  String get priceAlertsEmpty;

  /// No description provided for @notFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get notFoundTitle;

  /// No description provided for @notFoundBody.
  ///
  /// In en, this message translates to:
  /// **'The page you\'re looking for doesn\'t exist or has moved.'**
  String get notFoundBody;

  /// No description provided for @notFoundGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get notFoundGoHome;

  /// No description provided for @addMedicineTitle.
  ///
  /// In en, this message translates to:
  /// **'Add medicine'**
  String get addMedicineTitle;

  /// No description provided for @addMedicineHeading.
  ///
  /// In en, this message translates to:
  /// **'List a medicine'**
  String get addMedicineHeading;

  /// No description provided for @addMedicineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sell, request, or barter surplus stock with nearby pharmacies.'**
  String get addMedicineSubtitle;

  /// No description provided for @fieldMedicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get fieldMedicine;

  /// No description provided for @addMedicineTapToSearch.
  ///
  /// In en, this message translates to:
  /// **'Tap to search or type a medicine name'**
  String get addMedicineTapToSearch;

  /// No description provided for @fieldManufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get fieldManufacturer;

  /// No description provided for @fieldForm.
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get fieldForm;

  /// No description provided for @addMedicineControlledTitle.
  ///
  /// In en, this message translates to:
  /// **'Controlled substance — can\'t be listed here'**
  String get addMedicineControlledTitle;

  /// No description provided for @addMedicineControlledBody.
  ///
  /// In en, this message translates to:
  /// **'{name} is a controlled substance. Pharma Exchange Egypt doesn\'t support self-service listing of controlled substances yet — contact support if you believe this is an error.'**
  String addMedicineControlledBody(Object name);

  /// No description provided for @addMedicineChooseDifferent.
  ///
  /// In en, this message translates to:
  /// **'Choose a different medicine'**
  String get addMedicineChooseDifferent;

  /// No description provided for @fieldListingType.
  ///
  /// In en, this message translates to:
  /// **'Listing type'**
  String get fieldListingType;

  /// No description provided for @fieldQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get fieldQuantity;

  /// No description provided for @addMedicineQuantityValidator.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid quantity'**
  String get addMedicineQuantityValidator;

  /// No description provided for @fieldDiscountPrice.
  ///
  /// In en, this message translates to:
  /// **'Discount price'**
  String get fieldDiscountPrice;

  /// No description provided for @addMedicineDiscountExceeds.
  ///
  /// In en, this message translates to:
  /// **'Can\'t exceed price'**
  String get addMedicineDiscountExceeds;

  /// No description provided for @fieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get fieldDescription;

  /// No description provided for @addMedicineDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — packaging, condition, or anything else buyers should know.'**
  String get addMedicineDescriptionHint;

  /// No description provided for @fieldExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry date'**
  String get fieldExpiryDate;

  /// No description provided for @addMedicineExpiryHint.
  ///
  /// In en, this message translates to:
  /// **'Must be a future date'**
  String get addMedicineExpiryHint;

  /// No description provided for @addMedicineAddAlternative.
  ///
  /// In en, this message translates to:
  /// **'Add alternative'**
  String get addMedicineAddAlternative;

  /// No description provided for @addMedicineAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a photo (optional)'**
  String get addMedicineAddPhoto;

  /// No description provided for @addMedicinePhotoAttached.
  ///
  /// In en, this message translates to:
  /// **'Photo attached — tap to replace'**
  String get addMedicinePhotoAttached;

  /// No description provided for @addMedicineCouldntCreate.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create listing — try again.'**
  String get addMedicineCouldntCreate;

  /// No description provided for @addMedicineCreateListing.
  ///
  /// In en, this message translates to:
  /// **'Create listing'**
  String get addMedicineCreateListing;

  /// No description provided for @addMedicineMissingFields.
  ///
  /// In en, this message translates to:
  /// **'Choose a medicine, listing type, and expiry date.'**
  String get addMedicineMissingFields;

  /// No description provided for @addMedicineSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Listing created'**
  String get addMedicineSuccessTitle;

  /// No description provided for @addMedicineSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Your medicine is now visible to nearby pharmacies.'**
  String get addMedicineSuccessBody;

  /// No description provided for @addMedicineSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search or type a medicine name…'**
  String get addMedicineSearchHint;

  /// No description provided for @addMedicineSearchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Start typing to search ~23,600 medicines'**
  String get addMedicineSearchPrompt;

  /// No description provided for @addMedicineUseCustom.
  ///
  /// In en, this message translates to:
  /// **'Use \"{name}\"'**
  String addMedicineUseCustom(Object name);

  /// No description provided for @addMedicineNotInCatalog.
  ///
  /// In en, this message translates to:
  /// **'Not in the catalog — list it under this name'**
  String get addMedicineNotInCatalog;

  /// No description provided for @addMedicineNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No catalog matches — you can still use the option above.'**
  String get addMedicineNoMatches;

  /// No description provided for @addMedicineCouldntSelect.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t select that medicine — try again.'**
  String get addMedicineCouldntSelect;

  /// No description provided for @myListingsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Listings'**
  String get myListingsTitle;

  /// No description provided for @myListingsCouldntLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your listings'**
  String get myListingsCouldntLoad;

  /// No description provided for @myListingsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No listings yet'**
  String get myListingsEmpty;

  /// No description provided for @myListingsEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No {state} listings'**
  String myListingsEmptyFiltered(Object state);

  /// No description provided for @myListingsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Medicines you list will show up here.'**
  String get myListingsEmptyBody;

  /// No description provided for @favoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'My Favorites'**
  String get favoritesTitle;

  /// No description provided for @favoritesCouldntLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your favorites'**
  String get favoritesCouldntLoad;

  /// No description provided for @favoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get favoritesEmpty;

  /// No description provided for @favoritesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on a listing to save it here.'**
  String get favoritesEmptyBody;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @commonSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get commonSubmit;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get commonSave;

  /// No description provided for @fieldDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get fieldDescriptionOptional;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get errorNetwork;

  /// No description provided for @errorAuthRequired.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again.'**
  String get errorAuthRequired;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get errorInvalidCredentials;

  /// No description provided for @errorEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email address first — check your inbox for the code.'**
  String get errorEmailNotConfirmed;

  /// No description provided for @errorEmailAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'An account already exists for this email. Try signing in.'**
  String get errorEmailAlreadyRegistered;

  /// No description provided for @errorOtpInvalid.
  ///
  /// In en, this message translates to:
  /// **'That code is wrong or has expired. Request a new one.'**
  String get errorOtpInvalid;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a minute and try again.'**
  String get errorRateLimited;

  /// No description provided for @errorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters with an uppercase letter, a number and a symbol.'**
  String get errorWeakPassword;

  /// No description provided for @errorFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That file is too large.'**
  String get errorFileTooLarge;

  /// No description provided for @errorFileType.
  ///
  /// In en, this message translates to:
  /// **'That file type isn’t supported.'**
  String get errorFileType;

  /// No description provided for @errorNotApproved.
  ///
  /// In en, this message translates to:
  /// **'Your pharmacy is still awaiting approval, so you can’t trade yet.'**
  String get errorNotApproved;

  /// No description provided for @errorAccountIsAdmin.
  ///
  /// In en, this message translates to:
  /// **'This is an admin account — use the admin dashboard instead.'**
  String get errorAccountIsAdmin;

  /// No description provided for @errorAccountHasActiveDeals.
  ///
  /// In en, this message translates to:
  /// **'Finish or cancel your open deals before deleting your account.'**
  String get errorAccountHasActiveDeals;

  /// No description provided for @errorAccountHasOpenDisputes.
  ///
  /// In en, this message translates to:
  /// **'You have an unresolved dispute. It must be closed before your account can be deleted.'**
  String get errorAccountHasOpenDisputes;

  /// No description provided for @errorListingNotFound.
  ///
  /// In en, this message translates to:
  /// **'This listing no longer exists.'**
  String get errorListingNotFound;

  /// No description provided for @errorListingOwn.
  ///
  /// In en, this message translates to:
  /// **'This is your own listing.'**
  String get errorListingOwn;

  /// No description provided for @errorListingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This listing is no longer available.'**
  String get errorListingUnavailable;

  /// No description provided for @errorListingExpired.
  ///
  /// In en, this message translates to:
  /// **'This listing’s medicine has passed its expiry date.'**
  String get errorListingExpired;

  /// No description provided for @errorListingExpiryInPast.
  ///
  /// In en, this message translates to:
  /// **'Pick an expiry date in the future.'**
  String get errorListingExpiryInPast;

  /// No description provided for @errorListingNotOwner.
  ///
  /// In en, this message translates to:
  /// **'This isn’t your listing.'**
  String get errorListingNotOwner;

  /// No description provided for @errorListingNotEditable.
  ///
  /// In en, this message translates to:
  /// **'This listing can no longer be edited.'**
  String get errorListingNotEditable;

  /// No description provided for @errorListingReservedNoEdit.
  ///
  /// In en, this message translates to:
  /// **'You can’t change the details while this listing is reserved for a buyer.'**
  String get errorListingReservedNoEdit;

  /// No description provided for @errorListingHasActiveDeal.
  ///
  /// In en, this message translates to:
  /// **'There’s an open request on this listing. Cancel it first.'**
  String get errorListingHasActiveDeal;

  /// No description provided for @errorQuantityInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid quantity.'**
  String get errorQuantityInvalid;

  /// No description provided for @errorPriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid price.'**
  String get errorPriceInvalid;

  /// No description provided for @errorDiscountInvalid.
  ///
  /// In en, this message translates to:
  /// **'The discount must be lower than the price.'**
  String get errorDiscountInvalid;

  /// No description provided for @errorControlledSubstance.
  ///
  /// In en, this message translates to:
  /// **'This is a controlled substance and can’t be listed here.'**
  String get errorControlledSubstance;

  /// No description provided for @errorDealNotFound.
  ///
  /// In en, this message translates to:
  /// **'This conversation no longer exists.'**
  String get errorDealNotFound;

  /// No description provided for @errorDealNotParticipant.
  ///
  /// In en, this message translates to:
  /// **'You’re not part of this deal.'**
  String get errorDealNotParticipant;

  /// No description provided for @errorDealAlreadyOpen.
  ///
  /// In en, this message translates to:
  /// **'You already have an open request on this listing.'**
  String get errorDealAlreadyOpen;

  /// No description provided for @errorDealSellerOnly.
  ///
  /// In en, this message translates to:
  /// **'Only the seller can do that.'**
  String get errorDealSellerOnly;

  /// No description provided for @errorDealNotPending.
  ///
  /// In en, this message translates to:
  /// **'This request has already been answered.'**
  String get errorDealNotPending;

  /// No description provided for @errorDealNotActive.
  ///
  /// In en, this message translates to:
  /// **'This deal is already closed.'**
  String get errorDealNotActive;

  /// No description provided for @errorDisputeAlreadyOpen.
  ///
  /// In en, this message translates to:
  /// **'You already have an open dispute on this deal.'**
  String get errorDisputeAlreadyOpen;

  /// No description provided for @errorDisputeReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Give a reason for the dispute.'**
  String get errorDisputeReasonRequired;

  /// No description provided for @errorRatingInvalidStars.
  ///
  /// In en, this message translates to:
  /// **'Pick a rating from 1 to 5 stars.'**
  String get errorRatingInvalidStars;

  /// No description provided for @errorRatingDealNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'You can only rate a completed deal.'**
  String get errorRatingDealNotCompleted;

  /// No description provided for @errorDrugNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the medicine name.'**
  String get errorDrugNameRequired;

  /// No description provided for @errorDrugNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'That medicine name is too long.'**
  String get errorDrugNameTooLong;

  /// No description provided for @errorPharmacyNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your pharmacy name.'**
  String get errorPharmacyNameRequired;

  /// No description provided for @errorGovernorateRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick your governorate.'**
  String get errorGovernorateRequired;

  /// No description provided for @errorLocationRequired.
  ///
  /// In en, this message translates to:
  /// **'Drop a pin on your pharmacy’s location.'**
  String get errorLocationRequired;

  /// No description provided for @errorLocationOutOfBounds.
  ///
  /// In en, this message translates to:
  /// **'That location isn’t inside Egypt.'**
  String get errorLocationOutOfBounds;

  /// No description provided for @errorLicenseRequired.
  ///
  /// In en, this message translates to:
  /// **'Upload your pharmacy licence.'**
  String get errorLicenseRequired;

  /// No description provided for @successGenericTitle.
  ///
  /// In en, this message translates to:
  /// **'All done'**
  String get successGenericTitle;

  /// No description provided for @successGenericBody.
  ///
  /// In en, this message translates to:
  /// **'That went through successfully.'**
  String get successGenericBody;

  /// No description provided for @successGenericCta.
  ///
  /// In en, this message translates to:
  /// **'Go to home'**
  String get successGenericCta;

  /// No description provided for @loginInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get loginInvalidEmail;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get loginPasswordRequired;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a new password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a password you haven’t used before.'**
  String get resetPasswordSubtitle;

  /// No description provided for @resetPasswordNew.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get resetPasswordNew;

  /// No description provided for @resetPasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get resetPasswordConfirm;

  /// No description provided for @resetPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don’t match.'**
  String get resetPasswordMismatch;

  /// No description provided for @resetPasswordRule.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters, with an uppercase letter, a number and a symbol.'**
  String get resetPasswordRule;

  /// No description provided for @resetPasswordSave.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get resetPasswordSave;

  /// No description provided for @resetPasswordDone.
  ///
  /// In en, this message translates to:
  /// **'Password updated. You can sign in with it now.'**
  String get resetPasswordDone;

  /// No description provided for @resetPasswordLinkExpired.
  ///
  /// In en, this message translates to:
  /// **'This reset link has expired. Request a new one from the sign-in screen.'**
  String get resetPasswordLinkExpired;

  /// No description provided for @resetPasswordBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get resetPasswordBackToSignIn;

  /// No description provided for @kycSuspendedLabel.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get kycSuspendedLabel;

  /// No description provided for @kycAccountSuspended.
  ///
  /// In en, this message translates to:
  /// **'Account suspended'**
  String get kycAccountSuspended;

  /// No description provided for @kycSuspendedBody.
  ///
  /// In en, this message translates to:
  /// **'Your pharmacy’s access has been suspended. Contact support to find out why and how to restore it.'**
  String get kycSuspendedBody;

  /// No description provided for @kycAdminLabel.
  ///
  /// In en, this message translates to:
  /// **'Admin account'**
  String get kycAdminLabel;

  /// No description provided for @kycAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Use the admin dashboard'**
  String get kycAdminTitle;

  /// No description provided for @kycAdminBody.
  ///
  /// In en, this message translates to:
  /// **'This is an administrator account. The pharmacy app is for pharmacies — sign in to the admin dashboard instead.'**
  String get kycAdminBody;

  /// No description provided for @kycFinishSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish setting up'**
  String get kycFinishSetupTitle;

  /// No description provided for @kycFinishSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Your account was created but your pharmacy details never finished saving. Fill them in here to complete your registration — you won’t need to sign up again.'**
  String get kycFinishSetupBody;

  /// No description provided for @kycOtpResend.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get kycOtpResend;

  /// No description provided for @kycOtpResendIn.
  ///
  /// In en, this message translates to:
  /// **'Send a new code in {seconds}s'**
  String kycOtpResendIn(int seconds);

  /// No description provided for @kycOtpResent.
  ///
  /// In en, this message translates to:
  /// **'A new code is on its way.'**
  String get kycOtpResent;

  /// No description provided for @kycOtpAcceptedRetry.
  ///
  /// In en, this message translates to:
  /// **'Your code was accepted. We just need to finish saving your pharmacy details.'**
  String get kycOtpAcceptedRetry;

  /// No description provided for @accountDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get accountDelete;

  /// No description provided for @accountDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get accountDeleteTitle;

  /// No description provided for @accountDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'This removes your pharmacy profile, licence document and listings, and you won’t be able to sign in again. Completed deals stay on record for the pharmacies you traded with. This can’t be undone.'**
  String get accountDeleteWarning;

  /// No description provided for @accountDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get accountDeleteConfirm;

  /// No description provided for @accountDeleteDone.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get accountDeleteDone;

  /// No description provided for @accountDeleteExplainer.
  ///
  /// In en, this message translates to:
  /// **'Open deals and unresolved disputes must be closed first.'**
  String get accountDeleteExplainer;

  /// No description provided for @editListingTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit listing'**
  String get editListingTitle;

  /// No description provided for @editListingSaved.
  ///
  /// In en, this message translates to:
  /// **'Listing updated.'**
  String get editListingSaved;

  /// No description provided for @editListingDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete this listing'**
  String get editListingDelete;

  /// No description provided for @editListingDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this listing?'**
  String get editListingDeleteTitle;

  /// No description provided for @editListingDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from the marketplace. If it already has deal history it will be closed rather than erased.'**
  String get editListingDeleteWarning;

  /// No description provided for @editListingDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get editListingDeleteConfirm;

  /// No description provided for @editListingDeleted.
  ///
  /// In en, this message translates to:
  /// **'Listing removed.'**
  String get editListingDeleted;

  /// No description provided for @editListingReserved.
  ///
  /// In en, this message translates to:
  /// **'This listing is reserved for a buyer right now, so its details are locked. Cancel the deal first if you need to change them.'**
  String get editListingReserved;

  /// No description provided for @editListingClosed.
  ///
  /// In en, this message translates to:
  /// **'This listing is closed and can no longer be edited.'**
  String get editListingClosed;

  /// No description provided for @editListingQuantityValidator.
  ///
  /// In en, this message translates to:
  /// **'Enter a quantity between 1 and 1,000,000'**
  String get editListingQuantityValidator;

  /// No description provided for @editListingDiscountNeedsPrice.
  ///
  /// In en, this message translates to:
  /// **'Set a price before adding a discount'**
  String get editListingDiscountNeedsPrice;

  /// No description provided for @chatAcceptRequest.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get chatAcceptRequest;

  /// No description provided for @chatDeclineRequest.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get chatDeclineRequest;

  /// No description provided for @chatWithdrawRequest.
  ///
  /// In en, this message translates to:
  /// **'Withdraw request'**
  String get chatWithdrawRequest;

  /// No description provided for @chatAcceptConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Accept this request?'**
  String get chatAcceptConfirmTitle;

  /// No description provided for @chatAcceptConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The listing will be reserved for this pharmacy, and any other pending requests on it will be declined.'**
  String get chatAcceptConfirmBody;

  /// No description provided for @chatDeclineConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Decline this request?'**
  String get chatDeclineConfirmTitle;

  /// No description provided for @chatDeclineConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The listing stays available for other pharmacies.'**
  String get chatDeclineConfirmBody;

  /// No description provided for @chatDealPendingBar.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the seller to accept'**
  String get chatDealPendingBar;

  /// No description provided for @chatDealDeclinedBar.
  ///
  /// In en, this message translates to:
  /// **'Request declined'**
  String get chatDealDeclinedBar;

  /// No description provided for @chatExpiresInHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String chatExpiresInHours(int hours);

  /// No description provided for @chatExpiresInDays.
  ///
  /// In en, this message translates to:
  /// **'{days}d'**
  String chatExpiresInDays(int days);

  /// No description provided for @chatAwaitingSellerIn.
  ///
  /// In en, this message translates to:
  /// **'Seller has {time} to respond'**
  String chatAwaitingSellerIn(Object time);

  /// No description provided for @chatReservedUntilIn.
  ///
  /// In en, this message translates to:
  /// **'Reserved for {time}'**
  String chatReservedUntilIn(Object time);

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notificationsMarkAllRead;

  /// No description provided for @chatBadgeNeedsYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Needs your answer'**
  String get chatBadgeNeedsYourAnswer;

  /// No description provided for @chatBadgeAwaitingSeller.
  ///
  /// In en, this message translates to:
  /// **'Awaiting seller'**
  String get chatBadgeAwaitingSeller;

  /// No description provided for @chatBadgeDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get chatBadgeDeclined;

  /// No description provided for @chatBadgeCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get chatBadgeCompleted;

  /// No description provided for @chatBadgeCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get chatBadgeCancelled;

  /// No description provided for @offlineTitle.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get offlineTitle;

  /// No description provided for @offlineBody.
  ///
  /// In en, this message translates to:
  /// **'We can\'t reach Pharma Exchange right now. Check your internet — we\'ll retry automatically as soon as you\'re back.'**
  String get offlineBody;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Some things won\'t work until you reconnect.'**
  String get offlineBanner;

  /// No description provided for @offlineReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get offlineReconnecting;

  /// No description provided for @offlineActionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'You need a connection to do that.'**
  String get offlineActionUnavailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
