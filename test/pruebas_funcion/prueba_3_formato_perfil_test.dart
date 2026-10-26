import 'package:flutter_test/flutter_test.dart';
import 'package:restaurante_app/features/auth/domain/user_profile.dart';

void main() {
  test('Prueba 3: el plan mensual acepta valores booleanos y texto', () {
    final numericProfile = UserProfile.fromJson({
      'id': 'employee-3',
      'email': 'numeric@example.com',
      'full_name': 'Empleado Numérico',
      'role': 'empleado',
      'has_monthly_plan': 1,
    });
    final textProfile = UserProfile.fromJson({
      'id': 'employee-4',
      'email': 'text@example.com',
      'full_name': 'Empleado Texto',
      'role': 'empleado',
      'has_monthly_plan': 'true',
    });

    expect(numericProfile.isPensioner, isTrue);
    expect(textProfile.isPensioner, isTrue);
  });
}
