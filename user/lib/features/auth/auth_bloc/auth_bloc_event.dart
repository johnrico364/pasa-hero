import 'package:flutter/widgets.dart';

@immutable
abstract class AuthBlocEvent {}

/// Login with email and password
class LoginEvent extends AuthBlocEvent {
  final String email;
  final String password;

  LoginEvent({
    required this.email,
    required this.password,
  });

  @override
  String toString() => 'LoginEvent';
}

/// Register with email and password
class RegisterEvent extends AuthBlocEvent {
  final String email;
  final String password;
  final String firstName;
  final String lastName;

  RegisterEvent({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
  });

  @override
  String toString() => 'RegisterEvent';
}

/// Sign in with Google (for login)
class GoogleSignInEvent extends AuthBlocEvent {
  @override
  String toString() => 'GoogleSignInEvent';
}

/// Sign up with Google (for registration)
class GoogleSignUpEvent extends AuthBlocEvent {
  @override
  String toString() => 'GoogleSignUpEvent';
}

/// Sign out
class LogoutEvent extends AuthBlocEvent {
  @override
  String toString() => 'LogoutEvent';
}

/// Check authentication state
class CheckAuthStateEvent extends AuthBlocEvent {
  @override
  String toString() => 'CheckAuthStateEvent';
}
