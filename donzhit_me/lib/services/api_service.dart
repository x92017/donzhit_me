import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, VoidCallback;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/traffic_report.dart';
import '../models/user.dart';
import 'auth_service.dart';

/// API Service for handling RESTful operations with Google IAP authentication
class ApiService {
  // Base URL configuration
  // Production: Your Cloud Run service URL
  static const String _productionUrl =
      'https://traffic-watch-backend-stj2wh25xa-uc.a.run.app/v1';

  // Development: Local server
  static const String _developmentUrl = 'http://localhost:8080/v1';

  // Always use production URL (Cloud Run)
  static String get _baseUrl => _productionUrl;

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // HTTP client
  final http.Client _client = http.Client();

  // Auth service for JWT storage
  final AuthService _authService = AuthService();

  // Google Sign-In instance (v7.x API)
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // Client IDs for Google Sign-In
  static const String _webClientId =
      '976110980114-fvr3a1snaptljv5ei3o297kep52eof9u.apps.googleusercontent.com';

  // Cached authentication token
  String? _cachedToken;
  DateTime? _tokenExpiry;

  // Current signed-in user info
  String? _currentUserEmail;
  String? _currentUserDisplayName;
  bool _isInitialized = false;
  Future<void>? _initializeFuture;

  // Flag to ignore SignOut events during token caching
  // (Credential Manager can emit spurious SignOut events during authorization)
  bool _ignoringSignOutEvents = false;

  // Auth state change listeners
  final List<VoidCallback> _authStateListeners = [];
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;

  /// Add a listener to be notified when auth state changes
  void addAuthStateListener(VoidCallback listener) {
    _authStateListeners.add(listener);
  }

  /// Remove an auth state listener
  void removeAuthStateListener(VoidCallback listener) {
    _authStateListeners.remove(listener);
  }

  void _notifyAuthStateListeners() {
    for (final listener in _authStateListeners) {
      listener();
    }
  }

