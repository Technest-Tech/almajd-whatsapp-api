import '../../../core/api/api_client.dart';
import 'models/schedule_model.dart';

class ScheduleRepository {
  final ApiClient apiClient;

  ScheduleRepository({required this.apiClient});

  Future<List<ScheduleModel>> getSchedules({
    bool? isActive,
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (isActive != null) params['is_active'] = isActive ? 1 : 0;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await apiClient.dio.get('/schedules', queryParameters: params);
    final List data = response.data['data'];
    return data.map((j) => ScheduleModel.fromJson(j)).toList();
  }

  Future<ScheduleModel> getSchedule(int id) async {
    final response = await apiClient.dio.get('/schedules/$id');
    return ScheduleModel.fromJson(response.data['data']);
  }

  Future<ScheduleModel> createSchedule(Map<String, dynamic> data) async {
    final response = await apiClient.dio.post('/schedules', data: data);
    return ScheduleModel.fromJson(response.data['data']);
  }

  Future<ScheduleModel> updateSchedule(int id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.put('/schedules/$id', data: data);
    return ScheduleModel.fromJson(response.data['data']);
  }

  Future<void> deleteSchedule(int id) async {
    await apiClient.dio.delete('/schedules/$id');
  }

  // ── Entries ──

  Future<ScheduleEntryModel> addEntry(int scheduleId, Map<String, dynamic> data) async {
    final response = await apiClient.dio.post('/schedules/$scheduleId/entries', data: data);
    return ScheduleEntryModel.fromJson(response.data['data']);
  }

  Future<ScheduleEntryModel> updateEntry(int scheduleId, int entryId, Map<String, dynamic> data) async {
    final response = await apiClient.dio.put('/schedules/$scheduleId/entries/$entryId', data: data);
    return ScheduleEntryModel.fromJson(response.data['data']);
  }

  Future<void> deleteEntry(int scheduleId, int entryId) async {
    await apiClient.dio.delete('/schedules/$scheduleId/entries/$entryId');
  }
}
