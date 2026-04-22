import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/calendar_repository.dart';
import '../../data/models/calendar_event_model.dart';
import '../../data/models/calendar_teacher_model.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

class CalendarBloc extends Bloc<CalendarEvent, CalendarState> {
  final CalendarRepository repository;
  List<CalendarEventModel>? _cachedEvents;
  List<CalendarTeacherModel>? _cachedTeachers;
  Map<int, List<Map<String, dynamic>>>? _cachedStudents; // Cache students by teacherId

  CalendarBloc(this.repository) : super(CalendarInitial()) {
    // Calendar Events
    on<LoadCalendarEvents>(_onLoadCalendarEvents);

    // Reminders
    on<GenerateDailyReminder>(_onGenerateDailyReminder);
    on<GetExceptionalReminders>(_onGetExceptionalReminders);

    // Teacher Timetables
    on<CreateTeacherTimetable>(_onCreateTeacherTimetable);
    on<UpdateTeacherTimetable>(_onUpdateTeacherTimetable);
    on<DeleteTeacherTimetable>(_onDeleteTeacherTimetable);

    // Exceptional Classes
    on<LoadStudentExceptionalClasses>(_onLoadStudentExceptionalClasses);
    on<CreateExceptionalClass>(_onCreateExceptionalClass);
    on<DeleteExceptionalClass>(_onDeleteExceptionalClass);

    // Calendar Teachers
    on<LoadCalendarTeachers>(_onLoadCalendarTeachers);
    on<LoadCalendarTeacher>(_onLoadCalendarTeacher);
    on<CreateCalendarTeacher>(_onCreateCalendarTeacher);
    on<UpdateCalendarTeacher>(_onUpdateCalendarTeacher);
    on<DeleteCalendarTeacher>(_onDeleteCalendarTeacher);
    
    // Teacher Students
    on<LoadTeacherStudents>(_onLoadTeacherStudents);
    
    // Student Status
    on<UpdateStudentStatus>(_onUpdateStudentStatus);

    // Student Stops
    on<LoadStudentStops>(_onLoadStudentStops);
    on<LoadStudentStop>(_onLoadStudentStop);
    on<CreateStudentStop>(_onCreateStudentStop);
    on<UpdateStudentStop>(_onUpdateStudentStop);
    on<DeleteStudentStop>(_onDeleteStudentStop);
  }

