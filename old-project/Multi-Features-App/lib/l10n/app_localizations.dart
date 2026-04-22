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
    Locale('en')
  ];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'Almajd Academy'**
  String get appName;

  /// Application tagline
  ///
  /// In en, this message translates to:
  /// **'Management System'**
  String get appTagline;

  /// Login button text
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Logout button text
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Forgot password link text
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// Welcome back greeting
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// Login prompt text
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get loginToContinue;

  /// Invalid credentials error message
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get invalidCredentials;

  /// Dashboard title
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// Select module prompt
  ///
  /// In en, this message translates to:
  /// **'Choose a module'**
  String get selectModule;

  /// Rooms module name
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get rooms;

  /// Users and courses module name
  ///
  /// In en, this message translates to:
  /// **'Users & Courses'**
  String get usersAndCourses;

  /// Billing and Reports module name
  ///
  /// In en, this message translates to:
  /// **'Billing and Reports'**
  String get billings;

  /// Calendar module name
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// Certificates module name
  ///
  /// In en, this message translates to:
  /// **'Certificates'**
  String get certificates;

  /// Settings module name
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsReports;

  /// Settings module name
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Coming soon message
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// Feature in development message
  ///
  /// In en, this message translates to:
  /// **'This feature is currently under development'**
  String get featureInDevelopment;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorOccurred;

  /// Try again button text
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// Back button text
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Submit button text
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// Cancel button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Save button text
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Delete button text
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Edit button text
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Certificate demo page title
  ///
  /// In en, this message translates to:
  /// **'Certificate Demo'**
  String get certificateDemo;

  /// Modern certificate template title
  ///
  /// In en, this message translates to:
  /// **'Modern Certificate Template'**
  String get modernCertificateTemplate;

  /// Live preview description
  ///
  /// In en, this message translates to:
  /// **'This is a live preview of the \"Professional\" template'**
  String get livePreviewDescription;

  /// Template features section title
  ///
  /// In en, this message translates to:
  /// **'Template Features:'**
  String get templateFeatures;

  /// Choose template button text
  ///
  /// In en, this message translates to:
  /// **'Choose Template'**
  String get chooseTemplate;

  /// Preview and generate PDF button text
  ///
  /// In en, this message translates to:
  /// **'Preview & Generate PDF'**
  String get previewGeneratePdf;

  /// Create room button text
  ///
  /// In en, this message translates to:
  /// **'Create Room'**
  String get createRoom;

  /// Create new room dialog title
  ///
  /// In en, this message translates to:
  /// **'Create New Room'**
  String get createNewRoom;

  /// Create room dialog subtitle
  ///
  /// In en, this message translates to:
  /// **'Set up a new video conference room'**
  String get setUpNewVideoConferenceRoom;

  /// Room name field label
  ///
  /// In en, this message translates to:
  /// **'Room Name'**
  String get roomName;

  /// Room name field hint
  ///
  /// In en, this message translates to:
  /// **'Enter room name'**
  String get enterRoomName;

  /// Room active toggle label
  ///
  /// In en, this message translates to:
  /// **'Room Active'**
  String get roomActive;

  /// Room active toggle description
  ///
  /// In en, this message translates to:
  /// **'Enable or disable the room'**
  String get enableOrDisableTheRoom;

  /// Allow recording toggle label
  ///
  /// In en, this message translates to:
  /// **'Allow Recording'**
  String get allowRecording;

  /// Allow recording toggle description
  ///
  /// In en, this message translates to:
  /// **'Allow recording of meetings in this room'**
  String get allowRecordingOfMeetingsInThisRoom;

  /// Edit room dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit Room'**
  String get editRoom;

  /// Edit room dialog subtitle
  ///
  /// In en, this message translates to:
  /// **'Update room settings and configuration'**
  String get updateRoomSettingsAndConfiguration;

  /// Room information section title
  ///
  /// In en, this message translates to:
  /// **'Room Information'**
  String get roomInformation;

  /// Participants label
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get participants;

  /// Created date label
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get created;

  /// Save changes button text
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// Total rooms stat label
  ///
  /// In en, this message translates to:
  /// **'Total Rooms'**
  String get totalRooms;

  /// Active rooms stat label
  ///
  /// In en, this message translates to:
  /// **'Active Rooms'**
  String get activeRooms;

  /// Search rooms field hint
  ///
  /// In en, this message translates to:
  /// **'Search rooms...'**
  String get searchRooms;

  /// No rooms found message
  ///
  /// In en, this message translates to:
  /// **'No rooms found'**
  String get noRoomsFound;

  /// No rooms match search message
  ///
  /// In en, this message translates to:
  /// **'No rooms match your search'**
  String get noRoomsMatchYourSearch;

  /// Empty state message
  ///
  /// In en, this message translates to:
  /// **'Create your first room to get started'**
  String get createYourFirstRoomToGetStarted;

  /// Host link label
  ///
  /// In en, this message translates to:
  /// **'Host Link'**
  String get hostLink;

  /// Guest link label
  ///
  /// In en, this message translates to:
  /// **'Guest Link'**
  String get guestLink;

  /// Link copied message
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard!'**
  String get linkCopiedToClipboard;

  /// Copy link tooltip
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// Max participants label
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get max;

  /// Active status label
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// Inactive status label
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// Recording allowed status label
  ///
  /// In en, this message translates to:
  /// **'Recording Allowed'**
  String get recordingAllowed;

  /// No recording status label
  ///
  /// In en, this message translates to:
  /// **'No Recording'**
  String get noRecording;

  /// Room created success message
  ///
  /// In en, this message translates to:
  /// **'Room created successfully!'**
  String get roomCreatedSuccessfully;

  /// Room updated success message
  ///
  /// In en, this message translates to:
  /// **'Room updated successfully!'**
  String get roomUpdatedSuccessfully;

  /// Room deleted success message
  ///
  /// In en, this message translates to:
  /// **'Room deleted successfully!'**
  String get roomDeletedSuccessfully;

  /// Error creating room message
  ///
  /// In en, this message translates to:
  /// **'Error creating room'**
  String get errorCreatingRoom;

  /// Error updating room message
  ///
  /// In en, this message translates to:
  /// **'Error updating room'**
  String get errorUpdatingRoom;

  /// Error deleting room message
  ///
  /// In en, this message translates to:
  /// **'Error deleting room'**
  String get errorDeletingRoom;

  /// Error loading rooms message
  ///
  /// In en, this message translates to:
  /// **'Error loading rooms'**
  String get errorLoadingRooms;

  /// Delete room dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Room'**
  String get deleteRoom;

  /// Delete room confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{roomName}\"? This action cannot be undone.'**
  String areYouSureYouWantToDeleteRoom(String roomName);

  /// Room name validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter a room name'**
  String get pleaseEnterARoomName;

  /// Email field hint
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get enterYourEmailAddress;

  /// Password field hint
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterYourPassword;

  /// Search students field hint
  ///
  /// In en, this message translates to:
  /// **'Search students...'**
  String get searchStudents;

  /// Search teachers field hint
  ///
  /// In en, this message translates to:
  /// **'Search teachers...'**
  String get searchTeachers;

  /// Search courses field hint
  ///
  /// In en, this message translates to:
  /// **'Search courses...'**
  String get searchCourses;

  /// All countries filter option
  ///
  /// In en, this message translates to:
  /// **'All Countries'**
  String get allCountries;

  /// All currencies filter option
  ///
  /// In en, this message translates to:
  /// **'All Currencies'**
  String get allCurrencies;

  /// Search label
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Email and password validation error
  ///
  /// In en, this message translates to:
  /// **'Please enter email and password'**
  String get pleaseEnterEmailAndPassword;

  /// Required field validation message
  ///
  /// In en, this message translates to:
  /// **'is required'**
  String get isRequired;

  /// Login failed dialog title
  ///
  /// In en, this message translates to:
  /// **'Login Failed'**
  String get loginFailed;

  /// OK button text
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Network connection error message
  ///
  /// In en, this message translates to:
  /// **'Network error occurred. Please check your internet connection'**
  String get networkError;

  /// Add student page title
  ///
  /// In en, this message translates to:
  /// **'Add Student'**
  String get addStudent;

  /// Edit student page title
  ///
  /// In en, this message translates to:
  /// **'Edit Student'**
  String get editStudent;

  /// Name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// Name validation error
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameIsRequired;

  /// Email validation error
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailIsRequired;

  /// Invalid email format error
  ///
  /// In en, this message translates to:
  /// **'Invalid email format'**
  String get invalidEmailFormat;

  /// WhatsApp number field label
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Number'**
  String get whatsappNumber;

  /// Country field label
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// Currency field label
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// Hour price field label
  ///
  /// In en, this message translates to:
  /// **'Hour Price'**
  String get hourPrice;

  /// Invalid price error
  ///
  /// In en, this message translates to:
  /// **'Invalid price'**
  String get invalidPrice;

  /// Create student button text
  ///
  /// In en, this message translates to:
  /// **'Create Student'**
  String get createStudent;

  /// Update student button text
  ///
  /// In en, this message translates to:
  /// **'Update Student'**
  String get updateStudent;

  /// Add teacher page title
  ///
  /// In en, this message translates to:
  /// **'Add Teacher'**
  String get addTeacher;

  /// Edit teacher page title
  ///
  /// In en, this message translates to:
  /// **'Edit Teacher'**
  String get editTeacher;

  /// Password required label
  ///
  /// In en, this message translates to:
  /// **'Password *'**
  String get passwordRequired;

  /// Password optional label for edit
  ///
  /// In en, this message translates to:
  /// **'Password (leave empty to keep current)'**
  String get passwordLeaveEmpty;

  /// Password validation error
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordIsRequired;

  /// Password minimum length error
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordMinLength;

  /// Bank name field label
  ///
  /// In en, this message translates to:
  /// **'Bank Name'**
  String get bankName;

  /// Account number field label
  ///
  /// In en, this message translates to:
  /// **'Account Number'**
  String get accountNumber;

  /// Assigned students label
  ///
  /// In en, this message translates to:
  /// **'Assigned Students'**
  String get assignedStudents;

  /// No students assigned message
  ///
  /// In en, this message translates to:
  /// **'No students assigned'**
  String get noStudentsAssigned;

  /// Create teacher button text
  ///
  /// In en, this message translates to:
  /// **'Create Teacher'**
  String get createTeacher;

  /// Update teacher button text
  ///
  /// In en, this message translates to:
  /// **'Update Teacher'**
  String get updateTeacher;

  /// Add course page title
  ///
  /// In en, this message translates to:
  /// **'Add Course'**
  String get addCourse;

  /// Edit course page title
  ///
  /// In en, this message translates to:
  /// **'Edit Course'**
  String get editCourse;

  /// Course name field label
  ///
  /// In en, this message translates to:
  /// **'Course Name'**
  String get courseName;

  /// Student field label
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get student;

  /// Teacher field label
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get teacher;

  /// Course field label
  ///
  /// In en, this message translates to:
  /// **'Course'**
  String get course;

  /// Course name validation error
  ///
  /// In en, this message translates to:
  /// **'Course name is required'**
  String get courseNameIsRequired;

  /// Student selection validation error
  ///
  /// In en, this message translates to:
  /// **'Please select a student'**
  String get pleaseSelectStudent;

  /// Teacher selection validation error
  ///
  /// In en, this message translates to:
  /// **'Please select a teacher'**
  String get pleaseSelectTeacher;

  /// Create course button text
  ///
  /// In en, this message translates to:
  /// **'Create Course'**
  String get createCourse;

  /// Update course button text
  ///
  /// In en, this message translates to:
  /// **'Update Course'**
  String get updateCourse;

  /// Add lesson page title
  ///
  /// In en, this message translates to:
  /// **'Add Lesson'**
  String get addLesson;

  /// Edit lesson page title
  ///
  /// In en, this message translates to:
  /// **'Edit Lesson'**
  String get editLesson;

  /// Date field label
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// Duration field label
  ///
  /// In en, this message translates to:
  /// **'Duration (minutes)'**
  String get durationMinutes;

  /// Duration validation error
  ///
  /// In en, this message translates to:
  /// **'Duration is required'**
  String get durationIsRequired;

  /// Invalid duration error
  ///
  /// In en, this message translates to:
  /// **'Invalid duration'**
  String get invalidDuration;

  /// Status field label
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// Notes field label
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// Duty payment field label
  ///
  /// In en, this message translates to:
  /// **'Duty (Payment)'**
  String get dutyPayment;

  /// Invalid duty amount error
  ///
  /// In en, this message translates to:
  /// **'Invalid duty amount'**
  String get invalidDutyAmount;

  /// Course selection validation error
  ///
  /// In en, this message translates to:
  /// **'Please select a course'**
  String get pleaseSelectCourse;

  /// Present status
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get present;

  /// Cancelled status
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// Create lesson button text
  ///
  /// In en, this message translates to:
  /// **'Create Lesson'**
  String get createLesson;

  /// Update lesson button text
  ///
  /// In en, this message translates to:
  /// **'Update Lesson'**
  String get updateLesson;

  /// USD currency option
  ///
  /// In en, this message translates to:
  /// **'USD - US Dollar'**
  String get usd;

  /// GBP currency option
  ///
  /// In en, this message translates to:
  /// **'GBP - British Pound'**
  String get gbp;

  /// EUR currency option
  ///
  /// In en, this message translates to:
  /// **'EUR - Euro'**
  String get eur;

  /// EGP currency option
  ///
  /// In en, this message translates to:
  /// **'EGP - Egyptian Pound'**
  String get egp;

  /// SAR currency option
  ///
  /// In en, this message translates to:
  /// **'SAR - Saudi Riyal'**
  String get sar;

  /// AED currency option
  ///
  /// In en, this message translates to:
  /// **'AED - UAE Dirham'**
  String get aed;

  /// CAD currency option
  ///
  /// In en, this message translates to:
  /// **'CAD - Canadian Dollar'**
  String get cad;
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
      'that was used.');
}
