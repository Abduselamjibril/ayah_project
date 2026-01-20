class Khatmah {
  final String id;
  final DateTime startDate;
  final int durationDays;
  final int lastReadPage;
  final bool isCompleted;

  Khatmah({
    required this.id,
    required this.startDate,
    required this.durationDays,
    this.lastReadPage = 0,
    this.isCompleted = false,
  });

  // Pages per day calculation
  int get pagesPerDay => (604 / durationDays).ceil();

  // Current day (1-based)
  int get currentDay {
    final now = DateTime.now();
    // Reset time to midnight for accurate day calculation
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(start).inDays;
    return difference + 1;
  }

  // Target page for today
  int get targetPageForToday {
    final day = currentDay;
    if (day > durationDays) return 604;
    return (day * pagesPerDay).clamp(1, 604);
  }

  // Start page for today
  int get startPageForToday {
    final day = currentDay;
    if (day <= 1) return 1;
    return ((day - 1) * pagesPerDay + 1).clamp(1, 604);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startDate': startDate.toIso8601String(),
      'durationDays': durationDays,
      'lastReadPage': lastReadPage,
      'isCompleted': isCompleted,
    };
  }

  factory Khatmah.fromJson(Map<String, dynamic> json) {
    return Khatmah(
      id: json['id'],
      startDate: DateTime.parse(json['startDate']),
      durationDays: json['durationDays'],
      lastReadPage: json['lastReadPage'],
      isCompleted: json['isCompleted'],
    );
  }

  Khatmah copyWith({
    int? lastReadPage,
    bool? isCompleted,
  }) {
    return Khatmah(
      id: id,
      startDate: startDate,
      durationDays: durationDays,
      lastReadPage: lastReadPage ?? this.lastReadPage,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
