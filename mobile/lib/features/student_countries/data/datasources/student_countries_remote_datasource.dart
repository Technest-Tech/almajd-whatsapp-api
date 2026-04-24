import '../../../../core/utils/api_service.dart';

abstract class StudentCountriesRemoteDataSource {
  Future<Map<String, dynamic>> updateCountryTime(String action, String country);
}

class StudentCountriesRemoteDataSourceImpl
    implements StudentCountriesRemoteDataSource {
  final ApiService apiService;

  StudentCountriesRemoteDataSourceImpl(this.apiService);

  @override
  Future<Map<String, dynamic>> updateCountryTime(
      String action, String country) async {
    try {
      final response = await apiService.get('/student-countries/$action/$country');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      // Log the error for debugging
      print('Error updating country time: $e');
      rethrow;
    }
  }
}

