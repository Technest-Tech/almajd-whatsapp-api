import '../../domain/repositories/calendar_repository.dart';
import '../datasources/calendar_remote_datasource.dart';
import '../models/calendar_event_model.dart';
import '../models/calendar_teacher_model.dart';
import '../models/calendar_exceptional_class_model.dart';
import '../models/calendar_student_stop_model.dart';
import '../models/calendar_teacher_timetable_model.dart';

class CalendarRepositoryImpl implements CalendarRepository {
  final CalendarRemoteDataSource remoteDataSource;

  CalendarRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<CalendarEventModel>> getEvents({
    DateTime? fromDate,
    DateTime? toDate,
    int? teacherId,
    String? day,
  }) {
    return remoteDataSource.getEvents(
      fromDate: fromDate,
      toDate: toDate,
      teacherId: teacherId,
      day: day,
    );
  }

  @override
  Future<String> generateDailyReminder({
    required String startTime,
    required String endTime,
    required String day,
  }) {
    return remoteDataSource.generateDailyReminder(
      startTime: startTime,
      endTime: endTime,
      day: day,
    );
  }

  @override
  Future<String> getExceptionalReminders({
    required DateTime date,
  }) {
    return remoteDataSource.getExceptionalReminders(date: date);
  }

  @override
  Future<CalendarTeacherTimetableModel> createTeacherTimetable(
    CalendarTeacherTimetableModel timetable,
  ) {
    return remoteDataSource.createTeacherTimetable(timetable);
  }

  @override
  Future<CalendarTeacherTimetableModel> updateTeacherTimetable(
    int id,
    CalendarTeacherTimetableModel timetable,
  ) {
    return remoteDataSource.updateTeacherTimetable(id, timetable);
  }

  @override
  Future<void> deleteTeacherTimetable(int id) {
    return remoteDataSource.deleteTeacherTimetable(id);
  }

  @override
  Future<List<CalendarExceptionalClassModel>> getStudentExceptionalClasses(String studentName) {
    return remoteDataSource.getStudentExceptionalClasses(studentName);
  }

  @override
  Future<CalendarExceptionalClassModel> createExceptionalClass(
    CalendarExceptionalClassModel exceptionalClass,
  ) {
    return remoteDataSource.createExceptionalClass(exceptionalClass);
  }

  @override
  Future<void> deleteExceptionalClass(int id) {
    return remoteDataSource.deleteExceptionalClass(id);
  }

  @override
  Future<List<CalendarTeacherModel>> getCalendarTeachers() {
    return remoteDataSource.getCalendarTeachers();
  }

  @override
  Future<CalendarTeacherModel> getCalendarTeacher(int id) {
    return remoteDataSource.getCalendarTeacher(id);
  }

  @override
  Future<CalendarTeacherModel> createCalendarTeacher(
    CalendarTeacherModel teacher,
  ) {
    return remoteDataSource.createCalendarTeacher(teacher);
  }

  @override
  Future<CalendarTeacherModel> updateCalendarTeacher(
    int id,
    CalendarTeacherModel teacher,
  ) {
    return remoteDataSource.updateCalendarTeacher(id, teacher);
  }

  @override
  Future<void> deleteCalendarTeacher(int id) {
    return remoteDataSource.deleteCalendarTeacher(id);
  }

  @override
  Future<List<CalendarStudentStopModel>> getStudentStops({
    String? studentName,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    return remoteDataSource.getStudentStops(
      studentName: studentName,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }

  @override
  Future<CalendarStudentStopModel> getStudentStop(int id) {
    return remoteDataSource.getStudentStop(id);
  }

  @override
  Future<CalendarStudentStopModel> createStudentStop(
    CalendarStudentStopModel stop,
  ) {
    return remoteDataSource.createStudentStop(stop);
  }

  @override
  Future<CalendarStudentStopModel> updateStudentStop(
    int id,
    CalendarStudentStopModel stop,
  ) {
    return remoteDataSource.updateStudentStop(id, stop);
  }

  @override
  Future<void> deleteStudentStop(int id) {
    return remoteDataSource.deleteStudentStop(id);
  }

  @override
  Future<Map<String, dynamic>> getTeacherTimetableWhatsApp(int teacherId) {
    return remoteDataSource.getTeacherTimetableWhatsApp(teacherId);
  }

  @override
  Future<void> sendTeacherTimetableWhatsApp(int teacherId) {
    return remoteDataSource.sendTeacherTimetableWhatsApp(teacherId);
  }

  @override
  Future<List<Map<String, dynamic>>> getTeacherStudents(int teacherId) {
    return remoteDataSource.getTeacherStudents(teacherId);
  }

  @override
  Future<void> updateStudentStatus({
    required String studentName,
    required String status,
    DateTime? reactiveDate,
  }) {
    return remoteDataSource.updateStudentStatus(
      studentName: studentName,
      status: status,
      reactiveDate: reactiveDate,
    );
  }

  @override
  Future<List<String>> getStudentsList() {
    return remoteDataSource.getStudentsList();
  }

  @override
  Future<String> sendDailyReminderWhatsApp({
    required String startTime,
    required String endTime,
    required String day,
  }) {
    return remoteDataSource.sendDailyReminderWhatsApp(
      startTime: startTime,
      endTime: endTime,
      day: day,
    );
  }

  @override
  Future<String> sendExceptionalReminderWhatsApp({required DateTime date}) {
    return remoteDataSource.sendExceptionalReminderWhatsApp(date: date);
  }
}
