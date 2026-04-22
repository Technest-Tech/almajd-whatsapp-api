import 'package:equatable/equatable.dart';

abstract class StudentCountriesEvent extends Equatable {
  const StudentCountriesEvent();

  @override
  List<Object?> get props => [];
}

class UpdateCountryTime extends StudentCountriesEvent {
  final String action; // 'plus' or 'minus'
  final String country; // 'canada', 'uk', or 'eg'

  const UpdateCountryTime({
    required this.action,
    required this.country,
  });

  @override
  List<Object?> get props => [action, country];
}


