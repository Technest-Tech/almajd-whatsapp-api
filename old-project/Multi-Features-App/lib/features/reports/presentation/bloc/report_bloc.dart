import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/report_repository.dart';
import 'report_event.dart';
import 'report_state.dart';

class ReportBloc extends Bloc<ReportEvent, ReportState> {
  final ReportRepository repository;

  ReportBloc(this.repository) : super(ReportInitial()) {
    on<GenerateStudentReport>(_onGenerateStudentReport);
    on<GenerateMultiStudentReport>(_onGenerateMultiStudentReport);
    on<GenerateAcademyStatisticsReport>(_onGenerateAcademyStatisticsReport);
    on<ResetReportState>(_onResetReportState);
  }

  Future<void> _onGenerateStudentReport(
    GenerateStudentReport event,
    Emitter<ReportState> emit,
  ) async {
    emit(const ReportLoading(ReportType.student));
    try {
      final pdfBytes = await repository.generateStudentReport(
        studentId: event.studentId,
        fromDate: event.fromDate,
        toDate: event.toDate,
      );
      emit(ReportSuccess(
        pdfBytes: pdfBytes,
        filename: 'student-report-${event.studentId}.pdf',
        reportType: ReportType.student,
      ));
    } catch (e) {
      emit(ReportError(e.toString(), reportType: ReportType.student));
    }
  }

  Future<void> _onGenerateMultiStudentReport(
    GenerateMultiStudentReport event,
    Emitter<ReportState> emit,
  ) async {
    emit(const ReportLoading(ReportType.multiStudent));
    try {
      final pdfBytes = await repository.generateMultiStudentReport(
        studentIds: event.studentIds,
        fromDate: event.fromDate,
        toDate: event.toDate,
      );
      emit(ReportSuccess(
        pdfBytes: pdfBytes,
        filename: 'multi-student-report.pdf',
        reportType: ReportType.multiStudent,
      ));
    } catch (e) {
      emit(ReportError(e.toString(), reportType: ReportType.multiStudent));
    }
  }

  Future<void> _onGenerateAcademyStatisticsReport(
    GenerateAcademyStatisticsReport event,
    Emitter<ReportState> emit,
  ) async {
    emit(const ReportLoading(ReportType.academyStatistics));
    try {
      final pdfBytes = await repository.generateAcademyStatisticsReport(
        fromDate: event.fromDate,
        toDate: event.toDate,
      );
      emit(ReportSuccess(
        pdfBytes: pdfBytes,
        filename: 'academy-statistics-report.pdf',
        reportType: ReportType.academyStatistics,
      ));
    } catch (e) {
      emit(ReportError(e.toString(), reportType: ReportType.academyStatistics));
    }
  }

  Future<void> _onResetReportState(
    ResetReportState event,
    Emitter<ReportState> emit,
  ) async {
    emit(ReportInitial());
  }
}
