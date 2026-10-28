import '../value_objects/geo_coordinate.dart';
import 'trip_document_record.dart';

enum EventType {
  flight,
  lodging,
  transport,
  activity,
  meal,
  note;

  static EventType fromString(String val) =>
      EventType.values.firstWhere((e) => e.name == val, orElse: () => EventType.note);
}

enum TransitMode {
  walk,
  drive,
  rail,
  publicTransit,
  boatFerry,
  flightLeg,
  cycle;

  static TransitMode fromString(String val) =>
      TransitMode.values.firstWhere((e) => e.name == val, orElse: () => TransitMode.walk);
}

enum NoteSeverity {
  info,
  tip,
  warning,
  critical;

  static NoteSeverity fromString(String val) =>
      NoteSeverity.values.firstWhere((e) => e.name == val, orElse: () => NoteSeverity.info);
}

class FlightDetails {
  final String airlineName;
  final String flightNumber;
  final String departureIata;
  final String arrivalIata;
  final String departureTimezoneIana;
  final String arrivalTimezoneIana;
  final String terminal;
  final String gate;
  final String seatNumber;
  final String baggageAllowance;
  final String pnrConfirmationCode;

  const FlightDetails({
    required this.airlineName,
    required this.flightNumber,
    required this.departureIata,
    required this.arrivalIata,
    required this.departureTimezoneIana,
    required this.arrivalTimezoneIana,
    this.terminal = '',
    this.gate = '',
    this.seatNumber = '',
    this.baggageAllowance = '',
    this.pnrConfirmationCode = '',
  });

  FlightDetails sanitized() => FlightDetails(
        airlineName: airlineName,
        flightNumber: flightNumber,
        departureIata: departureIata,
        arrivalIata: arrivalIata,
        departureTimezoneIana: departureTimezoneIana,
        arrivalTimezoneIana: arrivalTimezoneIana,
        terminal: terminal,
        gate: '',
        seatNumber: '',
        baggageAllowance: baggageAllowance,
        pnrConfirmationCode: '',
      );

  Map<String, dynamic> toJson() => {
        'airlineName': airlineName,
        'flightNumber': flightNumber,
        'departureIata': departureIata,
        'arrivalIata': arrivalIata,
        'departureTimezoneIana': departureTimezoneIana,
        'arrivalTimezoneIana': arrivalTimezoneIana,
        'terminal': terminal,
        'gate': gate,
        'seatNumber': seatNumber,
        'baggageAllowance': baggageAllowance,
        'pnrConfirmationCode': pnrConfirmationCode,
      };

  factory FlightDetails.fromJson(Map<String, dynamic> json) => FlightDetails(
        airlineName: (json['airlineName'] as String?) ?? '',
        flightNumber: (json['flightNumber'] as String?) ?? '',
        departureIata: (json['departureIata'] as String?) ?? '',
        arrivalIata: (json['arrivalIata'] as String?) ?? '',
        departureTimezoneIana: (json['departureTimezoneIana'] as String?) ?? 'UTC',
        arrivalTimezoneIana: (json['arrivalTimezoneIana'] as String?) ?? 'UTC',
        terminal: (json['terminal'] as String?) ?? '',
        gate: (json['gate'] as String?) ?? '',
        seatNumber: (json['seatNumber'] as String?) ?? '',
        baggageAllowance: (json['baggageAllowance'] as String?) ?? '',
        pnrConfirmationCode: (json['pnrConfirmationCode'] as String?) ?? '',
      );
}

class LodgingDetails {
  final String propertyName;
  final String address;
  final GeoCoordinate? coordinates;
  final String roomType;
  final String mealPlan;
  final String confirmationNumber;
  final String contactPhone;
  final String contactEmail;

  const LodgingDetails({
    required this.propertyName,
    required this.address,
    this.coordinates,
    this.roomType = '',
    this.mealPlan = '',
    this.confirmationNumber = '',
    this.contactPhone = '',
    this.contactEmail = '',
  });

  LodgingDetails sanitized() => LodgingDetails(
        propertyName: propertyName,
        address: address,
        coordinates: coordinates,
        roomType: roomType,
        mealPlan: mealPlan,
        confirmationNumber: '',
        contactPhone: contactPhone,
        contactEmail: contactEmail,
      );

