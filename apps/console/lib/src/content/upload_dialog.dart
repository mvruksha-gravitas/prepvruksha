import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import 'content_providers.dart';
import 'content_text.dart';
import 'file_picker_service.dart';

/// Opens the upload dialog. Returns the queued file, or null if cancelled.
Future<SourceFile?> showUploadDialog(BuildContext context) =>
    showDialog<SourceFile>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const UploadDialog(),
    );

enum _Step { hashing, recording, uploading, confirming }

/// Choose a file, its rights status (no default) and rights note; for an
/// official previous-year paper also the exam and year. Then: hash in the
/// browser → record the file → upload straight to Storage → confirm.
class UploadDialog extends ConsumerStatefulWidget {
  const UploadDialog({super.key});

  @override
  ConsumerState<UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends ConsumerState<UploadDialog> {
  final _note = TextEditingController();
  final _year = TextEditingController();

  PickedFile? _file;
  SourceFileType? _fileType;
  String? _fileError;
  RightsStatus? _rights;
  String _exam = pyqExamCodes.first;
  bool _showErrors = false;

  _Step? _step;
  double? _hashProgress;
  String? _error;

  bool get _busy => _step != null;

  @override
  void dispose() {
    _note.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final l10n = AppLocalizations.of(context);
    final file = await ref.read(filePickerProvider).pickSourceFile();
    if (file == null || !mounted) return;
    final type = SourceFileType.forFileName(file.name);
    setState(() {
      _file = file;
      _fileType = type;
      _error = null;
      _fileError = type == null
          ? l10n.fileTypeNotAccepted
          : (file.size ?? 0) > maxSourceFileBytes
          ? l10n.fileTooLarge
          : null;
    });
  }

  int get _maxYear => DateTime.now().year;

  int? get _parsedYear {
    final year = int.tryParse(_year.text.trim());
    return year != null && year >= 1980 && year <= _maxYear ? year : null;
  }

  bool get _valid =>
      _file != null &&
      _fileError == null &&
      _rights != null &&
      _note.text.trim().isNotEmpty &&
      (_rights != RightsStatus.officialPyq || _parsedYear != null);

  Future<void> _submit() async {
    setState(() => _showErrors = true);
    if (!_valid) return;
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(contentRepositoryProvider);
    final file = _file!;
    final type = _fileType!;
    final rights = RightsInput(
      status: _rights!,
      note: _note.text,
      pyqExamCode: _exam,
      pyqYear: _parsedYear,
    );

    setState(() {
      _step = _Step.hashing;
      _hashProgress = 0;
      _error = null;
    });
    try {
      final bytes = await file.readBytes();
      if (bytes.length > maxSourceFileBytes) {
        setState(() {
          _fileError = l10n.fileTooLarge;
          _step = null;
        });
        return;
      }
      final hash = await sha256Hex(
        bytes,
        onProgress: (p) {
          if (mounted) setState(() => _hashProgress = p);
        },
      );

      setState(() => _step = _Step.recording);
      final created = await repo.createFile(
        NewSourceFile(
          originalName: file.name,
          fileType: type,
          sizeBytes: bytes.length,
          sha256: hash,
          rights: rights,
        ),
      );

      setState(() => _step = _Step.uploading);
      await repo.upload(created.uploadUrl, bytes, type);

      setState(() => _step = _Step.confirming);
      final queued = await repo.completeUpload(created.file.id);
      if (mounted) Navigator.of(context).pop(queued);
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          _error = e.localized(l10n);
          _step = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final file = _file;
    return AlertDialog(
      title: Text(l10n.uploadTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                key: const Key('choose-file'),
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.attach_file),
                label: Text(
                  file == null ? l10n.chooseFile : l10n.chooseAnotherFile,
                ),
              ),
              if (file != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(file.name),
                  subtitle: Text(
                    _fileError ?? l10n.fileSize(megabytes(file.size ?? 0)),
                    style: _fileError == null
                        ? null
                        : TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                l10n.rightsStatusLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              RadioGroup<RightsStatus>(
                groupValue: _rights,
                onChanged: (value) {
                  if (!_busy) setState(() => _rights = value);
                },
                child: Column(
                  children: [
                    for (final status in RightsStatus.values)
                      RadioListTile<RightsStatus>(
                        key: Key('rights-${status.wire}'),
                        value: status,
                        contentPadding: EdgeInsets.zero,
                        title: Text(status.label(l10n)),
                        subtitle: Text(status.help(l10n)),
                      ),
                  ],
                ),
              ),
              if (_showErrors && _rights == null)
                Text(
                  l10n.rightsStatusRequired,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_rights == RightsStatus.officialPyq) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _exam,
                        decoration: InputDecoration(
                          labelText: l10n.pyqExamLabel,
                        ),
                        items: [
                          for (final code in pyqExamCodes)
                            DropdownMenuItem(
                              value: code,
                              child: Text(examLabel(code, l10n)),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _exam = value!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        key: const Key('pyq-year'),
                        controller: _year,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: InputDecoration(
                          labelText: l10n.pyqYearLabel,
                          errorText: _showErrors && _parsedYear == null
                              ? l10n.pyqYearInvalid(_maxYear)
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                key: const Key('rights-note'),
                controller: _note,
                enabled: !_busy,
                maxLines: 3,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText: l10n.rightsNoteLabel,
                  hintText: l10n.rightsNoteHint,
                  errorText: _showErrors && _note.text.trim().isEmpty
                      ? l10n.rightsNoteRequired
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_step case final step?) ...[
                const SizedBox(height: 8),
                Text(switch (step) {
                  _Step.hashing => l10n.stepHashing,
                  _Step.recording => l10n.stepRecording,
                  _Step.uploading => l10n.stepUploading,
                  _Step.confirming => l10n.stepConfirming,
                }),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: step == _Step.hashing ? _hashProgress : null,
                ),
              ],
              if (_error case final error?) ...[
                const SizedBox(height: 8),
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('upload-submit'),
          onPressed: _busy ? null : _submit,
          child: Text(l10n.upload),
        ),
      ],
    );
  }
}
