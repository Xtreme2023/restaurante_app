import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String dishImagesBucket = 'platos';

  /// URL del proyecto Supabase.
  static String get supabaseUrl {
    if (dotenv.isInitialized) {
      final fromEnv = dotenv.env['SUPABASE_URL']?.trim() ?? '';
      if (fromEnv.isNotEmpty) return fromEnv;
    }
    return const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://vzcrkhjqdsnxizhyjjjk.supabase.co',
    );
  }

  /// Clave anónima pública de Supabase.
  static String get supabaseAnonKey {
    if (dotenv.isInitialized) {
      final fromEnv = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
      if (fromEnv.isNotEmpty) return fromEnv;
    }
    return const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ6Y3JraGpxZHNueGl6aHlqamprIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE0NzgwNjQsImV4cCI6MjEwNzA1NDA2NH0.1CspDh3s9fLpn9cSU--xYlEYa4q6JEGjEySoWkT3yR8',
    );
  }

  /// Retorna si Supabase está activo y conectado.
  static bool get isInitialized {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Retorna el cliente Supabase si está disponible.
  static SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Convierte una ruta guardada en la tabla `platos` en una URL pública del
  /// bucket de imágenes. Las rutas locales se dejan para el fallback de demo.
  static String? publicDishImageUrl(String? rawPath) {
    final path = rawPath?.trim() ?? '';
    if (path.isEmpty) return null;

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (path.startsWith('assets/')) return null;

    final normalizedPath = path
        .replaceFirst(RegExp(r'^/+'), '')
        .replaceFirst(RegExp('^$dishImagesBucket/'), '');
    final supabaseClient = client;
    if (supabaseClient == null || normalizedPath.isEmpty) return null;

    return supabaseClient.storage
        .from(dishImagesBucket)
        .getPublicUrl(normalizedPath);
  }

  /// Inicializa Supabase de manera tolerante a fallos.
  /// Si la URL no es válida o no hay conexión, la app inicia en modo demostración/híbrido.
  static Future<void> initialize() async {
    try {
      if (isInitialized) return;
      if (supabaseUrl.isNotEmpty &&
          supabaseUrl.startsWith('https://') &&
          !supabaseUrl.contains('demo-restaurante')) {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseAnonKey,
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
        );
        debugPrint('✅ Supabase inicializado correctamente.');
      } else {
        debugPrint(
          'ℹ️ Supabase no configurado con credenciales reales. Iniciando en modo local/demo.',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error al inicializar Supabase ($e). Modo local activo.');
    }
  }

  /// Comprueba el estado de la conexión a Supabase y retorna un diagnóstico legible.
  static Future<Map<String, dynamic>> checkConnectionHealth() async {
    final client = SupabaseConfig.client;
    if (!isInitialized || client == null) {
      return {
        'connected': false,
        'message': 'Supabase no inicializado o modo local activo',
        'url': supabaseUrl,
      };
    }
    try {
      final res = await client.from('platos').select('id').limit(1);
      return {
        'connected': true,
        'message': 'Conexión exitosa a Supabase y tablas accesibles',
        'url': supabaseUrl,
        'data': res,
      };
    } catch (e) {
      return {
        'connected': true,
        'message':
            'Cliente conectado con éxito al endpoint (RLS o permisos requeridos): $e',
        'url': supabaseUrl,
      };
    }
  }
}