  Map<String, dynamic> toJson() => {
        'propertyName': propertyName,
        'address': address,
        if (coordinates != null) 'coordinates': coordinates!.toJson(),
        'roomType': roomType,
        'mealPlan': mealPlan,
        'confirmationNumber': confirmationNumber,
        'contactPhone': contactPhone,
        'contactEmail': contactEmail,
      };

  factory LodgingDetails.fromJson(Map<String, dynamic> json) => LodgingDetails(
        propertyName: (json['propertyName'] as String?) ?? '',
        address: (json['address'] as String?) ?? '',
        coordinates: json['coordinates'] != null
            ? GeoCoordinate.fromJson(json['coordinates'] as Map<String, dynamic>)
            : null,
        roomType: (json['roomType'] as String?) ?? '',
        mealPlan: (json['mealPlan'] as String?) ?? '',
        confirmationNumber: (json['confirmationNumber'] as String?) ?? '',
        contactPhone: (json['contactPhone'] as String?) ?? '',
        contactEmail: (json['contactEmail'] as String?) ?? '',
      );
}

class TransportDetails {
  final TransitMode mode;
  final String carrierName;
  final String vehicleNumber;
  final String pickupLocation;
  final String dropoffLocation;
  final String coachSeatNumber;
  final String pickupInstructions;
  final String confirmationCode;

  const TransportDetails({
    required this.mode,
    required this.carrierName,
    this.vehicleNumber = '',
    required this.pickupLocation,
    required this.dropoffLocation,
    this.coachSeatNumber = '',
    this.pickupInstructions = '',
    this.confirmationCode = '',
  });

  TransportDetails sanitized() => TransportDetails(
        mode: mode,
        carrierName: carrierName,
        vehicleNumber: vehicleNumber,
        pickupLocation: pickupLocation,
        dropoffLocation: dropoffLocation,
        coachSeatNumber: '',
        pickupInstructions: pickupInstructions,
        confirmationCode: '',
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'carrierName': carrierName,
        'vehicleNumber': vehicleNumber,
        'pickupLocation': pickupLocation,
        'dropoffLocation': dropoffLocation,
        'coachSeatNumber': coachSeatNumber,
        'pickupInstructions': pickupInstructions,
        'confirmationCode': confirmationCode,
      };

  factory TransportDetails.fromJson(Map<String, dynamic> json) => TransportDetails(
        mode: TransitMode.fromString((json['mode'] as String?) ?? 'walk'),
        carrierName: (json['carrierName'] as String?) ?? '',
        vehicleNumber: (json['vehicleNumber'] as String?) ?? '',
        pickupLocation: (json['pickupLocation'] as String?) ?? '',
        dropoffLocation: (json['dropoffLocation'] as String?) ?? '',
        coachSeatNumber: (json['coachSeatNumber'] as String?) ?? '',
        pickupInstructions: (json['pickupInstructions'] as String?) ?? '',
        confirmationCode: (json['confirmationCode'] as String?) ?? '',
      );
}

class ActivityDetails {
  final String meetingPointAddress;
  final GeoCoordinate? coordinates;
  final int durationMinutes;
  final String operatorName;
  final String operatorPhone;
  final String dressCodeNotes;
  final String confirmationCode;

  const ActivityDetails({
    required this.meetingPointAddress,
    this.coordinates,
    required this.durationMinutes,
    this.operatorName = '',
    this.operatorPhone = '',
    this.dressCodeNotes = '',
    this.confirmationCode = '',
  });

  ActivityDetails sanitized() => ActivityDetails(
        meetingPointAddress: meetingPointAddress,
        coordinates: coordinates,
        durationMinutes: durationMinutes,
        operatorName: operatorName,
        operatorPhone: operatorPhone,
        dressCodeNotes: dressCodeNotes,
        confirmationCode: '',
      );

  Map<String, dynamic> toJson() => {
        'meetingPointAddress': meetingPointAddress,
        if (coordinates != null) 'coordinates': coordinates!.toJson(),
        'durationMinutes': durationMinutes,
        'operatorName': operatorName,
        'operatorPhone': operatorPhone,
        'dressCodeNotes': dressCodeNotes,
        'confirmationCode': confirmationCode,
      };

