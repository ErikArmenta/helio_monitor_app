enum AppRole { super_admin, supervisor, inspector }

class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final AppRole role;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.createdAt,
  });

  factory UserProfile.fromSupabase(Map<String, dynamic> data) {
    AppRole parsedRole;
    switch (data['role']) {
      case 'super_admin':
        parsedRole = AppRole.super_admin;
        break;
      case 'supervisor':
        parsedRole = AppRole.supervisor;
        break;
      case 'inspector':
      default:
        parsedRole = AppRole.inspector;
    }

    return UserProfile(
      id: data['id'] as String,
      email: data['email'] as String,
      fullName: data['full_name'] as String,
      role: parsedRole,
      createdAt: DateTime.parse(data['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role.name,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
