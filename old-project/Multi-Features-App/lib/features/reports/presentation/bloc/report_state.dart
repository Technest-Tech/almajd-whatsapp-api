import 'dart:typed_data';
import 'package:equatable/equatable.dart';

enum ReportType { student, multiStudent, academyStatistics }

abstract class ReportState extends Equatable {
  const ReportState();

  @override
  List<Object?> get props => [];
}

class ReportInitial extends ReportState {}

class ReportLoading extends ReportState {
  final ReportType reportType;

  const ReportLoading(this.reportType);

  @override
  List<Object?> get props => [reportType];
}

class ReportSuccess extends ReportState {
  final Uint8List pdfBytes;
  final String filename;
  final ReportType reportType;

  const ReportSuccess({
    required this.pdfBytes,
    required this.filename,
    required this.reportType,
  });

  @override
  List<Object?> get props => [pdfBytes, filename, reportType];
}

class ReportError extends ReportState {
  final String message;
  final ReportType? reportType;

  const ReportError(this.message, {this.reportType});

  @override
  List<Object?> get props => [message, reportType];
}
