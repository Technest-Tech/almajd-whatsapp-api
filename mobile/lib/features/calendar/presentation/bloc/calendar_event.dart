import 'package:equatable/equatable.dart';
import '../../data/models/calendar_event_model.dart';
import '../../data/models/calendar_teacher_model.dart';
import '../../data/models/calendar_exceptional_class_model.dart';
import '../../data/models/calendar_student_stop_model.dart';
import '../../data/models/calendar_teacher_timetable_model.dart';

abstract class CalendarEvent extends Equatable {
  const CalendarEvent();

  @override
  List<Object?> get props => [];
}

// Calendar Events
class LoadCalendarEvents extends CalendarEvent {
  final DateTime? fromDate;
  final DateTime? toDate;
  final int? teacherId;
  final String? day;

  const LoadCalendarEvents({
    this.fromDate,
    this.toDate,
    this.teacherId,
    this.day,
  });

  @override
  List<Object?> get props => [fromDate, toDate, teacherId, day];
}

// Reminders
class GenerateDailyReminder extends CalendarEvent {
  final String startTime;
  final String endTime;
  final String day;

  const GenerateDailyReminder({
    required this.startTime,
    required this.endTime,
    required this.day,
  });

  @override
  List<Object?> get props => [startTime, endTime, day];
}

class GetExceptionalReminders extends CalendarEvent {
  final DateTime date;

  const GetExceptionalReminders(this.date);

  @override
  List<Object?> get props => [date];
}

class SendDailyReminderWhatsApp extends CalendarEvent {
  final String startTime;
  final String endTime;
  final String day;

  const SendDailyReminderWhatsApp({
    required this.startTime,
    required this.endTime,
    required this.day,
  });

  @override
  List<Object?> get props => [startTime, endTime, day];
}

class SendExceptionalReminderWhatsApp extends CalendarEvent {
  final DateTime date;

  const SendExceptionalReminderWhatsApp(this.date);

  @override
  List<Object?> get props => [date];
}

// Teacher Timetables
class CreateTeacherTimetable extends CalendarEvent {
  final CalendarTeacherTimetableModel timetable;

  const CreateTeacherTimetable(this.timetable);

  @override
  List<Object?> get props => [timetable];
}

class UpdateTeacherTimetable extends CalendarEvent {
  final int id;
  final CalendarTeacherTimetableModel timetable;

  const UpdateTeacherTimetable(this.id, this.timetable);

  @override
  List<Object?> get props => [id, timetable];
}

class DeleteTeacherTimetable extends CalendarEvent {
  final int id;

  const DeleteTeacherTimetable(this.id);

  @override
  List<Object?> get props => [id];
}

// Exceptional Classes
class LoadStudentExceptionalClasses extends CalendarEvent {
  final String studentName;

  const LoadStudentExceptionalClasses(this.studentName);

  @override
  List<Object?> get props => [studentName];
}

class CreateExceptionalClass extends CalendarEvent {
  final CalendarExceptionalClassModel exceptionalClass;

  const CreateExceptionalClass(this.exceptionalClass);

  @override
  List<Object?> get props => [exceptionalClass];
}

class DeleteExceptionalClass extends CalendarEvent {
  final int id;

  const DeleteExceptionalClass(this.id);

  @override
  List<Object?> get props => [id];
}

// Calendar Teachers
class LoadCalendarTeachers extends CalendarEvent {
  const LoadCalendarTeachers();
}

class LoadCalendarTeacher extends CalendarEvent {
  final int id;

  const LoadCalendarTeacher(this.id);

  @override
  List<Object?> get props => [id];
}

class CreateCalendarTeacher extends CalendarEvent {
  final CalendarTeacherModel teacher;

  const CreateCalendarTeacher(this.teacher);

  @override
  List<Object?> get props => [teacher];
}

class UpdateCalendarTeacher extends CalendarEvent {
  final int id;
  final CalendarTeacherModel teacher;

  const UpdateCalendarTeacher(this.id, this.teacher);

  @override
  List<Object?> get props => [id, teacher];
}

class DeleteCalendarTeacher extends CalendarEvent {
  final int id;

  const DeleteCalendarTeacher(this.id);

  @override
  List<Object?> get props => [id];
}

// Teacher Students
class LoadTeacherStudents extends CalendarEvent {
  final int teacherId;

  const LoadTeacherStudents(this.teacherId);

  @override
  List<Object?> get props => [teacherId];
}

// Student Status
class UpdateStudentStatus extends CalendarEvent {
  final String studentName;
  final String status;
  final DateTime? reactiveDate;

  const UpdateStudentStatus({
    required this.studentName,
    required this.status,
    this.reactiveDate,
  });

  @override
  List<Object?> get props => [studentName, status, reactiveDate];
}

// Student Stops
class LoadStudentStops extends CalendarEvent {
  final String? studentName;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const LoadStudentStops({
    this.studentName,
    this.dateFrom,
    this.dateTo,
  });

  @override
  List<Object?> get props => [studentName, dateFrom, dateTo];
}

class LoadStudentStop extends CalendarEvent {
  final int id;

  const LoadStudentStop(this.id);

  @override
  List<Object?> get props => [id];
}

class CreateStudentStop extends CalendarEvent {
  final CalendarStudentStopModel stop;

  const CreateStudentStop(this.stop);

  @override
  List<Object?> get props => [stop];
}

class UpdateStudentStop extends CalendarEvent {
  final int id;
  final CalendarStudentStopModel stop;

  const UpdateStudentStop(this.id, this.stop);

  @override
  List<Object?> get props => [id, stop];
}

class DeleteStudentStop extends CalendarEvent {
  final int id;

  const DeleteStudentStop(this.id);

  @override
  List<Object?> get props => [id];
}
