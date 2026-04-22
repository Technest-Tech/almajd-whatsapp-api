// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'أكاديمية المجد';

  @override
  String get appTagline => 'نظام الإدارة';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get welcomeBack => 'مرحباً بعودتك';

  @override
  String get loginToContinue => 'سجل دخولك للمتابعة';

  @override
  String get invalidCredentials => 'البريد الإلكتروني أو كلمة المرور غير صحيحة';

  @override
  String get dashboard => 'لوحة التحكم';

  @override
  String get selectModule => 'اختر وحدة';

  @override
  String get rooms => 'القاعات';

  @override
  String get usersAndCourses => 'المستخدمون والدورات';

  @override
  String get billings => 'الفواتير والتقارير';

  @override
  String get calendar => 'التقويم';

  @override
  String get certificates => 'الشهادات';

  @override
  String get settingsReports => 'الإعدادات';

  @override
  String get settings => 'الإعدادات';

  @override
  String get comingSoon => 'قريباً';

  @override
  String get featureInDevelopment => 'هذه الميزة قيد التطوير حالياً';

  @override
  String get errorOccurred => 'حدث خطأ';

  @override
  String get tryAgain => 'حاول مرة أخرى';

  @override
  String get back => 'رجوع';

  @override
  String get submit => 'إرسال';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'تعديل';

  @override
  String get certificateDemo => 'عرض الشهادة';

  @override
  String get modernCertificateTemplate => 'قالب شهادة حديث';

  @override
  String get livePreviewDescription => 'هذا معاينة مباشرة لقالب \"المهني\"';

  @override
  String get templateFeatures => 'ميزات القالب:';

  @override
  String get chooseTemplate => 'اختر القالب';

  @override
  String get previewGeneratePdf => 'معاينة وإنشاء PDF';

  @override
  String get createRoom => 'إنشاء قاعة';

  @override
  String get createNewRoom => 'إنشاء قاعة جديدة';

  @override
  String get setUpNewVideoConferenceRoom => 'إعداد قاعة مؤتمرات فيديو جديدة';

  @override
  String get roomName => 'اسم القاعة';

  @override
  String get enterRoomName => 'أدخل اسم القاعة';

  @override
  String get roomActive => 'القاعة نشطة';

  @override
  String get enableOrDisableTheRoom => 'تفعيل أو تعطيل القاعة';

  @override
  String get allowRecording => 'السماح بالتسجيل';

  @override
  String get allowRecordingOfMeetingsInThisRoom =>
      'السماح بتسجيل الاجتماعات في هذه القاعة';

  @override
  String get editRoom => 'تعديل القاعة';

  @override
  String get updateRoomSettingsAndConfiguration =>
      'تحديث إعدادات وتكوين القاعة';

  @override
  String get roomInformation => 'معلومات القاعة';

  @override
  String get participants => 'المشاركون';

  @override
  String get created => 'تاريخ الإنشاء';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get totalRooms => 'إجمالي القاعات';

  @override
  String get activeRooms => 'القاعات النشطة';

  @override
  String get searchRooms => 'البحث في القاعات...';

  @override
  String get noRoomsFound => 'لا توجد قاعات';

  @override
  String get noRoomsMatchYourSearch => 'لا توجد قاعات تطابق بحثك';

  @override
  String get createYourFirstRoomToGetStarted => 'أنشئ قاعتك الأولى للبدء';

  @override
  String get hostLink => 'رابط المضيف';

  @override
  String get guestLink => 'رابط الضيف';

  @override
  String get linkCopiedToClipboard => 'تم نسخ الرابط إلى الحافظة!';

  @override
  String get copyLink => 'نسخ الرابط';

  @override
  String get max => 'الحد الأقصى';

  @override
  String get active => 'نشط';

  @override
  String get inactive => 'غير نشط';

  @override
  String get recordingAllowed => 'التسجيل مسموح';

  @override
  String get noRecording => 'لا يوجد تسجيل';

  @override
  String get roomCreatedSuccessfully => 'تم إنشاء القاعة بنجاح!';

  @override
  String get roomUpdatedSuccessfully => 'تم تحديث القاعة بنجاح!';

  @override
  String get roomDeletedSuccessfully => 'تم حذف القاعة بنجاح!';

  @override
  String get errorCreatingRoom => 'خطأ في إنشاء القاعة';

  @override
  String get errorUpdatingRoom => 'خطأ في تحديث القاعة';

  @override
  String get errorDeletingRoom => 'خطأ في حذف القاعة';

  @override
  String get errorLoadingRooms => 'خطأ في تحميل القاعات';

  @override
  String get deleteRoom => 'حذف القاعة';

  @override
  String areYouSureYouWantToDeleteRoom(String roomName) {
    return 'هل أنت متأكد من حذف \"$roomName\"؟ لا يمكن التراجع عن هذا الإجراء.';
  }

  @override
  String get pleaseEnterARoomName => 'الرجاء إدخال اسم القاعة';

  @override
  String get enterYourEmailAddress => 'أدخل عنوان بريدك الإلكتروني';

  @override
  String get enterYourPassword => 'أدخل كلمة المرور';

  @override
  String get searchStudents => 'البحث عن الطلاب...';

  @override
  String get searchTeachers => 'البحث عن المعلمين...';

  @override
  String get searchCourses => 'البحث عن الدورات...';

  @override
  String get allCountries => 'جميع البلدان';

  @override
  String get allCurrencies => 'جميع العملات';

  @override
  String get search => 'بحث';

  @override
  String get pleaseEnterEmailAndPassword =>
      'الرجاء إدخال البريد الإلكتروني وكلمة المرور';

  @override
  String get isRequired => 'مطلوب';

  @override
  String get loginFailed => 'فشل تسجيل الدخول';

  @override
  String get ok => 'حسناً';

  @override
  String get networkError =>
      'حدث خطأ في الاتصال. يرجى التحقق من اتصالك بالإنترنت';

  @override
  String get addStudent => 'إضافة طالب';

  @override
  String get editStudent => 'تعديل طالب';

  @override
  String get name => 'الاسم';

  @override
  String get nameIsRequired => 'الاسم مطلوب';

  @override
  String get emailIsRequired => 'البريد الإلكتروني مطلوب';

  @override
  String get invalidEmailFormat => 'تنسيق البريد الإلكتروني غير صحيح';

  @override
  String get whatsappNumber => 'رقم الواتساب';

  @override
  String get country => 'البلد';

  @override
  String get currency => 'العملة';

  @override
  String get hourPrice => 'سعر الساعة';

  @override
  String get invalidPrice => 'السعر غير صحيح';

  @override
  String get createStudent => 'إنشاء طالب';

  @override
  String get updateStudent => 'تحديث طالب';

  @override
  String get addTeacher => 'إضافة معلم';

  @override
  String get editTeacher => 'تعديل معلم';

  @override
  String get passwordRequired => 'كلمة المرور *';

  @override
  String get passwordLeaveEmpty =>
      'كلمة المرور (اتركها فارغة للاحتفاظ بالحالية)';

  @override
  String get passwordIsRequired => 'كلمة المرور مطلوبة';

  @override
  String get passwordMinLength => 'يجب أن تكون كلمة المرور 8 أحرف على الأقل';

  @override
  String get bankName => 'اسم البنك';

  @override
  String get accountNumber => 'رقم الحساب';

  @override
  String get assignedStudents => 'الطلاب المعينون';

  @override
  String get noStudentsAssigned => 'لا يوجد طلاب معينون';

  @override
  String get createTeacher => 'إنشاء معلم';

  @override
  String get updateTeacher => 'تحديث معلم';

  @override
  String get addCourse => 'إضافة دورة';

  @override
  String get editCourse => 'تعديل دورة';

  @override
  String get courseName => 'اسم الدورة';

  @override
  String get student => 'الطالب';

  @override
  String get teacher => 'المعلم';

  @override
  String get course => 'الدورة';

  @override
  String get courseNameIsRequired => 'اسم الدورة مطلوب';

  @override
  String get pleaseSelectStudent => 'الرجاء اختيار طالب';

  @override
  String get pleaseSelectTeacher => 'الرجاء اختيار معلم';

  @override
  String get createCourse => 'إنشاء دورة';

  @override
  String get updateCourse => 'تحديث دورة';

  @override
  String get addLesson => 'إضافة درس';

  @override
  String get editLesson => 'تعديل درس';

  @override
  String get date => 'التاريخ';

  @override
  String get durationMinutes => 'المدة (بالدقائق)';

  @override
  String get durationIsRequired => 'المدة مطلوبة';

  @override
  String get invalidDuration => 'المدة غير صحيحة';

  @override
  String get status => 'الحالة';

  @override
  String get notes => 'ملاحظات';

  @override
  String get dutyPayment => 'الواجب (الدفع)';

  @override
  String get invalidDutyAmount => 'مبلغ الواجب غير صحيح';

  @override
  String get pleaseSelectCourse => 'الرجاء اختيار دورة';

  @override
  String get present => 'حاضر';

  @override
  String get cancelled => 'ملغي';

  @override
  String get createLesson => 'إنشاء درس';

  @override
  String get updateLesson => 'تحديث درس';

  @override
  String get usd => 'دولار أمريكي - USD';

  @override
  String get gbp => 'جنيه إسترليني - GBP';

  @override
  String get eur => 'يورو - EUR';

  @override
  String get egp => 'جنيه مصري - EGP';

  @override
  String get sar => 'ريال سعودي - SAR';

  @override
  String get aed => 'درهم إماراتي - AED';

  @override
  String get cad => 'دولار كندي - CAD';
}
