import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurante_app/features/admin/domain/admin_employee_entity.dart';
import 'package:restaurante_app/features/admin/presentation/attendance_admin_tab.dart';
import 'package:restaurante_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:restaurante_app/features/auth/domain/user_profile.dart';
import 'package:restaurante_app/features/auth/presentation/profile_screen.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurante_app/features/reservas/domain/holiday_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_entity.dart';
import 'package:restaurante_app/features/reservas/domain/reservation_repository.dart';
import 'package:restaurante_app/features/reservas/presentation/personal_consumption_metrics_screen.dart';
import 'package:restaurante_app/features/reservas/presentation/providers/reservation_providers.dart';

class MockReservationRepoForTests implements ReservationRepository {
  List<Reservation> reservations = [];
  List<Map<String, dynamic>> attendanceRecords = [];

  @override
  Future<List<Reservation>> getUserReservations(String userId) async {
    return reservations.where((r) => r.userId == userId).toList();
  }

  @override
  Future<List<Reservation>> getUserReservationsForPeriod(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    return reservations
        .where((r) =>
            r.userId == userId &&
            !r.date.isBefore(startDate) &&
            !r.date.isAfter(endDate) &&
            r.status.toLowerCase() != 'cancelada')
        .toList();
  }

  @override
  Future<List<Reservation>> getAllReservationsForDate(DateTime date) async {
    return reservations
        .where((r) =>
            r.date.year == date.year &&
            r.date.month == date.month &&
            r.date.day == date.day)
        .toList();
  }

  @override
  Future<void> createReservation(Reservation reservation) async {
    reservations.add(reservation);
  }

  @override
  Future<void> cancelReservation(String reservationId) async {
    final idx = reservations.indexWhere((r) => r.id == reservationId);
    if (idx != -1) {
      reservations[idx] = reservations[idx].copyWith(status: 'cancelada');
    }
  }

  @override
  Future<void> updateReservationStatus(
      String reservationId, String status) async {
    final idx = reservations.indexWhere((r) => r.id == reservationId);
    if (idx != -1) {
      reservations[idx] = reservations[idx].copyWith(status: status);
    }
  }

