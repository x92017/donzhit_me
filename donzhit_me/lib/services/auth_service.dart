import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';

/// Service for managing JWT-based authentication
class AuthService {
  static const String _tokenKey = 'donzhit_jwt_token';
  static const String _userKey = 'donzhit_user';
  static const String _expiresAtKey = 'donzhit_token_expires_at';

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  String? _cachedToken;
  User? _cachedUser;
  DateTime? _expiresAt;

  final List<VoidCallback> _authStateListeners = [];

  /// Add a listener for auth state changes
  void addAuthStateListener(VoidCallback listener) {
    _authStateListeners.add(listener);
  }

  /// Remove an auth state listener
  void removeAuthStateListener(VoidCallback listener) {
    _authStateListeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _authStateListeners) {
      listener();
    }
  }

  /// Get the current JWT token
  Future<String?> getToken() async {
    if (_cachedToken != null && !_isTokenExpired()) {
      return _cachedToken;
    }

    _cachedToken = await _secureStorage.read(key: _tokenKey);
    final expiresAtStr = await _secureStorage.read(key: _expiresAtKey);
    if (expiresAtStr != null) {
      _expiresAt = DateTime.fromMillisecondsSinceEpoch(int.parse(expiresAtStr));
    }

    // If token is expired or not found, just return null
    // Don't call clearAuth() here as it can cause race conditions during login
    if (_isTokenExpired()) {
      return null;
    }

    return _cachedToken;
  }

  /// Get the current user
  Future<User?> getUser() async {
    if (_cachedUser != null) return _cachedUser;

    final userJson = await _secureStorage.read(key: _userKey);
    if (userJson != null) {
      try {
        _cachedUser = User.fromJson(jsonDecode(userJson));
      } catch (e) {
        if (kDebugMode) print('Failed to parse cached user: $e');
      }
    }
    return _cachedUser;
  }

  /// Check if the user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && !_isTokenExpired();
  }

  /// Check if the current user is an admin
  bool get isAdmin => _cachedUser?.isAdmin ?? false;

  /// Check if user has contributor or higher access
  bool get isContributor => _cachedUser?.isContributor ?? false;

  /// Get the user's role
  UserRole? get userRole => _cachedUser?.role;

  /// Get the user's email
  String? get userEmail => _cachedUser?.email;

  /// Get the cached user (sync)
  User? get currentUser => _cachedUser;

  bool _isTokenExpired() {
    if (_expiresAt == null) return true;
    // Consider token expired 5 minutes before actual expiry
    return DateTime.now().isAfter(_expiresAt!.subtract(const Duration(minutes: 5)));
  }

  /// Save authentication data
  Future<void> saveAuth({
    required String token,
    required User user,
    required int expiresAt,
  }) async {
    _cachedToken = token;
    _cachedUser = user;
    _expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);

    await _secureStorage.write(key: _tokenKey, value: token);
    await _secureStorage.write(key: _userKey, value: jsonEncode(user.toJson()));
    await _secureStorage.write(
        key: _expiresAtKey, value: _expiresAt!.millisecondsSinceEpoch.toString());

    if (kDebugMode) {
      print('Auth saved: user=${user.email}, role=${user.role}, expires=$_expiresAt');
    }

    _notifyListeners();
  }

  /// Clear authentication data
  Future<void> clearAuth() async {
    _cachedToken = null;
    _cachedUser = null;
    _expiresAt = null;

    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userKey);
    await _secureStorage.delete(key: _expiresAtKey);

    if (kDebugMode) {
      print('Auth cleared');
    }

    _notifyListeners();
  }

  /// Initialize the service (load cached data)
  Future<void> initialize() async {
    await getToken();
    await getUser();
    if (kDebugMode) {
      print('AuthService initialized: isAuthenticated=${_cachedToken != null}, user=${_cachedUser?.email}');
    }
  }
}
