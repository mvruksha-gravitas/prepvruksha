import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/shared.dart';
import 'file_picker_service.dart';

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => ApiContentRepository(ref.watch(apiClientProvider)),
);

final filePickerProvider = Provider<FilePickerService>(
  (ref) => const PlatformFilePickerService(),
);

/// Filters of the file list; null means "all".
typedef FileFilters = ({SourceFileStatus? status, RightsStatus? rights});

class FileFiltersNotifier extends Notifier<FileFilters> {
  @override
  FileFilters build() => (status: null, rights: null);

  void setStatus(SourceFileStatus? status) =>
      state = (status: status, rights: state.rights);

  void setRights(RightsStatus? rights) =>
      state = (status: state.status, rights: rights);
}

final fileFiltersProvider = NotifierProvider<FileFiltersNotifier, FileFilters>(
  FileFiltersNotifier.new,
);

/// Newest first; reviewers never receive reference-only files (the API
/// and database filter them).
final sourceFilesProvider = FutureProvider<List<SourceFile>>((ref) {
  final filters = ref.watch(fileFiltersProvider);
  return ref
      .watch(contentRepositoryProvider)
      .listFiles(status: filters.status, rightsStatus: filters.rights);
}, retry: (_, _) => null);
