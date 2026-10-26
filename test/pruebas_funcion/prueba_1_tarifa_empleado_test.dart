import 'package:flutter_test/flutter_test.dart';
import 'package:restaurante_app/features/auth/domain/user_profile.dart';

void main() {
  test('Prueba funcional 1: plan mensual calcula Bs. 15 por almuerzo', () {
    const employee = UserProfile(
      id: 'employee-monthly',
      email: 'monthly@example.com',
      fullName: 'Empleado Mensual',
      isPensioner: true,
    );

    expect(employee.mealPrice, UserProfile.monthlyMealPrice);
    expect(employee.mealPrice, 15.0);
  });
}
