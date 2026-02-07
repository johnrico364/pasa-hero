import 'package:bloc/bloc.dart';
import 'auth_bloc_event.dart';
import 'auth_bloc_state.dart';
import 'auth_bloc_provider.dart';

class AuthBlocBloc extends Bloc<AuthBlocEvent, AuthBlocState> {
  AuthBlocBloc({
    required this.provider,
    AuthBlocState? initialState,
  }) : super(initialState ?? const AuthBlocState()) {
    on<LoginEvent>(_onLoginEvent);
    on<RegisterEvent>(_onRegisterEvent);
    on<GoogleSignInEvent>(_onGoogleSignInEvent);
    on<GoogleSignUpEvent>(_onGoogleSignUpEvent);
    on<LogoutEvent>(_onLogoutEvent);
    on<CheckAuthStateEvent>(_onCheckAuthStateEvent);
  }

  final AuthBlocProvider provider;

  Future<void> _onLoginEvent(
    LoginEvent event,
    Emitter<AuthBlocState> emit,
  ) async {
    emit(state.copyWithoutError(isLoading: true));
    try {
      final credential = await provider.authService.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );
      emit(state.copyWithoutError(
        isLoading: false,
        user: credential.user,
      ));
    } catch (error) {
      emit(state.copy(error: error, isLoading: false));
    }
  }

  Future<void> _onRegisterEvent(
    RegisterEvent event,
    Emitter<AuthBlocState> emit,
  ) async {
    emit(state.copyWithoutError(isLoading: true));
    try {
      final credential = await provider.authService.registerWithEmailAndPassword(
        email: event.email,
        password: event.password,
        firstName: event.firstName,
        lastName: event.lastName,
      );
      emit(state.copyWithoutError(
        isLoading: false,
        user: credential.user,
      ));
    } catch (error) {
      emit(state.copy(error: error, isLoading: false));
    }
  }

  Future<void> _onGoogleSignInEvent(
    GoogleSignInEvent event,
    Emitter<AuthBlocState> emit,
  ) async {
    emit(state.copyWithoutError(isLoading: true));
    try {
      final credential = await provider.authService.signInWithGoogle();
      emit(state.copyWithoutError(
        isLoading: false,
        user: credential.user,
      ));
    } catch (error) {
      emit(state.copy(error: error, isLoading: false));
    }
  }

  Future<void> _onGoogleSignUpEvent(
    GoogleSignUpEvent event,
    Emitter<AuthBlocState> emit,
  ) async {
    emit(state.copyWithoutError(isLoading: true));
    try {
      final credential = await provider.authService.signUpWithGoogle();
      emit(state.copyWithoutError(
        isLoading: false,
        user: credential.user,
      ));
    } catch (error) {
      emit(state.copy(error: error, isLoading: false));
    }
  }

  Future<void> _onLogoutEvent(
    LogoutEvent event,
    Emitter<AuthBlocState> emit,
  ) async {
    emit(state.copyWithoutError(isLoading: true));
    try {
      await provider.authService.signOut();
      emit(state.copyWithoutData(isLoading: false));
    } catch (error) {
      emit(state.copy(error: error, isLoading: false));
    }
  }

  Future<void> _onCheckAuthStateEvent(
    CheckAuthStateEvent event,
    Emitter<AuthBlocState> emit,
  ) async {
    final user = provider.authService.currentUser;
    emit(state.copyWithoutError(user: user));
  }
}
