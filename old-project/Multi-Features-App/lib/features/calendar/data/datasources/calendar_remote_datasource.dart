import '../../../../core/utils/api_service.dart';
import '../models/calendar_event_model.dart';
import '../models/calendar_teacher_model.dart';
import '../models/calendar_exceptional_class_model.dart';
import '../models/calendar_student_stop_model.dart';
import '../models/calendar_teacher_timetable_model.dart';

abstract class CalendarRemoteDataSource {
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

  // Students List (for dropdowns)
  Future<List<String>> getStudentsList();

  // Exceptional Classes
  Future<List<CalendarExceptionalClassModel>> getStudentExceptionalClasses(String studentName);
}

class CalendarRemoteDataSourceImpl implements CalendarRemoteDataSource {
  final ApiService apiService;

  CalendarRemoteDataSourceImpl(this.apiService);

  @override
  Future<List<CalendarEventModel>> getEvents({
    DateTime? fromDate,
    DateTime? toDate,
    int? teacherId,
    String? day,
  }) async {
    final queryParams = <String, dynamic>{};
    if (fromDate != null) {
      queryParams['from_date'] = fromDate.toIso8601String().split('T')[0];
    }
    if (toDate != null) {
      queryParams['to_date'] = toDate.toIso8601String().split('T')[0];
    }
    if (teacherId != null) {
      queryParams['teacher_id'] = teacherId;
    }
    if (day != null) {
      queryParams['day'] = day;
    }

    final response = await apiService.get(
      '/calendar/events',
      queryParameters: queryParams,
    );
    
    // Handle null or missing data
    if (response.data == null) {
      return [];
    }
    
    // Check if response has error
    if (response.data['error'] == true) {
      throw Exception(response.data['message'] ?? 'Failed to fetch calendar events');
    }
    
    final eventsData = response.data['events'];
    if (eventsData == null || eventsData is! List) {
      return [];
    }
    
    return (eventsData as List)
        .map((json) {
          try {
            return CalendarEventModel.fromJson(json as Map<String, dynamic>);
          } catch (e) {
            // Log error and return null, then filter out nulls
            print('Error parsing event: $e');
            print('Event data: $json');
            return null;
          }
        })
        .whereType<CalendarEventModel>()
        .toList();
  }

  @override
  Future<String> generateDailyReminder({
    required String startTime,
    required String endTime,
    required String day,
  }) async {
    final response = await apiService.get(
      '/calendar/reminders/daily',
      queryParameters: {
        'start_time': startTime,
        'end_time': endTime,
        'day': day,
      },
    );
    return response.data['message'] as String;
  }

  @override
  Future<String> getExceptionalReminders({
    required DateTime date,
  }) async {
    final response = await apiService.get(
      '/calendar/reminders/exceptional',
      queryParameters: {
        'date': date.toIso8601String().split('T')[0],
      },
    );
    return response.data['message'] as String;
  }

  @override
  Future<CalendarTeacherTimetableModel> createTeacherTimetable(
    CalendarTeacherTimetableModel timetable,
  ) async {
    final response = await apiService.post(
      '/calendar/teacher-timetable',
      data: timetable.toJson(),
    );
    return CalendarTeacherTimetableModel.fromJson(response.data);
  }

  @override
  Future<CalendarTeacherTimetableModel> updateTeacherTimetable(
    int id,
    CalendarTeacherTimetableModel timetable,
  ) async {
    final response = await apiService.put(
      '/calendar/teacher-timetable/$id',
      data: timetable.toJson(),
    );
    return CalendarTeacherTimetableModel.fromJson(response.data);
  }

  @override
  Future<void> deleteTeacherTimetable(int id) async {
    await apiService.delete('/calendar/teacher-timetable/$id');
  }

  @override
  Future<CalendarExceptionalClassModel> createExceptionalClass(
    CalendarExceptionalClassModel exceptionalClass,
  ) async {
    final response = await apiService.post(
      '/calendar/exceptional-class',
      data: exceptionalClass.toJson(),
    );
    return CalendarExceptionalClassModel.fromJson(response.data);
  }

  @override
  Future<void> deleteExceptionalClass(int id) async {
    await apiService.delete('/calendar/exceptional-class/$id');
  }

  @override
  Future<List<CalendarTeacherModel>> getCalendarTeachers() async {
    final response = await apiService.get('/calendar-teachers');
    
    if (response.data == null) {
      return [];
    }
    
    if (response.data is! List) {
      return [];
    }
    
    final data = response.data as List;
    return data
        .map((json) {
          try {
            return CalendarTeacherModel.fromJson(json as Map<String, dynamic>);
          } catch (e) {
            print('Error parsing teacher: $e');
            print('Teacher data: $json');
            return null;
          }
        })
        .whereType<CalendarTeacherModel>()
        .toList();
  }

