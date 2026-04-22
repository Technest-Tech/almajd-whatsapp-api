import 'package:equatable/equatable.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadPaymentSettings extends SettingsEvent {
  const LoadPaymentSettings();
}

class UpdatePaymentSettings extends SettingsEvent {
  final bool paypalEnabled;
  final bool anubpayEnabled;

  const UpdatePaymentSettings({
    required this.paypalEnabled,
    required this.anubpayEnabled,
  });

  @override
  List<Object?> get props => [paypalEnabled, anubpayEnabled];
}

class LoadLessonSettings extends SettingsEvent {
  const LoadLessonSettings();
}

class UpdateLessonSettings extends SettingsEvent {
  final bool teachersCanEditLessons;
  final bool teachersCanDeleteLessons;
  final bool teachersCanAddPastLessons;

  const UpdateLessonSettings({
    required this.teachersCanEditLessons,
    required this.teachersCanDeleteLessons,
    required this.teachersCanAddPastLessons,
  });

  @override
  List<Object?> get props => [teachersCanEditLessons, teachersCanDeleteLessons, teachersCanAddPastLessons];
}
