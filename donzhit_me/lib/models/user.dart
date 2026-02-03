/// User role enumeration
enum UserRole {
  viewer,
  contributor,
  admin;

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'contributor':
        return UserRole.contributor;
      default:
        return UserRole.viewer;
    }
  }

  String toJson() => name;
}

/// User model for authenticated users
class User {
  final String id;
  final String email;
  final UserRole role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;

  User({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      role: UserRole.fromString(json['role'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'lastLoginAt': lastLoginAt?.toIso8601String(),
      };

  /// Check if user can access features requiring a specific role
  bool canAccess(UserRole requiredRole) {
    const hierarchy = {
      UserRole.viewer: 0,
      UserRole.contributor: 1,
      UserRole.admin: 2,
    };
    return hierarchy[role]! >= hierarchy[requiredRole]!;
  }

  /// Check if user is an admin
  bool get isAdmin => role == UserRole.admin;

  /// Check if user is a contributor or higher
  bool get isContributor => role == UserRole.contributor || role == UserRole.admin;
}
