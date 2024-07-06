import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import 'auth_service.dart';

class AuthenticationBloc
    extends Bloc<AuthenticationEvent, AuthenticationState> {
  final AuthService _authService = AuthService();

  AuthenticationBloc() : super(AuthenticationInitial()) {
    on<AppStarted>(_onAppStarted);
    on<LoggedIn>(_onLoggedIn);
    on<LoggedOut>(_onLoggedOut);
  }

  Future<void> _onAppStarted(
      AppStarted event, Emitter<AuthenticationState> emit) async {
    final currentUser = await _authService.user.first;
    if (currentUser != null) {
      emit(Authenticated(user: currentUser));
    } else {
      emit(Unauthenticated());
    }
  }

  Future<void> _onLoggedIn(
      LoggedIn event, Emitter<AuthenticationState> emit) async {
    final currentUser = await _authService.user.first;
    if (currentUser != null) {
      emit(Authenticated(user: currentUser));
    } else {
      emit(Unauthenticated());
    }
  }

  Future<void> _onLoggedOut(
      LoggedOut event, Emitter<AuthenticationState> emit) async {
    await _authService.signOut();
    emit(Unauthenticated());
  }
}
