import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurante_app/features/auth/domain/user_profile.dart';
import 'package:restaurante_app/supabase/supabase_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{};
        }
        return true;
      },
    );
  });

  group('Supabase Client & Auth Configuration Tests', () {
    test('initSupabase initializes client and getter returns SupabaseClient', () async {
      await initSupabase();
      expect(supabase, isNotNull);
      expect(supabaseUrl.isNotEmpty, isTrue);
      expect(supabaseAnonKey.isNotEmpty, isTrue);
    });

    test('UserProfile correctly parses vista_usuarios JSON fields', () {
      final mockVistaRow = {
        'id_usuario': '1bca37f2-3536-4f36-8749-a643187867b1',
        'nombre': 'Admin',
        'apellidos': 'Sistema',
        'telefono': '77712345',
        'nombre_completo': 'Admin Sistema',
        'ci_codigo': '111111111',
        'email': 'admin@rest.cielo.com',
        'rol': 'Administrador',
        'activo': true,
        'created_at': '2026-10-16T19:55:25.038351+00:00'
      };

      final profile = UserProfile.fromJson(mockVistaRow);

      expect(profile.id, equals('1bca37f2-3536-4f36-8749-a643187867b1'));
      expect(profile.fullName, equals('Admin Sistema'));
      expect(profile.email, equals('admin@rest.cielo.com'));
      expect(profile.role, equals('admin'));
      expect(profile.isAdmin, isTrue);
      expect(profile.ciCodigo, equals('111111111'));
      expect(profile.telefono, equals('77712345'));
      expect(profile.activo, isTrue);
    });

    test('UserProfile correctly identifies inactive user from vista_usuarios', () {
      final mockInactiveRow = {
        'id_usuario': '6829218a-ca33-4b36-91f6-a0718dc9ea3b',
        'nombre': 'Samuel',
        'apellidos': 'De Luque',
        'telefono': '777012312',
        'nombre_completo': 'Samuel De Luque',
        'ci_codigo': '77919297',
        'email': 'samueldeluque@rest.cielo.com',
        'rol': 'Empleado',
        'activo': false,
      };

      final profile = UserProfile.fromJson(mockInactiveRow);

      expect(profile.isEmpleado, isTrue);
      expect(profile.activo, isFalse);
    });

    test('createAdminUser rejects registration when CI or Email is missing', () async {
      await initSupabase();

      expect(
        () => createAdminUser({
          'email': '',
          'password': '123',
          'nombre': 'Test',
          'apellidos': 'User',
          'ci_codigo': '999999',
          'telefono': '77777777',
          'rol': 'Empleado',
        }),
        throwsA(anything),
      );
    });

    test('tempClient with AuthFlowType.implicit does not assert _asyncStorage', () {
      final tempClient = SupabaseClient(
        supabaseUrl,
        supabaseAnonKey,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
      expect(tempClient.auth, isNotNull);
    });
  });
}
