// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Almajd Academy';

  @override
  String get appTagline => 'Management System';

  @override
  String get login => 'Login';

  @override
  String get logout => 'Logout';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get loginToContinue => 'Sign in to continue';

  @override
  String get invalidCredentials => 'Invalid email or password';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get selectModule => 'Choose a module';

  @override
  String get rooms => 'Rooms';

  @override
  String get usersAndCourses => 'Users & Courses';

  @override
  String get billings => 'Billing and Reports';

  @override
  String get calendar => 'Calendar';

  @override
  String get certificates => 'Certificates';

  @override
  String get settingsReports => 'Settings';

  @override
  String get settings => 'Settings';

  @override
  String get comingSoon => 'Coming Soon';

  @override
  String get featureInDevelopment =>
      'This feature is currently under development';

  @override
  String get errorOccurred => 'An error occurred';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get back => 'Back';

  @override
  String get submit => 'Submit';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get certificateDemo => 'Certificate Demo';

  @override
  String get modernCertificateTemplate => 'Modern Certificate Template';

  @override
  String get livePreviewDescription =>
      'This is a live preview of the \"Professional\" template';

  @override
  String get templateFeatures => 'Template Features:';

  @override
  String get chooseTemplate => 'Choose Template';

  @override
  String get previewGeneratePdf => 'Preview & Generate PDF';

  @override
  String get createRoom => 'Create Room';

  @override
  String get createNewRoom => 'Create New Room';

  @override
  String get setUpNewVideoConferenceRoom =>
      'Set up a new video conference room';

  @override
  String get roomName => 'Room Name';

  @override
  String get enterRoomName => 'Enter room name';

  @override
  String get roomActive => 'Room Active';

  @override
  String get enableOrDisableTheRoom => 'Enable or disable the room';

  @override
  String get allowRecording => 'Allow Recording';

  @override
  String get allowRecordingOfMeetingsInThisRoom =>
      'Allow recording of meetings in this room';

  @override
  String get editRoom => 'Edit Room';

  @override
  String get updateRoomSettingsAndConfiguration =>
      'Update room settings and configuration';

  @override
  String get roomInformation => 'Room Information';

  @override
  String get participants => 'Participants';

  @override
  String get created => 'Created';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get totalRooms => 'Total Rooms';

  @override
  String get activeRooms => 'Active Rooms';

  @override
  String get searchRooms => 'Search rooms...';

  @override
  String get noRoomsFound => 'No rooms found';

  @override
  String get noRoomsMatchYourSearch => 'No rooms match your search';

  @override
  String get createYourFirstRoomToGetStarted =>
      'Create your first room to get started';

  @override
  String get hostLink => 'Host Link';

  @override
  String get guestLink => 'Guest Link';

  @override
  String get linkCopiedToClipboard => 'Link copied to clipboard!';

  @override
  String get copyLink => 'Copy link';

  @override
  String get max => 'Max';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get recordingAllowed => 'Recording Allowed';

  @override
  String get noRecording => 'No Recording';

  @override
  String get roomCreatedSuccessfully => 'Room created successfully!';

  @override
  String get roomUpdatedSuccessfully => 'Room updated successfully!';

  @override
  String get roomDeletedSuccessfully => 'Room deleted successfully!';

  @override
  String get errorCreatingRoom => 'Error creating room';

  @override
  String get errorUpdatingRoom => 'Error updating room';

  @override
  String get errorDeletingRoom => 'Error deleting room';

  @override
  String get errorLoadingRooms => 'Error loading rooms';

  @override
  String get deleteRoom => 'Delete Room';

  @override
  String areYouSureYouWantToDeleteRoom(String roomName) {
    return 'Are you sure you want to delete \"$roomName\"? This action cannot be undone.';
  }

  @override
  String get pleaseEnterARoomName => 'Please enter a room name';

  @override
  String get enterYourEmailAddress => 'Enter your email address';

  @override
  String get enterYourPassword => 'Enter your password';

  @override
  String get searchStudents => 'Search students...';

  @override
  String get searchTeachers => 'Search teachers...';

  @override
  String get searchCourses => 'Search courses...';

  @override
  String get allCountries => 'All Countries';

  @override
  String get allCurrencies => 'All Currencies';

  @override
  String get search => 'Search';

  @override
  String get pleaseEnterEmailAndPassword => 'Please enter email and password';

  @override
  String get isRequired => 'is required';

  @override
  String get loginFailed => 'Login Failed';

  @override
  String get ok => 'OK';

  @override
  String get networkError =>
      'Network error occurred. Please check your internet connection';

  @override
  String get addStudent => 'Add Student';

  @override
  String get editStudent => 'Edit Student';

  @override
  String get name => 'Name';

  @override
  String get nameIsRequired => 'Name is required';

  @override
  String get emailIsRequired => 'Email is required';

  @override
  String get invalidEmailFormat => 'Invalid email format';

  @override
  String get whatsappNumber => 'WhatsApp Number';

  @override
  String get country => 'Country';

  @override
  String get currency => 'Currency';

  @override
  String get hourPrice => 'Hour Price';

  @override
  String get invalidPrice => 'Invalid price';

  @override
  String get createStudent => 'Create Student';

  @override
  String get updateStudent => 'Update Student';

  @override
  String get addTeacher => 'Add Teacher';

  @override
  String get editTeacher => 'Edit Teacher';

  @override
  String get passwordRequired => 'Password *';

  @override
  String get passwordLeaveEmpty => 'Password (leave empty to keep current)';

  @override
  String get passwordIsRequired => 'Password is required';

  @override
  String get passwordMinLength => 'Password must be at least 8 characters';

  @override
  String get bankName => 'Bank Name';

  @override
  String get accountNumber => 'Account Number';

  @override
  String get assignedStudents => 'Assigned Students';

  @override
  String get noStudentsAssigned => 'No students assigned';

  @override
  String get createTeacher => 'Create Teacher';

  @override
  String get updateTeacher => 'Update Teacher';

  @override
  String get addCourse => 'Add Course';

  @override
  String get editCourse => 'Edit Course';

  @override
  String get courseName => 'Course Name';

  @override
  String get student => 'Student';

  @override
  String get teacher => 'Teacher';

  @override
  String get course => 'Course';

  @override
  String get courseNameIsRequired => 'Course name is required';

  @override
  String get pleaseSelectStudent => 'Please select a student';

  @override
  String get pleaseSelectTeacher => 'Please select a teacher';

  @override
  String get createCourse => 'Create Course';

  @override
  String get updateCourse => 'Update Course';

  @override
  String get addLesson => 'Add Lesson';

  @override
  String get editLesson => 'Edit Lesson';

  @override
  String get date => 'Date';

  @override
  String get durationMinutes => 'Duration (minutes)';

  @override
  String get durationIsRequired => 'Duration is required';

  @override
  String get invalidDuration => 'Invalid duration';

  @override
  String get status => 'Status';

  @override
  String get notes => 'Notes';

  @override
  String get dutyPayment => 'Duty (Payment)';

  @override
  String get invalidDutyAmount => 'Invalid duty amount';

  @override
  String get pleaseSelectCourse => 'Please select a course';

  @override
  String get present => 'Present';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get createLesson => 'Create Lesson';

  @override
  String get updateLesson => 'Update Lesson';

  @override
  String get usd => 'USD - US Dollar';

  @override
  String get gbp => 'GBP - British Pound';

  @override
  String get eur => 'EUR - Euro';

  @override
  String get egp => 'EGP - Egyptian Pound';

  @override
  String get sar => 'SAR - Saudi Riyal';

  @override
  String get aed => 'AED - UAE Dirham';

  @override
  String get cad => 'CAD - Canadian Dollar';
}
