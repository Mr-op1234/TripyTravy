import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:tripytravy_core/tripytravy_core.dart';

void main() {
  late Directory tempDir;
  late FileCasAttachmentStorageAdapter storage;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tripy_cas_test_');
    storage = FileCasAttachmentStorageAdapter(storageDirectory: tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('stores, deduplicates, and reads blobs on disk', () async {
    final sampleBytes = utf8.encode('PDF boarding pass data for flight TT-204');
    final attachment = ProcessedAttachment(
      filename: 'boarding_pass.pdf',
      mimeType: 'application/pdf',
      category: AttachmentCategory.boardingPass,
      visibility: AttachmentVisibility.privateBooking,
      processedBytes: sampleBytes,
    );

    final desc1 = await storage.storeDeduplicated(attachment);
    expect(desc1.sha256Checksum, isNotEmpty);
    expect(storage.uniqueBlobCount, 1);

    // Storing identical content again should deduplicate
    final desc2 = await storage.storeDeduplicated(attachment);
    expect(desc2.sha256Checksum, desc1.sha256Checksum);
    expect(storage.uniqueBlobCount, 1);

    // Read back blob
    final readBytes = await storage.readBlobBySha256(desc1.sha256Checksum);
    expect(readBytes, isNotNull);
    expect(utf8.decode(readBytes!), 'PDF boarding pass data for flight TT-204');

    // Check direct path exists for native image/PDF rendering
    final filePath = await storage.getBlobPath(desc1.sha256Checksum);
    expect(filePath, isNotNull);
    expect(File(filePath!).existsSync(), isTrue);
  });
}