  @override
  Future<CalendarTeacherModel> getCalendarTeacher(int id) async {
    final response = await apiService.get('/calendar-teachers/$id');
    return CalendarTeacherModel.fromJson(response.data);
  }

  @override
  Future<CalendarTeacherModel> createCalendarTeacher(
    CalendarTeacherModel teacher,
  ) async {
    final response = await apiService.post(
      '/calendar-teachers',
      data: teacher.toJson(),
    );
    return CalendarTeacherModel.fromJson(response.data);
  }

  @override
  Future<CalendarTeacherModel> updateCalendarTeacher(
    int id,
    CalendarTeacherModel teacher,
  ) async {
    final response = await apiService.put(
      '/calendar-teachers/$id',
      data: teacher.toJson(),
    );
    return CalendarTeacherModel.fromJson(response.data);
  }

  @override
  Future<void> deleteCalendarTeacher(int id) async {
    await apiService.delete('/calendar-teachers/$id');
  }

  @override
  Future<List<CalendarStudentStopModel>> getStudentStops({
    String? studentName,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final queryParams = <String, dynamic>{};
    if (studentName != null) {
      queryParams['student_name'] = studentName;
    }
    if (dateFrom != null) {
      queryParams['date_from'] = dateFrom.toIso8601String().split('T')[0];
    }
    if (dateTo != null) {
      queryParams['date_to'] = dateTo.toIso8601String().split('T')[0];
    }

    final response = await apiService.get(
      '/calendar-student-stops',
      queryParameters: queryParams,
    );
    final data = response.data as List;
    return data
        .map((json) => CalendarStudentStopModel.fromJson(json))
        .toList();
  }

  @override
  Future<CalendarStudentStopModel> getStudentStop(int id) async {
    final response = await apiService.get('/calendar-student-stops/$id');
    return CalendarStudentStopModel.fromJson(response.data);
  }

  @override
  Future<CalendarStudentStopModel> createStudentStop(
    CalendarStudentStopModel stop,
  ) async {
    final response = await apiService.post(
      '/calendar-student-stops',
      data: stop.toJson(),
    );
    return CalendarStudentStopModel.fromJson(response.data);
  }

  @override
  Future<CalendarStudentStopModel> updateStudentStop(
    int id,
    CalendarStudentStopModel stop,
  ) async {
    final response = await apiService.put(
      '/calendar-student-stops/$id',
      data: stop.toJson(),
    );
    return CalendarStudentStopModel.fromJson(response.data);
  }

  @override
  Future<void> deleteStudentStop(int id) async {
    await apiService.delete('/calendar-student-stops/$id');
  }

  @override
  Future<Map<String, dynamic>> getTeacherTimetableWhatsApp(int teacherId) async {
    final response = await apiService.get('/calendar/teacher/$teacherId/whatsapp');
    return {
      'report': response.data['report'] as String? ?? '',
      'phoneNumber': response.data['phoneNumber'] as String? ?? '',
    };
  }

  @override
  Future<void> sendTeacherTimetableWhatsApp(int teacherId) async {
    await apiService.post('/calendar/teacher/$teacherId/send-whatsapp');
  }

  @override
  Future<List<Map<String, dynamic>>> getTeacherStudents(int teacherId) async {
    final response = await apiService.get('/calendar/teacher/$teacherId/students');
    if (response.data == null || response.data['students'] == null) {
      return [];
    }
    return List<Map<String, dynamic>>.from(response.data['students'] as List);
  }

  @override
  Future<void> updateStudentStatus({
    required String studentName,
    required String status,
    DateTime? reactiveDate,
  }) async {
    await apiService.put(
      '/calendar/student/status',
      data: {
        'student_name': studentName,
        'status': status,
        if (reactiveDate != null) 'reactive_date': reactiveDate.toIso8601String().split('T')[0],
      },
    );
  }

  @override
  Future<List<String>> getStudentsList() async {
    final response = await apiService.get('/calendar/students/list');
    if (response.data == null || response.data['students'] == null) {
      return [];
    }
    return List<String>.from(response.data['students'] as List);
  }

  @override
  Future<List<CalendarExceptionalClassModel>> getStudentExceptionalClasses(String studentName) async {
    final response = await apiService.get(
      '/calendar/exceptional-classes/student',
      queryParameters: {'student_name': studentName},
    );
    if (response.data == null || response.data['exceptional_classes'] == null) {
      return [];
    }
    return (response.data['exceptional_classes'] as List)
        .map((json) => CalendarExceptionalClassModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
