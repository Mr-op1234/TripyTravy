import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import '../../../domain/entities/attachment_descriptor.dart';
import '../../../domain/ports/outbound_ports.dart';

/// Persistent Content-Addressable Storage (CAS) adapter on disk.
/// Saves blobs named by their cryptographic SHA-256 hash.
/// Supports deduplication, raw streams, and direct file path resolution for native image/PDF rendering.
class FileCasAttachmentStorageAdapter implements AttachmentStoragePort {
  final Directory storageDirectory;

  FileCasAttachmentStorageAdapter({required this.storageDirectory}) {
    if (!storageDirectory.existsSync()) {
      storageDirectory.createSync(recursive: true);
    }
  }

  factory FileCasAttachmentStorageAdapter.fromPath(String path) {
    return FileCasAttachmentStorageAdapter(
      storageDirectory: Directory(path),
    );
  }

  File _getBlobFile(String sha256Checksum) =>
      File(p.join(storageDirectory.path, sha256Checksum));

  @override
  int get uniqueBlobCount {
    if (!storageDirectory.existsSync()) return 0;
    return storageDirectory
        .listSync(followLinks: false)
        .whereType<File>()
        .length;
  }

  @override
  Future<AttachmentDescriptor> storeDeduplicated(
      ProcessedAttachment attachment) async {
    final sha = sha256.convert(attachment.processedBytes).toString();
    final file = _getBlobFile(sha);

    if (!await file.exists()) {
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(attachment.processedBytes, flush: true);
      await tmp.rename(file.path);
    }

    return AttachmentDescriptor(
      assetId: 'asset_${sha.substring(0, 12)}',
      filename: attachment.filename,
      mimeType: attachment.mimeType,
      category: attachment.category,
      visibility: attachment.visibility,
      byteSize: attachment.processedBytes.length,
      sha256Checksum: sha,
    );
  }

  @override
  Future<List<int>?> readBlobBySha256(String sha256Checksum) async {
    final file = _getBlobFile(sha256Checksum);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> putRawBlob(String sha256Checksum, List<int> bytes) async {
    final file = _getBlobFile(sha256Checksum);
    if (await file.exists()) return; // Deduplicated

    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
  }

  @override
  Future<bool> hasBlob(String sha256Checksum) async {
    final file = _getBlobFile(sha256Checksum);
    return file.exists();
  }

  @override
  Future<String?> getBlobPath(String sha256Checksum) async {
    final file = _getBlobFile(sha256Checksum);
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }
}
