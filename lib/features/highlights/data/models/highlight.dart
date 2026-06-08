class Highlight {
  final int surahId;
  final int ayahId;
  final String colorHex;
  final DateTime createdAt;

  Highlight({
    required this.surahId,
    required this.ayahId,
    required this.colorHex,
    required this.createdAt,
  });

  factory Highlight.fromJson(Map<String, dynamic> json) => Highlight(
        surahId: json['surahId'],
        ayahId: json['ayahId'],
        colorHex: json['colorHex'],
        createdAt: DateTime.parse(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'surahId': surahId,
        'ayahId': ayahId,
        'colorHex': colorHex,
        'createdAt': createdAt.toIso8601String(),
      };
}
