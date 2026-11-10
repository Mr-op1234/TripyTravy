class GeoCoordinate {
  final double latitude;
  final double longitude;

  const GeoCoordinate({
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  factory GeoCoordinate.fromJson(Map<String, dynamic> json) => GeoCoordinate(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );

  @override
  String toString() => 'GeoCoordinate($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoCoordinate &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

class GeoBoundingBox {
  final double minLat, minLon, maxLat, maxLon;
  const GeoBoundingBox({
    required this.minLat,
    required this.minLon,
    required this.maxLat,
    required this.maxLon,
  });
  bool contains(double lat, double lon) =>
      lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;
}

