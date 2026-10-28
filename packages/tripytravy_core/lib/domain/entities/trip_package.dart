import 'attachment_descriptor.dart';
import 'itinerary_event.dart';

class TravelerProfile {
  final String travelerId;
  final String fullName;
  final String email;
  final String phone;
  final String passportExpiryIso8601;
  final String dietaryPreferences;
  final String emergencyContactName;
  final String emergencyContactPhone;

  const TravelerProfile({
    required this.travelerId,
    required this.fullName,
    this.email = '',
    this.phone = '',
    this.passportExpiryIso8601 = '',
    this.dietaryPreferences = '',
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
  });

  Map<String, dynamic> toJson() => {
        'travelerId': travelerId,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'passportExpiryIso8601': passportExpiryIso8601,
        'dietaryPreferences': dietaryPreferences,
        'emergencyContactName': emergencyContactName,
        'emergencyContactPhone': emergencyContactPhone,
      };

  factory TravelerProfile.fromJson(Map<String, dynamic> json) => TravelerProfile(
        travelerId: (json['travelerId'] as String?) ?? '',
        fullName: (json['fullName'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
        phone: (json['phone'] as String?) ?? '',
        passportExpiryIso8601: (json['passportExpiryIso8601'] as String?) ?? '',
        dietaryPreferences: (json['dietaryPreferences'] as String?) ?? '',
        emergencyContactName: (json['emergencyContactName'] as String?) ?? '',
        emergencyContactPhone: (json['emergencyContactPhone'] as String?) ?? '',
      );
}

class OfflineMapSlice {
  final String sliceAssetId;
  final double minLat;
  final double minLon;
  final double maxLat;
  final double maxLon;
  final int minZoom;
  final int maxZoom;

  const OfflineMapSlice({
    required this.sliceAssetId,
    required this.minLat,
    required this.minLon,
    required this.maxLat,
    required this.maxLon,
    this.minZoom = 7,
    this.maxZoom = 15,
  });

  Map<String, dynamic> toJson() => {
        'sliceAssetId': sliceAssetId,
        'minLat': minLat,
        'minLon': minLon,
        'maxLat': maxLat,
        'maxLon': maxLon,
        'minZoom': minZoom,
        'maxZoom': maxZoom,
      };

  factory OfflineMapSlice.fromJson(Map<String, dynamic> json) => OfflineMapSlice(
        sliceAssetId: (json['sliceAssetId'] as String?) ?? '',
        minLat: (json['minLat'] as num?)?.toDouble() ?? 0.0,
        minLon: (json['minLon'] as num?)?.toDouble() ?? 0.0,
        maxLat: (json['maxLat'] as num?)?.toDouble() ?? 0.0,
        maxLon: (json['maxLon'] as num?)?.toDouble() ?? 0.0,
        minZoom: (json['minZoom'] as num?)?.toInt() ?? 7,
        maxZoom: (json['maxZoom'] as num?)?.toInt() ?? 15,
      );
}

/// Trip Document and Information record exported from the Agent side
class TripDocumentRecord {
  final String id;
  final String title;
  final String docType;
  final String description;
  final String fileName;
  final String fileSize;
  final String filePath;
  final String? locationName;
  final String? mapUrl;

  const TripDocumentRecord({
    required this.id,
    required this.title,
    this.docType = 'general',
    this.description = '',
    this.fileName = '',
    this.fileSize = '',
    this.filePath = '',
    this.locationName,
    this.mapUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'docType': docType,
        'description': description,
        'fileName': fileName,
        'fileSize': fileSize,
        'filePath': filePath,
        'locationName': locationName,
        'mapUrl': mapUrl,
      };

  factory TripDocumentRecord.fromJson(Map<String, dynamic> json) =>
      TripDocumentRecord(
        id: (json['id'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        docType: (json['docType'] as String?) ?? 'general',
        description: (json['description'] as String?) ?? '',
        fileName: (json['fileName'] as String?) ?? '',
        fileSize: (json['fileSize'] as String?) ?? '',
        filePath: (json['filePath'] as String?) ?? '',
        locationName: json['locationName'] as String?,
        mapUrl: json['mapUrl'] as String?,
      );
}

class ItineraryDay {
  final int dayNumber;
  final String dateIso8601;
  final String title;
  final String description;
  final String primaryTimezoneIana;
  final List<ItineraryEvent> events;
  final List<RoutePath> routes;
  final List<GeofenceArea> geofences;
  final List<AttractionPoi> attractions;

  const ItineraryDay({
    required this.dayNumber,
    required this.dateIso8601,
    required this.title,
    this.description = '',
    required this.primaryTimezoneIana,
    this.events = const [],
    this.routes = const [],
    this.geofences = const [],
    this.attractions = const [],
  });

  ItineraryDay copyWith({
    int? dayNumber,
    String? dateIso8601,
    String? title,
    String? description,
    String? primaryTimezoneIana,
    List<ItineraryEvent>? events,
    List<RoutePath>? routes,
    List<GeofenceArea>? geofences,
    List<AttractionPoi>? attractions,
  }) {
    return ItineraryDay(
      dayNumber: dayNumber ?? this.dayNumber,
      dateIso8601: dateIso8601 ?? this.dateIso8601,
      title: title ?? this.title,
      description: description ?? this.description,
      primaryTimezoneIana: primaryTimezoneIana ?? this.primaryTimezoneIana,
      events: events ?? this.events,
      routes: routes ?? this.routes,
      geofences: geofences ?? this.geofences,
      attractions: attractions ?? this.attractions,
    );
  }

  Map<String, dynamic> toJson() => {
        'dayNumber': dayNumber,
        'dateIso8601': dateIso8601,
        'title': title,
        'description': description,
        'primaryTimezoneIana': primaryTimezoneIana,
        'events': events.map((e) => e.toJson()).toList(),
        'routes': routes.map((r) => r.toJson()).toList(),
        'geofences': geofences.map((g) => g.toJson()).toList(),
        'attractions': attractions.map((a) => a.toJson()).toList(),
      };

  factory ItineraryDay.fromJson(Map<String, dynamic> json) => ItineraryDay(
        dayNumber: (json['dayNumber'] as num?)?.toInt() ?? 1,
        dateIso8601: (json['dateIso8601'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        primaryTimezoneIana: (json['primaryTimezoneIana'] as String?) ?? 'UTC',
        events: (json['events'] as List<dynamic>? ?? const [])
            .map((e) => ItineraryEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        routes: (json['routes'] as List<dynamic>? ?? const [])
            .map((r) => RoutePath.fromJson(r as Map<String, dynamic>))
            .toList(),
        geofences: (json['geofences'] as List<dynamic>? ?? const [])
            .map((g) => GeofenceArea.fromJson(g as Map<String, dynamic>))
            .toList(),
        attractions: (json['attractions'] as List<dynamic>? ?? const [])
            .map((a) => AttractionPoi.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}

class TripPackage {
  final String tripId;
  final String title;
  final String subtitle;
  final List<String> destinationTags;
  final String startDateIso8601;
  final String endDateIso8601;
  final String primaryTimezoneIana;
  final String currencyCodeIso4217;
  final String languageBcp47;
  final bool isTemplate;
  final bool isCompleted;
  final List<TravelerProfile> travelers;
  final List<ItineraryDay> days;
  final List<AttachmentDescriptor> allAssets;
  final List<TripDocumentRecord> documents;
  final OfflineMapSlice? offlineMapSlice;

  const TripPackage({
    required this.tripId,
    required this.title,
    this.subtitle = '',
    this.destinationTags = const [],
    required this.startDateIso8601,
    required this.endDateIso8601,
    required this.primaryTimezoneIana,
    this.currencyCodeIso4217 = 'USD',
    this.languageBcp47 = 'en-US',
    this.isTemplate = false,
    this.isCompleted = false,
    this.travelers = const [],
    this.days = const [],
    this.allAssets = const [],
    this.documents = const [],
    this.offlineMapSlice,
  });

  TripPackage copyWith({
    String? tripId,
    String? title,
    String? subtitle,
    List<String>? destinationTags,
    String? startDateIso8601,
    String? endDateIso8601,
    String? primaryTimezoneIana,
    String? currencyCodeIso4217,
    String? languageBcp47,
    bool? isTemplate,
    bool? isCompleted,
    List<TravelerProfile>? travelers,
    List<ItineraryDay>? days,
    List<AttachmentDescriptor>? allAssets,
    List<TripDocumentRecord>? documents,
    OfflineMapSlice? offlineMapSlice,
  }) {
    return TripPackage(
      tripId: tripId ?? this.tripId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      destinationTags: destinationTags ?? this.destinationTags,
      startDateIso8601: startDateIso8601 ?? this.startDateIso8601,
      endDateIso8601: endDateIso8601 ?? this.endDateIso8601,
      primaryTimezoneIana: primaryTimezoneIana ?? this.primaryTimezoneIana,
      currencyCodeIso4217: currencyCodeIso4217 ?? this.currencyCodeIso4217,
      languageBcp47: languageBcp47 ?? this.languageBcp47,
      isTemplate: isTemplate ?? this.isTemplate,
      isCompleted: isCompleted ?? this.isCompleted,
      travelers: travelers ?? this.travelers,
      days: days ?? this.days,
      allAssets: allAssets ?? this.allAssets,
      documents: documents ?? this.documents,
      offlineMapSlice: offlineMapSlice ?? this.offlineMapSlice,
    );
  }

  Map<String, dynamic> toJson() => {
        'tripId': tripId,
        'title': title,
        'subtitle': subtitle,
        'destinationTags': destinationTags,
        'startDateIso8601': startDateIso8601,
        'endDateIso8601': endDateIso8601,
        'primaryTimezoneIana': primaryTimezoneIana,
        'currencyCodeIso4217': currencyCodeIso4217,
        'languageBcp47': languageBcp47,
        'isTemplate': isTemplate,
        'isCompleted': isCompleted,
        'travelers': travelers.map((t) => t.toJson()).toList(),
        'days': days.map((d) => d.toJson()).toList(),
        'allAssets': allAssets.map((a) => a.toJson()).toList(),
        'documents': documents.map((d) => d.toJson()).toList(),
        if (offlineMapSlice != null) 'offlineMapSlice': offlineMapSlice!.toJson(),
      };

  factory TripPackage.fromJson(Map<String, dynamic> json) => TripPackage(
        tripId: (json['tripId'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        subtitle: (json['subtitle'] as String?) ?? '',
        destinationTags: (json['destinationTags'] as List<dynamic>? ?? const []).cast<String>(),
        startDateIso8601: (json['startDateIso8601'] as String?) ?? '',
        endDateIso8601: (json['endDateIso8601'] as String?) ?? '',
        primaryTimezoneIana: (json['primaryTimezoneIana'] as String?) ?? 'UTC',
        currencyCodeIso4217: (json['currencyCodeIso4217'] as String?) ?? 'USD',
        languageBcp47: (json['languageBcp47'] as String?) ?? 'en-US',
        isTemplate: (json['isTemplate'] as bool?) ?? false,
        isCompleted: (json['isCompleted'] as bool?) ?? false,
        travelers: (json['travelers'] as List<dynamic>? ?? const [])
            .map((t) => TravelerProfile.fromJson(t as Map<String, dynamic>))
            .toList(),
        days: (json['days'] as List<dynamic>? ?? const [])
            .map((d) => ItineraryDay.fromJson(d as Map<String, dynamic>))
            .toList(),
        allAssets: (json['allAssets'] as List<dynamic>? ?? const [])
            .map((a) => AttachmentDescriptor.fromJson(a as Map<String, dynamic>))
            .toList(),
        documents: (json['documents'] as List<dynamic>? ?? const [])
            .map((d) => TripDocumentRecord.fromJson(d as Map<String, dynamic>))
            .toList(),
        offlineMapSlice: json['offlineMapSlice'] != null
            ? OfflineMapSlice.fromJson(json['offlineMapSlice'] as Map<String, dynamic>)
            : null,
      );
}
