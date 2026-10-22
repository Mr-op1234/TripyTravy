import 'dart:convert';
import 'dart:io';

class GoogleMapsLocation {
  final String locationName;
  final double? latitude;
  final double? longitude;
  final String rawUrl;

  const GoogleMapsLocation({
    required this.locationName,
    this.latitude,
    this.longitude,
    required this.rawUrl,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  String get coordinatesDisplay {
    if (latitude == null || longitude == null) return '';
    final latStr =
        '${latitude!.abs().toStringAsFixed(4)}° ${latitude! >= 0 ? "N" : "S"}';
    final lngStr =
        '${longitude!.abs().toStringAsFixed(4)}° ${longitude! >= 0 ? "E" : "W"}';
    return '$latStr, $lngStr';
  }

  Map<String, dynamic> toMap() => {
        'locationName': locationName,
        'latitude': latitude,
        'longitude': longitude,
        'rawUrl': rawUrl,
      };

  factory GoogleMapsLocation.fromMap(Map<String, dynamic> map) =>
      GoogleMapsLocation(
        locationName: map['locationName'] as String? ?? '',
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        rawUrl: map['rawUrl'] as String? ?? '',
      );
}

class GoogleMapsHelper {
  /// Parses a Google Maps link and extracts location name, latitude, and longitude.
  /// Handles standard place URLs, query URLs, short links (maps.app.goo.gl),
  /// and coordinate patterns.
  static Future<GoogleMapsLocation?> parse(String rawInput) async {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return null;

    String targetUrl = trimmed;

    // Check if it is a shortened Google Maps URL (follow 301/302 redirects)
    if (trimmed.contains('maps.app.goo.gl') ||
        trimmed.contains('goo.gl/maps')) {
      targetUrl = await _resolveRedirect(trimmed);
    }

    // Attempt direct extraction from URL
    var result = _extractFromUrl(targetUrl, trimmed);

    // If coordinates were found but location name is missing or generic, reverse geocode
    if (result != null && result.latitude != null && result.longitude != null) {
      if (result.locationName.isEmpty ||
          result.locationName.startsWith('Location (')) {
        final reverseName =
            await _reverseGeocode(result.latitude!, result.longitude!);
        if (reverseName != null && reverseName.isNotEmpty) {
          result = GoogleMapsLocation(
            locationName: reverseName,
            latitude: result.latitude,
            longitude: result.longitude,
            rawUrl: trimmed,
          );
        }
      }
    }

    // If location name was found but coordinates are missing, forward geocode
    if (result != null &&
        (result.latitude == null || result.longitude == null)) {
      if (result.locationName.isNotEmpty) {
        final coords = await _forwardGeocode(result.locationName);
        if (coords != null) {
          result = GoogleMapsLocation(
            locationName: result.locationName,
            latitude: coords[0],
            longitude: coords[1],
            rawUrl: trimmed,
          );
        }
      }
    }

    return result;
  }

  static Future<String> _resolveRedirect(String url) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      final response = await request.close();
      if (response.isRedirect) {
        final loc = response.headers.value(HttpHeaders.locationHeader);
        if (loc != null && loc.isNotEmpty) {
          return loc;
        }
      }
    } catch (_) {}
    return url;
  }

  static GoogleMapsLocation? _extractFromUrl(String url, String originalInput) {
    double? lat;
    double? lng;
    String name = '';

    // 1. Try extracting @lat,lng
    final atMatch = RegExp(r'/@(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(url);
    if (atMatch != null) {
      lat = double.tryParse(atMatch.group(1)!);
      lng = double.tryParse(atMatch.group(2)!);
    }

    // 2. Try extracting protobuf !3d<lat>!4d<lng>
    if (lat == null || lng == null) {
      final protoLatMatch = RegExp(r'!3d(-?\d+\.\d+)').firstMatch(url);
      final protoLngMatch = RegExp(r'!4d(-?\d+\.\d+)').firstMatch(url);
      if (protoLatMatch != null && protoLngMatch != null) {
        lat = double.tryParse(protoLatMatch.group(1)!);
        lng = double.tryParse(protoLngMatch.group(1)!);
      }
    }

    // 3. Try query parameters ll= or q= or query=
    if (lat == null || lng == null) {
      final queryCoordMatch =
          RegExp(r'[?&](?:ll|q|query)=(-?\d+\.\d+),(-?\d+\.\d+)')
              .firstMatch(url);
      if (queryCoordMatch != null) {
        lat = double.tryParse(queryCoordMatch.group(1)!);
        lng = double.tryParse(queryCoordMatch.group(2)!);
      }
    }

    // 4. Extract Location Name from /place/<Name>/
    final placeMatch = RegExp(r'/place/([^/@?]+)').firstMatch(url);
    if (placeMatch != null) {
      name = _cleanName(placeMatch.group(1)!);
    }

    // 5. If no /place/, try ?q=<Name> or ?query=<Name>
    if (name.isEmpty) {
      final qMatch = RegExp(r'[?&](?:q|query)=([^&]+)').firstMatch(url);
      if (qMatch != null) {
        final candidate = _cleanName(qMatch.group(1)!);
        // Ensure it's not raw coordinates
        if (!RegExp(r'^-?\d+\.\d+,-?\d+\.\d+$').hasMatch(candidate)) {
          name = candidate;
        }
      }
    }

    // 6. If no name found, try /search/<Name>/
    if (name.isEmpty) {
      final searchMatch = RegExp(r'/search/([^/@?]+)').firstMatch(url);
      if (searchMatch != null) {
        name = _cleanName(searchMatch.group(1)!);
      }
    }

    if (name.isEmpty && lat != null && lng != null) {
      name = 'Location (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
    }

    if (name.isEmpty && lat == null && lng == null) {
      return null;
    }

    return GoogleMapsLocation(
      locationName: name,
      latitude: lat,
      longitude: lng,
      rawUrl: originalInput,
    );
  }

  static String _cleanName(String raw) {
    try {
      final decoded = Uri.decodeComponent(raw.replaceAll('+', ' '));
      return decoded.trim();
    } catch (_) {
      return raw.replaceAll('+', ' ').trim();
    }
  }

  static Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=16');
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'TripyTravyApp/1.0 (Desktop)');
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final displayName = json['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          final parts = displayName.split(',').map((s) => s.trim()).toList();
          if (parts.length > 3) {
            return '${parts[0]}, ${parts[1]}, ${parts.last}';
          }
          return displayName;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<List<double>?> _forwardGeocode(String query) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final encoded = Uri.encodeComponent(query);
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=$encoded&limit=1');
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'TripyTravyApp/1.0 (Desktop)');
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final list = jsonDecode(body) as List<dynamic>;
        if (list.isNotEmpty) {
          final first = list.first as Map<String, dynamic>;
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lon = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            return [lat, lon];
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
