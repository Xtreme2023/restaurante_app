import 'package:flutter_test/flutter_test.dart';
import 'package:restaurante_app/features/auth/domain/user_profile.dart';

void main() {
  test('Prueba funcional 2: sin plan mensual calcula Bs. 18 por almuerzo', () {
    final profile = UserProfile.fromJson({
      'id': 'employee-2',
      'email': 'particular@example.com',
      'full_name': 'Empleado Particular',
      'role': 'empleado',
      'has_monthly_plan': false,
    });

    expect(profile.isPensioner, isFalse);
    expect(profile.mealPrice, UserProfile.dailyMealPrice);
    expect(profile.mealPrice, 18.0);
  });
}