  @override
  Future<void> markReservationAsPickedUp(
      String reservationId, bool recogido) async {
    final idx = reservations.indexWhere((r) => r.id == reservationId);
    if (idx != -1) {
      reservations[idx] = reservations[idx].copyWith(
        recogido: recogido,
        status: recogido ? 'entregada' : reservations[idx].status,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAttendanceForDate(DateTime date) async {
    final dateStr =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return attendanceRecords.where((a) => a['fecha'] == dateStr).toList();
  }

  @override
  Future<void> registerAttendance({
    required String userId,
    int? reservationId,
    required DateTime date,
    bool asistio = true,
    String? observacion,
  }) async {
    final dateStr =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    attendanceRecords.removeWhere(
      (a) => a['id_usuario'] == userId && a['fecha'] == dateStr,
    );
    attendanceRecords.add({
      'id_usuario': userId,
      'id_reserva': reservationId,
      'fecha': dateStr,
      'hora_marcado': '12:30:00',
      'asistio': asistio,
      'observacion': observacion,
    });
  }

  @override
  Future<List<Holiday>> getHolidays() async => [];
}

class TestAuthNotifier extends AuthNotifier {
  final UserProfile? initialUser;
  TestAuthNotifier(this.initialUser);

  @override
  UserProfile? build() => initialUser;
}

void main() {
  final employeeUser = const UserProfile(
    id: 'emp-uuid-1',
    email: 'empleado@institucion.gob.bo',
    fullName: 'Carlos Mamani',
    role: 'empleado',
    ciCodigo: '1234567',
  );

  final otherUser = const UserProfile(
    id: 'emp-uuid-2',
    email: 'otro@institucion.gob.bo',
    fullName: 'María Quispe',
    role: 'empleado',
    ciCodigo: '7654321',
  );

  group('1. ProfileScreen - Opciones limitadas para Empleado', () {
    testWidgets(
        'Empleado visualiza estrictamente: Pensión, Métricas Institucionales y Cambiar contraseña',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => TestAuthNotifier(employeeUser)),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ProfileScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Modalidad Mensual (Pensión)'), findsOneWidget);
      expect(find.text('Métricas Institucionales'), findsOneWidget);
      expect(find.text('Cambiar Contraseña'), findsOneWidget);

      // No debe existir el panel de cocina para un simple empleado
      expect(find.text('Panel de Cocina & Despacho'), findsNothing);
    });
  });

  group('2. HU12 - Estadísticas personales de consumo (Métricas Institucionales)', () {
    testWidgets('Sin selección de período al Consultar muestra: Debe seleccionar un período',
        (tester) async {
      final mockRepo = MockReservationRepoForTests();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => TestAuthNotifier(employeeUser)),
            reservationRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(body: PersonalConsumptionMetricsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clic directo en Consultar sin elegir período
      await tester.tap(find.widgetWithText(ElevatedButton, 'Consultar'));
      await tester.pumpAndSettle();

      expect(find.text('Debe seleccionar un período'), findsOneWidget);
    });

    testWidgets('Período sin registros de consumo muestra: Sin datos disponibles',
        (tester) async {
      final mockRepo = MockReservationRepoForTests();
      // No agregamos reservas para employeeUser

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => TestAuthNotifier(employeeUser)),
            reservationRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(body: PersonalConsumptionMetricsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Seleccionar un período del dropdown
      await tester.tap(find.byType(DropdownButtonFormField<ConsumptionPeriod>));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Mes Actual').last);
      await tester.pumpAndSettle();

      // Consultar
      await tester.tap(find.widgetWithText(ElevatedButton, 'Consultar'));
      await tester.pumpAndSettle();

      expect(find.text('Sin datos disponibles'), findsOneWidget);
    });

    testWidgets(
        'Con registros de consumo: Muestra almuerzos, montos y desglose titular y familiares sin mezclar con otros',
        (tester) async {
      final mockRepo = MockReservationRepoForTests();
      final now = DateTime.now();

      // 1 reserva del empleado Carlos Mamani
      mockRepo.reservations.add(
        Reservation(
          id: 'res-1',
          userId: employeeUser.id,
          userName: employeeUser.fullName,
          dishName: 'Silpancho Cochabambino',
          price: 15.0,
          date: now,
          status: 'confirmada',
          recogido: true,
          createdAt: now,
        ),
      );

      // 1 reserva de un familiar de Carlos Mamani
      mockRepo.reservations.add(
        Reservation(
          id: 'res-2',
          userId: employeeUser.id,
          userName: employeeUser.fullName,
          familiarId: 'fam-uuid-1',
          beneficiaryName: 'Lucía Mamani (Hija)',
          dishName: 'Majadito Tradicional',
          price: 18.0,
          date: now,
          status: 'confirmada',
          recogido: true,
          createdAt: now,
        ),
      );

      // 1 reserva de OTRO usuario María Quispe (NO debe aparecer para Carlos Mamani)
      mockRepo.reservations.add(
        Reservation(
          id: 'res-other',
          userId: otherUser.id,
          userName: otherUser.fullName,
          dishName: 'Pique Macho',
          price: 18.0,
          date: now,
          status: 'confirmada',
          createdAt: now,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => TestAuthNotifier(employeeUser)),
            reservationRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(body: PersonalConsumptionMetricsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Seleccionar período
      await tester.tap(find.byType(DropdownButtonFormField<ConsumptionPeriod>));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Mes Actual').last);
      await tester.pumpAndSettle();

      // Consultar
      await tester.tap(find.widgetWithText(ElevatedButton, 'Consultar'));
      await tester.pumpAndSettle();

      // Total de almuerzos: 2 (1 de Carlos y 1 de su hija, NUNCA el de María Quispe)
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Bs. 33.00'), findsOneWidget);

      // Desglose por persona presente
      expect(find.text('Carlos Mamani'), findsWidgets);
      expect(find.text('Lucía Mamani'), findsOneWidget);
      expect(find.text('María Quispe'), findsNothing);

      // Botón Exportar PDF presente
      expect(find.widgetWithText(ElevatedButton, 'Exportar PDF'), findsOneWidget);
    });
  });

  group('3. HU13 - Registro de asistencia y control de plato recogido', () {
    testWidgets('Sin selección de empleado al Registrar muestra: Debe seleccionar un empleado',
        (tester) async {
      final mockRepo = MockReservationRepoForTests();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reservationRepositoryProvider.overrideWithValue(mockRepo),
            adminEmployeesProvider.overrideWith(() => AdminEmployeesNotifierFake([])),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AttendanceAdminTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Presionar Registrar sin haber seleccionado un empleado en el dropdown
      await tester.tap(find.widgetWithText(ElevatedButton, 'Registrar'));
      await tester.pumpAndSettle();

      expect(find.text('Debe seleccionar un empleado'), findsOneWidget);
    });

    testWidgets('Empleado seleccionado sin reserva activa para hoy muestra: No existe reserva activa',
        (tester) async {
      final mockRepo = MockReservationRepoForTests();
      final adminEmp = AdminEmployee(
        id: employeeUser.id,
        ci: employeeUser.ciCodigo ?? '',
        nombres: 'Carlos',
        apellidos: 'Mamani',
        email: employeeUser.email,
        rol: 'EMPLEADO',
        creadoEn: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reservationRepositoryProvider.overrideWithValue(mockRepo),
            adminEmployeesProvider.overrideWith(
              () => AdminEmployeesNotifierFake([adminEmp]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AttendanceAdminTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Seleccionar al empleado Carlos Mamani en el dropdown
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Carlos Mamani').last);
      await tester.pumpAndSettle();

      // Presionar Registrar Asistencia
      await tester.tap(find.widgetWithText(ElevatedButton, 'Registrar').first);
      await tester.pumpAndSettle();

      expect(find.text('No existe reserva activa'), findsOneWidget);
    });

    testWidgets('Empleado con reserva activa y plato recogido: Muestra Recogió su plato y registra asistencia',
        (tester) async {
      final mockRepo = MockReservationRepoForTests();
      final now = DateTime.now();

      final adminEmp = AdminEmployee(
        id: employeeUser.id,
        ci: employeeUser.ciCodigo ?? '',
        nombres: 'Carlos',
        apellidos: 'Mamani',
        email: employeeUser.email,
        rol: 'EMPLEADO',
        creadoEn: now,
      );

      // Reserva activa para hoy con plato ya recogido
      mockRepo.reservations.add(
        Reservation(
          id: '101',
          userId: employeeUser.id,
          userName: employeeUser.fullName,
          dishName: 'Silpancho Cochabambino',
          price: 15.0,
          date: now,
          status: 'confirmada',
          recogido: true,
          createdAt: now,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reservationRepositoryProvider.overrideWithValue(mockRepo),
            adminEmployeesProvider.overrideWith(
              () => AdminEmployeesNotifierFake([adminEmp]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AttendanceAdminTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el badge "Recogió su plato"
      expect(find.text('Recogió su plato'), findsWidgets);

      // Seleccionar y registrar asistencia
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Carlos Mamani').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Registrar').first);
      await tester.pumpAndSettle();

      // Asistencia confirmada
      expect(
        find.textContaining('Asistencia registrada con éxito para Carlos Mamani'),
        findsOneWidget,
      );

      // Registro en tabla asistencia
      expect(mockRepo.attendanceRecords.length, 1);
      expect(mockRepo.attendanceRecords.first['id_usuario'], employeeUser.id);
    });
  });
}

class AdminEmployeesNotifierFake extends AdminEmployeesNotifier {
  final List<AdminEmployee> initialList;
  AdminEmployeesNotifierFake(this.initialList);

  @override
  AdminEmployeesState build() {
    return AdminEmployeesState(
      employees: initialList,
      isLoading: false,
    );
  }
}
