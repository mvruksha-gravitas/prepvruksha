import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth.dart';
import '../consent/consent.dart';
import '../home/home.dart';
import '../profile/profile.dart';
import '../shared/shared.dart';

/// Where a signed-in user must be, or null when signup is complete.
@visibleForTesting
String? signupRoute(AsyncValue<SignupState?> signup) {
  final state = signup.value;
  if (state == null) return Routes.gate;
  return switch (state.status) {
    SignupStatus.needsProfile => Routes.profile,
    SignupStatus.needsTerms => Routes.terms,
    SignupStatus.needsParental => Routes.parent,
    SignupStatus.complete => null,
  };
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = _RouterRefresh(auth.authStateChanges());
  ref.listen(signupStateProvider, (_, _) => refresh.notify());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final onLogin = location.startsWith(Routes.login);
      if (auth.currentUser == null) return onLogin ? null : Routes.login;
      if (location == Routes.policy) return null;

      // Signed in: incomplete signup or missing consent → the matching step.
      final required = signupRoute(ref.read(signupStateProvider));
      if (required != null) return location == required ? null : required;
      final inSignup =
          onLogin || location == Routes.gate || location.startsWith('/signup/');
      return inSignup ? Routes.home : null;
    },
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const PhoneScreen(),
      ),
      GoRoute(
        path: Routes.otp,
        redirect: (context, state) =>
            state.extra is PhoneNumber ? null : Routes.login,
        builder: (context, state) =>
            OtpScreen(phone: state.extra! as PhoneNumber),
      ),
      GoRoute(
        path: Routes.gate,
        builder: (context, state) => const SignupGateScreen(),
      ),
      GoRoute(
        path: Routes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: Routes.terms,
        builder: (context, state) => const TermsScreen(),
      ),
      GoRoute(
        path: Routes.parent,
        builder: (context, state) => const ParentConsentScreen(),
      ),
      GoRoute(
        path: Routes.policy,
        builder: (context, state) => const PolicyScreen(),
      ),
    ],
  );
});

/// Re-runs redirects on every auth event and signup state change.
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
