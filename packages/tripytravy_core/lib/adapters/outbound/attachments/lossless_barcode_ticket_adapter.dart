import '../../../domain/entities/attachment_descriptor.dart';
import '../../../domain/ports/outbound_ports.dart';

class LosslessBarcodeTicketAdapter implements AttachmentProcessorPort {
  static const _m = {'image/png', 'image/jpeg'};
  const LosslessBarcodeTicketAdapter();
  @override
  bool canHandle(String m, AttachmentCategory c) =>
      (c == AttachmentCategory.boardingPass || c == AttachmentCategory.activityTicket) && _m.contains(m.toLowerCase());
  @override
  Future<ProcessedAttachment> process(RawAttachmentInput i) async => ProcessedAttachment(
        filename: i.filename,
        mimeType: i.mimeType,
        category: i.category,
        visibility: AttachmentVisibility.privateBooking,
        processedBytes: List<int>.unmodifiable(i.rawBytes),
      );
}
