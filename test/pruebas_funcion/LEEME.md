# Pruebas funcionales

Esta carpeta contiene pruebas pequeñas para verificar reglas importantes de la
aplicación sin conectarse a Supabase:

- `prueba_1_tarifa_empleado_test.dart`: valida Bs. 15 para un empleado con Plan Mensual.
- `prueba_2_tarifa_particular_test.dart`: valida Bs. 18 para un empleado sin Plan Mensual.
- `prueba_3_perfil_desde_supabase_test.dart`: valida que `has_monthly_plan` se convierta correctamente al cargar un perfil remoto.

## Ejecutar todas las pruebas

Desde la raíz del proyecto:

```bash
flutter test test/pruebas_funcion
```

## Ejecutar una prueba específica

```bash
flutter test test/pruebas_funcion/prueba_1_tarifa_empleado_test.dart
```

## Cómo actualizar una prueba

1. Abre el archivo correspondiente.
2. Cambia los datos del caso dentro del `test(...)`.
3. Mantén la expectativa (`expect(...)`) alineada con la regla de negocio.
4. Ejecuta nuevamente `flutter test test/pruebas_funcion`.

Las tarifas están centralizadas en
`lib/features/auth/domain/user_profile.dart`. Si cambia una tarifa oficial,
actualiza `UserProfile.monthlyMealPrice` o `UserProfile.dailyMealPrice`; las
pantallas usan esos valores.
