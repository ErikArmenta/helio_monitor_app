import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';
import '../config/theme.dart';
import 'dashboard_screen.dart';
import 'new_reading_screen.dart';
import 'charts_screen.dart';
import 'ai_chat_screen.dart';
import 'ocr_screen.dart';
import 'readings_list_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
    NavigationDestination(icon: Icon(Icons.add_circle_outline_rounded), label: 'Lectura'),
    NavigationDestination(icon: Icon(Icons.table_chart_rounded), label: 'Datos'),
    NavigationDestination(icon: Icon(Icons.show_chart_rounded), label: 'Graficas'),
    NavigationDestination(icon: Icon(Icons.smart_toy_rounded), label: 'Jarvis IA'),
    NavigationDestination(icon: Icon(Icons.document_scanner_rounded), label: 'OCR'),
  ];

  static const _railDestinations = [
    NavigationRailDestination(icon: Icon(Icons.dashboard_rounded), label: Text('Dashboard')),
    NavigationRailDestination(icon: Icon(Icons.add_circle_outline_rounded), label: Text('Lectura')),
    NavigationRailDestination(icon: Icon(Icons.table_chart_rounded), label: Text('Datos')),
    NavigationRailDestination(icon: Icon(Icons.show_chart_rounded), label: Text('Graficas')),
    NavigationRailDestination(icon: Icon(Icons.smart_toy_rounded), label: Text('Jarvis IA')),
    NavigationRailDestination(icon: Icon(Icons.document_scanner_rounded), label: Text('OCR')),
  ];

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const NewReadingScreen();
      case 2:
        return const ReadingsListScreen();
      case 3:
        return const ChartsScreen();
      case 4:
        return const AiChatScreen();
      case 5:
        return const OcrScreen();
      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;
    final isDesktop = width >= 1100;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [EaColors.primary, EaColors.accent],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Helium Recovery'),
            if (isTablet) ...[
              const SizedBox(width: 8),
              Text(
                'EA Innovation',
                style: TextStyle(
                  fontSize: 12,
                  color: EaColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
        actions: [
          Consumer<SyncProvider>(
            builder: (_, sync, __) => IconButton(
              onPressed: sync.syncing ? null : () => sync.syncNow(),
              icon: sync.syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      sync.isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      color: sync.isOnline ? EaColors.success : EaColors.danger,
                    ),
              tooltip: sync.isOnline ? 'Sincronizado' : 'Sin conexion',
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (isTablet)
            NavigationRail(
              extended: isDesktop,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              destinations: _railDestinations,
              leading: isDesktop
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          CircleAvatar(
                            backgroundColor: EaColors.primary.withOpacity(0.2),
                            child: const Icon(Icons.engineering_rounded,
                                color: EaColors.primary),
                          ),
                          const SizedBox(height: 8),
                          const Text('Ing. Armenta',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    )
                  : null,
            ),
          if (isTablet) const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _buildPage(_selectedIndex)),
        ],
      ),
      bottomNavigationBar: isTablet
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              destinations: _destinations,
              height: 65,
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            ),
    );
  }
}
