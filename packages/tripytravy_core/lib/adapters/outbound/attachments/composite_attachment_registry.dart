import '../../../domain/entities/attachment_descriptor.dart';
import '../../../domain/ports/outbound_ports.dart';
import 'lossless_barcode_ticket_adapter.dart';
import 'lossy_photo_webp_adapter.dart';
import 'pdf_voucher_inspector_adapter.dart';
import 'pmtiles_map_slice_adapter.dart';

class CompositeAttachmentRegistry implements AttachmentProcessorPort {
  final List<AttachmentProcessorPort> adapters;
  const CompositeAttachmentRegistry({
    this.adapters = const [
      LossyPhotoWebpAdapter(),
      LosslessBarcodeTicketAdapter(),
      PdfVoucherInspectorAdapter(),
      PmTilesMapSliceAdapter(),
    ],
  });
  @override
  bool canHandle(String m, AttachmentCategory c) => adapters.any((a) => a.canHandle(m, c));
  @override
  Future<ProcessedAttachment> process(RawAttachmentInput i) =>
      adapters.firstWhere((a) => a.canHandle(i.mimeType, i.category)).process(i);
}
