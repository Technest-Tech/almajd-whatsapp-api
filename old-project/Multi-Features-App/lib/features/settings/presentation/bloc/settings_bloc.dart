import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/settings_remote_datasource.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsRemoteDataSource dataSource;

  SettingsBloc(this.dataSource) : super(const SettingsLoaded()) {
    on<LoadPaymentSettings>(_onLoadPaymentSettings);
    on<UpdatePaymentSettings>(_onUpdatePaymentSettings);
    on<LoadLessonSettings>(_onLoadLessonSettings);
    on<UpdateLessonSettings>(_onUpdateLessonSettings);
  }

  Future<void> _onLoadPaymentSettings(
    LoadPaymentSettings event,
    Emitter<SettingsState> emit,
  ) async {
    // Get current state values to preserve (read fresh each time)
    final currentState = state is SettingsLoaded 
        ? state as SettingsLoaded 
        : const SettingsLoaded();
    
    emit(currentState.copyWith(isLoadingPayment: true));
    
    try {
      final settings = await dataSource.getPaymentSettings();
      // Read current state again to get any updates from other handlers
      final latestState = state is SettingsLoaded 
          ? state as SettingsLoaded 
          : currentState;
      emit(latestState.copyWith(
        paypalEnabled: settings['paypal_enabled'] ?? false,
        anubpayEnabled: settings['anubpay_enabled'] ?? false,
        isLoadingPayment: false,
      ));
    } catch (e) {
      emit(PaymentSettingsError(e.toString()));
    }
  }

  Future<void> _onUpdatePaymentSettings(
    UpdatePaymentSettings event,
    Emitter<SettingsState> emit,
  ) async {
    // Get current state values to preserve
    final currentState = state is SettingsLoaded 
        ? state as SettingsLoaded 
        : const SettingsLoaded();
    
    emit(currentState.copyWith(isLoadingPayment: true));
    
    try {
      final settings = await dataSource.updatePaymentSettings(
        paypalEnabled: event.paypalEnabled,
        anubpayEnabled: event.anubpayEnabled,
      );
      // Read current state again to get any updates from other handlers
      final latestState = state is SettingsLoaded 
          ? state as SettingsLoaded 
          : currentState;
      emit(latestState.copyWith(
        paypalEnabled: settings['paypal_enabled'] ?? false,
        anubpayEnabled: settings['anubpay_enabled'] ?? false,
        isLoadingPayment: false,
      ));
    } catch (e) {
      emit(PaymentSettingsError(e.toString()));
    }
  }

  Future<void> _onLoadLessonSettings(
    LoadLessonSettings event,
    Emitter<SettingsState> emit,
  ) async {
    // Get current state values to preserve
    final currentState = state is SettingsLoaded 
        ? state as SettingsLoaded 
        : const SettingsLoaded();
    
    emit(currentState.copyWith(isLoadingLesson: true));
    
    try {
      final settings = await dataSource.getLessonSettings();
      // Read current state again to get any updates from other handlers
      final latestState = state is SettingsLoaded 
          ? state as SettingsLoaded 
          : currentState;
      emit(latestState.copyWith(
        teachersCanEditLessons: settings['teachers_can_edit_lessons'] ?? false,
        teachersCanDeleteLessons: settings['teachers_can_delete_lessons'] ?? false,
        teachersCanAddPastLessons: settings['teachers_can_add_past_lessons'] ?? false,
        isLoadingLesson: false,
      ));
    } catch (e) {
      emit(LessonSettingsError(e.toString()));
    }
  }

  Future<void> _onUpdateLessonSettings(
    UpdateLessonSettings event,
    Emitter<SettingsState> emit,
  ) async {
    // Get current state values to preserve
    final currentState = state is SettingsLoaded 
        ? state as SettingsLoaded 
        : const SettingsLoaded();
    
    emit(currentState.copyWith(isLoadingLesson: true));
    
    try {
      final settings = await dataSource.updateLessonSettings(
        teachersCanEditLessons: event.teachersCanEditLessons,
        teachersCanDeleteLessons: event.teachersCanDeleteLessons,
        teachersCanAddPastLessons: event.teachersCanAddPastLessons,
      );
      // Read current state again to get any updates from other handlers
      final latestState = state is SettingsLoaded 
          ? state as SettingsLoaded 
          : currentState;
      emit(latestState.copyWith(
        teachersCanEditLessons: settings['teachers_can_edit_lessons'] ?? false,
        teachersCanDeleteLessons: settings['teachers_can_delete_lessons'] ?? false,
        teachersCanAddPastLessons: settings['teachers_can_add_past_lessons'] ?? false,
        isLoadingLesson: false,
      ));
    } catch (e) {
      emit(LessonSettingsError(e.toString()));
    }
  }
}
