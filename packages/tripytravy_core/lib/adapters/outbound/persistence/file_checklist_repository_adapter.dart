import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../domain/entities/traveler_checklist.dart';
import '../../../domain/ports/outbound_ports.dart';

/// Persistent storage adapter for traveler checklists on disk.
/// Saves each trip's checklist as JSON in a dedicated directory.
class FileChecklistRepositoryAdapter implements ChecklistRepositoryPort {
  final Directory baseDirectory;
  late final Directory _checklistsDir;

  FileChecklistRepositoryAdapter({required this.baseDirectory}) {
    _checklistsDir = Directory(p.join(baseDirectory.path, 'checklists'));
    if (!_checklistsDir.existsSync()) {
      _checklistsDir.createSync(recursive: true);
    }
  }

  factory FileChecklistRepositoryAdapter.fromPath(String path) {
    return FileChecklistRepositoryAdapter(
      baseDirectory: Directory(path),
    );
  }

  File _getChecklistFile(String tripId) =>
      File(p.join(_checklistsDir.path, '$tripId.json'));

  @override
  Future<TripChecklistState> getChecklistForTrip(String tripId) async {
    final file = _getChecklistFile(tripId);
    if (!await file.exists()) {
      // If none exists yet, generate and save the default packing checklist
      final def = TripChecklistState.createDefault(tripId);
      await saveChecklist(def);
      return def;
    }

    try {
      final jsonStr = await file.readAsString();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return TripChecklistState.fromJson(map);
    } catch (_) {
      final def = TripChecklistState.createDefault(tripId);
      return def;
    }
  }

  @override
  Future<void> saveChecklist(TripChecklistState checklist) async {
    final file = _getChecklistFile(checklist.tripId);
    final tmp = File('${file.path}.tmp');

    final jsonStr = jsonEncode(checklist.toJson());
    await tmp.writeAsString(jsonStr, flush: true);

    if (await file.exists()) {
      await file.delete();
    }
    await tmp.rename(file.path);
  }

  @override
  Future<bool> deleteChecklist(String tripId) async {
    final file = _getChecklistFile(tripId);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }
}
