import 'package:flutter/material.dart';
import 'package:restaurante_app/core/theme/app_theme.dart';
import 'package:restaurante_app/core/layout/main_layout.dart'; // Importamos el layout

void main() {
  runApp(const RestauranteApp());
}

class RestauranteApp extends StatelessWidget {
  const RestauranteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Restaurante App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme, // Ya tiene Material 3 activado
      home: const MainLayout(), // <-- AHORA CARGAMOS MAINLAYOUT
    );
  }
}
