import 'dart:async';

import 'package:core/core.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.validCode = '123456'});

  final String validCode;
  final _changes = StreamController<AuthUser?>.broadcast();
  final sentTo = <PhoneNumber>[];
  AuthFailure? nextSendFailure;
  AuthUser? _user;

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  @override
  Future<void> sendOtp(PhoneNumber phone) async {
    final failure = nextSendFailure;
    if (failure != null) {
      nextSendFailure = null;
      throw failure;
    }
    sentTo.add(phone);
  }

  @override
  Future<void> verifyOtp(PhoneNumber phone, String code) async {
    if (code != validCode) {
      throw const AuthFailure(AuthFailureCode.invalidCode);
    }
    _set(AuthUser(id: 'user-1', phone: phone.e164.substring(1)));
  }

  @override
  Future<void> signOut() async => _set(null);

  void _set(AuthUser? user) {
    _user = user;
    _changes.add(user);
  }
}

class FakeProfileRepository implements ProfileRepository {
  Profile? profile;

  final savedLanguages = <String>[];

  @override
  Future<Profile?> fetchOwn() async => profile;

  @override
  Future<void> updatePreferredLanguage(String languageCode) async =>
      savedLanguages.add(languageCode);

  /// What the database rule returns; set [targetExamYearsError] to make it fail.
  List<int> targetExamYears = [2027, 2028, 2029];
  Object? targetExamYearsError;

  @override
  Future<List<int>> fetchTargetExamYears({String examCode = 'NEET_UG'}) async {
    if (targetExamYearsError case final error?) throw error;
    return targetExamYears;
  }
}

/// In-memory stand-in for the API's signup rules.
class FakeSignupRepository implements SignupRepository {
  FakeSignupRepository({this.status = SignupStatus.complete, this.isMinor});

  SignupStatus status;
  bool? isMinor;
  PendingParentRequest? pending;
  String validParentCode = '123456';
  String studentPhone = '9999900001';
  Duration resendDelay = const Duration(seconds: 60);
  SignupFailure? nextFailure;
  ProfileInput? savedProfile;
  final parentCodesSentTo = <String>[];
  final withdrawn = <ConsentType>[];
  int _attemptsLeft = 5;

  SignupState get _state => SignupState(
    status: status,
    isMinor: isMinor,
    termsVersion: '2026-10-draft',
    parentalVersion: '2026-10-draft',
    pendingRequest: pending,
  );

  void _maybeFail() {
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
  }

  @override
  Future<SignupState> fetchState() async {
    _maybeFail();
    return _state;
  }

  @override
  Future<SignupState> completeProfile(ProfileInput input) async {
    _maybeFail();
    savedProfile = input;
    final now = DateTime.now();
    var age = now.year - input.dateOfBirth.year;
    if (DateTime(
      now.year,
      input.dateOfBirth.month,
      input.dateOfBirth.day,
    ).isAfter(now)) {
      age--;
    }
    isMinor = age < 18;
    status = SignupStatus.needsTerms;
    return _state;
  }

  @override
  Future<SignupState> acceptTerms(String policyVersion) async {
    _maybeFail();
    status = isMinor ?? false
        ? SignupStatus.needsParental
        : SignupStatus.complete;
    return _state;
  }

  @override
  Future<SignupState> startParentalConsent({
    required String parentName,
    required String parentPhone,
  }) async {
    _maybeFail();
    if (parentPhone.endsWith(studentPhone)) {
      throw const SignupFailure('parent_phone_is_student_phone');
    }
    parentCodesSentTo.add(parentPhone);
    _attemptsLeft = 5;
    pending = PendingParentRequest(
      parentName: parentName.trim(),
      parentPhoneLast4: parentPhone.substring(parentPhone.length - 4),
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      attemptsLeft: _attemptsLeft,
      resendAvailableAt: DateTime.now().add(resendDelay),
    );
    return _state;
  }

  @override
  Future<ParentCodeOutcome> verifyParentCode(String code) async {
    _maybeFail();
    final request = pending;
    if (request == null) {
      return ParentCodeOutcome(
        result: ParentCodeResult.noPendingRequest,
        state: _state,
      );
    }
    if (code == validParentCode) {
      pending = null;
      status = SignupStatus.complete;
      return ParentCodeOutcome(
        result: ParentCodeResult.verified,
        state: _state,
      );
    }
    _attemptsLeft--;
    if (_attemptsLeft == 0) {
      pending = null;
      return ParentCodeOutcome(result: ParentCodeResult.locked, state: _state);
    }
    return ParentCodeOutcome(
      result: ParentCodeResult.invalid,
      attemptsLeft: _attemptsLeft,
      state: _state,
    );
  }

  @override
  Future<SignupState> withdrawConsent(ConsentType type) async {
    _maybeFail();
    withdrawn.add(type);
    status = type == ConsentType.terms
        ? SignupStatus.needsTerms
        : SignupStatus.needsParental;
    return _state;
  }
}
