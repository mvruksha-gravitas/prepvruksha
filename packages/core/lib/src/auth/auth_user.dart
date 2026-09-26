import 'package:meta/meta.dart';

/// The signed-in user, as far as authentication is concerned.
/// Profile details live in `Profile`.
@immutable
class AuthUser {
  const AuthUser({required this.id, this.phone});

  final String id;
  final String? phone;

  @override
  bool operator ==(Object other) =>
      other is AuthUser && other.id == id && other.phone == phone;

  @override
  int get hashCode => Object.hash(id, phone);
}
