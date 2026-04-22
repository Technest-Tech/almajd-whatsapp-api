import 'package:equatable/equatable.dart';
import '../../data/models/salary_model.dart';

abstract class SalaryState extends Equatable {
  const SalaryState();

  @override
  List<Object?> get props => [];
}

class SalaryInitial extends SalaryState {}

class SalaryLoading extends SalaryState {}

class SalariesLoaded extends SalaryState {
  final SalariesResponseModel response;

  const SalariesLoaded(this.response);

  @override
  List<Object?> get props => [response];
}

class SalaryError extends SalaryState {
  final String message;

  const SalaryError(this.message);

  @override
  List<Object?> get props => [message];
}

class SalaryExporting extends SalaryState {
  final SalariesResponseModel? lastLoadedResponse;

  const SalaryExporting({this.lastLoadedResponse});

  @override
  List<Object?> get props => [lastLoadedResponse];
}

class SalaryExportSuccess extends SalaryState {
  final String filePath;
  final SalariesResponseModel? lastLoadedResponse;

  const SalaryExportSuccess(this.filePath, {this.lastLoadedResponse});

  @override
  List<Object?> get props => [filePath, lastLoadedResponse];
}

class SalaryExportError extends SalaryState {
  final String message;
  final SalariesResponseModel? lastLoadedResponse;

  const SalaryExportError(this.message, {this.lastLoadedResponse});

  @override
  List<Object?> get props => [message, lastLoadedResponse];
}
