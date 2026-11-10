import 'dart:io';
import 'package:test/test.dart';
import 'package:tripytravy_core/tripytravy_core.dart';

void main() {
  late Directory tempDir;
  late FileChecklistRepositoryAdapter repo;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tripy_chk_test_');
    repo = FileChecklistRepositoryAdapter(baseDirectory: tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('generates default checklist and calculates progress', () async {
    final checklist = await repo.getChecklistForTrip('trip_paris_1');
    expect(checklist.tripId, 'trip_paris_1');
    expect(checklist.items, isNotEmpty);
    expect(checklist.completedCount, 0);
    expect(checklist.progressPercentage, 0.0);
    expect(checklist.isFullyCompleted, isFalse);

    // Verify key travel categories exist
    final docItems = checklist.getItemsByCategory(ChecklistCategory.documents);
    expect(docItems.any((i) => i.id == 'chk_passport'), isTrue);
    expect(docItems.any((i) => i.id == 'chk_insurance'), isTrue);

    final elecItems =
        checklist.getItemsByCategory(ChecklistCategory.electronics);
    expect(elecItems.any((i) => i.id == 'chk_phone_charger'), isTrue);
  });

  test('toggles, adds custom item, and persists checklist to disk', () async {
    var state = await repo.getChecklistForTrip('trip_rome');

    // Toggle passport to checked
    state = state.toggleItem('chk_passport', true);
    state = state.toggleItem('chk_insurance', true);
    expect(state.completedCount, 2);

    // Add custom item
    state = state.addItem(const TravelerChecklistItem(
      id: 'chk_snorkeling_mask',
      title: 'Prescription Snorkel Mask',
      category: ChecklistCategory.gear,
      isCustom: true,
      isChecked: true,
    ));

    await repo.saveChecklist(state);

    // Re-instantiate repo from the same directory to verify persistence across restarts
    final reloadedRepo = FileChecklistRepositoryAdapter(baseDirectory: tempDir);
    final loaded = await reloadedRepo.getChecklistForTrip('trip_rome');

    expect(loaded.completedCount, 3);
    final passport = loaded.items.firstWhere((i) => i.id == 'chk_passport');
    expect(passport.isChecked, isTrue);

    final custom =
        loaded.items.firstWhere((i) => i.id == 'chk_snorkeling_mask');
    expect(custom.isChecked, isTrue);
    expect(custom.isCustom, isTrue);
  });
}
