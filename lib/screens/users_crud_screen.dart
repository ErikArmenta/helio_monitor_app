import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../config/theme.dart';

class UsersCrudScreen extends StatefulWidget {
  const UsersCrudScreen({super.key});

  @override
  State<UsersCrudScreen> createState() => _UsersCrudScreenState();
}

class _UsersCrudScreenState extends State<UsersCrudScreen> {
  final _supabase = Supabase.instance.client;
  List<UserProfile> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _loading = true);
    try {
      final response = await _supabase.from('user_profiles').select().order('created_at', ascending: false);
      setState(() {
        _users = (response as List).map((data) => UserProfile.fromSupabase(data)).toList();
      });
    } catch (e) {
      debugPrint('Error fetching users: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateRole(String id, AppRole newRole) async {
    try {
      await _supabase.from('user_profiles').update({'role': newRole.name}).eq('id', id);
      _fetchUsers();
    } catch (e) {
      debugPrint('Error updating role: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración de Usuarios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUsers,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: EaColors.primary.withOpacity(0.2),
                child: const Icon(Icons.person, color: EaColors.primary),
              ),
              title: Text(user.fullName),
              subtitle: Text(user.email),
              trailing: DropdownButton<AppRole>(
                value: user.role,
                underline: const SizedBox(),
                items: AppRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (newRole) {
                  if (newRole != null && newRole != user.role) {
                    _updateRole(user.id, newRole);
                  }
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Nuevo Usuario'),
              content: const Text('Por seguridad, los nuevos usuarios deben registrarse usando la pantalla de registro (o puedes crearlos en el Dashboard de Supabase). Una vez que existan, aparecerán aquí para asignarles un rol.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendido'),
                )
              ],
            ),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Aviso'),
      ),
    );
  }
}
