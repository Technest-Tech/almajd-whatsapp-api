import '../../domain/repositories/lesson_repository.dart';
import '../datasources/lesson_remote_datasource.dart';
import '../models/lesson_model.dart';

class LessonRepositoryImpl implements LessonRepository {
  final LessonRemoteDataSource remoteDataSource;

  LessonRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<LessonModel>> getLessons({
    int? courseId,
    int? year,
    int? month,
    String? status,
    int page = 1,
  }) {
    return remoteDataSource.getLessons(
      courseId: courseId,
      year: year,
      month: month,
      status: status,
      page: page,
    );
  }

  @override
  Future<LessonModel> getLesson(int id) {
    return remoteDataSource.getLesson(id);
  }

  @override
  Future<LessonModel> createLesson(LessonModel lesson) {
    return remoteDataSource.createLesson(lesson);
  }

  @override
  Future<LessonModel> updateLesson(int id, LessonModel lesson) {
    return remoteDataSource.updateLesson(id, lesson);
  }

  @override
  Future<void> deleteLesson(int id) {
    return remoteDataSource.deleteLesson(id);
  }
}

