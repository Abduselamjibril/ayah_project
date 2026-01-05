class HijriDateResponse {
  final bool success;
  final HijriDateData? data;

  HijriDateResponse({required this.success, this.data});

  factory HijriDateResponse.fromJson(Map<String, dynamic> json) {
    return HijriDateResponse(
      success: json['success'] ?? false,
      data: json['data'] != null ? HijriDateData.fromJson(json['data']) : null,
    );
  }
}

class HijriDateData {
  final GregorianDate gregorian;
  final HijriDate hijri;

  HijriDateData({required this.gregorian, required this.hijri});

  factory HijriDateData.fromJson(Map<String, dynamic> json) {
    return HijriDateData(
      gregorian: GregorianDate.fromJson(json['gregorian']),
      hijri: HijriDate.fromJson(json['hijri']),
    );
  }
}

class GregorianDate {
  final String date;
  final String formatted;
  final String dayOfWeek;
  final int day;
  final int month;
  final String monthName;
  final int year;

  GregorianDate({
    required this.date,
    required this.formatted,
    required this.dayOfWeek,
    required this.day,
    required this.month,
    required this.monthName,
    required this.year,
  });

  factory GregorianDate.fromJson(Map<String, dynamic> json) {
    return GregorianDate(
      date: json['date'] ?? '',
      formatted: json['formatted'] ?? '',
      dayOfWeek: json['day_of_week'] ?? '',
      day: json['day'] ?? 0,
      month: json['month'] ?? 0,
      monthName: json['month_name'] ?? '',
      year: json['year'] ?? 0,
    );
  }
}

class HijriDate {
  final String date;
  final String formatted;
  final int day;
  final int month;
  final String monthName;
  final String monthNameArabic;
  final int year;
  final String era;

  HijriDate({
    required this.date,
    required this.formatted,
    required this.day,
    required this.month,
    required this.monthName,
    required this.monthNameArabic,
    required this.year,
    required this.era,
  });

  factory HijriDate.fromJson(Map<String, dynamic> json) {
    return HijriDate(
      date: json['date'] ?? '',
      formatted: json['formatted'] ?? '',
      day: json['day'] ?? 0,
      month: json['month'] ?? 0,
      monthName: json['month_name'] ?? '',
      monthNameArabic: json['month_name_arabic'] ?? '',
      year: json['year'] ?? 0,
      era: json['era'] ?? '',
    );
  }
}
