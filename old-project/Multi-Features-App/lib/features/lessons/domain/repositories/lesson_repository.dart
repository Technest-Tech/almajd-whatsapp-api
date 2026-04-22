import '../../data/models/lesson_model.dart';

abstract class LessonRepository {
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

