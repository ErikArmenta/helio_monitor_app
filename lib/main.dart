import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/theme.dart';
import 'providers/readings_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/ai_chat_provider.dart';
import 'providers/auth_provider.dart';
import 'services/local_database_service.dart';
import 'services/supabase_service.dart';
import 'services/sync_service.dart';
import 'screens/main_shell.dart';
import 'screens/login_screen.dart';

const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://vhmuvxmmxsgayzkgtmmi.supabase.co',
);
const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  final localDb = LocalDatabaseService();
  try {
    await localDb.initialize();
  } catch (e) {
    debugPrint('Local DB init failed: $e');
  }

  final supabaseService = SupabaseService();
  final syncService = SyncService(localDb: localDb, remote: supabaseService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) => ReadingsProvider(localDb, supabaseService),
        ),
        ChangeNotifierProvider(create: (_) => SyncProvider(syncService)),
        ChangeNotifierProvider(create: (_) => AiChatProvider()),
      ],
      child: const HeliumRecoveryApp(),
    ),
  );
}

class HeliumRecoveryApp extends StatelessWidget {
  const HeliumRecoveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Helium Recovery System',
      debugShowCheckedModeBanner: false,
      theme: EaTheme.light,
      darkTheme: EaTheme.dark,
      themeMode: ThemeMode.dark,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (auth.isAuthenticated) {
            return const MainShell();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
