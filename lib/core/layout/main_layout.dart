import 'package:flutter/material.dart';
import 'package:restaurante_app/features/menu/presentation/menu_screen.dart';
import 'package:restaurante_app/features/reservas/presentation/calendar_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const MenuScreen(),
    const CalendarScreen(), // <-- AHORA CARGA EL CALENDARIO REAL
    const Center(
      child: Text(
        'Mis Reservas',
        style: TextStyle(fontSize: 20, color: Colors.white),
      ),
    ),
    const Center(
      child: Text(
        'Perfil / Iniciar Sesión',
        style: TextStyle(fontSize: 20, color: Colors.white),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Contenedor principal con la imagen de fondo
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/mesa.jpeg'),
            fit: BoxFit.cover,
            // Un filtro oscuro sutil para que las tarjetas blancas resalten
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.5),
              BlendMode.darken,
            ),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _screens[_selectedIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: Colors.white,
        elevation: 10,
        indicatorColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu, color: Color(0xFF4A90E2)),
            label: 'Menú',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: Color(0xFF4A90E2)),
            label: 'Calendario',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF4A90E2)),
            label: 'Reservas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFF4A90E2)),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
