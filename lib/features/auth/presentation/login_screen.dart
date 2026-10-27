import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurante_app/features/auth/domain/login_attempt_policy.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isRequestingReset = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _requestPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ingresa tu correo institucional para solicitar el reinicio.',
          ),
        ),
      );
      return;
    }
    setState(() => _isRequestingReset = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .createPasswordResetRequest(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Solicitud enviada. Un administrador atenderá tu reinicio de contraseña.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo enviar la solicitud: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRequestingReset = false);
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa correo y contraseña'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final attempts = ref.read(loginAttemptPolicyProvider);
    if (attempts.isLocked(email)) {
      await _showLockedDialog();
      return;
    }

    setState(() => _isLoading = true);
    final ok = await ref.read(authProvider.notifier).signIn(email, password);
    if (ok) attempts.reset(email);
    if (mounted) {
      setState(() => _isLoading = false);
      if (!ok) {
        final error = ref.read(authProvider.notifier).lastError ?? '';
        final message =
            error.contains('email_not_confirmed') ||
                error.contains('Email not confirmed')
            ? 'Tu correo aún no está confirmado. Revisa tu bandeja de entrada o solicita al administrador que confirme la cuenta.'
            : error.contains('email_provider_disabled')
            ? 'No se puede consultar la base de datos porque el proveedor Email está deshabilitado en Supabase. Habilítalo en Authentication > Providers.'
            : error.contains('no tiene un perfil')
            ? 'La cuenta existe, pero no tiene un perfil asociado en Supabase. Registra el perfil del usuario y vuelve a intentar.'
            : null;
        if (message == null) {
          // Credenciales incorrectas: cuenta para el bloqueo.
          final remaining = attempts.registerFailure(email);
          if (remaining == 0) {
            await _showLockedDialog();
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Correo o contraseña incorrectos. '
                '${remaining == 1 ? 'Te queda 1 intento' : 'Te quedan $remaining intentos'} '
                'antes del bloqueo.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _showLockedDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.lock_outline, color: Colors.redAccent, size: 40),
        title: const Text('Acceso bloqueado'),
        content: const Text(LoginAttemptPolicy.lockedMessage),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const wine = Color(0xFF5B1F2A);
    const wineDark = Color(0xFF32121A);
    const champagne = Color(0xFFC9A66B);
    const ink = Color(0xFF241A1C);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/mesa.jpeg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              wineDark.withValues(alpha: 0.78),
              BlendMode.darken,
            ),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 820;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWide ? 980 : 460),
                  child: Card(
                    elevation: 24,
                    shadowColor: Colors.black.withValues(alpha: 0.35),
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    color: Colors.white,
                    child: IntrinsicHeight(
                      child: Flex(
                        direction: isWide ? Axis.horizontal : Axis.vertical,
                        children: [
                          if (isWide)
                            Expanded(
                              flex: 5,
                              child: Container(
                                padding: const EdgeInsets.all(42),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [wine, wineDark],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome,
                                      color: champagne,
                                      size: 28,
                                    ),
                                    SizedBox(height: 24),
                                    Text(
                                      'Una experiencia que comienza en la mesa.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 30,
                                        height: 1.15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 18),
                                    Text(
                                      'Gestiona tu servicio con la dedicación y el sabor de un restaurante de calidad.',
                                      style: TextStyle(
                                        color: Color(0xFFE9D9C0),
                                        fontSize: 14,
                                        height: 1.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Expanded(
                            flex: 6,
                            child: Padding(
                              padding: EdgeInsets.all(isWide ? 42 : 28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(15),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF4EBDD),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: const Icon(
                                        Icons.restaurant_menu,
                                        size: 34,
                                        color: wine,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'Bienvenido',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: ink,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Restaurante Institucional',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  TextField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    decoration: _inputDecoration(
                                      label: 'Correo electrónico',
                                      hint: 'usuario@institucion.gob.bo',
                                      icon: Icons.email_outlined,
                                      color: wine,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _handleLogin(),
                                    decoration:
                                        _inputDecoration(
                                          label: 'Contraseña',
                                          icon: Icons.lock_outline,
                                          color: wine,
                                        ).copyWith(
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                        .visibility_off_outlined,
                                              color: Colors.grey.shade600,
                                            ),
                                            onPressed: () => setState(
                                              () => _obscurePassword =
                                                  !_obscurePassword,
                                            ),
                                          ),
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed:
                                          _isLoading || _isRequestingReset
                                          ? null
                                          : _requestPasswordReset,
                                      style: TextButton.styleFrom(
                                        foregroundColor: wine,
                                      ),
                                      child: _isRequestingReset
                                          ? const Text('Enviando solicitud...')
                                          : const Text(
                                              '¿Olvidaste tu contraseña?',
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 54,
                                    child: ElevatedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: wine,
                                        foregroundColor: Colors.white,
                                        elevation: 3,
                                        shadowColor: wine.withValues(
                                          alpha: 0.35,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.5,
                                              ),
                                            )
                                          : const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Ingresar al sistema',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                SizedBox(width: 10),
                                                Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 19,
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.verified_user_outlined,
                                        size: 15,
                                        color: champagne,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Acceso seguro y protegido',
                                        style: TextStyle(
                                          color: Color(0xFF8A7477),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    required IconData icon,
    required Color color,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: color),
      filled: true,
      fillColor: const Color(0xFFFAF8F6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE8E0DC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE8E0DC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: 1.5),
      ),
    );
  }
}
