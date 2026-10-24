import 'dart:convert';

enum ChecklistCategory {
  documents,
  clothing,
  electronics,
  toiletries,
  health,
  gear,
  misc;

  static ChecklistCategory fromString(String val) =>
      ChecklistCategory.values.firstWhere(
        (e) => e.name.toLowerCase() == val.toLowerCase(),
        orElse: () => ChecklistCategory.misc,
      );

  String get displayName {
    switch (this) {
      case ChecklistCategory.documents:
        return 'Documents & Money';
      case ChecklistCategory.clothing:
        return 'Clothing & Apparel';
      case ChecklistCategory.electronics:
        return 'Electronics & Gadgets';
      case ChecklistCategory.toiletries:
        return 'Toiletries & Personal Care';
      case ChecklistCategory.health:
        return 'Health & Medications';
      case ChecklistCategory.gear:
        return 'Travel Gear & Bags';
      case ChecklistCategory.misc:
        return 'Miscellaneous';
    }
  }
}

class TravelerChecklistItem {
  final String id;
  final String title;
  final ChecklistCategory category;
  final bool isChecked;
  final bool isCustom;
  final String notes;
  final String? reminderIso8601;

  const TravelerChecklistItem({
    required this.id,
    required this.title,
    this.category = ChecklistCategory.misc,
    this.isChecked = false,
    this.isCustom = false,
    this.notes = '',
    this.reminderIso8601,
  });

  TravelerChecklistItem copyWith({
    String? id,
    String? title,
    ChecklistCategory? category,
    bool? isChecked,
    bool? isCustom,
    String? notes,
    String? reminderIso8601,
  }) {
    return TravelerChecklistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      isChecked: isChecked ?? this.isChecked,
      isCustom: isCustom ?? this.isCustom,
      notes: notes ?? this.notes,
      reminderIso8601: reminderIso8601 ?? this.reminderIso8601,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category.name,
        'isChecked': isChecked,
        'isCustom': isCustom,
        'notes': notes,
        if (reminderIso8601 != null) 'reminderIso8601': reminderIso8601,
      };

