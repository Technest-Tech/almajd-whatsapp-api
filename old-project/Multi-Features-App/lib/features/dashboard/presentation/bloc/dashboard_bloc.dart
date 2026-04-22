import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final DashboardRemoteDataSource dataSource;

  DashboardBloc(this.dataSource) : super(DashboardInitial()) {
    on<LoadAdminStats>(_onLoadAdminStats);
    on<LoadTeacherStats>(_onLoadTeacherStats);
  }

  Future<void> _onLoadAdminStats(
    LoadAdminStats event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());
    try {
      final stats = await dataSource.getAdminStats();
      emit(AdminStatsLoaded(stats));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }

  Future<void> _onLoadTeacherStats(
    LoadTeacherStats event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());
    try {
      final stats = await dataSource.getTeacherStats();
      emit(TeacherStatsLoaded(stats));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }
}