  Future<void> _onLoadCalendarEvents(
    LoadCalendarEvents event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());
    try {
      final events = await repository.getEvents(
        fromDate: event.fromDate,
        toDate: event.toDate,
        teacherId: event.teacherId,
        day: event.day,
      );
      _cachedEvents = events; // Cache events
      emit(CalendarEventsLoaded(events));
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> _onGenerateDailyReminder(
    GenerateDailyReminder event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());
    try {
      final message = await repository.generateDailyReminder(
        startTime: event.startTime,
        endTime: event.endTime,
        day: event.day,
      );
      emit(DailyReminderGenerated(message));
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> _onGetExceptionalReminders(
    GetExceptionalReminders event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());
    try {
      final message = await repository.getExceptionalReminders(date: event.date);
      emit(ExceptionalRemindersLoaded(message));
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> _onCreateTeacherTimetable(
    CreateTeacherTimetable event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());
    try {
      await repository.createTeacherTimetable(event.timetable);
      emit(const CalendarOperationSuccess('تم إضافة الدرس بنجاح'));
      add(const LoadCalendarEvents());
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> _onUpdateTeacherTimetable(
    UpdateTeacherTimetable event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());
    try {
      await repository.updateTeacherTimetable(event.id, event.timetable);
      emit(const CalendarOperationSuccess('Timetable updated successfully'));
      add(LoadCalendarEvents());
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> _onDeleteTeacherTimetable(
    DeleteTeacherTimetable event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());
    try {
      await repository.deleteTeacherTimetable(event.id);
      emit(const CalendarOperationSuccess('Timetable deleted successfully'));
      add(LoadCalendarEvents());
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> _onLoadStudentExceptionalClasses(
    LoadStudentExceptionalClasses event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());
    try {
      final exceptionalClasses = await repository.getStudentExceptionalClasses(event.studentName);
      emit(StudentExceptionalClassesLoaded(exceptionalClasses));
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> _onCreateExceptionalClass(
    CreateExceptionalClass event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());
    try {
      await repository.createExceptionalClass(event.exceptionalClass);
      emit(const CalendarOperationSuccess('تم إضافة الدرس بنجاح'));
      add(const LoadCalendarEvents());
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> _onDeleteExceptionalClass(
    DeleteExceptionalClass event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());
    try {
      await repository.deleteExceptionalClass(event.id);
      emit(const CalendarOperationSuccess('Exceptional class deleted successfully'));
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> _onLoadCalendarTeachers(
    LoadCalendarTeachers event,
    Emitter<CalendarState> emit,
  ) async {
    // Don't emit loading if we already have cached teachers - show them immediately
    if (_cachedTeachers != null && _cachedTeachers!.isNotEmpty) {
      // Emit cached teachers immediately without showing loading
      emit(CalendarTeachersLoaded(_cachedTeachers!));
      // Still fetch fresh data in background
      try {
        final teachers = await repository.getCalendarTeachers();
        _cachedTeachers = teachers; // Update cache
        // Always update with fresh data
        emit(CalendarTeachersLoaded(teachers));
      } catch (e) {
        // On error, keep showing cached teachers - don't emit error if we have cache
        // The cached data is still valid, just log the error
        if (_cachedTeachers != null && _cachedTeachers!.isNotEmpty) {
          // Keep showing cached data, don't emit error
        } else {
          emit(CalendarError(e.toString()));
        }
      }
      return;
    }
    
    // Only show loading if we don't have cached data
    emit(CalendarLoading());
    
    try {
      final teachers = await repository.getCalendarTeachers();
      _cachedTeachers = teachers; // Cache teachers
      
      // Always emit CalendarTeachersLoaded when loading teachers
      // This ensures the state always completes
      emit(CalendarTeachersLoaded(teachers));
    } catch (e) {
      // On error, show error state
      emit(CalendarError(e.toString()));
    }
  }
  
  // Getter to access cached teachers
  List<CalendarEventModel>? get cachedEvents => _cachedEvents;
  List<CalendarTeacherModel>? get cachedTeachers => _cachedTeachers;
  
  // Getter to access cached students for a teacher
  List<Map<String, dynamic>>? getCachedStudents(int teacherId) {
    return _cachedStudents?[teacherId];
  }

  Future<void> _onLoadCalendarTeacher(
    LoadCalendarTeacher event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());
    try {
      final teacher = await repository.getCalendarTeacher(event.id);
      emit(CalendarTeacherLoaded(teacher));
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> _onCreateCalendarTeacher(
    CreateCalendarTeacher event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());
    try {
      await repository.createCalendarTeacher(event.teacher);
      emit(const CalendarOperationSuccess('Teacher created successfully'));
      add(LoadCalendarTeachers());
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> _onUpdateCalendarTeacher(
    UpdateCalendarTeacher event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());
    try {
      await repository.updateCalendarTeacher(event.id, event.teacher);
      emit(const CalendarOperationSuccess('Teacher updated successfully'));
      add(LoadCalendarTeachers());
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> _onDeleteCalendarTeacher(
    DeleteCalendarTeacher event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());
    try {
      await repository.deleteCalendarTeacher(event.id);
      emit(const CalendarOperationSuccess('Teacher deleted successfully'));
      add(LoadCalendarTeachers());
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> _onLoadStudentStops(
    LoadStudentStops event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());
    try {
      final stops = await repository.getStudentStops(
        studentName: event.studentName,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
      );
      emit(StudentStopsLoaded(stops));
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> _onLoadStudentStop(
    LoadStudentStop event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());
    try {
      final stop = await repository.getStudentStop(event.id);
      emit(StudentStopLoaded(stop));
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> _onCreateStudentStop(
    CreateStudentStop event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());
    try {
      await repository.createStudentStop(event.stop);
      emit(const CalendarOperationSuccess('Student stop created successfully'));
      add(LoadStudentStops());
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> _onUpdateStudentStop(
    UpdateStudentStop event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());
    try {
      await repository.updateStudentStop(event.id, event.stop);
      emit(const CalendarOperationSuccess('Student stop updated successfully'));
      add(LoadStudentStops());
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> _onDeleteStudentStop(
    DeleteStudentStop event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());
    try {
      await repository.deleteStudentStop(event.id);
      emit(const CalendarOperationSuccess('Student stop deleted successfully'));
      add(LoadStudentStops());
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> _onLoadTeacherStudents(
    LoadTeacherStudents event,
    Emitter<CalendarState> emit,
  ) async {
    // Don't emit loading if we already have cached students - show them immediately
    if (_cachedStudents != null && _cachedStudents![event.teacherId] != null && _cachedStudents![event.teacherId]!.isNotEmpty) {
      // Emit cached students immediately without showing loading
      emit(CalendarTeacherStudentsLoaded(_cachedStudents![event.teacherId]!));
      // Still fetch fresh data in background
      try {
        final students = await repository.getTeacherStudents(event.teacherId);
        _cachedStudents ??= {};
        _cachedStudents![event.teacherId] = students; // Update cache
        // Always update with fresh data
        emit(CalendarTeacherStudentsLoaded(students));
      } catch (e) {
        // On error, keep showing cached students - don't emit error if we have cache
        // The cached data is still valid, just log the error
        if (_cachedStudents != null && _cachedStudents![event.teacherId] != null && _cachedStudents![event.teacherId]!.isNotEmpty) {
          // Keep showing cached data, don't emit error
        } else {
          emit(CalendarError(e.toString()));
        }
      }
      return;
    }
    
    // Only show loading if we don't have cached data
    emit(CalendarLoading());
    
    try {
      final students = await repository.getTeacherStudents(event.teacherId);
      _cachedStudents ??= {};
      _cachedStudents![event.teacherId] = students; // Cache students
      
      // Always emit CalendarTeacherStudentsLoaded when loading students
      // This ensures the state always completes
      emit(CalendarTeacherStudentsLoaded(students));
    } catch (e) {
      // On error, show error state
      emit(CalendarError(e.toString()));
    }
  }

  Future<void> _onUpdateStudentStatus(
    UpdateStudentStatus event,
    Emitter<CalendarState> emit,
  ) async {
    emit(CalendarLoading());
    try {
      await repository.updateStudentStatus(
        studentName: event.studentName,
        status: event.status,
        reactiveDate: event.reactiveDate,
      );
      emit(const CalendarOperationSuccess('تم تحديث حالة الطالب بنجاح'));
    } catch (e) {
      emit(CalendarError(e.toString()));
    }
  }
}
