/// Model for locally persisted saved/favourite routes.
library;

class SavedRoute {
  SavedRoute({
    this.id,
    required this.label,
    required this.originName,
    required this.destName,
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    required this.savedAt,
    this.isFavorite = false,
    this.lastEtaMinutes,
    this.lastDistanceKm,
  });

  final int? id;
  String label;
  final String originName;
  final String destName;
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final DateTime savedAt;
  bool isFavorite;
  final int? lastEtaMinutes;
  final double? lastDistanceKm;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'label': label,
        'origin_name': originName,
        'dest_name': destName,
        'origin_lat': originLat,
        'origin_lng': originLng,
        'dest_lat': destLat,
        'dest_lng': destLng,
        'saved_at': savedAt.toIso8601String(),
        'is_favorite': isFavorite ? 1 : 0,
        'last_eta_minutes': lastEtaMinutes,
        'last_distance_km': lastDistanceKm,
      };

  factory SavedRoute.fromMap(Map<String, dynamic> m) => SavedRoute(
        id: m['id'] as int?,
        label: m['label'] as String? ?? 'Saved Route',
        originName: m['origin_name'] as String? ?? '',
        destName: m['dest_name'] as String? ?? '',
        originLat: (m['origin_lat'] as num?)?.toDouble() ?? 0.0,
        originLng: (m['origin_lng'] as num?)?.toDouble() ?? 0.0,
        destLat: (m['dest_lat'] as num?)?.toDouble() ?? 0.0,
        destLng: (m['dest_lng'] as num?)?.toDouble() ?? 0.0,
        savedAt: DateTime.tryParse(m['saved_at'] as String? ?? '') ??
            DateTime.now(),
        isFavorite: (m['is_favorite'] as int?) == 1,
        lastEtaMinutes: m['last_eta_minutes'] as int?,
        lastDistanceKm: (m['last_distance_km'] as num?)?.toDouble(),
      );

  String get routeSummary => '$originName → $destName';
}
