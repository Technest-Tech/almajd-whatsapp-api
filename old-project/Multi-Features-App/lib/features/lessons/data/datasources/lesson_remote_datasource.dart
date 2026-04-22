import '../../../../core/utils/api_service.dart';
import '../models/lesson_model.dart';

abstract class LessonRemoteDataSource {
  Future<List<LessonModel>> getLessons({
    int? courseId,
    int? year,
    int? month,
    String? status,
    int page = 1,
  });
  Future<LessonModel> getLesson(int id);
  Future<LessonModel> createLesson(LessonModel lesson);
  Future<LessonModel> updateLesson(int id, LessonModel lesson);
  Future<void> deleteLesson(int id);
}

class LessonRemoteDataSourceImpl implements LessonRemoteDataSource {
  final ApiService apiService;

  LessonRemoteDataSourceImpl(this.apiService);

  @override
  Future<List<LessonModel>> getLessons({
    int? courseId,
    int? year,
    int? month,
    String? status,
    int page = 1,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      if (courseId != null) 'course_id': courseId,
      if (year != null) 'year': year,
      if (month != null) 'month': month,
      if (status != null && status.isNotEmpty) 'status': status,
    };

    final response = await apiService.get('/lessons', queryParameters: queryParams);
    
    // Safely extract data from response
    dynamic responseData = response.data;
    List<dynamic> lessonsList;
    
    if (responseData is Map) {
      // Handle paginated response: {data: [...], current_page: 1, ...}
      if (responseData.containsKey('data') && responseData['data'] is List) {
        lessonsList = responseData['data'] as List;
      } else {
        // Handle direct list response
        lessonsList = responseData.values.first is List 
            ? responseData.values.first as List 
            : [];
      }
    } else if (responseData is List) {
      lessonsList = responseData;
    } else {
      lessonsList = [];
    }
    
    return lessonsList
        .where((item) => item is Map<String, dynamic>)
        .map((json) => LessonModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<LessonModel> getLesson(int id) async {
    final response = await apiService.get('/lessons/$id');
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return LessonModel.fromJson(data);
    } else {
      throw Exception('Invalid response format for lesson');
    }
  }

  @override
  Future<LessonModel> createLesson(LessonModel lesson) async {
    try {
    final response = await apiService.post('/lessons', data: lesson.toJson());
      final data = response.data;
      if (data is Map<String, dynamic>) {
        // Check if response contains error
        if (data.containsKey('error')) {
          throw Exception(data['error'].toString());
        }
        return LessonModel.fromJson(data);
      } else {
        throw Exception('Invalid response format for created lesson');
      }
    } catch (e) {
      // Re-throw with more context if needed
      throw e;
    }
  }

  @override
  Future<LessonModel> updateLesson(int id, LessonModel lesson) async {
    final response = await apiService.put('/lessons/$id', data: lesson.toJson());
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return LessonModel.fromJson(data);
    } else {
      throw Exception('Invalid response format for updated lesson');
    }
  }

  @override
  Future<void> deleteLesson(int id) async {
    await apiService.delete('/lessons/$id');
  }
}

