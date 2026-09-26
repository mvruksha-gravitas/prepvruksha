import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'supabase_auth_repository.dart';

/// Ways staff can sign in. Production staff will need a stronger method
/// (e.g. Google with 2-step verification, a launch blocker); adding one here
/// adds it to the sign-in screen.
enum SignInMethod { phone }

final signInMethodsProvider = Provider<List<SignInMethod>>(
  (ref) => SignInMethod.values,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(Supabase.instance.client.auth),
);

final authStateProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// The signed-in user; changes only on sign-in and sign-out.
final currentUserProvider = Provider<AuthUser?>(
  (ref) => ref.watch(authStateProvider.select((user) => user.value)),
);
