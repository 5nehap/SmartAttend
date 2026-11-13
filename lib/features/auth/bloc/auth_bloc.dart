import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../data/models/employee_model.dart';
import '../../../data/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const AuthInitial()) {
    on<AuthSessionCheckRequested>(_onSessionCheck);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onSessionCheck(
    AuthSessionCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final employee = await _authRepository.restoreSession();
      if (employee != null) {
        emit(AuthAuthenticated(employee: employee));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (_) {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Client-side validation before hitting repository.
    final emailTrimmed = event.email.trim();
    final password = event.password.trim();

    if (emailTrimmed.isEmpty) {
      emit(const AuthError(message: 'Email address is required.'));
      return;
    }
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(emailTrimmed)) {
      emit(const AuthError(message: 'Please enter a valid email address.'));
      return;
    }
    if (password.isEmpty) {
      emit(const AuthError(message: 'Password is required.'));
      return;
    }
    if (password.length < 6) {
      emit(const AuthError(message: 'Password must be at least 6 characters.'));
      return;
    }

    emit(const AuthLoading());
    try {
      final employee = await _authRepository.login(
        email: emailTrimmed,
        password: password,
      );

      if (employee != null) {
        emit(AuthAuthenticated(employee: employee));
      } else {
        emit(const AuthError(
            message: 'Invalid credentials. Please check your email and password.'));
      }
    } catch (e) {
      emit(AuthError(message: 'Login failed: ${e.toString()}'));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _authRepository.logout();
    } catch (_) {
      // Always clear local state even if repo throws.
    } finally {
      emit(const AuthUnauthenticated());
    }
  }
}
