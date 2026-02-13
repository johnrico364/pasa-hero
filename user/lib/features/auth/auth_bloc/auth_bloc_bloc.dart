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
    on<SendOTPEvent>(_onSendOTPEvent);
    on<VerifyOTPAndRegisterEvent>(_onVerifyOTPAndRegisterEvent);
    on<VerifyOTPAndLoginEvent>(_onVerifyOTPAndLoginEvent);
    on<SendEmailVerificationEvent>(_onSendEmailVerificationEvent);
    on<CheckEmailVerificationEvent>(_onCheckEmailVerificationEvent);
    on<VerifyOTPAndGoogleSignUpEvent>(_onVerifyOTPAndGoogleSignUpEvent);
  }

  final AuthBlocProvider provider;
  
  // Temporary storage for Google sign-up info (used before OTP verification)
  String? _pendingGoogleEmail;
  String? _pendingGoogleDisplayName;
  
  String? get pendingGoogleEmail => _pendingGoogleEmail;
  String? get pendingGoogleDisplayName => _pendingGoogleDisplayName;
  
  void resetPendingGoogleInfo() {
    _pendingGoogleEmail = null;
    _pendingGoogleDisplayName = null;
  }

  Future<void> _onLoginEvent(
    LoginEvent event,
    Emitter<AuthBlocState> emit,
  ) async {
    emit(state.copyWithoutError(isLoading: true));
    try {
      // First verify user exists in database
      final userExists = await provider.authService.userExists(event.email);
      if (!userExists) {
        throw Exception('No account found for that email.');
      }
      
      // Verify credentials by attempting sign in (but sign out immediately)
      try {
        await provider.authService.signInWithEmailAndPassword(
          email: event.email,
          password: event.password,
        );
        // Sign out immediately - we'll sign in after OTP verification
        await provider.authService.signOut();
      } catch (e) {
        // If sign in fails, wrong password
        rethrow;
      }
      
      // Send OTP if credentials are valid
      await provider.authService.sendOTP(email: event.email);
      emit(state.copyWithoutError(isLoading: false));
      // Note: Login will be completed in VerifyOTPAndLoginEvent
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
      // Send OTP instead of directly registering
      await provider.authService.sendOTP(email: event.email);
      emit(state.copyWithoutError(isLoading: false));
      // Note: Registration will be completed in VerifyOTPAndRegisterEvent
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
      // Get Google user email without authenticating
      final googleUserInfo = await provider.authService.getGoogleUserEmail();
      final email = googleUserInfo['email'] ?? '';
      final displayName = googleUserInfo['displayName'] ?? '';
      
      if (email.isEmpty) {
        throw Exception('Failed to get email from Google account.');
      }
      
      // Store Google user info temporarily
      _pendingGoogleEmail = email;
      _pendingGoogleDisplayName = displayName;
      
      // Send OTP to the email
      try {
        await provider.authService.sendOTP(email: email);
      } catch (otpError) {
        _pendingGoogleEmail = null;
        _pendingGoogleDisplayName = null;
        throw Exception('Failed to send OTP: $otpError');
      }
      
      emit(state.copyWithoutError(
        isLoading: false,
      ));
    } catch (error) {
      _pendingGoogleEmail = null;
      _pendingGoogleDisplayName = null;
      emit(state.copy(error: error, isLoading: false));
    }
  }

  Future<void> _onVerifyOTPAndGoogleSignUpEvent(
    VerifyOTPAndGoogleSignUpEvent event,
    Emitter<AuthBlocState> emit,
  ) async {
    emit(state.copyWithoutError(isLoading: true));
    try {
      // First verify OTP
      await provider.authService.verifyOTP(
        email: event.email,
        otpCode: event.otpCode,
      );
      
      // If OTP is verified, complete Google sign-up
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

  Future<void> _onSendOTPEvent(
    SendOTPEvent event,
    Emitter<AuthBlocState> emit,
  ) async {
    emit(state.copyWithoutError(isLoading: true));
    try {
      await provider.authService.sendOTP(email: event.email);
      emit(state.copyWithoutError(isLoading: false));
    } catch (error) {
      emit(state.copy(error: error, isLoading: false));
    }
  }

  Future<void> _onVerifyOTPAndRegisterEvent(
    VerifyOTPAndRegisterEvent event,
    Emitter<AuthBlocState> emit,
  ) async {
    emit(state.copyWithoutError(isLoading: true));
    try {
      // First verify OTP
      await provider.authService.verifyOTP(
        email: event.email,
        otpCode: event.otpCode,
      );
      
      // If OTP is verified, create the account
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

  Future<void> _onVerifyOTPAndLoginEvent(
    VerifyOTPAndLoginEvent event,
    Emitter<AuthBlocState> emit,
  ) async {
    emit(state.copyWithoutError(isLoading: true));
    try {
      // First verify OTP
      await provider.authService.verifyOTP(
        email: event.email,
        otpCode: event.otpCode,
      );
      
      // If OTP is verified, proceed with login
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

  Future<void> _onSendEmailVerificationEvent(
    SendEmailVerificationEvent event,
    Emitter<AuthBlocState> emit,
  ) async {
    emit(state.copyWithoutError(isLoading: true));
    try {
      await provider.authService.sendEmailVerification();
      emit(state.copyWithoutError(isLoading: false));
    } catch (error) {
      emit(state.copy(error: error, isLoading: false));
    }
  }

  Future<void> _onCheckEmailVerificationEvent(
    CheckEmailVerificationEvent event,
    Emitter<AuthBlocState> emit,
  ) async {
    emit(state.copyWithoutError(isLoading: true));
    try {
      // Reload user to get latest verification status
      await provider.authService.reloadUser();
      final user = provider.authService.currentUser;
      emit(state.copyWithoutError(
        isLoading: false,
        user: user,
      ));
    } catch (error) {
      emit(state.copy(error: error, isLoading: false));
    }
  }
}
