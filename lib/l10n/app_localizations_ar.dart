// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonBack => 'رجوع';

  @override
  String get commonContinue => 'متابعة';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonDone => 'تم';

  @override
  String get commonConfirm => 'تأكيد';

  @override
  String get commonAll => 'الكل';

  @override
  String get commonView => 'عرض';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navSearch => 'بحث';

  @override
  String get navChat => 'المحادثات';

  @override
  String get navNews => 'الأخبار';

  @override
  String get navProfile => 'الملف الشخصي';

  @override
  String get listingTypeSell => 'بيع';

  @override
  String get listingTypeBuy => 'شراء';

  @override
  String get listingTypeExchange => 'مقايضة';

  @override
  String get listingStateAvailable => 'متاح';

  @override
  String get listingStateReserved => 'محجوز';

  @override
  String get listingStateCompleted => 'مكتمل';

  @override
  String get listingStateCancelled => 'ملغى';

  @override
  String get disputeStatusOpen => 'مفتوح';

  @override
  String get disputeStatusUnderReview => 'قيد المراجعة';

  @override
  String get disputeStatusResolved => 'تم الحل';

  @override
  String get newsCategoryRegulatory => 'تنظيمي';

  @override
  String get newsCategoryMarketPricing => 'أسعار السوق';

  @override
  String get newsCategoryCompanyNews => 'أخبار الشركات';

  @override
  String get newsCategoryRecallsSafety => 'السحب والسلامة';

  @override
  String get newsCategoryIndustryEvents => 'فعاليات القطاع';

  @override
  String get newsCategoryEducation => 'توعية';

  @override
  String get planTrial => 'تجريبية';

  @override
  String get planFree => 'مجانية';

  @override
  String get planActive => 'نشطة';

  @override
  String get disputeReasonNotAsDescribed => 'المنتج غير مطابق للوصف';

  @override
  String get disputeReasonNonDelivery => 'عدم التسليم';

  @override
  String get disputeReasonQuantityMismatch => 'عدم تطابق الكمية';

  @override
  String get disputeReasonPaymentIssue => 'مشكلة في الدفع';

  @override
  String get disputeReasonOther => 'أخرى';

  @override
  String get onboardSkip => 'تخطي';

  @override
  String get onboardSlide1Title => 'تصريف المخزون قريب الانتهاء';

  @override
  String get onboardSlide1Body =>
      'اعرض الأدوية الفائضة قبل انتهاء صلاحيتها بدلاً من إتلافها.';

  @override
  String get onboardSlide2Title => 'قايض أو بِع أو اشترِ';

  @override
  String get onboardSlide2Body =>
      'تداول مباشرة مع الصيدليات المرخصة القريبة منك — بدون وسيط جملة.';

  @override
  String get onboardSlide3Title => 'صيدليات مرخصة فقط';

  @override
  String get onboardSlide3Body =>
      'يتم التحقق من كل حساب قبل أن يتمكن من العرض أو التداول.';

  @override
  String get onboardGetStarted => 'ابدأ الآن';

  @override
  String get onboardNext => 'التالي';

  @override
  String get loginWelcomeBack => 'مرحبًا بعودتك';

  @override
  String get loginSubtitle =>
      'سجّل الدخول للتداول مع الصيدليات في جميع أنحاء مصر';

  @override
  String get loginEmailLabel => 'البريد الإلكتروني';

  @override
  String get loginPasswordLabel => 'كلمة المرور';

  @override
  String get loginRememberMe => 'تذكرني';

  @override
  String get loginForgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get loginSignIn => 'تسجيل الدخول';

  @override
  String get loginRegisterCta => 'سجّل صيدليتك';

  @override
  String get loginResetTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get loginResetBody =>
      'سنرسل لك رابطًا عبر البريد الإلكتروني لإعادة تعيين كلمة المرور.';

  @override
  String get loginSendLink => 'إرسال الرابط';

  @override
  String loginResetSent(Object email) {
    return 'تم إرسال رابط إعادة التعيين إلى $email';
  }

  @override
  String get loginResetError =>
      'تعذر إرسال رابط إعادة التعيين — حاول مرة أخرى.';

  @override
  String get loginError =>
      'تعذر تسجيل الدخول — تحقق من البريد الإلكتروني وكلمة المرور.';

  @override
  String get kycStepPharmacy => 'الصيدلية';

  @override
  String get kycStepAddress => 'العنوان';

  @override
  String get kycStepLicense => 'الترخيص';

  @override
  String get kycStepPassword => 'كلمة المرور';

  @override
  String get kycRegisterTitle => 'سجّل صيدليتك';

  @override
  String get kycPharmacyDetailsTitle => 'بيانات الصيدلية';

  @override
  String get kycPharmacyDetailsSubtitle =>
      'يجب أن تطابق الاسم الموجود في ترخيصك الرسمي.';

  @override
  String get fieldPharmacyName => 'اسم الصيدلية';

  @override
  String get kycPharmacyNameValidator => 'أدخل الاسم الكامل للصيدلية';

  @override
  String get fieldEmailAddress => 'البريد الإلكتروني';

  @override
  String get kycEmailHint => 'pharmacy@example.com';

  @override
  String get kycEmailValidator => 'أدخل بريدًا إلكترونيًا صحيحًا';

  @override
  String get kycAddressTitle => 'العنوان والموقع';

  @override
  String get kycAddressSubtitle =>
      'يحدد الدبوس موقعك الدقيق للبحث بالقرب منك — لا يلزم أن يطابق النص أدناه حرفيًا.';

  @override
  String get fieldGovernorate => 'المحافظة';

  @override
  String get fieldArea => 'المنطقة';

  @override
  String get fieldDetailedAddress => 'العنوان التفصيلي';

  @override
  String get kycPinYourPharmacy => 'حدد موقع صيدليتك';

  @override
  String get kycUseCurrentLocation => 'استخدام الموقع الحالي';

  @override
  String get kycTapToDropPin => 'اسحب الخريطة لتحريك الدبوس إلى موقع صيدليتك.';

  @override
  String kycPinSet(Object lat, Object lng) {
    return 'تم تحديد الموقع: $lat, $lng';
  }

  @override
  String get kycLocationDenied =>
      'تم رفض إذن الموقع — حدد الدبوس يدويًا بدلاً من ذلك.';

  @override
  String get kycLocationError =>
      'تعذر تحديد موقعك — حدد الدبوس يدويًا بدلاً من ذلك.';

  @override
  String get kycFillRequiredFields => 'أدخل المحافظة والمنطقة والعنوان.';

  @override
  String get kycDropPin => 'حدد دبوسًا على الخريطة عند الموقع الدقيق لصيدليتك.';

  @override
  String get kycLicenseTitle => 'التحقق من الترخيص';

  @override
  String get kycLicenseSubtitle => 'JPG أو PNG أو PDF، حتى 5 ميجابايت.';

  @override
  String get kycFileTooLarge =>
      'الملف أكبر من الحد المسموح به (5 ميجابايت) — اختر صورة أصغر.';

  @override
  String get kycTapToUpload => 'اضغط لرفع الترخيص';

  @override
  String get kycLicenseExpiryDate => 'تاريخ انتهاء الترخيص';

  @override
  String get kycUploadLicense => 'ارفع صورة أو ملف PDF لترخيص صيدليتك.';

  @override
  String get kycSelectValidExpiry => 'اختر تاريخ انتهاء صالحًا وغير منتهٍ.';

  @override
  String get kycSetPassword => 'تعيين كلمة مرور';

  @override
  String get kycPasswordSubtitle =>
      '8 أحرف على الأقل، حرف كبير، رقم، ورمز خاص.';

  @override
  String get fieldPassword => 'كلمة المرور';

  @override
  String get fieldConfirmPassword => 'تأكيد كلمة المرور';

  @override
  String get kycPasswordMismatch =>
      '8 أحرف على الأقل، تتضمن حرفًا كبيرًا ورقمًا ورمزًا خاصًا. يجب أن تتطابق كلمتا المرور.';

  @override
  String get kycSubmitForReview => 'إرسال للمراجعة';

  @override
  String get kycVerifyEmailTitle => 'تحقق من بريدك الإلكتروني';

  @override
  String kycOtpBody(Object email) {
    return 'أدخل الرمز المكون من 6 أرقام المرسل إلى $email. ينتهي خلال دقيقتين.';
  }

  @override
  String get kycOtpLabel => 'رمز التحقق';

  @override
  String get kycVerifyAndSubmit => 'تحقق وأرسل للمراجعة';

  @override
  String get kycPendingReview => 'قيد المراجعة';

  @override
  String get kycRejectedLabel => 'مرفوض';

  @override
  String get kycVerificationInProgress => 'التحقق جارٍ';

  @override
  String get kycApplicationRejected => 'تم رفض الطلب';

  @override
  String get kycRejectedBody =>
      'تعذر التحقق من ترخيصك. تواصل مع الدعم لإعادة التقديم.';

  @override
  String get kycPendingBody =>
      'فريقنا يراجع ترخيصك الآن. عادةً ما يستغرق ذلك حتى 24 ساعة — تتحدث هذه الشاشة تلقائيًا عند اتخاذ القرار.';

  @override
  String get homeWelcomeBack => 'مرحبًا بعودتك،';

  @override
  String get homeStatActiveListings => 'الإعلانات النشطة';

  @override
  String get homeStatExchanges => 'التبادلات';

  @override
  String get homeStatRating => 'التقييم';

  @override
  String get homeQuickSearch => 'بحث';

  @override
  String get homeQuickAdd => 'إضافة';

  @override
  String get homeQuickChat => 'محادثة';

  @override
  String get homePriceIncreased => 'ارتفاع الأسعار';

  @override
  String get homeNoPriceAlerts => 'لا توجد تنبيهات أسعار حاليًا — تحقق لاحقًا.';

  @override
  String get homeSeeAll => 'عرض الكل';

  @override
  String get homeLatestMedicines => 'أحدث الأدوية';

  @override
  String get homeViewAll => 'عرض الكل';

  @override
  String get homeNoListingsNearby => 'لا توجد إعلانات بالقرب منك بعد';

  @override
  String get homeAddFirstMedicine =>
      'اضغط على تبويب الإضافة أدناه لعرض أول دواء لك.';

  @override
  String get homeCouldntLoadListings => 'تعذر تحميل الإعلانات';

  @override
  String get searchTitle => 'بحث';

  @override
  String get searchListView => 'عرض القائمة';

  @override
  String get searchMapViewTooltip => 'عرض الخريطة';

  @override
  String get searchHint => 'ابحث باسم الدواء...';

  @override
  String get searchNearest => 'الأقرب';

  @override
  String get searchCouldntSearch => 'تعذر البحث في الإعلانات';

  @override
  String get searchLoadMore => 'تحميل المزيد';

  @override
  String get searchLoadMoreError =>
      'تعذر تحميل المزيد من الإعلانات — حاول مرة أخرى.';

  @override
  String get searchNoMatches => 'لا توجد إعلانات مطابقة للفلاتر';

  @override
  String get searchTryDifferent => 'جرّب اسم دواء أو نوعًا أو محافظة مختلفة.';

  @override
  String get searchNotifyMeSet => 'سنُعلمك عند توفره.';

  @override
  String get searchNotifyMeBody => 'سنُعلمك عند ظهور إعلان مطابق.';

  @override
  String get searchNotifyMeCta => 'أعلمني عند التوفر';

  @override
  String searchNotifyMeError(Object error) {
    return 'تعذر إعداد التنبيه: $error';
  }

  @override
  String get searchFilters => 'الفلاتر';

  @override
  String get fieldType => 'النوع';

  @override
  String get searchAllTypes => 'كل الأنواع';

  @override
  String get searchAllGovernorates => 'الكل';

  @override
  String get fieldConcentration => 'التركيز';

  @override
  String get searchAnyConcentration => 'أي تركيز';

  @override
  String get searchConcentrationHint => 'مثال: 500 مجم';

  @override
  String searchUseConcentration(Object value) {
    return 'استخدام \"$value\"';
  }

  @override
  String get searchExpiryBefore => 'تاريخ الانتهاء قبل';

  @override
  String get searchClear => 'مسح';

  @override
  String get searchApply => 'تطبيق';

  @override
  String get mapViewButtonView => 'عرض';

  @override
  String mapPinnedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صيدلية',
      many: '$count صيدلية',
      few: '$count صيدليات',
      two: 'صيدليتان',
      one: 'صيدلية واحدة',
    );
    return '$_temp0';
  }

  @override
  String listingQtyLabel(Object quantity) {
    return 'الكمية $quantity';
  }

  @override
  String get listingEditPrice => 'تعديل السعر';

  @override
  String get fieldPriceEgp => 'السعر (ج.م)';

  @override
  String get listingPriceValidator => 'أدخل سعرًا صحيحًا';

  @override
  String get fieldDiscountPriceOptional => 'سعر الخصم (اختياري)';

  @override
  String get listingDiscountExceedsPrice => 'لا يمكن أن يتجاوز السعر الأصلي';

  @override
  String get listingSavePrice => 'حفظ السعر';

  @override
  String listingCouldntUpdatePrice(Object error) {
    return 'تعذر تحديث السعر: $error';
  }

  @override
  String get listingMessageSeller => 'مراسلة البائع';

  @override
  String get listingMessageSellerBody =>
      'اختياري — اذكر ما تحتاجه. سيتم إرسال تحية افتراضية إذا تركت هذا فارغًا.';

  @override
  String get listingSendRequest => 'إرسال الطلب';

  @override
  String listingCouldntSendRequest(Object error) {
    return 'تعذر إرسال الطلب: $error';
  }

  @override
  String get listingCouldntLoad => 'تعذر تحميل هذا الإعلان';

  @override
  String get listingControlledSubstance => 'مادة مقيدة';

  @override
  String get fieldTypeLabel => 'النوع';

  @override
  String get fieldConcentrationLabel => 'التركيز';

  @override
  String get fieldQuantityLabel => 'الكمية';

  @override
  String get fieldExpiryDateLabel => 'تاريخ الانتهاء';

  @override
  String get listingSetPrice => 'تحديد سعر';

  @override
  String get listingEditPriceLink => 'تعديل السعر';

  @override
  String get listingAcceptedAlternatives => 'البدائل المقبولة';

  @override
  String listingDistanceAway(Object distance) {
    return 'على بعد $distance كم';
  }

  @override
  String listingExpires(Object date) {
    return 'تنتهي في $date';
  }

  @override
  String get listingYourOwn => 'هذا إعلانك الخاص.';

  @override
  String get listingNoLongerAvailable => 'هذا الإعلان لم يعد متاحًا للطلب.';

  @override
  String get listingContact => 'تواصل';

  @override
  String get listingBuyNow => 'اشترِ الآن';

  @override
  String get listingExchange => 'مقايضة';

  @override
  String get listingGreetingInterested => 'مرحبًا، أنا مهتم بهذا الإعلان.';

  @override
  String get listingGreetingGoAhead =>
      'مرحبًا، أرغب في المتابعة مع هذا الإعلان.';

  @override
  String listingPercentOff(Object pct) {
    return 'خصم $pct٪';
  }

  @override
  String get listingFavoriteTooltip => 'إضافة إلى المفضلة';

  @override
  String get listingUnfavoriteTooltip => 'إزالة من المفضلة';

  @override
  String listingCouldntToggleFavorite(Object error) {
    return 'تعذّر تحديث المفضلة: $error';
  }

  @override
  String get chatTitle => 'المحادثات';

  @override
  String get chatCouldntLoad => 'تعذر تحميل المحادثات';

  @override
  String get chatEmpty => 'لا توجد محادثات بعد';

  @override
  String get chatEmptyBody =>
      'اطلب إعلانًا من البحث أو الرئيسية لبدء محادثة مع البائع.';

  @override
  String get chatNoMessagesYet => 'لا توجد رسائل بعد';

  @override
  String chatCouldntSend(Object error) {
    return 'تعذر الإرسال: $error';
  }

  @override
  String chatCouldntSendAttachment(Object error) {
    return 'تعذر إرسال المرفق: $error';
  }

  @override
  String chatCouldntUpdateDeal(Object error) {
    return 'تعذر تحديث الصفقة: $error';
  }

  @override
  String get chatDealCompletedTitle => 'اكتملت الصفقة';

  @override
  String get chatDealCompletedBody =>
      'تم تأكيد التبادل. يمكنك تقييم هذه الصيدلية من المحادثة.';

  @override
  String get chatRateThisPharmacy => 'قيّم هذه الصيدلية';

  @override
  String get chatOverall => 'التقييم العام';

  @override
  String get chatCredibility => 'المصداقية';

  @override
  String get chatResponsiveness => 'سرعة الاستجابة';

  @override
  String get chatPackaging => 'التغليف';

  @override
  String get chatSubmitRating => 'إرسال التقييم';

  @override
  String get chatRatingSubmitted => 'تم إرسال التقييم — شكرًا لك.';

  @override
  String chatCouldntSubmitRating(Object error) {
    return 'تعذر إرسال التقييم: $error';
  }

  @override
  String get chatReportIssue => 'الإبلاغ عن مشكلة';

  @override
  String get chatReportBody =>
      'سيتم إخطار الصيدلية الأخرى وسيبقى هذا ظاهرًا حتى يتم الحل.';

  @override
  String get fieldReason => 'السبب';

  @override
  String get chatDetailsOptional => 'تفاصيل (اختياري)';

  @override
  String get chatAttachEvidence => 'إرفاق صورة كدليل (اختياري)';

  @override
  String get chatPhotoAttached => 'تم إرفاق الصورة';

  @override
  String get chatSubmitReport => 'إرسال البلاغ';

  @override
  String get chatReportSubmitted => 'تم إرسال البلاغ.';

  @override
  String chatCouldntSubmitReport(Object error) {
    return 'تعذر إرسال البلاغ: $error';
  }

  @override
  String get chatHeaderFallback => 'محادثة';

  @override
  String get chatReportTooltip => 'الإبلاغ عن مشكلة';

  @override
  String get chatCouldntLoadMessages => 'تعذر تحميل الرسائل';

  @override
  String get chatMarkComplete => 'وضع كمكتمل';

  @override
  String get chatDeclineCancel => 'رفض / إلغاء';

  @override
  String get chatCancelRequest => 'إلغاء الطلب';

  @override
  String get chatDealClosedRated => 'الصفقة مغلقة — شكرًا لتقييمك.';

  @override
  String get chatDealClosed => 'هذه الصفقة مغلقة.';

  @override
  String get chatTypeMessage => 'اكتب رسالة...';

  @override
  String get chatAttach => 'إرفاق';

  @override
  String get chatTakePhoto => 'التقاط صورة';

  @override
  String get chatChoosePhotos => 'اختيار صور';

  @override
  String get chatAttachPdf => 'مستند PDF';

  @override
  String get chatShareLocation => 'مشاركة الموقع';

  @override
  String get chatTapToViewPhoto => 'اضغط لعرض الصورة';

  @override
  String get chatTapToOpenPdf => 'اضغط لفتح ملف PDF';

  @override
  String get chatOpenInMaps => 'فتح في الخرائط';

  @override
  String get chatLocationPermissionDenied => 'تم رفض إذن الموقع';

  @override
  String chatCouldntShareLocation(Object error) {
    return 'تعذرت مشاركة الموقع: $error';
  }

  @override
  String chatCouldntOpenAttachment(Object error) {
    return 'تعذر فتح المرفق: $error';
  }

  @override
  String get chatMarkCompleteConfirmTitle => 'وضع الصفقة كمكتملة؟';

  @override
  String get chatMarkCompleteConfirmBody =>
      'هذا يؤكد حدوث التبادل ويغلق الإعلان.';

  @override
  String get chatCancelConfirmTitle => 'إلغاء هذه الصفقة؟';

  @override
  String get chatCancelConfirmBody =>
      'سيعود الإعلان إلى متاح للصيدليات الأخرى.';

  @override
  String get chatDealCompletedBar => 'اكتملت الصفقة';

  @override
  String get chatDealCancelledBar => 'أُلغيت الصفقة';

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get profileAccountSettingsTooltip => 'إعدادات الحساب';

  @override
  String get profileCouldntLoad => 'تعذر تحميل الملف الشخصي';

  @override
  String get profileStatRating => 'التقييم';

  @override
  String get profileStatExchanges => 'التبادلات';

  @override
  String get profileStatActive => 'نشط';

  @override
  String get profileNoRatingsYet =>
      'لا توجد تقييمات بعد — ستظهر هنا بعد أول صفقة مكتملة.';

  @override
  String get profileRatingsReviews => 'التقييمات والمراجعات';

  @override
  String profileRatingCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '($count تقييم)',
      many: '($count تقييمًا)',
      few: '($count تقييمات)',
      two: '(تقييمان)',
      one: '(تقييم واحد)',
    );
    return '$_temp0';
  }

  @override
  String get profileCredibility => 'المصداقية';

  @override
  String get profileResponsiveness => 'سرعة الاستجابة';

  @override
  String get profilePackaging => 'التغليف';

  @override
  String get profileMyListings => 'إعلاناتي';

  @override
  String get profileMyFavorites => 'المفضلة';

  @override
  String get profileDisputes => 'النزاعات';

  @override
  String get profileLanguage => 'اللغة';

  @override
  String get accountSettingsTitle => 'إعدادات الحساب';

  @override
  String get accountCouldntLoad => 'تعذر تحميل بيانات الحساب';

  @override
  String get accountEditProfile => 'تعديل الملف الشخصي';

  @override
  String get accountEditProfileSubtitle => 'الاسم والهاتف والعنوان';

  @override
  String get accountSignOut => 'تسجيل الخروج';

  @override
  String accountPlanSuffix(Object plan) {
    return 'خطة $plan';
  }

  @override
  String get accountNoTrialCountdown =>
      'لا يوجد عد تنازلي للتجربة في هذه الخطة.';

  @override
  String get accountTrialEnded => 'انتهت فترتك التجريبية.';

  @override
  String accountTrialDaysLeft(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days يوم متبقٍ في تجربتك.',
      many: '$days يومًا متبقيًا في تجربتك.',
      few: '$days أيام متبقية في تجربتك.',
      two: 'يومان متبقيان في تجربتك.',
      one: 'يوم واحد متبقٍ في تجربتك.',
    );
    return '$_temp0';
  }

  @override
  String get editProfileTitle => 'تعديل الملف الشخصي';

  @override
  String get editProfileFillRequired => 'أدخل جميع الحقول المطلوبة.';

  @override
  String get editProfileCouldntSave => 'تعذر حفظ التغييرات — حاول مرة أخرى.';

  @override
  String get editProfileCouldntLoad => 'تعذر تحميل ملفك الشخصي';

  @override
  String get editProfileNameValidator => 'أدخل الاسم الكامل للصيدلية';

  @override
  String get fieldPhoneNumber => 'رقم الهاتف';

  @override
  String get editProfileAreaValidator => 'أدخل منطقتك';

  @override
  String get editProfileAddressValidator => 'أدخل عنوانك';

  @override
  String get editProfileSaveChanges => 'حفظ التغييرات';

  @override
  String get disputesTitle => 'النزاعات';

  @override
  String get disputesCouldntLoad => 'تعذر تحميل النزاعات';

  @override
  String get disputesEmpty => 'لا توجد نزاعات';

  @override
  String get disputesEmptyBody =>
      'يمكنك الإبلاغ عن مشكلة في صفقة من محادثة تلك الصفقة.';

  @override
  String get disputeRaisedByYou => 'أبلغتَ عن';

  @override
  String disputeRaisedByOther(Object name) {
    return 'أبلغت $name عن';
  }

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get notificationsCouldntLoad => 'تعذر تحميل الإشعارات';

  @override
  String get notificationsEmpty => 'لا توجد إشعارات بعد';

  @override
  String get notificationsDeleteError => 'تعذر الحذف — حاول مرة أخرى.';

  @override
  String get newsTitle => 'الأخبار';

  @override
  String get newsAll => 'الكل';

  @override
  String get newsCouldntLoad => 'تعذر تحميل الأخبار';

  @override
  String get newsEmptyCategory => 'لا توجد مقالات في هذا التصنيف بعد';

  @override
  String get newsDetailCouldntLoad => 'تعذر تحميل هذا المقال';

  @override
  String get priceAlertsTitle => 'ارتفاع الأسعار';

  @override
  String get priceAlertsCouldntLoad => 'تعذر تحميل تنبيهات الأسعار';

  @override
  String get priceAlertsEmpty => 'لا توجد تنبيهات أسعار حاليًا';

  @override
  String get notFoundTitle => 'الصفحة غير موجودة';

  @override
  String get notFoundBody => 'الصفحة التي تبحث عنها غير موجودة أو تم نقلها.';

  @override
  String get notFoundGoHome => 'العودة للرئيسية';

  @override
  String get addMedicineTitle => 'إضافة دواء';

  @override
  String get addMedicineHeading => 'عرض دواء';

  @override
  String get addMedicineSubtitle =>
      'بِع أو اطلب أو قايض المخزون الفائض مع الصيدليات القريبة.';

  @override
  String get fieldMedicine => 'الدواء';

  @override
  String get addMedicineTapToSearch => 'اضغط للبحث أو كتابة اسم دواء';

  @override
  String get fieldManufacturer => 'الشركة المصنعة';

  @override
  String get fieldForm => 'الشكل الصيدلاني';

  @override
  String get addMedicineControlledTitle => 'مادة مقيدة — لا يمكن عرضها هنا';

  @override
  String addMedicineControlledBody(Object name) {
    return '$name مادة مقيدة. لا يدعم تطبيق فارما إكستشينج إيجيبت العرض الذاتي للمواد المقيدة بعد — تواصل مع الدعم إذا كنت تعتقد أن هذا خطأ.';
  }

  @override
  String get addMedicineChooseDifferent => 'اختر دواءً آخر';

  @override
  String get fieldListingType => 'نوع الإعلان';

  @override
  String get fieldQuantity => 'الكمية';

  @override
  String get addMedicineQuantityValidator => 'أدخل كمية صحيحة';

  @override
  String get fieldDiscountPrice => 'سعر الخصم';

  @override
  String get addMedicineDiscountExceeds => 'لا يمكن أن يتجاوز السعر';

  @override
  String get fieldDescription => 'الوصف';

  @override
  String get addMedicineDescriptionHint =>
      'اختياري — التغليف أو الحالة أو أي تفاصيل أخرى يجب أن يعرفها المشتري.';

  @override
  String get fieldExpiryDate => 'تاريخ الانتهاء';

  @override
  String get addMedicineExpiryHint => 'يجب أن يكون تاريخًا مستقبليًا';

  @override
  String get addMedicineAddAlternative => 'إضافة بديل';

  @override
  String get addMedicineAddPhoto => 'إضافة صورة (اختياري)';

  @override
  String get addMedicinePhotoAttached => 'تم إرفاق الصورة — اضغط للاستبدال';

  @override
  String get addMedicineCouldntCreate => 'تعذر إنشاء الإعلان — حاول مرة أخرى.';

  @override
  String get addMedicineCreateListing => 'إنشاء الإعلان';

  @override
  String get addMedicineMissingFields =>
      'اختر دواءً ونوع الإعلان وتاريخ الانتهاء.';

  @override
  String get addMedicineSuccessTitle => 'تم إنشاء الإعلان';

  @override
  String get addMedicineSuccessBody => 'دواؤك الآن مرئي للصيدليات القريبة.';

  @override
  String get addMedicineSearchHint => 'ابحث أو اكتب اسم دواء…';

  @override
  String get addMedicineSearchPrompt =>
      'ابدأ الكتابة للبحث بين نحو 23,600 دواء';

  @override
  String addMedicineUseCustom(Object name) {
    return 'استخدام \"$name\"';
  }

  @override
  String get addMedicineNotInCatalog =>
      'غير موجود في الكتالوج — أضفه بهذا الاسم';

  @override
  String get addMedicineNoMatches =>
      'لا توجد نتائج مطابقة — يمكنك استخدام الخيار أعلاه.';

  @override
  String get addMedicineCouldntSelect =>
      'تعذر اختيار هذا الدواء — حاول مرة أخرى.';

  @override
  String get myListingsTitle => 'إعلاناتي';

  @override
  String get myListingsCouldntLoad => 'تعذر تحميل إعلاناتك';

  @override
  String get myListingsEmpty => 'لا توجد إعلانات بعد';

  @override
  String myListingsEmptyFiltered(Object state) {
    return 'لا توجد إعلانات $state';
  }

  @override
  String get myListingsEmptyBody => 'الأدوية التي تعرضها ستظهر هنا.';

  @override
  String get favoritesTitle => 'المفضلة';

  @override
  String get favoritesCouldntLoad => 'تعذر تحميل المفضلة';

  @override
  String get favoritesEmpty => 'لا توجد عناصر مفضلة بعد';

  @override
  String get favoritesEmptyBody =>
      'اضغط على أيقونة القلب في أي إعلان لحفظه هنا.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get commonSubmit => 'إرسال';

  @override
  String get commonSave => 'حفظ التغييرات';

  @override
  String get fieldDescriptionOptional => 'ملاحظات (اختياري)';

  @override
  String get errorGeneric => 'حدث خطأ ما. من فضلك حاول مرة أخرى.';

  @override
  String get errorNetwork => 'لا يوجد اتصال. تحقق من الإنترنت وحاول مرة أخرى.';

  @override
  String get errorAuthRequired => 'من فضلك سجّل الدخول مرة أخرى.';

  @override
  String get errorInvalidCredentials =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get errorEmailNotConfirmed =>
      'أكّد بريدك الإلكتروني أولاً — تحقق من رسائلك للحصول على الرمز.';

  @override
  String get errorEmailAlreadyRegistered =>
      'يوجد حساب بهذا البريد الإلكتروني بالفعل. جرّب تسجيل الدخول.';

  @override
  String get errorOtpInvalid =>
      'هذا الرمز غير صحيح أو انتهت صلاحيته. اطلب رمزاً جديداً.';

  @override
  String get errorRateLimited =>
      'محاولات كثيرة جداً. انتظر دقيقة وحاول مرة أخرى.';

  @override
  String get errorWeakPassword =>
      'يجب أن تكون كلمة المرور 8 أحرف على الأقل وتحتوي على حرف كبير ورقم ورمز.';

  @override
  String get errorFileTooLarge => 'هذا الملف كبير جداً.';

  @override
  String get errorFileType => 'نوع الملف هذا غير مدعوم.';

  @override
  String get errorNotApproved =>
      'صيدليتك ما زالت في انتظار الموافقة، لذا لا يمكنك التداول بعد.';

  @override
  String get errorAccountIsAdmin =>
      'هذا حساب مسؤول — استخدم لوحة تحكم المسؤولين بدلاً من ذلك.';

  @override
  String get errorAccountHasActiveDeals =>
      'أنهِ أو ألغِ صفقاتك المفتوحة قبل حذف حسابك.';

  @override
  String get errorAccountHasOpenDisputes =>
      'لديك نزاع لم يُحسم بعد. يجب إغلاقه قبل حذف حسابك.';

  @override
  String get errorListingNotFound => 'هذا الإعلان لم يعد موجوداً.';

  @override
  String get errorListingOwn => 'هذا إعلانك أنت.';

  @override
  String get errorListingUnavailable => 'هذا الإعلان لم يعد متاحاً.';

  @override
  String get errorListingExpired => 'انتهت صلاحية الدواء في هذا الإعلان.';

  @override
  String get errorListingExpiryInPast => 'اختر تاريخ صلاحية في المستقبل.';

  @override
  String get errorListingNotOwner => 'هذا ليس إعلانك.';

  @override
  String get errorListingNotEditable => 'لم يعد من الممكن تعديل هذا الإعلان.';

  @override
  String get errorListingReservedNoEdit =>
      'لا يمكنك تغيير التفاصيل أثناء حجز هذا الإعلان لمشترٍ.';

  @override
  String get errorListingHasActiveDeal =>
      'يوجد طلب مفتوح على هذا الإعلان. ألغِه أولاً.';

  @override
  String get errorQuantityInvalid => 'أدخل كمية صحيحة.';

  @override
  String get errorPriceInvalid => 'أدخل سعراً صحيحاً.';

  @override
  String get errorDiscountInvalid =>
      'يجب أن يكون سعر الخصم أقل من السعر الأصلي.';

  @override
  String get errorControlledSubstance =>
      'هذه مادة خاضعة للرقابة ولا يمكن عرضها هنا.';

  @override
  String get errorDealNotFound => 'هذه المحادثة لم تعد موجودة.';

  @override
  String get errorDealNotParticipant => 'أنت لست طرفاً في هذه الصفقة.';

  @override
  String get errorDealAlreadyOpen => 'لديك طلب مفتوح بالفعل على هذا الإعلان.';

  @override
  String get errorDealSellerOnly => 'البائع وحده من يمكنه فعل ذلك.';

  @override
  String get errorDealNotPending => 'تم الرد على هذا الطلب بالفعل.';

  @override
  String get errorDealNotActive => 'هذه الصفقة مغلقة بالفعل.';

  @override
  String get errorDisputeAlreadyOpen =>
      'لديك نزاع مفتوح بالفعل على هذه الصفقة.';

  @override
  String get errorDisputeReasonRequired => 'اذكر سبب النزاع.';

  @override
  String get errorRatingInvalidStars => 'اختر تقييماً من 1 إلى 5 نجوم.';

  @override
  String get errorRatingDealNotCompleted => 'يمكنك تقييم الصفقات المكتملة فقط.';

  @override
  String get errorDrugNameRequired => 'أدخل اسم الدواء.';

  @override
  String get errorDrugNameTooLong => 'اسم الدواء طويل جداً.';

  @override
  String get errorPharmacyNameRequired => 'أدخل اسم صيدليتك.';

  @override
  String get errorGovernorateRequired => 'اختر المحافظة.';

  @override
  String get errorLocationRequired => 'حدّد موقع صيدليتك على الخريطة.';

  @override
  String get errorLocationOutOfBounds => 'هذا الموقع ليس داخل مصر.';

  @override
  String get errorLicenseRequired => 'ارفع ترخيص الصيدلية.';

  @override
  String get successGenericTitle => 'تم بنجاح';

  @override
  String get successGenericBody => 'تمت العملية بنجاح.';

  @override
  String get successGenericCta => 'العودة للرئيسية';

  @override
  String get loginInvalidEmail => 'أدخل بريداً إلكترونياً صحيحاً.';

  @override
  String get loginPasswordRequired => 'أدخل كلمة المرور.';

  @override
  String get resetPasswordTitle => 'تعيين كلمة مرور جديدة';

  @override
  String get resetPasswordSubtitle => 'اختر كلمة مرور لم تستخدمها من قبل.';

  @override
  String get resetPasswordNew => 'كلمة المرور الجديدة';

  @override
  String get resetPasswordConfirm => 'تأكيد كلمة المرور';

  @override
  String get resetPasswordMismatch => 'كلمتا المرور غير متطابقتين.';

  @override
  String get resetPasswordRule => '8 أحرف على الأقل، مع حرف كبير ورقم ورمز.';

  @override
  String get resetPasswordSave => 'حفظ كلمة المرور';

  @override
  String get resetPasswordDone =>
      'تم تحديث كلمة المرور. يمكنك تسجيل الدخول بها الآن.';

  @override
  String get resetPasswordLinkExpired =>
      'انتهت صلاحية رابط إعادة التعيين. اطلب رابطاً جديداً من شاشة تسجيل الدخول.';

  @override
  String get resetPasswordBackToSignIn => 'العودة لتسجيل الدخول';

  @override
  String get kycSuspendedLabel => 'موقوف';

  @override
  String get kycAccountSuspended => 'الحساب موقوف';

  @override
  String get kycSuspendedBody =>
      'تم إيقاف وصول صيدليتك. تواصل مع الدعم لمعرفة السبب وكيفية استعادة الحساب.';

  @override
  String get kycAdminLabel => 'حساب مسؤول';

  @override
  String get kycAdminTitle => 'استخدم لوحة تحكم المسؤولين';

  @override
  String get kycAdminBody =>
      'هذا حساب مسؤول. تطبيق الصيدليات مخصص للصيدليات — سجّل الدخول إلى لوحة تحكم المسؤولين بدلاً من ذلك.';

  @override
  String get kycFinishSetupTitle => 'أكمل الإعداد';

  @override
  String get kycFinishSetupBody =>
      'تم إنشاء حسابك لكن بيانات صيدليتك لم يكتمل حفظها. أدخلها هنا لإتمام التسجيل — لن تحتاج إلى التسجيل من جديد.';

  @override
  String get kycOtpResend => 'إرسال رمز جديد';

  @override
  String kycOtpResendIn(int seconds) {
    return 'إرسال رمز جديد خلال $seconds ثانية';
  }

  @override
  String get kycOtpResent => 'تم إرسال رمز جديد.';

  @override
  String get kycOtpAcceptedRetry =>
      'تم قبول الرمز. نحتاج فقط لإكمال حفظ بيانات صيدليتك.';

  @override
  String get accountDelete => 'حذف حسابي';

  @override
  String get accountDeleteTitle => 'حذف حسابك؟';

  @override
  String get accountDeleteWarning =>
      'سيؤدي هذا إلى حذف ملف صيدليتك ووثيقة الترخيص وإعلاناتك، ولن تتمكن من تسجيل الدخول مرة أخرى. تبقى الصفقات المكتملة مسجلة لدى الصيدليات التي تعاملت معها. لا يمكن التراجع عن هذا.';

  @override
  String get accountDeleteConfirm => 'حذف نهائي';

  @override
  String get accountDeleteDone => 'تم حذف حسابك.';

  @override
  String get accountDeleteExplainer =>
      'يجب إغلاق الصفقات المفتوحة والنزاعات غير المحسومة أولاً.';

  @override
  String get editListingTitle => 'تعديل الإعلان';

  @override
  String get editListingSaved => 'تم تحديث الإعلان.';

  @override
  String get editListingDelete => 'حذف هذا الإعلان';

  @override
  String get editListingDeleteTitle => 'حذف هذا الإعلان؟';

  @override
  String get editListingDeleteWarning =>
      'ستتم إزالته من السوق. إذا كان له سجل صفقات فسيتم إغلاقه بدلاً من حذفه.';

  @override
  String get editListingDeleteConfirm => 'حذف';

  @override
  String get editListingDeleted => 'تمت إزالة الإعلان.';

  @override
  String get editListingReserved =>
      'هذا الإعلان محجوز لمشترٍ الآن، لذا فتفاصيله مقفلة. ألغِ الصفقة أولاً إذا أردت تغييرها.';

  @override
  String get editListingClosed => 'هذا الإعلان مغلق ولم يعد من الممكن تعديله.';

  @override
  String get editListingQuantityValidator => 'أدخل كمية بين 1 و 1,000,000';

  @override
  String get editListingDiscountNeedsPrice => 'حدّد السعر قبل إضافة خصم';

  @override
  String get chatAcceptRequest => 'قبول';

  @override
  String get chatDeclineRequest => 'رفض';

  @override
  String get chatWithdrawRequest => 'سحب الطلب';

  @override
  String get chatAcceptConfirmTitle => 'قبول هذا الطلب؟';

  @override
  String get chatAcceptConfirmBody =>
      'سيتم حجز الإعلان لهذه الصيدلية، وسيتم رفض أي طلبات أخرى معلّقة عليه.';

  @override
  String get chatDeclineConfirmTitle => 'رفض هذا الطلب؟';

  @override
  String get chatDeclineConfirmBody => 'سيظل الإعلان متاحاً للصيدليات الأخرى.';

  @override
  String get chatDealPendingBar => 'في انتظار موافقة البائع';

  @override
  String get chatDealDeclinedBar => 'تم رفض الطلب';

  @override
  String chatExpiresInHours(int hours) {
    return '$hours ساعة';
  }

  @override
  String chatExpiresInDays(int days) {
    return '$days يوم';
  }

  @override
  String chatAwaitingSellerIn(Object time) {
    return 'أمام البائع $time للرد';
  }

  @override
  String chatReservedUntilIn(Object time) {
    return 'محجوز لمدة $time';
  }

  @override
  String get notificationsMarkAllRead => 'تعليم الكل كمقروء';

  @override
  String get chatBadgeNeedsYourAnswer => 'بانتظار ردك';

  @override
  String get chatBadgeAwaitingSeller => 'بانتظار البائع';

  @override
  String get chatBadgeDeclined => 'مرفوض';

  @override
  String get chatBadgeCompleted => 'مكتمل';

  @override
  String get chatBadgeCancelled => 'ملغى';
}
