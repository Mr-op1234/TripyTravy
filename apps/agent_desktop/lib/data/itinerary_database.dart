import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'google_maps_helper.dart';

class DestinationItem {
  final int id;
  final String title;
  final String subtitle;
  final String duration;
  final String dateRange;
  final String imagePath;
  final String? startDate;
  final String? endDate;
  final String? tagline;
  final String? description;

  const DestinationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.dateRange,
    required this.imagePath,
    this.startDate,
    this.endDate,
    this.tagline,
    this.description,
  });

  String get effectiveTagline {
    if (tagline != null && tagline!.trim().isNotEmpty) {
      return tagline!.trim();
    }
    return 'EXPLORE • DISCOVER • EXPERIENCE';
  }

  String get effectiveDescription {
    if (description != null && description!.trim().isNotEmpty) {
      return description!.trim();
    }
    return subtitle.isNotEmpty ? subtitle : 'No one knows what is going to happen in the future. Fortunately the creator of this itinerary does! A marvelous adventure awaits.';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'duration': duration,
      'date_range': dateRange,
      'image_path': imagePath,
      'start_date': startDate,
      'end_date': endDate,
      'tagline': tagline,
      'description': description,
    };
  }

  factory DestinationItem.fromMap(Map<String, dynamic> map) {
    return DestinationItem(
      id: map['id'] as int,
      title: map['title'] as String,
      subtitle: map['subtitle'] as String,
      duration: map['duration'] as String,
      dateRange: map['date_range'] as String,
      imagePath: map['image_path'] as String,
      startDate: map['start_date'] as String?,
      endDate: map['end_date'] as String?,
      tagline: map['tagline'] as String?,
      description: map['description'] as String?,
    );
  }

  DestinationItem copyWith({
    int? id,
    String? title,
    String? subtitle,
    String? duration,
    String? dateRange,
    String? imagePath,
    String? startDate,
    String? endDate,
    String? tagline,
    String? description,
  }) {
    return DestinationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      duration: duration ?? this.duration,
      dateRange: dateRange ?? this.dateRange,
      imagePath: imagePath ?? this.imagePath,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      tagline: tagline ?? this.tagline,
      description: description ?? this.description,
    );
  }
}

/// Entity representing a Day in an Itinerary
class TripDayItem {
  final String id;
  final int itineraryId;
  final int dayNumber;
  final String title;
  final String? date;
  final String? description;
  final int sortOrder;

  const TripDayItem({
    required this.id,
    required this.itineraryId,
    required this.dayNumber,
    required this.title,
    this.date,
    this.description,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itinerary_id': itineraryId,
      'day_number': dayNumber,
      'title': title,
      'date': date,
      'description': description,
      'sort_order': sortOrder,
    };
  }

