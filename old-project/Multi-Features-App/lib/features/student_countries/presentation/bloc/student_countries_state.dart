import 'package:equatable/equatable.dart';

abstract class StudentCountriesState extends Equatable {
  const StudentCountriesState();

  @override
  List<Object?> get props => [];
}

class StudentCountriesInitial extends StudentCountriesState {
  const StudentCountriesInitial();
}

class StudentCountriesLoading extends StudentCountriesState {
  final String? country;
  final String? action;

  const StudentCountriesLoading({this.country, this.action});

  @override
  List<Object?> get props => [country, action];
}

class StudentCountriesSuccess extends StudentCountriesState {
  final String message;
  final String country;
  final String action;

  const StudentCountriesSuccess({
    required this.message,
    required this.country,
    required this.action,
  });

  @override
  List<Object?> get props => [message, country, action];
}

class StudentCountriesError extends StudentCountriesState {
  final String message;

  const StudentCountriesError(this.message);

  @override
  List<Object?> get props => [message];
}


