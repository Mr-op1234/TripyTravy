import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DestinationItem {
  final int id;
  final String title;
  final String subtitle;
  final String duration;
  final String dateRange;
  final String imagePath;
  final String? startDate;
  final String? endDate;

  const DestinationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.dateRange,
    required this.imagePath,
    this.startDate,
    this.endDate,
  });

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

    return await openDatabase(
      dbPath,
      version: 2,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE itineraries ADD COLUMN start_date TEXT');
            await db.execute('ALTER TABLE itineraries ADD COLUMN end_date TEXT');
          } catch (_) {}
        }
      },
    );
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
        end_date TEXT
      )
    ''');

    // Seed initial default itineraries on first launch
    await db.insert('itineraries', {
      'title': 'Japan',
      'subtitle': 'Ancient temples, neon cities, and breathtaking Mount Fuji.',
      'duration': '6 Days',
      'date_range': 'Apr 12 - Apr 17, 2025',
      'image_path': 'assets/images/japan_clean.png',
      'start_date': '2025-04-12',
      'end_date': '2025-04-17',
    });

    await db.insert('itineraries', {
      'title': 'Switzerland',
      'subtitle': 'Breathtaking mountain peaks, charming alpine towns, and crystal lakes.',
      'duration': '7 Days',
      'date_range': 'May 05 - May 12, 2025',
      'image_path': 'assets/images/switzerland_clean.png',
      'start_date': '2025-05-05',
      'end_date': '2025-05-12',
    });

    await db.insert('itineraries', {
      'title': 'Malaysia',
      'subtitle': 'Lush tropical rainforests, diverse cuisine, and iconic skylines.',
      'duration': '5 Days',
      'date_range': 'Jun 10 - Jun 15, 2025',
      'image_path': 'assets/images/malaysia_clean.png',
      'start_date': '2025-06-10',
      'end_date': '2025-06-15',
    });
  }

  Future<List<DestinationItem>> getAllItineraries() async {
    final db = await database;
    final maps = await db.query('itineraries', orderBy: 'id ASC');
    return maps.map((m) => DestinationItem.fromMap(m)).toList();
  }

  Future<DestinationItem> insertItinerary({
    required String title,
    required String subtitle,
    required String duration,
    required String dateRange,
    required String imagePath,
    String? startDate,
    String? endDate,
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
    });
    return DestinationItem(
      id: id,
      title: title,
      subtitle: subtitle,
      duration: duration,
      dateRange: dateRange,
      imagePath: imagePath,
      startDate: startDate,
      endDate: endDate,
    );
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

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