  factory ActivityDetails.fromJson(Map<String, dynamic> json) => ActivityDetails(
        meetingPointAddress: (json['meetingPointAddress'] as String?) ?? '',
        coordinates: json['coordinates'] != null
            ? GeoCoordinate.fromJson(json['coordinates'] as Map<String, dynamic>)
            : null,
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 60,
        operatorName: (json['operatorName'] as String?) ?? '',
        operatorPhone: (json['operatorPhone'] as String?) ?? '',
        dressCodeNotes: (json['dressCodeNotes'] as String?) ?? '',
        confirmationCode: (json['confirmationCode'] as String?) ?? '',
      );
}

class MealDetails {
  final String restaurantName;
  final String address;
  final GeoCoordinate? coordinates;
  final String cuisineType;
  final String dressCode;
  final String dietaryNotes;
  final String confirmationCode;
  final String contactPhone;

  const MealDetails({
    required this.restaurantName,
    required this.address,
    this.coordinates,
    this.cuisineType = '',
    this.dressCode = '',
    this.dietaryNotes = '',
    this.confirmationCode = '',
    this.contactPhone = '',
  });

  MealDetails sanitized() => MealDetails(
        restaurantName: restaurantName,
        address: address,
        coordinates: coordinates,
        cuisineType: cuisineType,
        dressCode: dressCode,
        dietaryNotes: dietaryNotes,
        confirmationCode: '',
        contactPhone: contactPhone,
      );

  Map<String, dynamic> toJson() => {
        'restaurantName': restaurantName,
        'address': address,
        if (coordinates != null) 'coordinates': coordinates!.toJson(),
        'cuisineType': cuisineType,
        'dressCode': dressCode,
        'dietaryNotes': dietaryNotes,
        'confirmationCode': confirmationCode,
        'contactPhone': contactPhone,
      };

  factory MealDetails.fromJson(Map<String, dynamic> json) => MealDetails(
        restaurantName: (json['restaurantName'] as String?) ?? '',
        address: (json['address'] as String?) ?? '',
        coordinates: json['coordinates'] != null
            ? GeoCoordinate.fromJson(json['coordinates'] as Map<String, dynamic>)
            : null,
        cuisineType: (json['cuisineType'] as String?) ?? '',
        dressCode: (json['dressCode'] as String?) ?? '',
        dietaryNotes: (json['dietaryNotes'] as String?) ?? '',
        confirmationCode: (json['confirmationCode'] as String?) ?? '',
        contactPhone: (json['contactPhone'] as String?) ?? '',
      );
}

class ChecklistItem {
  final String itemId;
  final String label;
  final bool isCheckedDefault;

  const ChecklistItem({
    required this.itemId,
    required this.label,
    this.isCheckedDefault = false,
  });

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'label': label,
        'isCheckedDefault': isCheckedDefault,
      };

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
        itemId: (json['itemId'] as String?) ?? '',
        label: (json['label'] as String?) ?? '',
        isCheckedDefault: (json['isCheckedDefault'] as bool?) ?? false,
      );
}

class NoteDetails {
  final NoteSeverity severity;
  final String categoryLabel;
  final String markdownBody;
  final List<ChecklistItem> checklistItems;

  const NoteDetails({
    this.severity = NoteSeverity.info,
    required this.categoryLabel,
    required this.markdownBody,
    this.checklistItems = const [],
  });

  Map<String, dynamic> toJson() => {
        'severity': severity.name,
        'categoryLabel': categoryLabel,
        'markdownBody': markdownBody,
        'checklistItems': checklistItems.map((c) => c.toJson()).toList(),
      };

