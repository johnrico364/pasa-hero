import 'auth_bloc_view_model.dart';

class AuthBlocState {
  final bool isLoading;
  final AuthBlocViewModel? data;
  final Object? error;
  final int version;

  const AuthBlocState({
    this.version = 0,
    this.isLoading = false,
    this.data,
    this.error,
  });

  bool get hasData => data != null && data!.items != null && data!.items!.isNotEmpty;

  AuthBlocState copy({
    bool? isLoading,
    AuthBlocViewModel? data,
    Object? error,
    int? version,
  }) {
    return AuthBlocState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error ?? this.error,
      version: version ?? this.version,
    );
  }

  AuthBlocState copyWithoutError({
    bool? isLoading,
    AuthBlocViewModel? data,
    int? version,
  }) {
    return AuthBlocState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
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
      data: null,
      error: error ?? this.error,
      version: version ?? this.version,
    );
  }

  T when<T>({
    required T Function() onLoading,
    required T Function(AuthBlocViewModel? data) onEmpty,
    required T Function(AuthBlocViewModel data) onData,
    required T Function(Object error) onError,
  }) {
    if (error != null) {
      return onError(error!);
    }
    if (isLoading) {
      return onLoading();
    }
    if (data == null || data!.items == null || data!.items!.isEmpty) {
      return onEmpty(data);
    }
    return onData(data!);
  }
}
