import 'package:equatable/equatable.dart';

class SalaryModel extends Equatable {
  final int teacherId;
  final String teacherName;
  final String teacherEmail;
  final String currency;
  final double totalHours;
  final double salary;
  final int lessonsCount;
  final double hourPrice;

  const SalaryModel({
    required this.teacherId,
    required this.teacherName,
    required this.teacherEmail,
    required this.currency,
    required this.totalHours,
    required this.salary,
    required this.lessonsCount,
    required this.hourPrice,
  });

  factory SalaryModel.fromJson(Map<String, dynamic> json) {
    return SalaryModel(
      teacherId: json['teacher_id'] as int,
      teacherName: json['teacher_name'] as String,
      teacherEmail: json['teacher_email'] as String,
      currency: json['currency'] as String,
      totalHours: (json['total_hours'] as num).toDouble(),
      salary: (json['salary'] as num).toDouble(),
      lessonsCount: json['lessons_count'] as int,
      hourPrice: (json['hour_price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'teacher_email': teacherEmail,
      'currency': currency,
      'total_hours': totalHours,
      'salary': salary,
      'lessons_count': lessonsCount,
      'hour_price': hourPrice,
    };
  }

  @override
  List<Object?> get props => [
        teacherId,
        teacherName,
        teacherEmail,
        currency,
        totalHours,
        salary,
        lessonsCount,
        hourPrice,
      ];
}

class SalariesResponseModel extends Equatable {
  final int year;
  final int month;
  final List<SalaryModel> salaries;
  final Map<String, double> totalsByCurrency;

  const SalariesResponseModel({
    required this.year,
    required this.month,
    required this.salaries,
    required this.totalsByCurrency,
  });

  factory SalariesResponseModel.fromJson(Map<String, dynamic> json) {
    // Handle totals_by_currency - it should be a Map, but handle array case defensively
    Map<String, double> totalsByCurrency;
    final totalsData = json['totals_by_currency'];
    if (totalsData is Map) {
      totalsByCurrency = (totalsData as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, (value as num).toDouble()));
    } else if (totalsData is List) {
      // If it's an array (legacy/error case), return empty map
      totalsByCurrency = {};
    } else {
      totalsByCurrency = {};
    }
    
    return SalariesResponseModel(
      year: json['year'] as int,
      month: json['month'] as int,
      salaries: (json['salaries'] as List)
          .map((item) => SalaryModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalsByCurrency: totalsByCurrency,
    );
  }

  @override
  List<Object?> get props => [year, month, salaries, totalsByCurrency];
}
