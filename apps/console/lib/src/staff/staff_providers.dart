import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import '../shared/shared.dart';

final staffRepositoryProvider = Provider<StaffRepository>(
  (ref) => ApiStaffRepository(ref.watch(apiClientProvider)),
);

/// The signed-in user's staff roles (null when signed out). Reloaded on
/// every sign-in. No automatic retry: a failure shows the error screen,
/// whose Retry button invalidates this provider.
final staffMemberProvider = FutureProvider<StaffMember?>((ref) async {
  final userId = ref.watch(currentUserProvider.select((user) => user?.id));
  if (userId == null) return null;
  return ref.watch(staffRepositoryProvider).fetchMe();
}, retry: (_, _) => null);
