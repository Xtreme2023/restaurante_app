import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurante_app/features/reservas/domain/usecases/reservation_policy.dart';
import 'package:restaurante_app/features/reservas/presentation/providers/reservation_providers.dart';

void main() {
  // Martes a las 18:00: fuera del horario de reserva y de entrega.
  final afterHours = DateTime(2030, 3, 5, 18, 0);
  final today = DateTime(2030, 3, 5);
  const normal = ReservationPolicy();
  const demo = ReservationPolicy(ignoreServiceHours: true);

  group('Modo demostración en ReservationPolicy', () {
    test('sin modo demo se respetan los horarios', () {
      expect(normal.canReserve(today, afterHours), isFalse);
      expect(normal.canCancel(today, afterHours), isFalse);
      expect(normal.canDeliver(today, afterHours), isFalse);
    });

    test('con modo demo se puede reservar, cancelar y entregar hoy', () {
      expect(demo.canReserve(today, afterHours), isTrue);
      expect(demo.canCancel(today, afterHours), isTrue);
      expect(demo.canDeliver(today, afterHours), isTrue);
    });

    test('el modo demo mantiene las demás reglas', () {
      final yesterday = DateTime(2030, 3, 4);
      final saturday = DateTime(2030, 3, 9);
      final tomorrow = DateTime(2030, 3, 6);

      expect(demo.canReserve(yesterday, afterHours), isFalse);
      expect(demo.canReserve(saturday, afterHours), isFalse);
      // La entrega sigue siendo solo el día de la reserva.
      expect(demo.canDeliver(tomorrow, afterHours), isFalse);
    });
  });

  test('el interruptor cambia la política usada por la app', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(demoModeProvider), isFalse);
    expect(
      container
          .read(reservationPolicyUseCaseProvider)
          .canDeliver(today, afterHours),
      isFalse,
    );

    container.read(demoModeProvider.notifier).setEnabled(true);
    expect(
      container
          .read(reservationPolicyUseCaseProvider)
          .canDeliver(today, afterHours),
      isTrue,
    );

    container.read(demoModeProvider.notifier).setEnabled(false);
    expect(
      container
          .read(reservationPolicyUseCaseProvider)
          .canDeliver(today, afterHours),
      isFalse,
    );
  });
}
