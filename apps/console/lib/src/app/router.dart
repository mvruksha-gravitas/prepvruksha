import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth.dart';
import '../content/content.dart';
import '../shared/shared.dart';
import '../staff/staff.dart';

/// Where a signed-in user must be given their staff roles, or null when
/// they may go anywhere in the console.
@visibleForTesting
String? staffRoute(AsyncValue<StaffMember?> staff) {
  final member = staff.value;
  if (staff.isLoading || staff.hasError || member == null) {
    return Routes.checking;
  }
  return member.isStaff ? null : Routes.noAccess;
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = _RouterRefresh(auth.authStateChanges());
  ref.listen(staffMemberProvider, (_, _) => refresh.notify());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.files,
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final onSignIn = location.startsWith(Routes.signIn);
      if (auth.currentUser == null) return onSignIn ? null : Routes.signIn;

      final required = staffRoute(ref.read(staffMemberProvider));
      if (required != null) return location == required ? null : required;
      final outside =
          onSignIn ||
          location == Routes.checking ||
          location == Routes.noAccess;
      return outside ? Routes.files : null;
    },
    routes: [
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: Routes.otp,
        redirect: (context, state) =>
            state.extra is PhoneNumber ? null : Routes.signIn,
        builder: (context, state) =>
            OtpScreen(phone: state.extra! as PhoneNumber),
      ),
      GoRoute(
        path: Routes.checking,
        builder: (context, state) => const CheckingAccessScreen(),
      ),
      GoRoute(
        path: Routes.noAccess,
        builder: (context, state) => const NoAccessScreen(),
      ),
      GoRoute(
        path: Routes.files,
        builder: (context, state) => const FilesScreen(),
      ),
    ],
  );
});

/// Re-runs redirects on every auth event and staff role change.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  void notify() => notifyListeners();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
