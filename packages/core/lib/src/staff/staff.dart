import '../api/api_client.dart';

/// Content-team roles (`staff_roles`). `superAdmin` satisfies every role.
enum StaffRole {
  reviewer('reviewer'),
  contentAdmin('content_admin'),
  superAdmin('super_admin');

  const StaffRole(this.wire);

  final String wire;

  static StaffRole? fromWire(String value) {
    for (final role in values) {
      if (role.wire == value) return role;
    }
    return null;
  }
}

/// The signed-in user's staff roles; empty for non-staff.
class StaffMember {
  const StaffMember({required this.userId, required this.roles});

  factory StaffMember.fromJson(Map<String, Object?> json) => StaffMember(
    userId: json['user_id']! as String,
    roles: {
      for (final value in json['roles']! as List<Object?>)
        ?StaffRole.fromWire(value! as String),
    },
  );

  final String userId;
  final Set<StaffRole> roles;

  bool get isStaff => roles.isNotEmpty;

  bool has(StaffRole role) =>
      roles.contains(role) || roles.contains(StaffRole.superAdmin);

  /// Content admins and super admins upload files and change rights.
  bool get canUpload => has(StaffRole.contentAdmin);
}

abstract interface class StaffRepository {
  /// Throws `ApiFailure` on error.
  Future<StaffMember> fetchMe();
}

/// [StaffRepository] over `GET /staff/me`.
class ApiStaffRepository implements StaffRepository {
  ApiStaffRepository(this._api);

  final ApiClient _api;

  @override
  Future<StaffMember> fetchMe() async => StaffMember.fromJson(
    (await _api.send('GET', '/staff/me'))! as Map<String, Object?>,
  );
}
