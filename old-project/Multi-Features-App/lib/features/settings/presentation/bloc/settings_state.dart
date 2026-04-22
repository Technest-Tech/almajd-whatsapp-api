import 'package:equatable/equatable.dart';

abstract class SettingsState extends Equatable {
  const SettingsState();

  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

class PaymentSettingsLoading extends SettingsState {
  const PaymentSettingsLoading();
}

class PaymentSettingsLoaded extends SettingsState {
  final bool paypalEnabled;
  final bool anubpayEnabled;

  const PaymentSettingsLoaded({
    required this.paypalEnabled,
    required this.anubpayEnabled,
  });

  @override
  List<Object?> get props => [paypalEnabled, anubpayEnabled];
}

class PaymentSettingsError extends SettingsState {
  final String message;

  const PaymentSettingsError(this.message);

  @override
  List<Object?> get props => [message];
}

class PaymentSettingsUpdated extends SettingsState {
  final bool paypalEnabled;
  final bool anubpayEnabled;

  const PaymentSettingsUpdated({
    required this.paypalEnabled,
    required this.anubpayEnabled,
  });

  @override
  List<Object?> get props => [paypalEnabled, anubpayEnabled];
}

class LessonSettingsLoading extends SettingsState {
  const LessonSettingsLoading();
}

class LessonSettingsLoaded extends SettingsState {
  final bool teachersCanEditLessons;
  final bool teachersCanDeleteLessons;
  final bool teachersCanAddPastLessons;

  const LessonSettingsLoaded({
    required this.teachersCanEditLessons,
    required this.teachersCanDeleteLessons,
    required this.teachersCanAddPastLessons,
  });

  @override
  List<Object?> get props => [teachersCanEditLessons, teachersCanDeleteLessons, teachersCanAddPastLessons];
}

class LessonSettingsError extends SettingsState {
  final String message;

  const LessonSettingsError(this.message);

  @override
  List<Object?> get props => [message];
}

class LessonSettingsUpdated extends SettingsState {
  final bool teachersCanEditLessons;
  final bool teachersCanDeleteLessons;
  final bool teachersCanAddPastLessons;

  const LessonSettingsUpdated({
    required this.teachersCanEditLessons,
    required this.teachersCanDeleteLessons,
    required this.teachersCanAddPastLessons,
  });

  @override
  List<Object?> get props => [teachersCanEditLessons, teachersCanDeleteLessons, teachersCanAddPastLessons];
}

/// Combined state that holds both payment and lesson settings
class SettingsLoaded extends SettingsState {
  final bool? paypalEnabled;
  final bool? anubpayEnabled;
  final bool? teachersCanEditLessons;
  final bool? teachersCanDeleteLessons;
  final bool? teachersCanAddPastLessons;
  final bool isLoadingPayment;
  final bool isLoadingLesson;

  const SettingsLoaded({
    this.paypalEnabled,
    this.anubpayEnabled,
    this.teachersCanEditLessons,
    this.teachersCanDeleteLessons,
    this.teachersCanAddPastLessons,
    this.isLoadingPayment = false,
    this.isLoadingLesson = false,
  });

  SettingsLoaded copyWith({
    bool? paypalEnabled,
    bool? anubpayEnabled,
    bool? teachersCanEditLessons,
    bool? teachersCanDeleteLessons,
    bool? teachersCanAddPastLessons,
    bool? isLoadingPayment,
    bool? isLoadingLesson,
  }) {
    return SettingsLoaded(
      paypalEnabled: paypalEnabled ?? this.paypalEnabled,
      anubpayEnabled: anubpayEnabled ?? this.anubpayEnabled,
      teachersCanEditLessons: teachersCanEditLessons ?? this.teachersCanEditLessons,
      teachersCanDeleteLessons: teachersCanDeleteLessons ?? this.teachersCanDeleteLessons,
      teachersCanAddPastLessons: teachersCanAddPastLessons ?? this.teachersCanAddPastLessons,
      isLoadingPayment: isLoadingPayment ?? this.isLoadingPayment,
      isLoadingLesson: isLoadingLesson ?? this.isLoadingLesson,
    );
  }

  @override
  List<Object?> get props => [
        paypalEnabled,
        anubpayEnabled,
        teachersCanEditLessons,
        teachersCanDeleteLessons,
        teachersCanAddPastLessons,
        isLoadingPayment,
        isLoadingLesson,
      ];
}
