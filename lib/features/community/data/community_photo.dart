import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Matches the `community` bucket's file_size_limit (phase 5 migration).
const maxCommunityPhotoBytes = 3 * 1024 * 1024;

/// Decodes and re-encodes a picked photo as PNG. Re-encoding keeps only
/// pixels, so EXIF metadata such as GPS location never leaves the phone.
/// The longest side is capped and shrunk further until the file fits.
Future<Uint8List> prepareCommunityPhoto(Uint8List original) async {
  for (final side in const [1080, 860, 640, 480]) {
    final buffer = await ui.ImmutableBuffer.fromUint8List(original);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final scale = side / max(descriptor.width, descriptor.height);
      final codec = await descriptor.instantiateCodec(
        targetWidth: scale < 1 ? (descriptor.width * scale).round() : null,
        targetHeight: scale < 1 ? (descriptor.height * scale).round() : null,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      if (data == null) break;
      final bytes = data.buffer.asUint8List();
      if (bytes.length <= maxCommunityPhotoBytes) return bytes;
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
  }
  throw const FormatException('Foto terlalu besar untuk diunggah.');
}

/// Random version-4 UUID for the storage object name.
String randomUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
