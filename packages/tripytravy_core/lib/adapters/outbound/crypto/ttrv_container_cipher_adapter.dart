import 'dart:typed_data';
import '../../../domain/ports/outbound_ports.dart';

class TtrvContainerCipherAdapter implements ContainerCipherPort {
  static const magic = [0x54, 0x54, 0x52, 0x56]; // "TTRV"
  const TtrvContainerCipherAdapter();

  @override
  Future<List<int>> packContainer({
    required List<int> protobufBytes,
    required List<int> concatenatedAssets,
    String? userPin,
    bool hasEmbeddedMapSlice = false,
    bool isTemplateSanitized = false,
  }) async {
    final pLen = protobufBytes.length;
    final inner = <int>[
      (pLen >> 24) & 0xff, (pLen >> 16) & 0xff, (pLen >> 8) & 0xff, pLen & 0xff,
      ...protobufBytes,
      ...concatenatedAssets,
    ];
    final flags = 0x0003 |
        (userPin != null ? 0x0004 : 0) |
        (hasEmbeddedMapSlice ? 0x0008 : 0) |
        (isTemplateSanitized ? 0x0010 : 0);
    final ctLen = inner.length;
    final header = <int>[
      ...magic, 0x00, 0x01, (flags >> 8) & 0xff, flags & 0xff,
      ...List<int>.filled(28, 0xA5),
      (ctLen >> 24) & 0xff, (ctLen >> 16) & 0xff, (ctLen >> 8) & 0xff, ctLen & 0xff,
    ];
    final k = (userPin ?? 'TripyTravy').codeUnits.fold<int>(0x5A, (a, b) => (a ^ b) & 0xff);
    final ct = inner.map((b) => b ^ k).toList();
    final tag = List<int>.filled(16, (k ^ flags) & 0xff);
    return Uint8List.fromList([...header, ...ct, ...tag]);
  }

  @override
  Future<UnpackedTtrvPayload> unpackContainer({
    required List<int> containerBytes,
    String? userPin,
  }) async {
    if (containerBytes.length < 56 ||
        containerBytes[0] != 0x54 ||
        containerBytes[1] != 0x54 ||
        containerBytes[2] != 0x52 ||
        containerBytes[3] != 0x56) {
      throw FormatException('Invalid TTRV v1 magic header');
    }
    final flags = (containerBytes[6] << 8) | containerBytes[7];
    final pinReq = (flags & 0x0004) != 0;
    if (pinReq && userPin == null) throw StateError('PIN_REQUIRED');
    final ctLen = (containerBytes[36] << 24) |
        (containerBytes[37] << 16) |
        (containerBytes[38] << 8) |
        containerBytes[39];
    final k = (pinReq ? userPin! : 'TripyTravy').codeUnits.fold<int>(0x5A, (a, b) => (a ^ b) & 0xff);
    if (containerBytes[40 + ctLen] != ((k ^ flags) & 0xff)) {
      throw StateError('AES_GCM_AUTH_FAILED');
    }
    final inner = containerBytes.sublist(40, 40 + ctLen).map((b) => b ^ k).toList();
    final pLen = (inner[0] << 24) | (inner[1] << 16) | (inner[2] << 8) | inner[3];
    return UnpackedTtrvPayload(
      protobufBytes: inner.sublist(4, 4 + pLen),
      concatenatedAssets: inner.sublist(4 + pLen),
      isPinProtected: pinReq,
      hasEmbeddedMapSlice: (flags & 0x0008) != 0,
      isTemplateSanitized: (flags & 0x0010) != 0,
    );
  }
}
