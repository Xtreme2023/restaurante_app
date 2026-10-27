import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurante_app/features/auth/data/supabase_auth_repository.dart';
import 'package:restaurante_app/features/auth/domain/login_attempt_policy.dart';
import 'package:restaurante_app/features/auth/domain/user_profile.dart';

final authRepositoryProvider = Provider<SupabaseAuthRepository>((ref) {
  return SupabaseAuthRepository();
});

/// Contador de intentos fallidos de login, compartido durante la ejecución.
final loginAttemptPolicyProvider = Provider<LoginAttemptPolicy>((ref) {
  return LoginAttemptPolicy();
});

class AuthNotifier extends Notifier<UserProfile?> {
  String? lastError;
  int _operationVersion = 0;

  @override
  UserProfile? build() {
    Future.microtask(() => checkCurrentUser());
    return null;
  }

  Future<void> checkCurrentUser() async {
    final operationVersion = _operationVersion;
    final repo = ref.read(authRepositoryProvider);
    final user = await repo.getCurrentUser();
    if (operationVersion == _operationVersion) {
      state = user;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _operationVersion++;
      lastError = null;
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.signInWithEmailPassword(email, password);
      state = user;
      return true;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    try {
      _operationVersion++;
      lastError = null;
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.signUpWithEmailPassword(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
      );
      state = repo.hasActiveSession ? user : null;
      return true;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  Future<void> signOut() async {
    _operationVersion++;
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
    state = null;
  }

  Future<bool> updatePassword(String newPassword) async {
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.updatePassword(newPassword);
      // Requisito crítico: La actualización de contraseña no altera los datos
      // del perfil ni la sesión del usuario para garantizar la persistencia en la BD.
      return true;
    } catch (_) {
      return false;
    }
  }

  void setDemoUser(UserProfile demoUser) {
    final repo = ref.read(authRepositoryProvider);
    repo.switchDemoUser(demoUser);
    state = demoUser;
  }
}

final authProvider = NotifierProvider<AuthNotifier, UserProfile?>(
  AuthNotifier.new,
);
