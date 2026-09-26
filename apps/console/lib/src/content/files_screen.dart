import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';
import '../auth/auth.dart';
import '../staff/staff.dart';
import 'content_providers.dart';
import 'content_text.dart';
import 'upload_dialog.dart';

class FilesScreen extends ConsumerWidget {
  const FilesScreen({super.key});

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final queued = await showUploadDialog(context);
    if (queued == null) return;
    ref.invalidate(sourceFilesProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.uploadDone(queued.originalName))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canUpload = ref.watch(staffMemberProvider).value?.canUpload ?? false;
    final filters = ref.watch(fileFiltersProvider);
    final files = ref.watch(sourceFilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.filesTitle),
        actions: const [RolesLabel(), SignOutButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<SourceFileStatus?>(
                  value: filters.status,
                  items: [
                    DropdownMenuItem(child: Text(l10n.filterAllStatuses)),
                    for (final status in SourceFileStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(status.label(l10n)),
                      ),
                  ],
                  onChanged: ref.read(fileFiltersProvider.notifier).setStatus,
                ),
                DropdownButton<RightsStatus?>(
                  value: filters.rights,
                  items: [
                    DropdownMenuItem(child: Text(l10n.filterAllRights)),
                    for (final rights in RightsStatus.values)
                      DropdownMenuItem(
                        value: rights,
                        child: Text(rights.label(l10n)),
                      ),
                  ],
                  onChanged: ref.read(fileFiltersProvider.notifier).setRights,
                ),
                TextButton.icon(
                  onPressed: () => ref.invalidate(sourceFilesProvider),
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.refresh),
                ),
                if (canUpload)
                  FilledButton.icon(
                    key: const Key('upload-button'),
                    onPressed: () => _upload(context, ref),
                    icon: const Icon(Icons.upload_file),
                    label: Text(l10n.uploadFile),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: switch (files) {
                AsyncData(:final value) when value.isEmpty => Center(
                  child: Text(
                    filters.status == null && filters.rights == null
                        ? l10n.filesEmpty
                        : l10n.filesNoneMatch,
                  ),
                ),
                AsyncData(:final value) => SingleChildScrollView(
                  child: _FilesTable(files: value),
                ),
                AsyncError() => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.filesLoadFailed),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => ref.invalidate(sourceFilesProvider),
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FilesTable extends StatelessWidget {
  const _FilesTable({required this.files});

  final List<SourceFile> files;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = DateFormat.yMMMd().add_Hm();
    return DataTable(
      columns: [
        DataColumn(label: Text(l10n.columnFile)),
        DataColumn(label: Text(l10n.columnRights)),
        DataColumn(label: Text(l10n.columnStatus)),
        DataColumn(label: Text(l10n.columnUploaded)),
      ],
      rows: [
        for (final file in files)
          DataRow(
            cells: [
              DataCell(
                Text.rich(
                  TextSpan(
                    text: file.originalName,
                    children: [
                      TextSpan(
                        text:
                            '  ${file.fileType.wire.toUpperCase()} · '
                            '${l10n.fileSize(megabytes(file.sizeBytes))}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              DataCell(
                Tooltip(
                  message: file.rightsNote,
                  child: Text(
                    [
                      file.rightsStatus.label(l10n),
                      if (file.pyqExamCode case final exam?)
                        l10n.pyqLabel(examLabel(exam, l10n), file.pyqYear ?? 0),
                    ].join(' · '),
                  ),
                ),
              ),
              DataCell(Text(file.status.label(l10n))),
              DataCell(Text(date.format(file.createdAt.toLocal()))),
            ],
          ),
      ],
    );
  }
}
