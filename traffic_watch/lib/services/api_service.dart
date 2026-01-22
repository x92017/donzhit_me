import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
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

  // Google Sign-In instance for IAP authentication
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: kIsWeb
        ? '976110980114-fvr3a1snaptljv5ei3o297kep52eof9u.apps.googleusercontent.com'
        : null, // Android uses OAuth client from google-services.json
    serverClientId: '976110980114-fvr3a1snaptljv5ei3o297kep52eof9u.apps.googleusercontent.com',
  );

  // Cached authentication token
  String? _cachedToken;
  DateTime? _tokenExpiry;

  // Current signed-in user
  GoogleSignInAccount? _currentUser;

  /// Initialize the service and attempt silent sign-in
  Future<void> initialize() async {
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      _currentUser = account;
      if (account == null) {
        _cachedToken = null;
        _tokenExpiry = null;
      }
    });

    // Try silent sign-in
    await _googleSignIn.signInSilently();
  }

  /// Sign in with Google
  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      return account != null;
    } catch (e) {
      if (kDebugMode) {
        print('Google Sign-In error: $e');
      }
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _cachedToken = null;
    _tokenExpiry = null;
  }

  /// Check if user is signed in
  bool get isSignedIn => _currentUser != null;

  /// Get current user email
  String? get userEmail => _currentUser?.email;

  /// Get IAP JWT token for authentication
  Future<String?> _getIAPToken() async {
    // Return cached token if still valid (with 5 minute buffer)
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        _tokenExpiry!.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      return _cachedToken;
    }

    // In development mode, return a mock token
    if (kDebugMode && _baseUrl == _developmentUrl) {
      return 'dev-mode-token';
    }

    // Get fresh authentication
    final account = _currentUser ?? await _googleSignIn.signInSilently();
    if (account == null) {
      return null;
    }

    final auth = await account.authentication;

    // The ID token can be used for IAP authentication
    // For production, you might need to exchange this for an IAP-specific token
    _cachedToken = auth.idToken;
    _tokenExpiry = DateTime.now().add(const Duration(hours: 1));

    return _cachedToken;
  }

  /// Get headers with IAP authentication
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getIAPToken();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      // IAP expects the JWT in this header
      headers['X-Goog-IAP-JWT-Assertion'] = token;
      // Also add standard Authorization header as fallback
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// POST a new traffic report
  /// Returns the created report with server-assigned ID
  Future<ApiResponse<TrafficReport>> submitReport(TrafficReport report) async {
    try {
      final url = Uri.parse('$_baseUrl/reports');
      final headers = await _getHeaders();

      final response = await _client.post(
        url,
        headers: headers,
        body: jsonEncode(report.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final createdReport = TrafficReport.fromJson(data['data'] ?? data);
        return ApiResponse.success(createdReport);
      } else if (response.statusCode == 401) {
        // Token expired or invalid, clear cache and retry once
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
      final token = await _getIAPToken();
      request.headers.addAll({
        'Accept': 'application/json',
      });

      if (token != null) {
        request.headers['X-Goog-IAP-JWT-Assertion'] = token;
        request.headers['Authorization'] = 'Bearer $token';
      }

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final createdReport = TrafficReport.fromJson(data['data'] ?? data);
        return ApiResponse.success(createdReport);
      } else if (response.statusCode == 401) {
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
