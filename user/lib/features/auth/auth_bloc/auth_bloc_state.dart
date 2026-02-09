import 'package:firebase_auth/firebase_auth.dart';

class AuthBlocState {
  final bool isLoading;
  final User? user;
  final Object? error;
  final int version;

  const AuthBlocState({
    this.version = 0,
    this.isLoading = false,
    this.user,
    this.error,
  });

  bool get isAuthenticated => user != null;
  bool get isUnauthenticated => user == null && !isLoading && error == null;

  AuthBlocState copy({
    bool? isLoading,
    User? user,
    Object? error,
    int? version,
  }) {
    return AuthBlocState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: error ?? this.error,
      version: version ?? this.version,
    );
  }

  AuthBlocState copyWithoutError({
    bool? isLoading,
    User? user,
    int? version,
  }) {
    return AuthBlocState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      error: null,
      version: version ?? this.version,
    );
  }

  AuthBlocState copyWithoutData({
    bool? isLoading,
    Object? error,
    int? version,
  }) {
    return AuthBlocState(
      isLoading: isLoading ?? this.isLoading,
      user: null,
      error: error ?? this.error,
      version: version ?? this.version,
    );
  }

  T when<T>({
    required T Function() onLoading,
    required T Function() onUnauthenticated,
    required T Function(User user) onAuthenticated,
    required T Function(Object error) onError,
  }) {
    if (error != null) {
      return onError(error!);
    }
    if (isLoading) {
      return onLoading();
    }
    if (user != null) {
      return onAuthenticated(user!);
    }
    return onUnauthenticated();
  }
}