  factory NoteDetails.fromJson(Map<String, dynamic> json) => NoteDetails(
        severity: NoteSeverity.fromString((json['severity'] as String?) ?? 'info'),
        categoryLabel: (json['categoryLabel'] as String?) ?? '',
        markdownBody: (json['markdownBody'] as String?) ?? '',
        checklistItems: (json['checklistItems'] as List<dynamic>? ?? const [])
            .map((c) => ChecklistItem.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

class ItineraryEvent {
  final String eventId;
  final EventType eventType;
  final String title;
  final String startIso8601;
  final String endIso8601;
  final String timezoneIana;
  final List<String> attachmentAssetIds;
  final String category;
  final String subCategory;
  final String? subDetail;
  final String description;
  final List<String> photos;
  final List<TripDocumentRecord> documents;
  final FlightDetails? flight;
  final LodgingDetails? lodging;
  final TransportDetails? transport;
  final ActivityDetails? activity;
  final MealDetails? meal;
  final NoteDetails? note;

  const ItineraryEvent({
    required this.eventId,
    required this.eventType,
    required this.title,
    required this.startIso8601,
    required this.endIso8601,
    required this.timezoneIana,
    this.attachmentAssetIds = const [],
    this.category = '',
    this.subCategory = '',
    this.subDetail,
    this.description = '',
    this.photos = const [],
    this.documents = const [],
    this.flight,
    this.lodging,
    this.transport,
    this.activity,
    this.meal,
    this.note,
  });

  ItineraryEvent copyWith({
    String? title,
    String? startIso8601,
    String? endIso8601,
    String? timezoneIana,
    List<String>? attachmentAssetIds,
    String? category,
    String? subCategory,
    String? subDetail,
    String? description,
    List<String>? photos,
    List<TripDocumentRecord>? documents,
    FlightDetails? flight,
    LodgingDetails? lodging,
    TransportDetails? transport,
    ActivityDetails? activity,
    MealDetails? meal,
    NoteDetails? note,
  }) {
    return ItineraryEvent(
      eventId: eventId,
      eventType: eventType,
      title: title ?? this.title,
      startIso8601: startIso8601 ?? this.startIso8601,
      endIso8601: endIso8601 ?? this.endIso8601,
      timezoneIana: timezoneIana ?? this.timezoneIana,
      attachmentAssetIds: attachmentAssetIds ?? this.attachmentAssetIds,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      subDetail: subDetail ?? this.subDetail,
      description: description ?? this.description,
      photos: photos ?? this.photos,
      documents: documents ?? this.documents,
      flight: flight ?? this.flight,
      lodging: lodging ?? this.lodging,
      transport: transport ?? this.transport,
      activity: activity ?? this.activity,
      meal: meal ?? this.meal,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'eventType': eventType.name,
        'title': title,
        'startIso8601': startIso8601,
        'endIso8601': endIso8601,
        'timezoneIana': timezoneIana,
        'attachmentAssetIds': attachmentAssetIds,
        if (category.isNotEmpty) 'category': category,
        if (subCategory.isNotEmpty) 'subCategory': subCategory,
        if (subDetail != null) 'subDetail': subDetail,
        if (description.isNotEmpty) 'description': description,
        if (photos.isNotEmpty) 'photos': photos,
        if (documents.isNotEmpty) 'documents': documents.map((d) => d.toJson()).toList(),
        if (flight != null) 'flight': flight!.toJson(),
        if (lodging != null) 'lodging': lodging!.toJson(),
        if (transport != null) 'transport': transport!.toJson(),
        if (activity != null) 'activity': activity!.toJson(),
        if (meal != null) 'meal': meal!.toJson(),
        if (note != null) 'note': note!.toJson(),
      };

  factory ItineraryEvent.fromJson(Map<String, dynamic> json) {
    final type = EventType.fromString((json['eventType'] as String?) ?? 'note');
    return ItineraryEvent(
      eventId: (json['eventId'] as String?) ?? '',
      eventType: type,
      title: (json['title'] as String?) ?? '',
      startIso8601: (json['startIso8601'] as String?) ?? '',
      endIso8601: (json['endIso8601'] as String?) ?? '',
      timezoneIana: (json['timezoneIana'] as String?) ?? 'UTC',
      attachmentAssetIds: (json['attachmentAssetIds'] as List<dynamic>? ?? const []).cast<String>(),
      category: (json['category'] as String?) ?? '',
      subCategory: (json['subCategory'] as String?) ?? '',
      subDetail: json['subDetail'] as String?,
      description: (json['description'] as String?) ?? '',
      photos: (json['photos'] as List<dynamic>? ?? const []).cast<String>(),
      documents: (json['documents'] as List<dynamic>? ?? const [])
          .map((d) => TripDocumentRecord.fromJson(d as Map<String, dynamic>))
          .toList(),
      flight: json['flight'] != null ? FlightDetails.fromJson(json['flight'] as Map<String, dynamic>) : null,
      lodging: json['lodging'] != null ? LodgingDetails.fromJson(json['lodging'] as Map<String, dynamic>) : null,
      transport: json['transport'] != null ? TransportDetails.fromJson(json['transport'] as Map<String, dynamic>) : null,
      activity: json['activity'] != null ? ActivityDetails.fromJson(json['activity'] as Map<String, dynamic>) : null,
      meal: json['meal'] != null ? MealDetails.fromJson(json['meal'] as Map<String, dynamic>) : null,
      note: json['note'] != null ? NoteDetails.fromJson(json['note'] as Map<String, dynamic>) : null,
    );
  }
}

class RoutePath {
  final String routeId;
  final String fromEventId;
  final String toEventId;
  final TransitMode transitMode;
  final double distanceKm;
  final int durationMinutes;
  final String encodedPolyline;
  final String navigationTips;

  const RoutePath({
    required this.routeId,
    required this.fromEventId,
    required this.toEventId,
    required this.transitMode,
    required this.distanceKm,
    required this.durationMinutes,
    this.encodedPolyline = '',
    this.navigationTips = '',
  });

  Map<String, dynamic> toJson() => {
        'routeId': routeId,
        'fromEventId': fromEventId,
        'toEventId': toEventId,
        'transitMode': transitMode.name,
        'distanceKm': distanceKm,
        'durationMinutes': durationMinutes,
        'encodedPolyline': encodedPolyline,
        'navigationTips': navigationTips,
      };

  factory RoutePath.fromJson(Map<String, dynamic> json) => RoutePath(
        routeId: (json['routeId'] as String?) ?? '',
        fromEventId: (json['fromEventId'] as String?) ?? '',
        toEventId: (json['toEventId'] as String?) ?? '',
        transitMode: TransitMode.fromString((json['transitMode'] as String?) ?? 'walk'),
        distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
        encodedPolyline: (json['encodedPolyline'] as String?) ?? '',
        navigationTips: (json['navigationTips'] as String?) ?? '',
      );
}

class GeofenceArea {
  final String areaId;
  final String name;
  final String description;
  final String fillHexColor;
  final double opacity;
  final List<GeoCoordinate> polygonRing;

  const GeofenceArea({
    required this.areaId,
    required this.name,
    this.description = '',
    this.fillHexColor = '#10B981',
    this.opacity = 0.25,
    required this.polygonRing,
  });

  Map<String, dynamic> toJson() => {
        'areaId': areaId,
        'name': name,
        'description': description,
        'fillHexColor': fillHexColor,
        'opacity': opacity,
        'polygonRing': polygonRing.map((c) => c.toJson()).toList(),
      };

  factory GeofenceArea.fromJson(Map<String, dynamic> json) => GeofenceArea(
        areaId: (json['areaId'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        fillHexColor: (json['fillHexColor'] as String?) ?? '#10B981',
        opacity: (json['opacity'] as num?)?.toDouble() ?? 0.25,
        polygonRing: (json['polygonRing'] as List<dynamic>? ?? const [])
            .map((c) => GeoCoordinate.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

class AttractionPoi {
  final String poiId;
  final String name;
  final String category;
  final GeoCoordinate coordinates;
  final String openingHours;
  final int recommendedDurationMinutes;
  final double distanceFromLodgingKm;
  final String creatorNotes;

  const AttractionPoi({
    required this.poiId,
    required this.name,
    required this.category,
    required this.coordinates,
    this.openingHours = '',
    this.recommendedDurationMinutes = 60,
    this.distanceFromLodgingKm = 0.0,
    this.creatorNotes = '',
  });

  Map<String, dynamic> toJson() => {
        'poiId': poiId,
        'name': name,
        'category': category,
        'coordinates': coordinates.toJson(),
        'openingHours': openingHours,
        'recommendedDurationMinutes': recommendedDurationMinutes,
        'distanceFromLodgingKm': distanceFromLodgingKm,
        'creatorNotes': creatorNotes,
      };

  factory AttractionPoi.fromJson(Map<String, dynamic> json) => AttractionPoi(
        poiId: (json['poiId'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        category: (json['category'] as String?) ?? '',
        coordinates: GeoCoordinate.fromJson(json['coordinates'] as Map<String, dynamic>),
        openingHours: (json['openingHours'] as String?) ?? '',
        recommendedDurationMinutes: (json['recommendedDurationMinutes'] as num?)?.toInt() ?? 60,
        distanceFromLodgingKm: (json['distanceFromLodgingKm'] as num?)?.toDouble() ?? 0.0,
        creatorNotes: (json['creatorNotes'] as String?) ?? '',
      );
}
