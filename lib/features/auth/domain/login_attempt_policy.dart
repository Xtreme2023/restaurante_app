/// Regla de bloqueo del inicio de sesión.
///
/// Después de [maxAttempts] intentos fallidos con el mismo correo, el acceso
/// queda bloqueado y el usuario debe ponerse en contacto con el administrador.
/// Los intentos se cuentan por correo normalizado (sin espacios, minúsculas).
class LoginAttemptPolicy {
  static const int maxAttempts = 3;

  static const String lockedMessage =
      'Tu acceso fue bloqueado después de $maxAttempts intentos fallidos. '
      'Ponte en contacto con el administrador.';

  final Map<String, int> _failedAttempts = {};

  String _key(String email) => email.trim().toLowerCase();

  int failedAttempts(String email) => _failedAttempts[_key(email)] ?? 0;

  bool isLocked(String email) => failedAttempts(email) >= maxAttempts;

  int remainingAttempts(String email) {
    final remaining = maxAttempts - failedAttempts(email);
    return remaining < 0 ? 0 : remaining;
  }

  /// Registra un intento fallido y devuelve los intentos restantes.
  int registerFailure(String email) {
    final key = _key(email);
    _failedAttempts[key] = (_failedAttempts[key] ?? 0) + 1;
    return remainingAttempts(email);
  }

  /// Limpia el contador tras un inicio de sesión correcto.
  void reset(String email) => _failedAttempts.remove(_key(email));
}
