import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages filesystem folders and exported .tt container files for TripyTravy itineraries.
class ItineraryFileManager {
  /// Default pre-existing itineraries that must have folders created automatically.
  static const List<String> defaultItineraryNames = [
    'Switzerland & Italy',
    'Vietnam',
    'Malaysia',
  ];

  @visibleForTesting
  static Directory? overrideBaseDirectory;

  @visibleForTesting
  static Future<void> Function(String path)? openExplorerOverride;

  /// Returns the base directory for TripyTravy exported itineraries.
  /// Defaults to `<UserDocuments>/TripyTravy`.
  static Future<Directory> getBaseDirectory() async {
    if (overrideBaseDirectory != null) {
      if (!overrideBaseDirectory!.existsSync()) {
        overrideBaseDirectory!.createSync(recursive: true);
      }
      return overrideBaseDirectory!;
    }

    Directory base;
    try {
      final docs = await getApplicationDocumentsDirectory();
      base = Directory(p.join(docs.path, 'TripyTravy'));
    } catch (_) {
      base = Directory(p.join(Directory.systemTemp.path, 'TripyTravy'));
    }

    if (!base.existsSync()) {
      base.createSync(recursive: true);
    }
    return base;
  }

  /// Sanitizes an itinerary title for use as a filesystem directory or filename.
  /// Strips or replaces characters prohibited on Windows / Unix: \ / : * ? " < > |
  static String sanitizeName(String name) {
    var sanitized = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    while (sanitized.endsWith('.')) {
      sanitized = sanitized.substring(0, sanitized.length - 1).trim();
    }
    if (sanitized.isEmpty) {
      return 'Untitled_Itinerary';
    }
    return sanitized;
  }

  /// Formats a DateTime as YYYY-MM-DD-HHmmss for filenames.
  static String formatTimestamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final sec = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d-$h$min$sec';
  }

  /// Generates the default filename for an exported itinerary:
  /// `<itinerary-name-Date-time-stamp>.tt`
  static String generateTtFileName(String itineraryTitle, [DateTime? time]) {
    final safe = sanitizeName(itineraryTitle);
    final stamp = formatTimestamp(time ?? DateTime.now());
    return '$safe-$stamp.tt';
  }

  /// Returns the folder corresponding to an itinerary title, creating it if needed.
  static Future<Directory> ensureItineraryFolder(String itineraryTitle) async {
    final base = await getBaseDirectory();
    final safe = sanitizeName(itineraryTitle);
    final dir = Directory(p.join(base.path, safe));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Returns the directory for an itinerary title without creating it if it doesn't exist.
  static Future<Directory> getItineraryFolder(String itineraryTitle) async {
    final base = await getBaseDirectory();
    final safe = sanitizeName(itineraryTitle);
    return Directory(p.join(base.path, safe));
  }

  /// Ensures folders for default pre-existing itineraries and any provided titles exist.
  static Future<void> ensureDefaultFolders([List<String>? additionalTitles]) async {
    final titlesToCreate = <String>{...defaultItineraryNames};
    if (additionalTitles != null) {
      titlesToCreate.addAll(additionalTitles);
    }
    for (final title in titlesToCreate) {
      if (title.trim().isNotEmpty) {
        await ensureItineraryFolder(title);
      }
    }
  }

  /// Returns all exported `.tt` files inside the itinerary's folder,
  /// sorted newest first.
  static Future<List<File>> getExportedTtFiles(String itineraryTitle) async {
    final folder = await ensureItineraryFolder(itineraryTitle);
    if (!folder.existsSync()) return [];

    final list = <File>[];
    try {
      final entries = folder.listSync(recursive: false, followLinks: false);
      for (final entity in entries) {
        if (entity is File && entity.path.toLowerCase().endsWith('.tt')) {
          list.add(entity);
        }
      }
    } catch (_) {}

    list.sort((a, b) {
      try {
        return b.lastModifiedSync().compareTo(a.lastModifiedSync());
      } catch (_) {
        return 0;
      }
    });

    return list;
  }

  /// Saves the compiled `.tt` container bytes directly into the itinerary's folder.
  static Future<File> saveTtFile({
    required String itineraryTitle,
    required List<int> bytes,
    String? customFileName,
    DateTime? timestamp,
  }) async {
    final folder = await ensureItineraryFolder(itineraryTitle);
    final fileName = customFileName ?? generateTtFileName(itineraryTitle, timestamp);
    final targetFile = File(p.join(folder.path, fileName));
    targetFile.writeAsBytesSync(bytes, flush: true);
    return targetFile;
  }

  /// Opens the itinerary's folder in the native OS File Explorer.
  static Future<void> openFolderInExplorer(String folderPath) async {
    if (openExplorerOverride != null) {
      await openExplorerOverride!(folderPath);
      return;
    }
    try {
      final dir = Directory(folderPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [folderPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [folderPath]);
      } else {
        await Process.run('xdg-open', [folderPath]);
      }
    } catch (e) {
      debugPrint('Failed to open folder in explorer: $e');
    }
  }

  /// Opens the native OS File Explorer and selects/highlights the specified file.
  static Future<void> openFileInExplorer(String filePath) async {
    if (openExplorerOverride != null) {
      await openExplorerOverride!(filePath);
      return;
    }
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        final parent = file.parent;
        if (parent.existsSync()) {
          await openFolderInExplorer(parent.path);
        }
        return;
      }
      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', filePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', filePath]);
      } else {
        await Process.run('xdg-open', [file.parent.path]);
      }
    } catch (e) {
      debugPrint('Failed to open file in explorer: $e');
    }
  }

  /// Opens the base root TripyTravy folder in File Explorer.
  static Future<void> openBaseFolderInExplorer() async {
    final base = await getBaseDirectory();
    await openFolderInExplorer(base.path);
  }
}
