import 'package:equatable/equatable.dart';

abstract class ReportEvent extends Equatable {
  const ReportEvent();

  @override
  List<Object?> get props => [];
}

class GenerateStudentReport extends ReportEvent {
  final int studentId;
  final String fromDate;
  final String toDate;

  const GenerateStudentReport({
    required this.studentId,
    required this.fromDate,
    required this.toDate,
  });

  @override
  List<Object?> get props => [studentId, fromDate, toDate];
}

class GenerateMultiStudentReport extends ReportEvent {
  final List<int> studentIds;
  final String fromDate;
  final String toDate;

  const GenerateMultiStudentReport({
    required this.studentIds,
    required this.fromDate,
    required this.toDate,
  });

  @override
  List<Object?> get props => [studentIds, fromDate, toDate];
}

class GenerateAcademyStatisticsReport extends ReportEvent {
  final String fromDate;
  final String toDate;

  const GenerateAcademyStatisticsReport({
    required this.fromDate,
    required this.toDate,
  });

  @override
  List<Object?> get props => [fromDate, toDate];
}

class ResetReportState extends ReportEvent {
  const ResetReportState();
}
