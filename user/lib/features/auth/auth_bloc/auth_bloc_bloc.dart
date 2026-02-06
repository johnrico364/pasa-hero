import 'package:bloc/bloc.dart';
import 'auth_bloc_event.dart';
import 'auth_bloc_state.dart';
import 'auth_bloc_provider.dart';
import 'auth_bloc_view_model.dart';

class AuthBlocBloc extends Bloc<AuthBlocEvent, AuthBlocState> {
  AuthBlocBloc({
    required this.provider,
    AuthBlocState? initialState,
  }) : super(initialState ?? const AuthBlocState()) {
    on<LoadAuthBlocEvent>(_onLoadAuthBlocEvent);
    on<AddAuthBlocEvent>(_onAddAuthBlocEvent);
    on<ClearAuthBlocEvent>(_onClearAuthBlocEvent);
    on<ErrorYouAwesomeEvent>(_onErrorYouAwesomeEvent);
  }

  /// Use this for all requests to backend -  you can mock it in tests
  final AuthBlocProvider provider;

  Future<void> _onLoadAuthBlocEvent(
    LoadAuthBlocEvent event,
    Emitter<AuthBlocState> emit,
  ) async {
    emit(state.copyWithoutError(isLoading: true));
    try {
      final result = await provider.fetchAsync(event.id);
      emit(state.copyWithoutError(
        isLoading: false,
        data: AuthBlocViewModel(items: result),
      ));
    } catch (error) {
      emit(state.copy(error: error, isLoading: false));
    }
  }

  Future<void> _onAddAuthBlocEvent(
    AddAuthBlocEvent event,
    Emitter<AuthBlocState> emit,
  ) async {
    emit(state.copyWithoutError(isLoading: true));
    try {
      final result = await provider.addMore(state.data?.items);
      emit(state.copyWithoutError(
        isLoading: false,
        data: AuthBlocViewModel(items: result),
      ));
    } catch (error) {
      emit(state.copy(error: error, isLoading: false));
    }
  }

  Future<void> _onClearAuthBlocEvent(
    ClearAuthBlocEvent event,
    Emitter<AuthBlocState> emit,
  ) async {
    emit(state.copyWithoutError(isLoading: true));
    emit(state.copyWithoutData(isLoading: false));
  }

  Future<void> _onErrorYouAwesomeEvent(
    ErrorYouAwesomeEvent event,
    Emitter<AuthBlocState> emit,
  ) async {
    throw Exception('Test error');
  }
}
