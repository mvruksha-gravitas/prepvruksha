/// Rights status of an uploaded file (CLAUDE.md rule 14).
enum RightsStatus {
  /// We own or licensed the content; may be published.
  ownedLicensed('owned_licensed'),

  /// An official previous-year paper; records exam and year.
  officialPyq('official_pyq'),

  /// Never published; similarity checks and inspiration only.
  referenceOnly('reference_only');

  const RightsStatus(this.wire);

  final String wire;

  static RightsStatus fromWire(String value) =>
      values.firstWhere((s) => s.wire == value);
}

enum SourceFileStatus {
  awaitingUpload('awaiting_upload'),
  queued('queued'),
  extracting('extracting'),
  parsing('parsing'),
  needsReview('needs_review'),
  done('done'),
  failed('failed');

  const SourceFileStatus(this.wire);

  final String wire;

  static SourceFileStatus fromWire(String value) =>
      values.firstWhere((s) => s.wire == value);
}

enum SourceFileType {
  pdf('pdf', 'application/pdf'),
  docx(
    'docx',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  );

  const SourceFileType(this.wire, this.mimeType);

  final String wire;
  final String mimeType;

  static SourceFileType fromWire(String value) =>
      values.firstWhere((t) => t.wire == value);

  /// The type for a file name's extension, or null when not accepted.
  static SourceFileType? forFileName(String name) {
    final lower = name.toLowerCase();
    for (final type in values) {
      if (lower.endsWith('.${type.wire}')) return type;
    }
    return null;
  }
}

/// Exams a previous-year paper can belong to. Codes match `exams.code`.
const pyqExamCodes = ['NEET_UG'];

/// Largest accepted file (matches the `source-files` bucket limit).
const maxSourceFileBytes = 100 * 1024 * 1024;

class SourceFile {
  const SourceFile({
    required this.id,
    required this.originalName,
    required this.fileType,
    required this.sizeBytes,
    required this.sha256,
    required this.rightsStatus,
    required this.rightsNote,
    required this.status,
    required this.createdAt,
    this.pyqExamCode,
    this.pyqYear,
    this.error,
    this.uploadedBy,
    this.queuedAt,
  });

  factory SourceFile.fromJson(Map<String, Object?> json) => SourceFile(
    id: json['id']! as String,
    originalName: json['original_name']! as String,
    fileType: SourceFileType.fromWire(json['file_type']! as String),
    sizeBytes: json['size_bytes']! as int,
    sha256: json['sha256']! as String,
    rightsStatus: RightsStatus.fromWire(json['rights_status']! as String),
    rightsNote: json['rights_note']! as String,
    pyqExamCode: json['pyq_exam_code'] as String?,
    pyqYear: json['pyq_year'] as int?,
    status: SourceFileStatus.fromWire(json['status']! as String),
    error: json['error'] as String?,
    uploadedBy: json['uploaded_by'] as String?,
    createdAt: DateTime.parse(json['created_at']! as String),
    queuedAt: switch (json['queued_at']) {
      final String value => DateTime.parse(value),
      _ => null,
    },
  );

  final String id;
  final String originalName;
  final SourceFileType fileType;
  final int sizeBytes;
  final String sha256;
  final RightsStatus rightsStatus;
  final String rightsNote;
  final String? pyqExamCode;
  final int? pyqYear;
  final SourceFileStatus status;
  final String? error;
  final String? uploadedBy;
  final DateTime createdAt;
  final DateTime? queuedAt;
}

/// The rights details chosen at upload (or when changing them later).
class RightsInput {
  const RightsInput({
    required this.status,
    required this.note,
    this.pyqExamCode,
    this.pyqYear,
  });

  final RightsStatus status;
  final String note;
  final String? pyqExamCode;
  final int? pyqYear;

  Map<String, Object?> toJson() => {
    'rights_status': status.wire,
    'rights_note': note.trim(),
    'pyq_exam_code': status == RightsStatus.officialPyq ? pyqExamCode : null,
    'pyq_year': status == RightsStatus.officialPyq ? pyqYear : null,
  };
}

class NewSourceFile {
  const NewSourceFile({
    required this.originalName,
    required this.fileType,
    required this.sizeBytes,
    required this.sha256,
    required this.rights,
  });

  final String originalName;
  final SourceFileType fileType;
  final int sizeBytes;
  final String sha256;
  final RightsInput rights;

  Map<String, Object?> toJson() => {
    'original_name': originalName,
    'file_type': fileType.wire,
    'size_bytes': sizeBytes,
    'sha256': sha256,
    ...rights.toJson(),
  };
}

/// A recorded file and the short-lived URL to upload its bytes to.
class CreatedSourceFile {
  const CreatedSourceFile({required this.file, required this.uploadUrl});

  final SourceFile file;
  final String uploadUrl;
}
