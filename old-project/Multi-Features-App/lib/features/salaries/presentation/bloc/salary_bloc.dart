import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/models/salary_model.dart';
import '../../domain/repositories/salary_repository.dart';
import 'salary_event.dart';
import 'salary_state.dart';

class SalaryBloc extends Bloc<SalaryEvent, SalaryState> {
  final SalaryRepository repository;
  final ApiService apiService;
  SalariesResponseModel? _lastLoadedResponse;

  SalaryBloc(this.repository, this.apiService) : super(SalaryInitial()) {
    on<LoadSalaries>(_onLoadSalaries);
    on<ExportSalaries>(_onExportSalaries);
  }

  Future<void> _onLoadSalaries(
    LoadSalaries event,
    Emitter<SalaryState> emit,
  ) async {
    emit(SalaryLoading());
    try {
      final response = await repository.getSalaries(
        event.year, 
        event.month,
        unifiedHourPrice: event.unifiedHourPrice,
      );
      _lastLoadedResponse = response;
      emit(SalariesLoaded(response));
    } catch (e) {
      emit(SalaryError(e.toString()));
    }
  }

  Future<void> _onExportSalaries(
    ExportSalaries event,
    Emitter<SalaryState> emit,
  ) async {
    emit(SalaryExporting(lastLoadedResponse: _lastLoadedResponse));
    try {
      final exportUrl = await repository.getExportUrl(
        event.year, 
        event.month,
        unifiedHourPrice: event.unifiedHourPrice,
      );
      
      // Get download directory
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'salaries_${event.year}_${event.month.toString().padLeft(2, '0')}.xlsx';
      final filePath = '${directory.path}/$fileName';

      // Download file using dio with authentication
      final token = await StorageService.getToken();
      if (token != null) {
        apiService.setAuthToken(token);
      }
      
      await apiService.dio.download(
        exportUrl,
        filePath,
        options: Options(
          headers: {
            'Accept': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          },
          responseType: ResponseType.bytes,
        ),
      );

      emit(SalaryExportSuccess(filePath, lastLoadedResponse: _lastLoadedResponse));
    } catch (e) {
      emit(SalaryExportError(e.toString(), lastLoadedResponse: _lastLoadedResponse));
    }
  }
}
