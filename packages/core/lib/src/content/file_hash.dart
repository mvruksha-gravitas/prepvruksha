import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// Hex SHA-256 of [bytes], computed in chunks so the UI can show progress
/// (0.0–1.0) and stay responsive on large files (up to 100 MB).
Future<String> sha256Hex(
  Uint8List bytes, {
  void Function(double progress)? onProgress,
  int chunkSize = 4 * 1024 * 1024,
}) async {
  final output = _DigestSink();
  final input = crypto.sha256.startChunkedConversion(output);
  for (var start = 0; start < bytes.length; start += chunkSize) {
    final end = start + chunkSize < bytes.length
        ? start + chunkSize
        : bytes.length;
    input.add(Uint8List.sublistView(bytes, start, end));
    onProgress?.call(end / bytes.length);
    // Let the UI repaint between chunks.
    await Future<void>.delayed(Duration.zero);
  }
  input.close();
  return output.value.toString();
}

class _DigestSink implements Sink<crypto.Digest> {
  late crypto.Digest value;

  @override
  void add(crypto.Digest data) => value = data;

  @override
  void close() {}
}
