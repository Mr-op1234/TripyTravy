import 'dart:convert';
import '../../../domain/entities/attachment_descriptor.dart';
import '../../../domain/ports/outbound_ports.dart';

class PdfVoucherInspectorAdapter implements AttachmentProcessorPort {
  const PdfVoucherInspectorAdapter();
  @override
  bool canHandle(String m, AttachmentCategory c) => m.toLowerCase() == 'application/pdf';
  @override
  Future<ProcessedAttachment> process(RawAttachmentInput i) async {
    if (i.rawBytes.length < 5 || ascii.decode(i.rawBytes.sublist(0, 5), allowInvalid: true) != '%PDF-') {
      throw FormatException('Invalid PDF: ${i.filename}');
    }
    return ProcessedAttachment(
      filename: i.filename,
      mimeType: 'application/pdf',
      category: i.category,
      visibility: i.category.defaultVisibility,
      processedBytes: List<int>.unmodifiable(i.rawBytes),
    );
  }
}
