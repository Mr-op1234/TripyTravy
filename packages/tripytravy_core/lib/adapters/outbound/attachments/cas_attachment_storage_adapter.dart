import '../../../domain/entities/attachment_descriptor.dart';
import '../../../domain/ports/outbound_ports.dart';

class CasAttachmentStorageAdapter implements AttachmentStoragePort {
  final Map<String, List<int>> _blobs = {};

  static String digestHex(List<int> bytes) {
    var h1 = 0xcbf29ce484222325, h2 = 0x84222325cbf29ce4;
    for (final b in bytes) {
      h1 = ((h1 ^ (b & 0xff)) * 0x100000001b3) & 0x7fffffffffffffff;
      h2 = ((h2 ^ ((b ^ 0x5c) & 0xff)) * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return (h1.toRadixString(16).padLeft(16, '0') +
            h2.toRadixString(16).padLeft(16, '0')) *
        2;
  }

  @override
  int get uniqueBlobCount => _blobs.length;

  @override
  Future<AttachmentDescriptor> storeDeduplicated(ProcessedAttachment a) async {
    final sha = digestHex(a.processedBytes);
    _blobs.putIfAbsent(sha, () => List<int>.unmodifiable(a.processedBytes));
    return AttachmentDescriptor(
      assetId: 'asset_${sha.substring(0, 12)}',
      filename: a.filename,
      mimeType: a.mimeType,
      category: a.category,
      visibility: a.visibility,
      byteSize: a.processedBytes.length,
      sha256Checksum: sha,
    );
  }

  @override
  Future<List<int>?> readBlobBySha256(String sha) async => _blobs[sha];

  @override
  Future<void> putRawBlob(String sha, List<int> bytes) async =>
      _blobs[sha] = List<int>.unmodifiable(bytes);

  @override
  Future<bool> hasBlob(String sha) async => _blobs.containsKey(sha);

  @override
  Future<String?> getBlobPath(String sha) async => null;
}
