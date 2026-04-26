import 'package:equatable/equatable.dart';
import '../../data/models/calendar_event_model.dart';
import '../../data/models/calendar_teacher_model.dart';
import '../../data/models/calendar_exceptional_class_model.dart';
import '../../data/models/calendar_student_stop_model.dart';
import '../../data/models/calendar_teacher_timetable_model.dart';

abstract class CalendarState extends Equatable {
  const CalendarState();

  @override
  List<Object?> get props => [];
}

class CalendarInitial extends CalendarState {}

class CalendarLoading extends CalendarState {}

// Calendar Events States
class CalendarEventsLoaded extends CalendarState {
  final List<CalendarEventModel> events;

  const CalendarEventsLoaded(this.events);

  @override
  List<Object?> get props => [events];
}

// Reminder States
class DailyReminderGenerated extends CalendarState {
  final String message;

  const DailyReminderGenerated(this.message);

  @override
  List<Object?> get props => [message];
}

class ExceptionalRemindersLoaded extends CalendarState {
  final String message;

  const ExceptionalRemindersLoaded(this.message);

  @override
  List<Object?> get props => [message];
}

class ReminderSentSuccess extends CalendarState {
  final String message;

  const ReminderSentSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// Calendar Teachers States
class CalendarTeachersLoaded extends CalendarState {
  final List<CalendarTeacherModel> teachers;

  const CalendarTeachersLoaded(this.teachers);

  @override
  List<Object?> get props => [teachers];
}

class CalendarTeacherLoaded extends CalendarState {
  final CalendarTeacherModel teacher;

  const CalendarTeacherLoaded(this.teacher);

  @override
  List<Object?> get props => [teacher];
}

// Teacher Students States
class CalendarTeacherStudentsLoaded extends CalendarState {
  final List<Map<String, dynamic>> students;

  const CalendarTeacherStudentsLoaded(this.students);

  @override
  List<Object?> get props => [students];
}

// Exceptional Classes States
class StudentExceptionalClassesLoaded extends CalendarState {
  final List<CalendarExceptionalClassModel> exceptionalClasses;

  const StudentExceptionalClassesLoaded(this.exceptionalClasses);

  @override
  List<Object?> get props => [exceptionalClasses];
}

// Student Stops States
class StudentStopsLoaded extends CalendarState {
  final List<CalendarStudentStopModel> stops;

  const StudentStopsLoaded(this.stops);

  @override
  List<Object?> get props => [stops];
}

class StudentStopLoaded extends CalendarState {
  final CalendarStudentStopModel stop;

  const StudentStopLoaded(this.stop);

  @override
  List<Object?> get props => [stop];
}

// Operation Success States
class CalendarOperationSuccess extends CalendarState {
  final String message;

  const CalendarOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// Error State
class CalendarError extends CalendarState {
  final String message;

  const CalendarError(this.message);

  @override
  List<Object?> get props => [message];
}
