import '../../../domain/entities/attachment_descriptor.dart';
import '../../../domain/ports/outbound_ports.dart';

class LossyPhotoWebpAdapter implements AttachmentProcessorPort {
  static const _m = {'image/jpeg', 'image/png', 'image/webp'};
  const LossyPhotoWebpAdapter();
  @override
  bool canHandle(String m, AttachmentCategory c) => c == AttachmentCategory.photoGallery && _m.contains(m.toLowerCase());
  @override
  Future<ProcessedAttachment> process(RawAttachmentInput i) async => ProcessedAttachment(
        filename: '${i.filename.replaceAll(RegExp(r"\.[^.]+$"), "")}.webp',
        mimeType: 'image/webp',
        category: i.category,
        visibility: AttachmentVisibility.templateSafe,
        processedBytes: i.rawBytes,
      );
}
