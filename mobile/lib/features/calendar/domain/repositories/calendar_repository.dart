import '../../data/models/calendar_event_model.dart';
import '../../data/models/calendar_teacher_model.dart';
import '../../data/models/calendar_exceptional_class_model.dart';
import '../../data/models/calendar_student_stop_model.dart';
import '../../data/models/calendar_teacher_timetable_model.dart';

abstract class CalendarRepository {
  Future<List<CalendarEventModel>> getEvents({
    DateTime? fromDate,
    DateTime? toDate,
    int? teacherId,
    String? day,
  });

  Future<String> generateDailyReminder({
    required String startTime,
    required String endTime,
    required String day,
  });

  Future<String> getExceptionalReminders({
    required DateTime date,
  });

  Future<CalendarTeacherTimetableModel> createTeacherTimetable(
    CalendarTeacherTimetableModel timetable,
  );

  Future<CalendarTeacherTimetableModel> updateTeacherTimetable(
    int id,
    CalendarTeacherTimetableModel timetable,
  );

  Future<void> deleteTeacherTimetable(int id);

  Future<List<CalendarExceptionalClassModel>> getStudentExceptionalClasses(String studentName);

  Future<CalendarExceptionalClassModel> createExceptionalClass(
    CalendarExceptionalClassModel exceptionalClass,
  );

  Future<void> deleteExceptionalClass(int id);

  // Calendar Teachers
  Future<List<CalendarTeacherModel>> getCalendarTeachers();
  Future<CalendarTeacherModel> getCalendarTeacher(int id);
  Future<CalendarTeacherModel> createCalendarTeacher(
    CalendarTeacherModel teacher,
  );
  Future<CalendarTeacherModel> updateCalendarTeacher(
    int id,
    CalendarTeacherModel teacher,
  );
  Future<void> deleteCalendarTeacher(int id);

  // Calendar Student Stops
  Future<List<CalendarStudentStopModel>> getStudentStops({
    String? studentName,
    DateTime? dateFrom,
    DateTime? dateTo,
  });
  Future<CalendarStudentStopModel> getStudentStop(int id);
  Future<CalendarStudentStopModel> createStudentStop(
    CalendarStudentStopModel stop,
  );
  Future<CalendarStudentStopModel> updateStudentStop(
    int id,
    CalendarStudentStopModel stop,
  );
  Future<void> deleteStudentStop(int id);

  // Teacher Timetable WhatsApp
  Future<Map<String, dynamic>> getTeacherTimetableWhatsApp(int teacherId);
  Future<void> sendTeacherTimetableWhatsApp(int teacherId);

  // Teacher Students
  Future<List<Map<String, dynamic>>> getTeacherStudents(int teacherId);

  // Student Status
  Future<void> updateStudentStatus({
    required String studentName,
    required String status,
    DateTime? reactiveDate,
  });

  // Students List
  Future<List<String>> getStudentsList();
}