  factory TripDayItem.fromMap(Map<String, dynamic> map) {
    return TripDayItem(
      id: map['id'] as String,
      itineraryId: map['itinerary_id'] as int,
      dayNumber: map['day_number'] as int? ?? 1,
      title: map['title'] as String,
      date: map['date'] as String?,
      description: map['description'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  TripDayItem copyWith({
    String? id,
    int? itineraryId,
    int? dayNumber,
    String? title,
    String? date,
    String? description,
    int? sortOrder,
  }) {
    return TripDayItem(
      id: id ?? this.id,
      itineraryId: itineraryId ?? this.itineraryId,
      dayNumber: dayNumber ?? this.dayNumber,
      title: title ?? this.title,
      date: date ?? this.date,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class TripEventItem {
  final String id;
  final int itineraryId;
  final String? dayId;
  final int dayNumber;
  final String title;
  final String eventDate;
  final String? startTime;
  final String? endTime;
  final String duration;
  final String location;
  final String description;
  final String coverImage;
  final List<String> photos; // Actual PNG/JPG photos
  final List<String> notes;
  final int sortOrder;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String? mapUrl;
  final String? attachmentsJson; // Attached document vouchers, passes, tickets
  final String? flightDataJson; // Structured Flight details (route, times, stops, booking, status)
  final String? locationsJson; // Structured multiple location cards JSON
  final String category; // 'Activity', 'Lodging', 'Transportation', 'Info'
  final String subCategory; // e.g. 'Attraction', 'Check-in', 'Flight', etc.
  final String? subDetail; // e.g. 'Departure', 'Arrival' (for Transportation)

  const TripEventItem({
    required this.id,
    required this.itineraryId,
    this.dayId,
    this.dayNumber = 1,
    required this.title,
    required this.eventDate,
    this.startTime,
    this.endTime,
    required this.duration,
    required this.location,
    this.description = '',
    this.coverImage = '',
    this.photos = const [],
    this.notes = const [],
    this.sortOrder = 0,
    this.locationName,
    this.latitude,
    this.longitude,
    this.mapUrl,
    this.attachmentsJson,
    this.flightDataJson,
    this.locationsJson,
    this.category = 'Activity',
    this.subCategory = 'Activity',
    this.subDetail,
  });

  bool get hasLocation =>
      (locationName != null && locationName!.trim().isNotEmpty) ||
      locations.isNotEmpty;
  bool get hasCoordinates => latitude != null && longitude != null;

  List<GoogleMapsLocation> get locations {
    if (locationsJson != null && locationsJson!.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(locationsJson!) as List<dynamic>;
        return decoded
            .map((e) => GoogleMapsLocation.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }
    if (locationName != null && locationName!.trim().isNotEmpty) {
      return [
        GoogleMapsLocation(
          locationName: locationName!,
          latitude: latitude,
          longitude: longitude,
          rawUrl: mapUrl ?? '',
        )
      ];
    }
    if (mapUrl != null && mapUrl!.trim().isNotEmpty) {
      return [
        GoogleMapsLocation(
          locationName: location.isNotEmpty ? location : 'Location',
          latitude: latitude,
          longitude: longitude,
          rawUrl: mapUrl!,
        )
      ];
    }
    return [];
  }

  String get coordinatesDisplay {
    if (!hasCoordinates) return '';
    final latStr = '${latitude!.abs().toStringAsFixed(4)}° ${latitude! >= 0 ? "N" : "S"}';
    final lngStr = '${longitude!.abs().toStringAsFixed(4)}° ${longitude! >= 0 ? "E" : "W"}';
    return '$latStr, $lngStr';
  }

  List<Map<String, String>> get attachments {
    if (attachmentsJson != null && attachmentsJson!.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(attachmentsJson!) as List<dynamic>;
        return decoded.map((e) => Map<String, String>.from(e as Map)).toList();
      } catch (_) {}
    }
    return [];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itinerary_id': itineraryId,
      'day_id': dayId,
      'day_number': dayNumber,
      'title': title,
      'event_date': eventDate,
      'start_time': startTime,
      'end_time': endTime,
      'duration': duration,
      'location': location,
      'description': description,
      'cover_image': coverImage,
      'photos_json': jsonEncode(photos),
      'notes_json': jsonEncode(notes),
      'sort_order': sortOrder,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'map_url': mapUrl,
      'attachments_json': attachmentsJson,
      'flight_data_json': flightDataJson,
      'locations_json': locationsJson,
      'category': category,
      'sub_category': subCategory,
      'sub_detail': subDetail,
    };
  }

  factory TripEventItem.fromMap(Map<String, dynamic> map) {
    List<String> parsedPhotos = [];
    if (map['photos_json'] != null) {
      try {
        final decoded = jsonDecode(map['photos_json'] as String);
        if (decoded is List) {
          parsedPhotos = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    List<String> parsedNotes = [];
    if (map['notes_json'] != null) {
      try {
        final decoded = jsonDecode(map['notes_json'] as String);
        if (decoded is List) {
          parsedNotes = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return TripEventItem(
      id: map['id'] as String,
      itineraryId: map['itinerary_id'] as int,
      dayId: map['day_id'] as String?,
      dayNumber: map['day_number'] as int? ?? 1,
      title: map['title'] as String,
      eventDate: map['event_date'] as String? ?? '',
      startTime: map['start_time'] as String?,
      endTime: map['end_time'] as String?,
      duration: map['duration'] as String? ?? '',
      location: map['location'] as String? ?? '',
      description: map['description'] as String? ?? '',
      coverImage: map['cover_image'] as String? ?? '',
      photos: parsedPhotos,
      notes: parsedNotes,
      sortOrder: map['sort_order'] as int? ?? 0,
      locationName: map['location_name'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      mapUrl: map['map_url'] as String?,
      attachmentsJson: map['attachments_json'] as String?,
      flightDataJson: map['flight_data_json'] as String?,
      locationsJson: map['locations_json'] as String?,
      category: map['category'] as String? ?? 'Activity',
      subCategory: map['sub_category'] as String? ?? 'Activity',
      subDetail: map['sub_detail'] as String?,
    );
  }

  TripEventItem copyWith({
    String? id,
    int? itineraryId,
    String? dayId,
    int? dayNumber,
    String? title,
    String? eventDate,
    String? startTime,
    String? endTime,
    String? duration,
    String? location,
    String? description,
    String? coverImage,
    List<String>? photos,
    List<String>? notes,
    int? sortOrder,
    String? locationName,
    double? latitude,
    double? longitude,
    String? mapUrl,
    String? attachmentsJson,
    String? flightDataJson,
    String? locationsJson,
    String? category,
    String? subCategory,
    String? subDetail,
  }) {
    return TripEventItem(
      id: id ?? this.id,
      itineraryId: itineraryId ?? this.itineraryId,
      dayId: dayId ?? this.dayId,
      dayNumber: dayNumber ?? this.dayNumber,
      title: title ?? this.title,
      eventDate: eventDate ?? this.eventDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      location: location ?? this.location,
      description: description ?? this.description,
      coverImage: coverImage ?? this.coverImage,
      photos: photos ?? this.photos,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      mapUrl: mapUrl ?? this.mapUrl,
      attachmentsJson: attachmentsJson ?? this.attachmentsJson,
      flightDataJson: flightDataJson ?? this.flightDataJson,
      locationsJson: locationsJson ?? this.locationsJson,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      subDetail: subDetail ?? this.subDetail,
    );
  }
}

class TripDocumentItem {
  final String id;
  final int itineraryId;
  final String? eventId;
  final String docType;
  final String title;
  final String description;
  final String fileName;
  final String fileSize;
  final String filePath;
  final String colorScheme;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String? mapUrl;
  final String? attachmentsJson;

  const TripDocumentItem({
    required this.id,
    required this.itineraryId,
    this.eventId,
    required this.docType,
    required this.title,
    this.description = '',
    required this.fileName,
    required this.fileSize,
    required this.filePath,
    this.colorScheme = 'blue',
    this.locationName,
    this.latitude,
    this.longitude,
    this.mapUrl,
    this.attachmentsJson,
  });

  bool get hasLocation => locationName != null && locationName!.trim().isNotEmpty;
  bool get hasCoordinates => latitude != null && longitude != null;

  String get coordinatesDisplay {
    if (!hasCoordinates) return '';
    final latStr = '${latitude!.abs().toStringAsFixed(4)}° ${latitude! >= 0 ? "N" : "S"}';
    final lngStr = '${longitude!.abs().toStringAsFixed(4)}° ${longitude! >= 0 ? "E" : "W"}';
    return '$latStr, $lngStr';
  }

  List<Map<String, String>> get attachments {
    if (attachmentsJson != null && attachmentsJson!.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(attachmentsJson!) as List<dynamic>;
        return decoded.map((e) => Map<String, String>.from(e as Map)).toList();
      } catch (_) {}
    }
    if (filePath.isNotEmpty && filePath != 'None') {
      return [
        {'name': fileName, 'size': fileSize, 'path': filePath}
      ];
    }
    return [];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itinerary_id': itineraryId,
      'event_id': eventId,
      'doc_type': docType,
      'title': title,
      'description': description,
      'file_name': fileName,
      'file_size': fileSize,
      'file_path': filePath,
      'color_scheme': colorScheme,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'map_url': mapUrl,
      'attachments_json': attachmentsJson,
    };
  }

  factory TripDocumentItem.fromMap(Map<String, dynamic> map) {
    return TripDocumentItem(
      id: map['id'] as String,
      itineraryId: map['itinerary_id'] as int,
      eventId: map['event_id'] as String?,
      docType: map['doc_type'] as String? ?? 'info',
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      fileName: map['file_name'] as String? ?? '',
      fileSize: map['file_size'] as String? ?? '',
      filePath: map['file_path'] as String? ?? '',
      colorScheme: map['color_scheme'] as String? ?? 'blue',
      locationName: map['location_name'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      mapUrl: map['map_url'] as String?,
      attachmentsJson: map['attachments_json'] as String?,
    );
  }

  TripDocumentItem copyWith({
    String? id,
    int? itineraryId,
    String? eventId,
    String? docType,
    String? title,
    String? description,
    String? fileName,
    String? fileSize,
    String? filePath,
    String? colorScheme,
    String? locationName,
    double? latitude,
    double? longitude,
    String? mapUrl,
    String? attachmentsJson,
  }) {
    return TripDocumentItem(
      id: id ?? this.id,
      itineraryId: itineraryId ?? this.itineraryId,
      eventId: eventId ?? this.eventId,
      docType: docType ?? this.docType,
      title: title ?? this.title,
      description: description ?? this.description,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      filePath: filePath ?? this.filePath,
      colorScheme: colorScheme ?? this.colorScheme,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      mapUrl: mapUrl ?? this.mapUrl,
      attachmentsJson: attachmentsJson ?? this.attachmentsJson,
    );
  }
}

/// Normalized 1NF Child Entity for Document Attachments
class DocumentAttachmentItem {
  final int? id;
  final String documentId;
  final String fileName;
  final String fileSize;
  final String filePath;
  final String? mimeType;
  final int sortOrder;

  const DocumentAttachmentItem({
    this.id,
    required this.documentId,
    required this.fileName,
    required this.fileSize,
    required this.filePath,
    this.mimeType,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'document_id': documentId,
      'file_name': fileName,
      'file_size': fileSize,
      'file_path': filePath,
      'mime_type': mimeType,
      'sort_order': sortOrder,
    };
  }

  factory DocumentAttachmentItem.fromMap(Map<String, dynamic> map) {
    return DocumentAttachmentItem(
      id: map['id'] as int?,
      documentId: map['document_id'] as String,
      fileName: map['file_name'] as String? ?? '',
      fileSize: map['file_size'] as String? ?? '',
      filePath: map['file_path'] as String? ?? '',
      mimeType: map['mime_type'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }
}

/// Normalized 1NF Child Entity for Event Notes
class EventNoteItem {
  final int? id;
  final String eventId;
  final String noteText;
  final int sortOrder;

  const EventNoteItem({
    this.id,
    required this.eventId,
    required this.noteText,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'event_id': eventId,
      'note_text': noteText,
      'sort_order': sortOrder,
    };
  }

  factory EventNoteItem.fromMap(Map<String, dynamic> map) {
    return EventNoteItem(
      id: map['id'] as int?,
      eventId: map['event_id'] as String,
      noteText: map['note_text'] as String? ?? '',
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }
}

/// Normalized 1NF Child Entity for Event Photos
class EventPhotoItem {
  final int? id;
  final String eventId;
  final String photoPath;
  final String? caption;
  final int sortOrder;

  const EventPhotoItem({
    this.id,
    required this.eventId,
    required this.photoPath,
    this.caption,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'event_id': eventId,
      'photo_path': photoPath,
      'caption': caption,
      'sort_order': sortOrder,
    };
  }

  factory EventPhotoItem.fromMap(Map<String, dynamic> map) {
    return EventPhotoItem(
      id: map['id'] as int?,
      eventId: map['event_id'] as String,
      photoPath: map['photo_path'] as String? ?? '',
      caption: map['caption'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }
}

/// Normalized 3NF Entity for Locations
class TripLocationItem {
  final int? id;
  final int itineraryId;
  final String? documentId;
  final String? eventId;
  final String locationName;
  final double? latitude;
  final double? longitude;
  final String? mapUrl;

  const TripLocationItem({
    this.id,
    required this.itineraryId,
    this.documentId,
    this.eventId,
    required this.locationName,
    this.latitude,
    this.longitude,
    this.mapUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'itinerary_id': itineraryId,
      'document_id': documentId,
      'event_id': eventId,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'map_url': mapUrl,
    };
  }

  factory TripLocationItem.fromMap(Map<String, dynamic> map) {
    return TripLocationItem(
      id: map['id'] as int?,
      itineraryId: map['itinerary_id'] as int,
      documentId: map['document_id'] as String?,
      eventId: map['event_id'] as String?,
      locationName: map['location_name'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      mapUrl: map['map_url'] as String?,
    );
  }
}

class ItineraryDatabase {
  static final ItineraryDatabase instance = ItineraryDatabase._init();
  static Database? _database;

  ItineraryDatabase._init();

  static void initializeFfi() {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  @visibleForTesting
  static void setDatabase(Database? db) {
    _database = db;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tripytravy.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    String dbPath;
    if (kIsWeb) {
      dbPath = fileName;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final appSupportDir = await getApplicationSupportDirectory();
      final dir = Directory(p.join(appSupportDir.path, 'TripyTravy'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      dbPath = p.join(dir.path, fileName);
    } else {
      final dbFolder = await getDatabasesPath();
      dbPath = p.join(dbFolder, fileName);
    }

    final db = await openDatabase(
      dbPath,
      version: 6,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE itineraries ADD COLUMN start_date TEXT');
            await db.execute('ALTER TABLE itineraries ADD COLUMN end_date TEXT');
          } catch (_) {}
        }
        if (oldVersion < 3) {
          try {
            await db.delete(
              'itineraries',
              where: "title IN ('Japan', 'Switzerland', 'Malaysia') AND image_path LIKE 'assets/%'",
            );
          } catch (_) {}
        }
        if (oldVersion < 4) {
          try {
            await db.execute('ALTER TABLE itineraries ADD COLUMN trip_code TEXT');
            await db.execute('ALTER TABLE itineraries ADD COLUMN tagline TEXT');
            await db.execute('ALTER TABLE itineraries ADD COLUMN description TEXT');
            await db.execute('ALTER TABLE itineraries ADD COLUMN is_liked INTEGER DEFAULT 0');
          } catch (_) {}
          await _createEventAndDocTables(db);
        }
        if (oldVersion < 5) {
          await _ensureDocumentColumns(db);
        }
        if (oldVersion < 6) {
          await _createEventAndDocTables(db);
        }
      },
    );

    await _createEventAndDocTables(db);
    await _ensureDocumentColumns(db);
    await _ensureEventColumns(db);
    return db;
  }

  static Future<void> _ensureDocumentColumns(Database db) async {
    for (final col in [
      'location_name TEXT',
      'latitude REAL',
      'longitude REAL',
      'map_url TEXT',
      'attachments_json TEXT',
    ]) {
      try {
        await db.execute('ALTER TABLE trip_documents ADD COLUMN $col');
      } catch (_) {}
    }
  }

  static Future<void> _ensureEventColumns(Database db) async {
    for (final col in [
      'day_id TEXT',
      'location_name TEXT',
      'latitude REAL',
      'longitude REAL',
      'map_url TEXT',
      'attachments_json TEXT',
      'flight_data_json TEXT',
      'locations_json TEXT',
      'category TEXT NOT NULL DEFAULT "Activity"',
      'sub_category TEXT',
      'sub_detail TEXT',
    ]) {
      try {
        await db.execute('ALTER TABLE trip_events ADD COLUMN $col');
      } catch (_) {}
    }
  }

  static Future<void> _createEventAndDocTables(Database db) async {
    // 0. Itinerary Days Table (Child of itineraries)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS itinerary_days (
        id TEXT PRIMARY KEY,
        itinerary_id INTEGER NOT NULL,
        day_number INTEGER NOT NULL,
        title TEXT NOT NULL,
        date TEXT,
        description TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (itinerary_id) REFERENCES itineraries(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_days_itinerary ON itinerary_days(itinerary_id);');

    // 1. Trip Events Table (Child of itineraries, optionally associated with day)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trip_events (
        id TEXT PRIMARY KEY,
        itinerary_id INTEGER NOT NULL,
        day_id TEXT,
        day_number INTEGER NOT NULL DEFAULT 1,
        title TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'Activity',
        sub_category TEXT,
        sub_detail TEXT,
        event_date TEXT NOT NULL,
        start_time TEXT,
        end_time TEXT,
        duration TEXT NOT NULL,
        location TEXT NOT NULL,
        description TEXT,
        cover_image TEXT,
        photos_json TEXT,
        notes_json TEXT,
        sort_order INTEGER NOT NULL,
        location_name TEXT,
        latitude REAL,
        longitude REAL,
        map_url TEXT,
        attachments_json TEXT,
        flight_data_json TEXT,
        locations_json TEXT,
        FOREIGN KEY (itinerary_id) REFERENCES itineraries(id) ON DELETE CASCADE,
        FOREIGN KEY (day_id) REFERENCES itinerary_days(id) ON DELETE CASCADE
      )
    ''');

    // 2. Event Notes Table (Normalized 1NF Child of trip_events)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS event_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id TEXT NOT NULL,
        note_text TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (event_id) REFERENCES trip_events(id) ON DELETE CASCADE
      )
    ''');

    // 3. Event Photos Table (Normalized 1NF Child of trip_events)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS event_photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id TEXT NOT NULL,
        photo_path TEXT NOT NULL,
        caption TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (event_id) REFERENCES trip_events(id) ON DELETE CASCADE
      )
    ''');

    // 4. Trip Documents Table (Child of itineraries, optional link to trip_events)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trip_documents (
        id TEXT PRIMARY KEY,
        itinerary_id INTEGER NOT NULL,
        event_id TEXT,
        doc_type TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        file_name TEXT NOT NULL,
        file_size TEXT NOT NULL,
        file_path TEXT NOT NULL,
        color_scheme TEXT NOT NULL,
        location_name TEXT,
        latitude REAL,
        longitude REAL,
        map_url TEXT,
        attachments_json TEXT,
        FOREIGN KEY (itinerary_id) REFERENCES itineraries(id) ON DELETE CASCADE,
        FOREIGN KEY (event_id) REFERENCES trip_events(id) ON DELETE SET NULL
      )
    ''');

    // 5. Document Attachments Table (Normalized 1NF Child of trip_documents)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS document_attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_size TEXT NOT NULL,
        file_path TEXT NOT NULL,
        mime_type TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (document_id) REFERENCES trip_documents(id) ON DELETE CASCADE
      )
    ''');

    // 6. Trip Locations Table (Normalized 3NF Entity for Locations)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trip_locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itinerary_id INTEGER NOT NULL,
        document_id TEXT,
        event_id TEXT,
        location_name TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        map_url TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (itinerary_id) REFERENCES itineraries(id) ON DELETE CASCADE,
        FOREIGN KEY (document_id) REFERENCES trip_documents(id) ON DELETE CASCADE,
        FOREIGN KEY (event_id) REFERENCES trip_events(id) ON DELETE SET NULL
      )
    ''');

    // Performance Indexes on Foreign Keys
    await db.execute('CREATE INDEX IF NOT EXISTS idx_events_itinerary ON trip_events(itinerary_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_docs_itinerary ON trip_documents(itinerary_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_docs_event ON trip_documents(event_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_event_notes ON event_notes(event_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_event_photos ON event_photos(event_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_doc_attachments ON document_attachments(document_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_locations_itinerary ON trip_locations(itinerary_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_locations_doc ON trip_locations(document_id);');

    for (final col in [
      'location_name TEXT',
      'latitude REAL',
      'longitude REAL',
      'map_url TEXT',
      'attachments_json TEXT',
    ]) {
      try {
        await db.execute('ALTER TABLE trip_documents ADD COLUMN $col');
      } catch (_) {}
    }

    for (final col in [
      'category TEXT NOT NULL DEFAULT "Activity"',
      'sub_category TEXT',
      'sub_detail TEXT',
    ]) {
      try {
        await db.execute('ALTER TABLE trip_events ADD COLUMN $col');
      } catch (_) {}
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE itineraries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        subtitle TEXT NOT NULL,
        duration TEXT NOT NULL,
        date_range TEXT NOT NULL,
        image_path TEXT NOT NULL,
        start_date TEXT,
        end_date TEXT,
        tagline TEXT,
        description TEXT
      )
    ''');

    await _createEventAndDocTables(db);
  }

  Future<List<DestinationItem>> getAllItineraries() async {
    final db = await database;
    final maps = await db.query('itineraries', orderBy: 'id ASC');
    return maps.map((m) => DestinationItem.fromMap(m)).toList();
  }

  Future<DestinationItem?> getItineraryById(int id) async {
    final db = await database;
    final maps = await db.query('itineraries', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return DestinationItem.fromMap(maps.first);
    }
    return null;
  }

  static DateTime? parseFlexibleDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final text = raw.trim();
    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;

    final dmyMatch =
        RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$').firstMatch(text);
    if (dmyMatch != null) {
      final day = int.tryParse(dmyMatch.group(1)!);
      final month = int.tryParse(dmyMatch.group(2)!);
      final year = int.tryParse(dmyMatch.group(3)!);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  static int parseDurationDays(String duration,
      {String? startDate, String? endDate}) {
    if (startDate != null && endDate != null) {
      final start = parseFlexibleDate(startDate);
      final end = parseFlexibleDate(endDate);
      if (start != null && end != null) {
        final diff = end.difference(start).inDays + 1;
        if (diff > 0) return diff;
      }
    }
    final match =
        RegExp(r'(\d+)\s*Day', caseSensitive: false).firstMatch(duration);
    if (match != null) {
      final parsed = int.tryParse(match.group(1)!);
      if (parsed != null && parsed > 0) return parsed;
    }
    return 1;
  }

  Future<DestinationItem> insertItinerary({
    required String title,
    required String subtitle,
    required String duration,
    required String dateRange,
    required String imagePath,
    String? startDate,
    String? endDate,
    String? tagline,
    String? description,
    bool autoCreateDays = false,
  }) async {
    final db = await database;
    final id = await db.insert('itineraries', {
      'title': title,
      'subtitle': subtitle,
      'duration': duration,
      'date_range': dateRange,
      'image_path': imagePath,
      'start_date': startDate,
      'end_date': endDate,
      'tagline': tagline,
      'description': description,
    });
    final item = DestinationItem(
      id: id,
      title: title,
      subtitle: subtitle,
      duration: duration,
      dateRange: dateRange,
      imagePath: imagePath,
      startDate: startDate,
      endDate: endDate,
      tagline: tagline,
      description: description,
    );
    if (autoCreateDays) {
      await autoCreateDaysForItinerary(item);
    }
    return item;
  }

  Future<int> deleteItinerary(int id) async {
    final db = await database;
    return await db.delete('itineraries', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateItinerary(DestinationItem item) async {
    final db = await database;
    return await db.update(
      'itineraries',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  // --- Days CRUD ---
  Future<List<TripDayItem>> getDaysForItinerary(int itineraryId) async {
    final db = await database;
    final maps = await db.query(
      'itinerary_days',
      where: 'itinerary_id = ?',
      whereArgs: [itineraryId],
      orderBy: 'sort_order ASC, day_number ASC, id ASC',
    );
    return maps.map((m) => TripDayItem.fromMap(m)).toList();
  }

  Future<List<TripDayItem>> autoCreateDaysForItinerary(
      DestinationItem trip) async {
    final existingDays = await getDaysForItinerary(trip.id);
    if (existingDays.isNotEmpty) {
      return existingDays;
    }

    final int dayCount = parseDurationDays(
      trip.duration,
      startDate: trip.startDate,
      endDate: trip.endDate,
    );

    DateTime? startDate = parseFlexibleDate(trip.startDate);
    if (startDate == null && trip.dateRange.isNotEmpty) {
      final rangeMatch =
          RegExp(r'(\d{2}-\d{2}-\d{4})\s*->\s*(\d{2}-\d{2}-\d{4})')
              .firstMatch(trip.dateRange);
      if (rangeMatch != null) {
        startDate = parseFlexibleDate(rangeMatch.group(1));
      }
    }

    final createdDays = <TripDayItem>[];
    for (int i = 1; i <= dayCount; i++) {
      String? dateStr;
      if (startDate != null) {
        final d = startDate.add(Duration(days: i - 1));
        dateStr =
            '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
      }
      final dayItem = TripDayItem(
        id: 'day_${trip.id}_${i}_${DateTime.now().microsecondsSinceEpoch}',
        itineraryId: trip.id,
        dayNumber: i,
        title: 'Day $i',
        date: dateStr,
        sortOrder: i - 1,
      );
      await insertDay(dayItem);
      createdDays.add(dayItem);
    }
    return createdDays;
  }

  Future<void> syncDaysWithDuration(DestinationItem trip) async {
    final existingDays = await getDaysForItinerary(trip.id);
    final int targetCount = parseDurationDays(
      trip.duration,
      startDate: trip.startDate,
      endDate: trip.endDate,
    );

    if (existingDays.isEmpty) {
      await autoCreateDaysForItinerary(trip);
      return;
    }

    DateTime? startDate = parseFlexibleDate(trip.startDate);
    if (startDate == null && trip.dateRange.isNotEmpty) {
      final rangeMatch =
          RegExp(r'(\d{2}-\d{2}-\d{4})\s*->\s*(\d{2}-\d{2}-\d{4})')
              .firstMatch(trip.dateRange);
      if (rangeMatch != null) {
        startDate = parseFlexibleDate(rangeMatch.group(1));
      }
    }

    // Update dates on existing days if start date is known
    if (startDate != null) {
      for (int i = 0; i < existingDays.length; i++) {
        final currentDay = existingDays[i];
        final expectedDate =
            startDate.add(Duration(days: currentDay.dayNumber - 1));
        final expectedDateStr =
            '${expectedDate.day.toString().padLeft(2, '0')}-${expectedDate.month.toString().padLeft(2, '0')}-${expectedDate.year}';
        if (currentDay.date != expectedDateStr) {
          await updateDay(currentDay.copyWith(date: expectedDateStr));
        }
      }
    }

    // If duration increased, append new days
    if (targetCount > existingDays.length) {
      final maxDayNumber = existingDays
          .map((d) => d.dayNumber)
          .fold<int>(0, (max, dn) => dn > max ? dn : max);

      for (int dn = maxDayNumber + 1; dn <= targetCount; dn++) {
        String? dateStr;
        if (startDate != null) {
          final d = startDate.add(Duration(days: dn - 1));
          dateStr =
              '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
        }
        final newDay = TripDayItem(
          id: 'day_${trip.id}_${dn}_${DateTime.now().microsecondsSinceEpoch}',
          itineraryId: trip.id,
          dayNumber: dn,
          title: 'Day $dn',
          date: dateStr,
          sortOrder: dn - 1,
        );
        await insertDay(newDay);
      }
    } else if (targetCount < existingDays.length) {
      // If duration decreased, remove empty days beyond targetCount
      final events = await getEventsForItinerary(trip.id);
      for (final day in existingDays) {
        if (day.dayNumber > targetCount) {
          final hasEvents = events.any((e) =>
              e.dayId == day.id ||
              (e.dayId == null && e.dayNumber == day.dayNumber));
          if (!hasEvents) {
            await deleteDay(day.id);
          }
        }
      }
    }
  }

  Future<int> insertDay(TripDayItem day) async {
    final db = await database;
    return await db.insert('itinerary_days', day.toMap());
  }

  Future<int> updateDay(TripDayItem day) async {
    final db = await database;
    return await db.update(
      'itinerary_days',
      day.toMap(),
      where: 'id = ?',
      whereArgs: [day.id],
    );
  }

  Future<int> deleteDay(String dayId) async {
    final db = await database;
    await db.delete('trip_events', where: 'day_id = ?', whereArgs: [dayId]);
    return await db.delete('itinerary_days', where: 'id = ?', whereArgs: [dayId]);
  }

  Future<void> reorderDays(List<TripDayItem> days) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < days.length; i++) {
      batch.update(
        'itinerary_days',
        {'sort_order': i, 'day_number': i + 1},
        where: 'id = ?',
        whereArgs: [days[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  // --- Events CRUD ---
  Future<List<TripEventItem>> getEventsForDay(int itineraryId, String dayId) async {
    final db = await database;
    final maps = await db.query(
      'trip_events',
      where: 'itinerary_id = ? AND (day_id = ? OR day_number = ?)',
      whereArgs: [itineraryId, dayId, int.tryParse(dayId) ?? -1],
      orderBy: 'sort_order ASC, start_time ASC, id ASC',
    );
    return maps.map((m) => TripEventItem.fromMap(m)).toList();
  }

  Future<List<TripEventItem>> getEventsForItinerary(int itineraryId) async {
    final db = await database;
    final maps = await db.query(
      'trip_events',
      where: 'itinerary_id = ?',
      whereArgs: [itineraryId],
      orderBy: 'sort_order ASC, day_number ASC, start_time ASC, id ASC',
    );
    return maps.map((m) => TripEventItem.fromMap(m)).toList();
  }

  Future<int> insertEvent(TripEventItem event) async {
    final db = await database;
    final res = await db.insert('trip_events', event.toMap());
    try {
      for (int i = 0; i < event.notes.length; i++) {
        await db.insert('event_notes', {
          'event_id': event.id,
          'note_text': event.notes[i],
          'sort_order': i,
        });
      }
      for (int i = 0; i < event.photos.length; i++) {
        await db.insert('event_photos', {
          'event_id': event.id,
          'photo_path': event.photos[i],
          'sort_order': i,
        });
      }
    } catch (_) {}
    return res;
  }

  Future<int> updateEvent(TripEventItem event) async {
    final db = await database;
    final count = await db.update(
      'trip_events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
    try {
      await db.delete('event_notes', where: 'event_id = ?', whereArgs: [event.id]);
      for (int i = 0; i < event.notes.length; i++) {
        await db.insert('event_notes', {
          'event_id': event.id,
          'note_text': event.notes[i],
          'sort_order': i,
        });
      }
      await db.delete('event_photos', where: 'event_id = ?', whereArgs: [event.id]);
      for (int i = 0; i < event.photos.length; i++) {
        await db.insert('event_photos', {
          'event_id': event.id,
          'photo_path': event.photos[i],
          'sort_order': i,
        });
      }
    } catch (_) {}
    return count;
  }

  Future<int> deleteEvent(String eventId) async {
    final db = await database;
    return await db.delete('trip_events', where: 'id = ?', whereArgs: [eventId]);
  }

  Future<void> reorderEvents(List<TripEventItem> events) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < events.length; i++) {
      batch.update(
        'trip_events',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [events[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  // --- Documents CRUD ---
  Future<List<TripDocumentItem>> getDocumentsForItinerary(int itineraryId) async {
    final db = await database;
    final maps = await db.query(
      'trip_documents',
      where: 'itinerary_id = ?',
      whereArgs: [itineraryId],
      orderBy: 'id ASC',
    );
    final docs = maps.map((m) => TripDocumentItem.fromMap(m)).toList();
    for (int i = 0; i < docs.length; i++) {
      final d = docs[i];
      if (d.attachments.isEmpty) {
        try {
          final childRows = await db.query(
            'document_attachments',
            where: 'document_id = ?',
            whereArgs: [d.id],
            orderBy: 'sort_order ASC',
          );
          if (childRows.isNotEmpty) {
            final atts = childRows.map((r) => {
              'name': r['file_name'] as String? ?? '',
              'size': r['file_size'] as String? ?? '',
              'path': r['file_path'] as String? ?? '',
            }).toList();
            docs[i] = d.copyWith(attachmentsJson: jsonEncode(atts));
          }
        } catch (_) {}
      }
    }
    return docs;
  }

  Future<int> insertDocument(TripDocumentItem doc) async {
    final db = await database;
    int res = 0;
    try {
      res = await db.insert('trip_documents', doc.toMap());
    } catch (_) {
      await _ensureDocumentColumns(db);
      res = await db.insert('trip_documents', doc.toMap());
    }

    try {
      for (int i = 0; i < doc.attachments.length; i++) {
        final att = doc.attachments[i];
        await db.insert('document_attachments', {
          'document_id': doc.id,
          'file_name': att['name'] ?? '',
          'file_size': att['size'] ?? '',
          'file_path': att['path'] ?? '',
          'sort_order': i,
        });
      }
      if (doc.hasLocation) {
        await db.insert('trip_locations', {
          'itinerary_id': doc.itineraryId,
          'document_id': doc.id,
          'event_id': doc.eventId,
          'location_name': doc.locationName ?? '',
          'latitude': doc.latitude,
          'longitude': doc.longitude,
          'map_url': doc.mapUrl,
        });
      }
    } catch (_) {}

    return res;
  }

  Future<int> updateDocument(TripDocumentItem doc) async {
    final db = await database;
    int count = 0;
    try {
      count = await db.update(
        'trip_documents',
        doc.toMap(),
        where: 'id = ?',
        whereArgs: [doc.id],
      );
    } catch (_) {
      await _ensureDocumentColumns(db);
      count = await db.update(
        'trip_documents',
        doc.toMap(),
        where: 'id = ?',
        whereArgs: [doc.id],
      );
    }

    try {
      await db.delete('document_attachments', where: 'document_id = ?', whereArgs: [doc.id]);
      for (int i = 0; i < doc.attachments.length; i++) {
        final att = doc.attachments[i];
        await db.insert('document_attachments', {
          'document_id': doc.id,
          'file_name': att['name'] ?? '',
          'file_size': att['size'] ?? '',
          'file_path': att['path'] ?? '',
          'sort_order': i,
        });
      }

      await db.delete('trip_locations', where: 'document_id = ?', whereArgs: [doc.id]);
      if (doc.hasLocation) {
        await db.insert('trip_locations', {
          'itinerary_id': doc.itineraryId,
          'document_id': doc.id,
          'event_id': doc.eventId,
          'location_name': doc.locationName ?? '',
          'latitude': doc.latitude,
          'longitude': doc.longitude,
          'map_url': doc.mapUrl,
        });
      }
    } catch (_) {}

    return count;
  }

  Future<int> deleteDocument(String docId) async {
    final db = await database;
    return await db.delete('trip_documents', where: 'id = ?', whereArgs: [docId]);
  }

  // --- Storage Helpers ---
  static Future<String> saveBannerToAppStorage(String sourcePath) async {
    try {
      if (sourcePath.startsWith('assets/')) return sourcePath;
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return sourcePath;

      final appSupportDir = await getApplicationSupportDirectory();
      final bannerDir = Directory(p.join(appSupportDir.path, 'TripyTravy', 'banners'));
      if (!await bannerDir.exists()) {
        await bannerDir.create(recursive: true);
      }
      final ext = p.extension(sourcePath);
      final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}$ext';
      final destPath = p.join(bannerDir.path, fileName);
      await sourceFile.copy(destPath);
      return destPath;
    } catch (_) {
      return sourcePath;
    }
  }

  static Future<String> saveEventPhotoToAppStorage(String sourcePath) async {
    try {
      if (sourcePath.startsWith('assets/')) return sourcePath;
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return sourcePath;

      final appSupportDir = await getApplicationSupportDirectory();
      final photosDir = Directory(p.join(appSupportDir.path, 'TripyTravy', 'event_photos'));
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      final ext = p.extension(sourcePath);
      final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}_${(sourcePath.hashCode % 1000).abs()}$ext';
      final destPath = p.join(photosDir.path, fileName);
      await sourceFile.copy(destPath);
      return destPath;
    } catch (_) {
      return sourcePath;
    }
  }

  static Future<String> saveDocumentToAppStorage(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return sourcePath;

      final appSupportDir = await getApplicationSupportDirectory();
      final docsDir = Directory(p.join(appSupportDir.path, 'TripyTravy', 'documents'));
      if (!await docsDir.exists()) {
        await docsDir.create(recursive: true);
      }
      final ext = p.extension(sourcePath);
      final fileName = 'doc_${DateTime.now().millisecondsSinceEpoch}$ext';
      final destPath = p.join(docsDir.path, fileName);
      await sourceFile.copy(destPath);
      return destPath;
    } catch (_) {
      return sourcePath;
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
