import 'package:flutter_test/flutter_test.dart';
import 'package:restaurante_app/features/auth/domain/user_profile.dart';

void main() {
  test('Prueba funcional 3: el perfil remoto conserva la tarifa mensual', () {
    final employee = UserProfile.fromJson({
      'id': 'employee-remote',
      'email': 'remote@example.com',
      'full_name': 'Empleado Remoto',
      'role': 'empleado',
      'has_monthly_plan': true,
    });

    expect(employee.isPensioner, isTrue);
    expect(employee.mealPrice, 15.0);
  });
}
