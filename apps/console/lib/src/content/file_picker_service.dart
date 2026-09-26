import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as fp;

/// A file chosen by the user; bytes are read only when uploading.
abstract interface class PickedFile {
  String get name;

  /// Size in bytes, or null when unknown until read.
  int? get size;

  Future<Uint8List> readBytes();
}

abstract interface class FilePickerService {
  /// Returns null when the user cancels.
  Future<PickedFile?> pickSourceFile();
}

class PlatformFilePickerService implements FilePickerService {
  const PlatformFilePickerService();

  @override
  Future<PickedFile?> pickSourceFile() async {
    final files = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: const ['pdf', 'docx'],
    );
    if (files.isEmpty) return null;
    final file = files.first;
    return _PlatformPickedFile(file, await file.length());
  }
}

class _PlatformPickedFile implements PickedFile {
  _PlatformPickedFile(this._file, this.size);

  final fp.PlatformFile _file;

  @override
  final int? size;

  @override
  String get name => _file.name;

  @override
  Future<Uint8List> readBytes() => _file.readAsBytes();
}
