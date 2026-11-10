import '../entities/attachment_descriptor.dart';
import '../entities/trip_package.dart';

class TemplateSanitizerPolicy {
  const TemplateSanitizerPolicy();

  TripPackage sanitizeForTemplate(TripPackage trip) {
    final safe = trip.allAssets.where((a) => a.visibility == AttachmentVisibility.templateSafe).toList();
    final ids = safe.map((a) => a.assetId).toSet();
    return trip.copyWith(
      isTemplate: true,
      travelers: const [],
      allAssets: safe,
      documents: trip.documents.where((d) => d.assetSha256 == null || safe.any((a) => a.sha256Checksum == d.assetSha256)).toList(),
      days: trip.days
          .map((d) => d.copyWith(
                events: d.events
                    .map((e) => e.copyWith(
                          photos: e.photos.where((photo) => !photo.startsWith('asset:') || safe.any((a) => a.sha256Checksum == photo.substring(6))).toList(),
                          documents: e.documents.where((d) => d.assetSha256 == null || safe.any((a) => a.sha256Checksum == d.assetSha256)).toList(),
                          attachmentAssetIds: e.attachmentAssetIds.where(ids.contains).toList(),
                          flight: e.flight?.sanitized(),
                          lodging: e.lodging?.sanitized(),
                          transport: e.transport?.sanitized(),
                          activity: e.activity?.sanitized(),
                          meal: e.meal?.sanitized(),
                        ))
                    .toList(),
              ))
          .toList(),
    );
  }
}