  /// Handle authentication events from the new v7.x API
  void _handleAuthenticationEvent(GoogleSignInAuthenticationEvent event) {
    if (kDebugMode) {
      print('Auth event received: ${event.runtimeType}');
    }
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn():
        final user = event.user;
        if (kDebugMode) {
          print('SignIn event - email: ${user.email}');
        }
        _currentUserEmail = user.email;
        _currentUserDisplayName = user.displayName;
        // Cache token from silent sign-in, then exchange for JWT
        _cacheTokenFromUser(user).then((_) async {
          // Exchange Google token for JWT
          if (_cachedToken != null) {
            if (kDebugMode) {
              print('Auto sign-in: Attempting JWT login...');
            }
            final loginSuccess = await _login(_cachedToken!);
            if (loginSuccess) {
              // Update email from JWT user info
              final jwtUser = _authService.currentUser;
              if (jwtUser != null) {
                _currentUserEmail = jwtUser.email;
              }
              if (kDebugMode) {
                print('Auto sign-in: JWT login succeeded');
              }
            } else {
              if (kDebugMode) {
                print('Auto sign-in: JWT login failed, using Google token');
              }
            }
          }
          _notifyAuthStateListeners();
        });
      case GoogleSignInAuthenticationEventSignOut():
        // Ignore SignOut events during token caching
        // (Credential Manager can emit spurious SignOut events during authorization)
        if (_ignoringSignOutEvents) {
          if (kDebugMode) {
            print('SignOut event ignored (during token caching)');
          }
          return;
        }
        if (kDebugMode) {
          print('SignOut event received - clearing user data');
        }
        _currentUserEmail = null;
        _currentUserDisplayName = null;
        _cachedToken = null;
        _tokenExpiry = null;
        _notifyAuthStateListeners();
    }
  }

  /// Initialize the service and attempt silent sign-in
  Future<void> initialize() {
    // Return existing future if already initializing or initialized
    if (_initializeFuture != null) return _initializeFuture!;

    _initializeFuture = _doInitialize();
    return _initializeFuture!;
  }

  Future<void> _doInitialize() async {
    if (_isInitialized) return;

    try {
      // Initialize AuthService first (loads cached JWT)
      await _authService.initialize();

      // If we have a valid JWT, restore user state
      final user = _authService.currentUser;
      if (user != null) {
        _currentUserEmail = user.email;
        if (kDebugMode) {
          print('Restored user from JWT: ${user.email}, role: ${user.role}');
        }
        // Notify listeners that user is already signed in
        _notifyAuthStateListeners();
      }

      // Initialize Google Sign-In with client IDs (v7.x API)
      // Note: serverClientId is not supported on Web
      await _googleSignIn.initialize(
        clientId: kIsWeb ? _webClientId : null,
        serverClientId: kIsWeb ? null : _webClientId,
      );

      // Listen to authentication events
      _authSubscription = _googleSignIn.authenticationEvents.listen(
        _handleAuthenticationEvent,
        onError: (error) {
          if (kDebugMode) {
            print('Google Sign-In stream error: $error');
          }
        },
      );

      // Only try silent Google auth if we don't already have a valid JWT
      if (user == null) {
        await _googleSignIn.attemptLightweightAuthentication();
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('Google Sign-In initialization error: $e');
      }
    }
  }

  /// Sign in with Google and exchange for JWT
  Future<bool> signIn() async {
    try {
      if (kDebugMode) {
        print('Starting Google Sign-In authenticate()...');
      }
      final result = await _googleSignIn.authenticate();
      if (kDebugMode) {
        print('Google Sign-In result: $result');
      }

      // Store user info directly in case event listener doesn't fire
      _currentUserEmail = result.email;
      _currentUserDisplayName = result.displayName;

      // Get and cache the Google token
      await _cacheTokenFromUser(result);

      // Exchange Google token for DonzHit.me JWT
      if (_cachedToken != null) {
        if (kDebugMode) {
          print('=== Attempting JWT login with Google token ===');
          print('Google token length: ${_cachedToken!.length}');
        }
        final loginSuccess = await _login(_cachedToken!);
        if (!loginSuccess) {
          if (kDebugMode) {
            print('=== JWT login FAILED, falling back to Google token ===');
          }
          // Fall back to using Google token directly if JWT login fails
        } else {
          if (kDebugMode) {
            print('=== JWT login SUCCEEDED ===');
          }
          // Update email from JWT user info (more authoritative)
          final user = _authService.currentUser;
          if (user != null) {
            _currentUserEmail = user.email;
          }
        }
      } else {
        if (kDebugMode) {
          print('=== WARNING: No Google token cached, cannot exchange for JWT ===');
        }
      }

      _notifyAuthStateListeners();

      return true;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Google Sign-In error: $e');
        print('Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Cache the token from a signed-in user
  Future<void> _cacheTokenFromUser(GoogleSignInAccount user) async {
    // Set flag to ignore SignOut events during authorization
    // (Credential Manager can emit spurious SignOut events)
    _ignoringSignOutEvents = true;
    try {
      final authClient = user.authorizationClient;
      if (kDebugMode) {
        print('Caching token from user during sign-in...');
        print('User email: ${user.email}');
      }

      // Request email and profile scopes
      final scopes = ['email', 'profile'];

      // First check if we already have authorization
      var authorization = await authClient.authorizationForScopes(scopes);

      // If not found, request authorization (this may show a popup on web)
      if (authorization == null) {
        if (kDebugMode) {
          print('No existing authorization, requesting new authorization...');
        }
        authorization = await authClient.authorizeScopes(scopes);
      }

      if (authorization != null) {
        _cachedToken = authorization.accessToken;
        _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
        if (kDebugMode) {
          print('Access token cached: ${_cachedToken?.substring(0, 20)}...');
        }
      } else {
        if (kDebugMode) {
          print('No access token available');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error caching token during sign-in: $e');
      }
    } finally {
      _ignoringSignOutEvents = false;
    }
  }

  /// Exchange Google token for DonzHit.me JWT
  Future<bool> _login(String googleToken) async {
    try {
      final url = Uri.parse('$_baseUrl/auth/login');
      if (kDebugMode) {
        print('=== _login() called ===');
        print('Login URL: $url');
        print('Google token length: ${googleToken.length}');
        print('Making POST request...');
      }

      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'googleToken': googleToken}),
      );

      if (kDebugMode) {
        print('Login response status: ${response.statusCode}');
        print('Login response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String;
        final expiresAt = data['expiresAt'] as int;
        final userData = data['user'] as Map<String, dynamic>;
        final user = User.fromJson(userData);

        if (kDebugMode) {
          print('Received JWT from backend (length: ${token.length})');
          print('JWT preview: ${token.substring(0, token.length > 50 ? 50 : token.length)}...');
          print('User: ${user.email}, role: ${user.role}');
          print('Expires at: $expiresAt (${DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)})');
        }

        // Save JWT and user info
        await _authService.saveAuth(
          token: token,
          user: user,
          expiresAt: expiresAt,
        );

        // Verify it was saved correctly
        final savedToken = await _authService.getToken();
        if (kDebugMode) {
          print('Verified saved token: ${savedToken != null ? "OK (${savedToken.length} chars)" : "FAILED"}');
        }

        return true;
      } else {
        if (kDebugMode) {
          print('Login failed: ${response.statusCode} - ${response.body}');
        }
        return false;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('=== Login EXCEPTION ===');
        print('Error: $e');
        print('Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    // Clear JWT first
    await _authService.clearAuth();

    // Disconnect from Google
    await _googleSignIn.disconnect();
    _currentUserEmail = null;
    _currentUserDisplayName = null;
    _cachedToken = null;
    _tokenExpiry = null;
    _notifyAuthStateListeners();
  }

  /// Check if user is signed in (has valid JWT)
  bool get isSignedIn => _authService.currentUser != null || _currentUserEmail != null;

  /// Get current user email
  String? get userEmail => _authService.userEmail ?? _currentUserEmail;

  /// Get current user display name
  String? get userDisplayName => _currentUserDisplayName;

  /// Get current user (from JWT)
  User? get currentUser => _authService.currentUser;

  /// Get current user's role
  UserRole? get userRole => _authService.userRole;

  /// Check if current user is an admin
  bool get isAdmin => _authService.isAdmin;

  /// Check if current user is a contributor or higher
  bool get isContributor => _authService.isContributor;

  /// Get JWT token for authentication
  /// Prefers DonzHit.me JWT, falls back to Google token
  Future<String?> _getAuthToken() async {
    // First, try to get JWT from AuthService
    final jwt = await _authService.getToken();
    if (jwt != null) {
      if (kDebugMode) {
        print('Using JWT from AuthService (length: ${jwt.length})');
        print('JWT preview: ${jwt.substring(0, jwt.length > 50 ? 50 : jwt.length)}...');
      }
      return jwt;
    }

    if (kDebugMode) {
      print('No JWT available from AuthService');
      print('AuthService currentUser: ${_authService.currentUser?.email}');
      print('AuthService userRole: ${_authService.userRole}');
    }

    // Fallback: Return cached Google token if still valid (for backwards compatibility)
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        _tokenExpiry!.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      if (kDebugMode) {
        print('Using cached Google token (fallback)');
      }
      return _cachedToken;
    }

    // In development mode, return a mock token
    if (kDebugMode && _baseUrl == _developmentUrl) {
      return 'dev-mode-token';
    }

    // If not signed in, return null - user needs to sign in first
    if (!isSignedIn) {
      if (kDebugMode) {
        print('Not signed in, cannot get token');
      }
      return null;
    }

    // Token expired or not cached - user needs to sign in again
    if (kDebugMode) {
      print('Token expired or not available. User needs to sign in again.');
    }
    return null;
  }

  /// Get headers with JWT authentication
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getAuthToken();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      if (kDebugMode) {
        print('Using access token for auth');
      }
      // Standard Authorization header with Bearer token
      headers['Authorization'] = 'Bearer $token';
    } else {
      if (kDebugMode) {
        print('WARNING: No token available for authentication');
      }
    }

    return headers;
  }

  /// POST a new traffic report
  /// Returns the created report with server-assigned ID
  Future<ApiResponse<TrafficReport>> submitReport(TrafficReport report) async {
    try {
      final url = Uri.parse('$_baseUrl/reports');
      if (kDebugMode) {
        print('submitReport: Getting headers...');
      }
      final headers = await _getHeaders();
      if (kDebugMode) {
        print('submitReport: Making POST request to $url');
      }

      final response = await _client.post(
        url,
        headers: headers,
        body: jsonEncode(report.toJson()),
      );

      if (kDebugMode) {
        print('submitReport: Response status ${response.statusCode}');
        print('submitReport: Response body: ${response.body}');
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final createdReport = TrafficReport.fromJson(data['data'] ?? data);
        return ApiResponse.success(createdReport);
      } else if (response.statusCode == 401) {
        // Token expired or invalid, clear cache
        if (kDebugMode) {
          print('submitReport: 401 received, clearing token cache');
        }
        await _authService.clearAuth();
        _cachedToken = null;
        _tokenExpiry = null;
        return ApiResponse.error(
          'Authentication required. Please sign in again.',
          statusCode: response.statusCode,
        );
      } else {
        // Try to parse error message from response body
        String errorMsg = 'Failed to submit report: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          if (errorData['message'] != null) {
            errorMsg = errorData['message'];
          }
          if (kDebugMode) {
            print('API Error: ${response.body}');
          }
        } catch (_) {}
        return ApiResponse.error(
          errorMsg,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST report with multipart file upload
  /// Use this when uploading media files along with the report
  Future<ApiResponse<TrafficReport>> submitReportWithMedia(
    TrafficReport report,
    List<File> files,
  ) async {
    try {
      if (kDebugMode) {
        print('submitReportWithMedia: Starting upload with ${files.length} files');
      }
      final url = Uri.parse('$_baseUrl/reports');
      final request = http.MultipartRequest('POST', url);

      // Add report data as fields
      request.fields['title'] = report.title;
      request.fields['description'] = report.description;
      request.fields['dateTime'] = report.dateTime.toIso8601String();
      request.fields['roadUsages'] = report.roadUsages.join(',');
      request.fields['eventTypes'] = report.eventTypes.join(',');
      request.fields['state'] = report.state;
      request.fields['city'] = report.city;
      request.fields['injuries'] = report.injuries;
      request.fields['retainMediaMetadata'] = report.retainMediaMetadata.toString();

      // Add files with the field name expected by the backend
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        if (!kIsWeb && await file.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'files', // Backend expects 'files' field name
              file.path,
            ),
          );
        }
      }

      // Add headers with JWT authentication
      if (kDebugMode) {
        print('submitReportWithMedia: Getting token...');
      }
      final token = await _getAuthToken();
      if (kDebugMode) {
        print('submitReportWithMedia: Token available: ${token != null}');
      }
      request.headers.addAll({
        'Accept': 'application/json',
      });

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      } else {
        if (kDebugMode) {
          print('submitReportWithMedia: WARNING - No token available!');
        }
      }

      if (kDebugMode) {
        print('submitReportWithMedia: Sending request to $url');
      }
      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (kDebugMode) {
        print('submitReportWithMedia: Response status ${response.statusCode}');
        print('submitReportWithMedia: Response body: ${response.body}');
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final createdReport = TrafficReport.fromJson(data['data'] ?? data);
        return ApiResponse.success(createdReport);
      } else if (response.statusCode == 401) {
        if (kDebugMode) {
          print('submitReportWithMedia: 401 received, clearing token cache');
        }
        await _authService.clearAuth();
        _cachedToken = null;
        _tokenExpiry = null;
        return ApiResponse.error(
          'Authentication required. Please sign in again.',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Failed to submit report: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('submitReportWithMedia: Exception: $e');
      }
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET all reports for the current user
  Future<ApiResponse<List<TrafficReport>>> getReports() async {
    try {
      final url = Uri.parse('$_baseUrl/reports');
      final headers = await _getHeaders();

      final response = await _client.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Backend returns { reports: [...], count: N }
        final reportsList = data['reports'] ?? data['data'] ?? [];
        final reports = (reportsList as List<dynamic>)
            .map((r) => TrafficReport.fromJson(r as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(reports);
      } else if (response.statusCode == 401) {
        await _authService.clearAuth();
        _cachedToken = null;
        _tokenExpiry = null;
        return ApiResponse.error(
          'Authentication required. Please sign in again.',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Failed to fetch reports: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET a single report by ID
  Future<ApiResponse<TrafficReport>> getReport(String id) async {
    try {
      final url = Uri.parse('$_baseUrl/reports/$id');
      final headers = await _getHeaders();

      final response = await _client.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final report = TrafficReport.fromJson(data['data'] ?? data);
        return ApiResponse.success(report);
      } else if (response.statusCode == 401) {
        await _authService.clearAuth();
        _cachedToken = null;
        _tokenExpiry = null;
        return ApiResponse.error(
          'Authentication required. Please sign in again.',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Failed to fetch report: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// DELETE a report by ID
  Future<ApiResponse<void>> deleteReport(String id) async {
    try {
      final url = Uri.parse('$_baseUrl/reports/$id');
      final headers = await _getHeaders();

      final response = await _client.delete(url, headers: headers);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse.success(null);
      } else if (response.statusCode == 401) {
        await _authService.clearAuth();
        _cachedToken = null;
        _tokenExpiry = null;
        return ApiResponse.error(
          'Authentication required. Please sign in again.',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Failed to delete report: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Health check endpoint (no auth required)
  Future<bool> healthCheck() async {
    try {
      final url = Uri.parse('$_baseUrl/health');
      final response = await _client.get(url);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ============================================================================
  // Public Endpoints (no auth required)
  // ============================================================================

  /// GET approved reports for public feed (no auth required)
  Future<ApiResponse<List<TrafficReport>>> getApprovedReports() async {
    try {
      final url = Uri.parse('$_baseUrl/public/reports');

      final response = await _client.get(url, headers: {
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final reportsList = data['reports'] ?? data['data'] ?? [];
        final reports = (reportsList as List<dynamic>)
            .map((r) => TrafficReport.fromJson(r as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(reports);
      } else {
        return ApiResponse.error(
          'Failed to fetch approved reports: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // ============================================================================
  // Admin Endpoints
  // ============================================================================

  /// GET all reports for admin dashboard (requires admin role)
  Future<ApiResponse<List<TrafficReport>>> getAllReportsAdmin() async {
    try {
      final url = Uri.parse('$_baseUrl/admin/reports');
      final headers = await _getHeaders();

      final response = await _client.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final reportsList = data['reports'] ?? data['data'] ?? [];
        final reports = (reportsList as List<dynamic>)
            .map((r) => TrafficReport.fromJson(r as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(reports);
      } else if (response.statusCode == 401) {
        await _authService.clearAuth();
        _cachedToken = null;
        _tokenExpiry = null;
        return ApiResponse.error(
          'Authentication required. Please sign in again.',
          statusCode: response.statusCode,
        );
      } else if (response.statusCode == 403) {
        return ApiResponse.error(
          'Admin access required.',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Failed to fetch admin reports: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// GET reports awaiting review (requires admin role)
  Future<ApiResponse<List<TrafficReport>>> getReportsForReview() async {
    try {
      final url = Uri.parse('$_baseUrl/admin/reports/review');
      final headers = await _getHeaders();

      final response = await _client.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final reportsList = data['reports'] ?? data['data'] ?? [];
        final reports = (reportsList as List<dynamic>)
            .map((r) => TrafficReport.fromJson(r as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(reports);
      } else if (response.statusCode == 401) {
        await _authService.clearAuth();
        _cachedToken = null;
        _tokenExpiry = null;
        return ApiResponse.error(
          'Authentication required. Please sign in again.',
          statusCode: response.statusCode,
        );
      } else if (response.statusCode == 403) {
        return ApiResponse.error(
          'Admin access required.',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Failed to fetch review queue: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// POST approve or reject a report (requires admin role)
  Future<ApiResponse<void>> reviewReport(
    String reportId, {
    required bool approve,
    String? reason,
    int? priority, // 1-5, only used when approving (1=highest priority)
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/admin/reports/$reportId/review');
      final headers = await _getHeaders();

      final body = {
        'status': approve ? 'reviewed_pass' : 'reviewed_fail',
        if (reason != null) 'reason': reason,
        if (approve && priority != null) 'priority': priority,
      };

      final response = await _client.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return ApiResponse.success(null);
      } else if (response.statusCode == 401) {
        await _authService.clearAuth();
        _cachedToken = null;
        _tokenExpiry = null;
        return ApiResponse.error(
          'Authentication required. Please sign in again.',
          statusCode: response.statusCode,
        );
      } else if (response.statusCode == 403) {
        return ApiResponse.error(
          'Admin access required.',
          statusCode: response.statusCode,
        );
      } else if (response.statusCode == 404) {
        return ApiResponse.error(
          'Report not found.',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Failed to review report: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // ============================================================================
  // Reactions Endpoints
  // ============================================================================

  /// Add a reaction to a report (requires auth)
  Future<ApiResponse<void>> addReaction(String reportId, ReactionType type) async {
    try {
      final url = Uri.parse('$_baseUrl/reports/$reportId/reactions');
      final headers = await _getHeaders();

      final response = await _client.post(
        url,
        headers: headers,
        body: jsonEncode({'reactionType': type.apiValue}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return ApiResponse.success(null);
      } else if (response.statusCode == 401) {
        return ApiResponse.error(
          'Please sign in to react.',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Failed to add reaction: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Remove a reaction from a report (requires auth)
  Future<ApiResponse<void>> removeReaction(String reportId, ReactionType type) async {
    try {
      final url = Uri.parse('$_baseUrl/reports/$reportId/reactions/${type.apiValue}');
      final headers = await _getHeaders();

      final response = await _client.delete(url, headers: headers);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse.success(null);
      } else if (response.statusCode == 401) {
        return ApiResponse.error(
          'Please sign in to react.',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Failed to remove reaction: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Get engagement data for a report (public, but user reactions require auth)
  Future<ApiResponse<ReportEngagement>> getReportEngagement(String reportId) async {
    try {
      final url = Uri.parse('$_baseUrl/public/reports/$reportId/engagement');

      // Get headers with optional auth
      final headers = <String, String>{
        'Accept': 'application/json',
      };
      final token = await _getAuthToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _client.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.success(ReportEngagement.fromJson(data));
      } else {
        return ApiResponse.error(
          'Failed to get engagement: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Get engagement data for multiple reports (public, but user reactions require auth)
  Future<ApiResponse<Map<String, ReportEngagement>>> getBulkEngagement(List<String> reportIds) async {
    try {
      final url = Uri.parse('$_baseUrl/public/reports/engagement');

      // Get headers with optional auth
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final token = await _getAuthToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _client.post(
        url,
        headers: headers,
        body: jsonEncode({'reportIds': reportIds}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final engagementsJson = data['engagements'] as Map<String, dynamic>? ?? {};
        final engagements = <String, ReportEngagement>{};
        for (final entry in engagementsJson.entries) {
          engagements[entry.key] = ReportEngagement.fromJson(entry.value as Map<String, dynamic>);
        }
        return ApiResponse.success(engagements);
      } else {
        return ApiResponse.error(
          'Failed to get bulk engagement: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // ============================================================================
  // Comments Endpoints
  // ============================================================================

  /// Add a comment to a report (requires auth)
  Future<ApiResponse<Comment>> addComment(String reportId, String content) async {
    try {
      final url = Uri.parse('$_baseUrl/reports/$reportId/comments');
      final headers = await _getHeaders();

      final response = await _client.post(
        url,
        headers: headers,
        body: jsonEncode({'content': content}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.success(Comment.fromJson(data));
      } else if (response.statusCode == 401) {
        return ApiResponse.error(
          'Please sign in to comment.',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Failed to add comment: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Get comments for a report (public)
  Future<ApiResponse<List<Comment>>> getComments(String reportId) async {
    try {
      final url = Uri.parse('$_baseUrl/public/reports/$reportId/comments');

      final response = await _client.get(url, headers: {
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final commentsList = data['comments'] as List<dynamic>? ?? [];
        final comments = commentsList
            .map((c) => Comment.fromJson(c as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(comments);
      } else {
        return ApiResponse.error(
          'Failed to get comments: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Delete a comment (requires auth, only owner can delete)
  Future<ApiResponse<void>> deleteComment(String reportId, String commentId) async {
    try {
      final url = Uri.parse('$_baseUrl/reports/$reportId/comments/$commentId');
      final headers = await _getHeaders();

      final response = await _client.delete(url, headers: headers);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse.success(null);
      } else if (response.statusCode == 401) {
        return ApiResponse.error(
          'Please sign in to delete comments.',
          statusCode: response.statusCode,
        );
      } else if (response.statusCode == 404) {
        return ApiResponse.error(
          'Comment not found or not authorized.',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse.error(
          'Failed to delete comment: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Dispose the client when done
  void dispose() {
    _authSubscription?.cancel();
    _client.close();
  }
}

/// Generic API response wrapper
class ApiResponse<T> {
  final T? data;
  final String? error;
  final int? statusCode;
  final bool isSuccess;

  ApiResponse._({
    this.data,
    this.error,
    this.statusCode,
    required this.isSuccess,
  });

  factory ApiResponse.success(T data) {
    return ApiResponse._(data: data, isSuccess: true);
  }

  factory ApiResponse.error(String message, {int? statusCode}) {
    return ApiResponse._(
      error: message,
      statusCode: statusCode,
      isSuccess: false,
    );
  }
}

/// API exception for error handling
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}
