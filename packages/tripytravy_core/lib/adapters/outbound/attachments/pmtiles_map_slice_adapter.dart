import 'dart:convert';
import '../../../domain/entities/attachment_descriptor.dart';
import '../../../domain/ports/outbound_ports.dart';

class PmTilesMapSliceAdapter implements AttachmentProcessorPort {
  const PmTilesMapSliceAdapter();
  @override
  bool canHandle(String m, AttachmentCategory c) =>
      c == AttachmentCategory.offlineMapSlice || m.toLowerCase() == 'application/vnd.pmtiles';
  @override
  Future<ProcessedAttachment> process(RawAttachmentInput i) async {
    if (i.rawBytes.length < 7 || ascii.decode(i.rawBytes.sublist(0, 7), allowInvalid: true) != 'PMTiles') {
      throw FormatException('Invalid PMTiles: ${i.filename}');
    }
    return ProcessedAttachment(
      filename: i.filename,
      mimeType: 'application/vnd.pmtiles',
      category: AttachmentCategory.offlineMapSlice,
      visibility: AttachmentVisibility.templateSafe,
      processedBytes: List<int>.unmodifiable(i.rawBytes),
    );
  }
}
