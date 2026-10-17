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
      days: trip.days
          .map((d) => d.copyWith(
                events: d.events
                    .map((e) => e.copyWith(
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