  factory TravelerChecklistItem.fromJson(Map<String, dynamic> json) =>
      TravelerChecklistItem(
        id: (json['id'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        category: ChecklistCategory.fromString(
            (json['category'] as String?) ?? 'misc'),
        isChecked: (json['isChecked'] as bool?) ?? false,
        isCustom: (json['isCustom'] as bool?) ?? false,
        notes: (json['notes'] as String?) ?? '',
        reminderIso8601: json['reminderIso8601'] as String?,
      );
}

class TripChecklistState {
  final String tripId;
  final List<TravelerChecklistItem> items;
  final DateTime lastModified;

  const TripChecklistState({
    required this.tripId,
    this.items = const [],
    required this.lastModified,
  });

  int get completedCount => items.where((i) => i.isChecked).length;
  int get totalCount => items.length;
  double get progressPercentage =>
      totalCount == 0 ? 0.0 : (completedCount / totalCount);
  bool get isFullyCompleted => totalCount > 0 && completedCount == totalCount;

  List<TravelerChecklistItem> getItemsByCategory(ChecklistCategory category) =>
      items.where((i) => i.category == category).toList();

  TripChecklistState toggleItem(String itemId, bool checked) {
    return copyWith(
      items: items.map((i) {
        if (i.id == itemId) {
          return i.copyWith(isChecked: checked);
        }
        return i;
      }).toList(),
      lastModified: DateTime.now().toUtc(),
    );
  }

  TripChecklistState addItem(TravelerChecklistItem newItem) {
    final existingIdx = items.indexWhere((i) => i.id == newItem.id);
    final updated = List<TravelerChecklistItem>.from(items);
    if (existingIdx >= 0) {
      updated[existingIdx] = newItem;
    } else {
      updated.add(newItem);
    }
    return copyWith(items: updated, lastModified: DateTime.now().toUtc());
  }

  TripChecklistState removeItem(String itemId) {
    return copyWith(
      items: items.where((i) => i.id != itemId).toList(),
      lastModified: DateTime.now().toUtc(),
    );
  }

  TripChecklistState resetAll() {
    return copyWith(
      items: items.map((i) => i.copyWith(isChecked: false)).toList(),
      lastModified: DateTime.now().toUtc(),
    );
  }

  TripChecklistState copyWith({
    String? tripId,
    List<TravelerChecklistItem>? items,
    DateTime? lastModified,
  }) {
    return TripChecklistState(
      tripId: tripId ?? this.tripId,
      items: items ?? this.items,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  Map<String, dynamic> toJson() => {
        'tripId': tripId,
        'lastModified': lastModified.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory TripChecklistState.fromJson(Map<String, dynamic> json) =>
      TripChecklistState(
        tripId: (json['tripId'] as String?) ?? '',
        lastModified: json['lastModified'] != null
            ? DateTime.parse(json['lastModified'] as String)
            : DateTime.now().toUtc(),
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((e) => TravelerChecklistItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static TripChecklistState createDefault(String tripId) {
    const defaultTemplates = [
      TravelerChecklistItem(
        id: 'chk_passport',
        title: 'Passport / National ID / Driver License',
        category: ChecklistCategory.documents,
      ),
      TravelerChecklistItem(
        id: 'chk_visa',
        title: 'Visa & Entry Permits (Printed or e-Visa)',
        category: ChecklistCategory.documents,
      ),
      TravelerChecklistItem(
        id: 'chk_insurance',
        title: 'Travel Insurance Policy Documents',
        category: ChecklistCategory.documents,
      ),
      TravelerChecklistItem(
        id: 'chk_tickets',
        title: 'Flight / Train / Hotel Vouchers',
        category: ChecklistCategory.documents,
      ),
      TravelerChecklistItem(
        id: 'chk_cards_cash',
        title: 'Credit / Debit Cards & Local Currency Cash',
        category: ChecklistCategory.documents,
      ),
      TravelerChecklistItem(
        id: 'chk_phone_charger',
        title: 'Phone & Laptop Chargers',
        category: ChecklistCategory.electronics,
      ),
      TravelerChecklistItem(
        id: 'chk_power_bank',
        title: 'Portable Power Bank (Under 100Wh)',
        category: ChecklistCategory.electronics,
      ),
      TravelerChecklistItem(
        id: 'chk_adapter',
        title: 'Universal Travel Power Adapter',
        category: ChecklistCategory.electronics,
      ),
      TravelerChecklistItem(
        id: 'chk_headphones',
        title: 'Noise-Cancelling Headphones / Earbuds',
        category: ChecklistCategory.electronics,
      ),
      TravelerChecklistItem(
        id: 'chk_clothes_daily',
        title: 'Weather-appropriate Outfits & Layers',
        category: ChecklistCategory.clothing,
      ),
      TravelerChecklistItem(
        id: 'chk_shoes_walk',
        title: 'Comfortable Walking Shoes',
        category: ChecklistCategory.clothing,
      ),
      TravelerChecklistItem(
        id: 'chk_rainwear',
        title: 'Rain Jacket or Compact Umbrella',
        category: ChecklistCategory.clothing,
      ),
      TravelerChecklistItem(
        id: 'chk_meds_regular',
        title: 'Prescription Medications & Prescriptions',
        category: ChecklistCategory.health,
      ),
      TravelerChecklistItem(
        id: 'chk_first_aid',
        title: 'First Aid Kit (Pain Relief, Band-Aids, Antiseptic)',
        category: ChecklistCategory.health,
      ),
      TravelerChecklistItem(
        id: 'chk_toiletries_kit',
        title: 'Toothbrush, Toothpaste & Skincare (<100ml)',
        category: ChecklistCategory.toiletries,
      ),
      TravelerChecklistItem(
        id: 'chk_daypack',
        title: 'Lightweight Daypack or Sling Bag',
        category: ChecklistCategory.gear,
      ),
    ];

    return TripChecklistState(
      tripId: tripId,
      items: defaultTemplates,
      lastModified: DateTime.now().toUtc(),
    );
  }
}
