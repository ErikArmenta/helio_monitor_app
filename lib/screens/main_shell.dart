import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_profile.dart';
import '../config/theme.dart';
import 'dashboard_screen.dart';
import 'new_reading_screen.dart';
import 'charts_screen.dart';
import 'ai_chat_screen.dart';
import 'ocr_screen.dart';
import 'readings_list_screen.dart';
import 'users_crud_screen.dart';

class NavItem {
  final IconData icon;
  final String label;
  final Widget screen;
  final List<AppRole> allowedRoles;

  NavItem(this.icon, this.label, this.screen, this.allowedRoles);
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  List<NavItem> get _availableItems {
    final role = context.watch<AuthProvider>().userProfile?.role ?? AppRole.inspector;
    final allItems = [
      NavItem(Icons.dashboard_rounded, 'Dashboard', const DashboardScreen(), [AppRole.super_admin, AppRole.supervisor]),
      NavItem(Icons.add_circle_outline_rounded, 'Lectura', const NewReadingScreen(), [AppRole.super_admin, AppRole.supervisor, AppRole.inspector]),
      NavItem(Icons.table_chart_rounded, 'Datos', const ReadingsListScreen(), [AppRole.super_admin, AppRole.supervisor]),
      NavItem(Icons.show_chart_rounded, 'Graficas', const ChartsScreen(), [AppRole.super_admin, AppRole.supervisor]),
      NavItem(Icons.smart_toy_rounded, 'Jarvis IA', const AiChatScreen(), [AppRole.super_admin]),
      NavItem(Icons.document_scanner_rounded, 'OCR', const OcrScreen(), [AppRole.super_admin, AppRole.inspector]),
      NavItem(Icons.group_rounded, 'Usuarios', const UsersCrudScreen(), [AppRole.super_admin]),
    ];
    return allItems.where((item) => item.allowedRoles.contains(role)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;
    final isDesktop = width >= 1100;
    final items = _availableItems;
    final authProfile = context.watch<AuthProvider>().userProfile;

    // Ensure selected index is within bounds if role changes
    if (_selectedIndex >= items.length) {
      _selectedIndex = 0;
    }

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
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthProvider>().signOut(),
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
              destinations: items.map((item) => NavigationRailDestination(
                icon: Icon(item.icon),
                label: Text(item.label),
              )).toList(),
              leading: isDesktop
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          CircleAvatar(
                            backgroundColor: EaColors.primary.withOpacity(0.2),
                            child: const Icon(Icons.person, color: EaColors.primary),
                          ),
                          const SizedBox(height: 8),
                          Text(authProfile?.fullName ?? 'Usuario', style: const TextStyle(fontSize: 12)),
                          Text(authProfile?.role.name.toUpperCase() ?? '', style: const TextStyle(fontSize: 10, color: EaColors.textSecondary)),
                        ],
                      ),
                    )
                  : null,
            ),
          if (isTablet) const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: items.isEmpty ? const Center(child: Text('Sin permisos')) : items[_selectedIndex].screen),
        ],
      ),
      bottomNavigationBar: isTablet
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              destinations: items.map((item) => NavigationDestination(
                icon: Icon(item.icon),
                label: item.label,
              )).toList(),
              height: 65,
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            ),
    );
  }
}
