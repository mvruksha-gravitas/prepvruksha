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

  @override
  Future<Profile?> fetchOwn() async => profile;
}
