import 'package:meta/meta.dart';

/// Where a signed-in user is in signup. Decided by the API from the database
/// at the time of asking (for example, parental consent stops being needed
/// on the 18th birthday).
enum SignupStatus {
  needsProfile('needs_profile'),
  needsTerms('needs_terms'),
  needsParental('needs_parental'),
  complete('complete');

  const SignupStatus(this.wire);

  final String wire;

  static SignupStatus fromWire(String value) => values.firstWhere(
    (s) => s.wire == value,
    orElse: () => throw FormatException('unknown signup status: $value'),
  );
}

/// A code sent to a parent that is waiting to be entered.
@immutable
class PendingParentRequest {
  const PendingParentRequest({
    required this.parentName,
    required this.parentPhoneLast4,
    required this.expiresAt,
    required this.attemptsLeft,
    required this.resendAvailableAt,
  });

  factory PendingParentRequest.fromJson(Map<String, Object?> json) =>
      PendingParentRequest(
        parentName: json['parent_name']! as String,
        parentPhoneLast4: json['parent_phone_last4']! as String,
        expiresAt: DateTime.parse(json['expires_at']! as String),
        attemptsLeft: json['attempts_left']! as int,
        resendAvailableAt: DateTime.parse(
          json['resend_available_at']! as String,
        ),
      );

  final String parentName;
  final String parentPhoneLast4;
  final DateTime expiresAt;
  final int attemptsLeft;
  final DateTime resendAvailableAt;
}

@immutable
class SignupState {
  const SignupState({
    required this.status,
    this.isMinor,
    this.termsVersion,
    this.parentalVersion,
    this.pendingRequest,
  });

  factory SignupState.fromJson(Map<String, Object?> json) => SignupState(
    status: SignupStatus.fromWire(json['status']! as String),
    isMinor: json['is_minor'] as bool?,
    termsVersion: json['terms_version'] as String?,
    parentalVersion: json['parental_version'] as String?,
    pendingRequest: switch (json['pending_request']) {
      final Map<String, Object?> m => PendingParentRequest.fromJson(m),
      _ => null,
    },
  );

  final SignupStatus status;

  /// Null until the date of birth is known.
  final bool? isMinor;

  /// Current terms/privacy version the student must accept.
  final String? termsVersion;
  final String? parentalVersion;
  final PendingParentRequest? pendingRequest;
}

enum ParentCodeResult {
  verified,
  invalid,
  locked,
  expired,
  noPendingRequest,
  notRequired;

  static ParentCodeResult fromWire(String value) => switch (value) {
    'verified' => verified,
    'invalid' => invalid,
    'locked' => locked,
    'expired' => expired,
    'no_pending_request' => noPendingRequest,
    'not_required' => notRequired,
    _ => throw FormatException('unknown code result: $value'),
  };
}

@immutable
class ParentCodeOutcome {
  const ParentCodeOutcome({
    required this.result,
    required this.state,
    this.attemptsLeft,
  });

  final ParentCodeResult result;
  final int? attemptsLeft;
  final SignupState state;
}

/// Details collected on the profile step.
@immutable
class ProfileInput {
  const ProfileInput({
    required this.fullName,
    required this.dateOfBirth,
    required this.targetExamYear,
    this.category,
    this.preferredLanguage,
  });

  final String fullName;
  final DateTime dateOfBirth;
  final int targetExamYear;

  /// `general`, `ews`, `obc_ncl`, `sc`, `st`, or null (optional).
  final String? category;

  /// `en` or `kn`.
  final String? preferredLanguage;

  Map<String, Object?> toJson() => {
    'full_name': fullName.trim(),
    'date_of_birth':
        '${dateOfBirth.year.toString().padLeft(4, '0')}-'
        '${dateOfBirth.month.toString().padLeft(2, '0')}-'
        '${dateOfBirth.day.toString().padLeft(2, '0')}',
    'target_exam_year': targetExamYear,
    'category': category,
    'preferred_language': preferredLanguage,
  };
}

enum ConsentType { terms, parental }
