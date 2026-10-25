import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restaurante_app/core/layout/admin_shell.dart';
import 'package:restaurante_app/core/layout/kitchen_shell.dart';
import 'package:restaurante_app/core/layout/main_layout.dart';
import 'package:restaurante_app/core/theme/app_theme.dart';
import 'package:restaurante_app/features/auth/presentation/login_screen.dart';
import 'package:restaurante_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:restaurante_app/supabase/supabase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carga de variables de entorno con fallback seguro
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Nota: Carga de .env omitida o fallida ($e). Usando valores predeterminados.');
  }

  // Inicializar cliente de Supabase
  await initSupabase();

  runApp(const ProviderScope(child: RestauranteApp()));
}

class RestauranteApp extends ConsumerWidget {
  const RestauranteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);

    Widget homeScreen;
    if (user == null) {
      homeScreen = const LoginScreen();
    } else if (user.isAdmin) {
      homeScreen = const AdminShell();
    } else if (user.isCocina) {
      homeScreen = const KitchenShell();
    } else {
      homeScreen = const MainLayout();
    }

    return MaterialApp(
      title: 'Restaurante App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: homeScreen,
    );
  }
}
