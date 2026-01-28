import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, VoidCallback;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/traffic_report.dart';

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
        // Cache token from silent sign-in as well
        _cacheTokenFromUser(user);
        _notifyAuthStateListeners();
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

      // Try lightweight (silent) authentication
      await _googleSignIn.attemptLightweightAuthentication();

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('Google Sign-In initialization error: $e');
      }
    }
  }

  /// Sign in with Google
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
      if (result != null) {
        _currentUserEmail = result.email;
        _currentUserDisplayName = result.displayName;

        // Get and cache the token immediately after sign-in
        // This prevents the need to call attemptLightweightAuthentication later
        // which can trigger spurious SignOut events from Credential Manager
        await _cacheTokenFromUser(result);

        _notifyAuthStateListeners();
      }

      return result != null;
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
      }

      // Request email and profile scopes
      final scopes = ['email', 'profile'];

      // First check if we already have authorization
      var authorization = await authClient.authorizationForScopes(scopes);

      // If not, request authorization
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
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error caching token during sign-in: $e');
      }
    } finally {
      _ignoringSignOutEvents = false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.disconnect();
    _currentUserEmail = null;
    _currentUserDisplayName = null;
    _cachedToken = null;
    _tokenExpiry = null;
    _notifyAuthStateListeners();
  }

  /// Check if user is signed in
  bool get isSignedIn => _currentUserEmail != null;

  /// Get current user email
  String? get userEmail => _currentUserEmail;

  /// Get current user display name
  String? get userDisplayName => _currentUserDisplayName;

  /// Admin email for entitlement checks
  static const String _adminEmail = 'jeffarbaugh@gmail.com';

  /// Check if current user is an admin
  bool get isAdmin => _currentUserEmail == _adminEmail;

  /// Get IAP JWT token for authentication
  Future<String?> _getIAPToken() async {
    // Return cached token if still valid (with 5 minute buffer)
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        _tokenExpiry!.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      if (kDebugMode) {
        print('Using cached token');
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
    // We don't call attemptLightweightAuthentication() here because it can
    // trigger spurious SignOut events from the Android Credential Manager
    if (kDebugMode) {
      print('Token expired or not available. User needs to sign in again.');
    }
    return null;
  }

  /// Get headers with IAP authentication
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getIAPToken();

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
      request.fields['roadUsage'] = report.roadUsage;
      request.fields['eventType'] = report.eventType;
      request.fields['state'] = report.state;
      request.fields['injuries'] = report.injuries;

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

      // Add headers with IAP authentication
      if (kDebugMode) {
        print('submitReportWithMedia: Getting token...');
      }
      final token = await _getIAPToken();
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
