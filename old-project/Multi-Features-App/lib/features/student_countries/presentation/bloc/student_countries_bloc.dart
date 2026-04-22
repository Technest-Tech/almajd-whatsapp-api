import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/student_countries_remote_datasource.dart';
import 'student_countries_event.dart';
import 'student_countries_state.dart';

class StudentCountriesBloc
    extends Bloc<StudentCountriesEvent, StudentCountriesState> {
  final StudentCountriesRemoteDataSource dataSource;

  StudentCountriesBloc(this.dataSource) : super(const StudentCountriesInitial()) {
    on<UpdateCountryTime>(_onUpdateCountryTime);
  }

  Future<void> _onUpdateCountryTime(
    UpdateCountryTime event,
    Emitter<StudentCountriesState> emit,
  ) async {
    emit(StudentCountriesLoading(
      country: event.country,
      action: event.action,
    ));

    try {
      final response = await dataSource.updateCountryTime(
        event.action,
        event.country,
      );
      
      // Log success for debugging
      print('Country time updated successfully: ${response.toString()}');
      
      emit(StudentCountriesSuccess(
        message: response['message'] as String? ?? 'تم التحديث بنجاح',
        country: event.country,
        action: event.action,
      ));
    } catch (e) {
      // Log error for debugging
      print('Error updating country time: $e');
      print('Error type: ${e.runtimeType}');
      
      String errorMessage = 'حدث خطأ أثناء التحديث';
      if (e.toString().contains('404')) {
        errorMessage = 'الخادم غير متاح. يرجى التحقق من الاتصال';
      } else if (e.toString().contains('500')) {
        errorMessage = 'خطأ في الخادم. يرجى المحاولة لاحقاً';
      } else if (e.toString().contains('Exception: ')) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      } else {
        errorMessage = e.toString();
      }
      
      emit(StudentCountriesError(errorMessage));
    }
  }
}

