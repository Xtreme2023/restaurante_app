import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurante_app/features/auth/domain/login_attempt_policy.dart';
import 'package:restaurante_app/features/auth/domain/user_profile.dart';
import 'package:restaurante_app/features/auth/presentation/login_screen.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';

/// Simula un backend que rechaza las credenciales y cuenta las llamadas.
class RejectingAuthNotifier extends AuthNotifier {
  int signInCalls = 0;

  @override
  UserProfile? build() => null;

  @override
  Future<bool> signIn(String email, String password) async {
    signInCalls++;
    lastError = 'AuthApiException(message: Invalid login credentials)';
    return false;
  }
}

void main() {
  group('LoginAttemptPolicy', () {
    test('bloquea después de 3 intentos fallidos', () {
      final policy = LoginAttemptPolicy();
      const email = 'juan@institucion.gob.bo';

      expect(policy.registerFailure(email), 2);
      expect(policy.isLocked(email), isFalse);
      expect(policy.registerFailure(email), 1);
      expect(policy.isLocked(email), isFalse);
      expect(policy.registerFailure(email), 0);
      expect(policy.isLocked(email), isTrue);
    });

    test('normaliza el correo y cuenta por usuario', () {
      final policy = LoginAttemptPolicy();
      for (var i = 0; i < 3; i++) {
        policy.registerFailure('  Juan@Institucion.gob.bo ');
      }

      expect(policy.isLocked('juan@institucion.gob.bo'), isTrue);
      expect(policy.isLocked('maria@institucion.gob.bo'), isFalse);
    });

    test('un ingreso correcto reinicia el contador', () {
      final policy = LoginAttemptPolicy();
      const email = 'juan@institucion.gob.bo';
      policy.registerFailure(email);
      policy.registerFailure(email);
      policy.reset(email);

      expect(policy.remainingAttempts(email), LoginAttemptPolicy.maxAttempts);
    });
  });

  testWidgets(
    'LoginScreen bloquea al tercer intento y pide contactar al administrador',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final notifier = RejectingAuthNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(() => notifier)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      await tester.enterText(
        find.byType(TextField).at(0),
        'juan@institucion.gob.bo',
      );
      await tester.enterText(find.byType(TextField).at(1), 'incorrecta');

      Future<void> tapLogin() async {
        ScaffoldMessenger.of(
          tester.element(find.byType(LoginScreen)),
        ).clearSnackBars();
        await tester.tap(find.text('Ingresar al sistema'));
        await tester.pumpAndSettle();
      }

      await tapLogin();
      expect(find.textContaining('Te quedan 2 intentos'), findsOneWidget);

      await tapLogin();
      expect(find.textContaining('Te queda 1 intento'), findsOneWidget);

      await tapLogin();
      expect(find.text('Acceso bloqueado'), findsOneWidget);
      expect(find.text(LoginAttemptPolicy.lockedMessage), findsOneWidget);

      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();

      // Un cuarto intento ya no llega al backend.
      await tapLogin();
      expect(notifier.signInCalls, 3);
      expect(find.text('Acceso bloqueado'), findsOneWidget);
    },
  );
}
