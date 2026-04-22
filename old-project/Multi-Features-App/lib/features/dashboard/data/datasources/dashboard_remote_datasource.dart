import '../../../../core/utils/api_service.dart';

abstract class DashboardRemoteDataSource {
  Future<Map<String, dynamic>> getAdminStats();
  Future<Map<String, dynamic>> getTeacherStats();
}

class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  final ApiService apiService;

  DashboardRemoteDataSourceImpl(this.apiService);

  @override
  Future<Map<String, dynamic>> getAdminStats() async {
    final response = await apiService.get('/dashboard/stats');
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getTeacherStats() async {
    final response = await apiService.get('/dashboard/teacher-stats');
    return response.data as Map<String, dynamic>;
  }
}

