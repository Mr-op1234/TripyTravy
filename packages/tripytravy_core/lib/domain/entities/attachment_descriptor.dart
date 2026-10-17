enum AttachmentCategory {
  boardingPass,
  hotelVoucher,
  activityTicket,
  photoGallery,
  diningMenu,
  offlineMapSlice,
  generalAdvisory;

  AttachmentVisibility get defaultVisibility {
    switch (this) {
      case AttachmentCategory.boardingPass:
      case AttachmentCategory.hotelVoucher:
      case AttachmentCategory.activityTicket:
        return AttachmentVisibility.privateBooking;
      case AttachmentCategory.photoGallery:
      case AttachmentCategory.diningMenu:
      case AttachmentCategory.offlineMapSlice:
      case AttachmentCategory.generalAdvisory:
        return AttachmentVisibility.templateSafe;
    }
  }
}

enum AttachmentVisibility {
  privateBooking,
  templateSafe,
}

class AttachmentDescriptor {
  final String assetId;
  final String filename;
  final String mimeType;
  final AttachmentCategory category;
  final AttachmentVisibility visibility;
  final int byteOffset;
  final int byteSize;
  final String sha256Checksum;

  const AttachmentDescriptor({
    required this.assetId,
    required this.filename,
    required this.mimeType,
    required this.category,
    required this.visibility,
    this.byteOffset = 0,
    required this.byteSize,
    required this.sha256Checksum,
  });

  AttachmentDescriptor copyWith({
    String? assetId,
    String? filename,
    String? mimeType,
    AttachmentCategory? category,
    AttachmentVisibility? visibility,
    int? byteOffset,
    int? byteSize,
    String? sha256Checksum,
  }) {
    return AttachmentDescriptor(
      assetId: assetId ?? this.assetId,
      filename: filename ?? this.filename,
      mimeType: mimeType ?? this.mimeType,
      category: category ?? this.category,
      visibility: visibility ?? this.visibility,
      byteOffset: byteOffset ?? this.byteOffset,
      byteSize: byteSize ?? this.byteSize,
      sha256Checksum: sha256Checksum ?? this.sha256Checksum,
    );
  }

  Map<String, dynamic> toJson() => {
        'assetId': assetId,
        'filename': filename,
        'mimeType': mimeType,
        'category': category.name,
        'visibility': visibility.name,
        'byteOffset': byteOffset,
        'byteSize': byteSize,
        'sha256Checksum': sha256Checksum,
      };

  factory AttachmentDescriptor.fromJson(Map<String, dynamic> json) {
    return AttachmentDescriptor(
      assetId: json['assetId'] as String,
      filename: json['filename'] as String,
      mimeType: json['mimeType'] as String,
      category: AttachmentCategory.values.byName(json['category'] as String),
      visibility: AttachmentVisibility.values.byName(json['visibility'] as String),
      byteOffset: (json['byteOffset'] as num?)?.toInt() ?? 0,
      byteSize: (json['byteSize'] as num).toInt(),
      sha256Checksum: json['sha256Checksum'] as String,
    );
  }
}
