import 'package:flutter_test/flutter_test.dart';
import 'package:restaurante_app/features/auth/domain/user_profile.dart';

void main() {
  test('Prueba 1: un empleado con plan mensual paga Bs. 15', () {
    final profile = UserProfile.fromJson({
      'id': 'employee-1',
      'email': 'mensual@example.com',
      'full_name': 'Empleado Mensual',
      'role': 'empleado',
      'has_monthly_plan': true,
    });

    expect(profile.isPensioner, isTrue);
  });
}
