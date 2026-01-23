import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/traffic_report.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Provider for managing traffic reports state
class ReportProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final Uuid _uuid = const Uuid();

  List<TrafficReport> _reports = [];
  TrafficReport? _currentDraft;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<TrafficReport> get reports => _reports;
  TrafficReport? get currentDraft => _currentDraft;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Statistics
  int get totalReports => _reports.length;
  int get submittedReports =>
      _reports.where((r) => r.status == ReportStatus.submitted).length;
  int get draftReports =>
      _reports.where((r) => r.status == ReportStatus.draft).length;
  int get reviewedReports =>
      _reports.where((r) => r.status == ReportStatus.reviewed).length;

  /// Initialize the provider
  Future<void> init() async {
    await _loadLocalReports();
    await _loadDraft();
  }

  /// Load reports from local storage
  Future<void> _loadLocalReports() async {
    _setLoading(true);
    try {
      _reports = await _storageService.loadReports();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load reports: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load draft from local storage
  Future<void> _loadDraft() async {
    _currentDraft = await _storageService.loadDraft();
    notifyListeners();
  }

  /// Fetch reports from API
  Future<void> fetchReports() async {
    _setLoading(true);
    _clearError();

    final response = await _apiService.getReports();

    if (response.isSuccess && response.data != null) {
      _reports = response.data!;
      await _storageService.saveReports(_reports);
    } else {
      _setError(response.error ?? 'Failed to fetch reports');
    }

    _setLoading(false);
  }

  /// Submit a new report
  Future<bool> submitReport(TrafficReport report, {List<File>? files}) async {
    _setLoading(true);
    _clearError();

    // Create a copy with generated ID and timestamps
    final newReport = report.copyWith(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      status: ReportStatus.submitting,
    );

    // Add to local list immediately for optimistic UI
    _reports.insert(0, newReport);
    notifyListeners();

    try {
      ApiResponse<TrafficReport> response;

      if (files != null && files.isNotEmpty) {
        response = await _apiService.submitReportWithMedia(newReport, files);
      } else {
        response = await _apiService.submitReport(newReport);
      }

      if (response.isSuccess && response.data != null) {
        // Update with server response
        final index = _reports.indexWhere((r) => r.id == newReport.id);
        if (index >= 0) {
          _reports[index] = response.data!.copyWith(
            status: ReportStatus.submitted,
          );
        }
        await _storageService.saveReports(_reports);
        await _storageService.clearDraft();
        _currentDraft = null;
        _setLoading(false);
        return true;
      } else {
        // Mark as failed
        final index = _reports.indexWhere((r) => r.id == newReport.id);
        if (index >= 0) {
          _reports[index] = newReport.copyWith(status: ReportStatus.failed);
        }
        await _storageService.saveReports(_reports);
        _setError(response.error ?? 'Failed to submit report');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      // Mark as failed on exception
      final index = _reports.indexWhere((r) => r.id == newReport.id);
      if (index >= 0) {
        _reports[index] = newReport.copyWith(status: ReportStatus.failed);
      }
      await _storageService.saveReports(_reports);
      _setError('Error submitting report: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Save report locally (without submitting to API)
  Future<bool> saveReportLocally(TrafficReport report) async {
    try {
      final newReport = report.copyWith(
        id: report.id ?? _uuid.v4(),
        createdAt: report.createdAt ?? DateTime.now(),
        status: ReportStatus.draft,
      );

      _reports.insert(0, newReport);
      await _storageService.saveReports(_reports);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to save report: $e');
      return false;
    }
  }

  /// Save current draft
  Future<void> saveDraft(TrafficReport draft) async {
    _currentDraft = draft;
    await _storageService.saveDraft(draft);
    notifyListeners();
  }

  /// Clear current draft
  Future<void> clearDraft() async {
    _currentDraft = null;
    await _storageService.clearDraft();
    notifyListeners();
  }

  /// Delete a report
  Future<bool> deleteReport(String id) async {
    _setLoading(true);
    _clearError();

    final report = _reports.firstWhere(
      (r) => r.id == id,
      orElse: () => throw Exception('Report not found'),
    );

    // Remove locally immediately
    _reports.removeWhere((r) => r.id == id);
    notifyListeners();

    // If it was submitted, also delete from server
    if (report.status == ReportStatus.submitted) {
      final response = await _apiService.deleteReport(id);
      if (!response.isSuccess) {
        // Restore if server deletion failed
        _reports.add(report);
        _setError(response.error ?? 'Failed to delete report');
        _setLoading(false);
        return false;
      }
    }

    await _storageService.saveReports(_reports);
    _setLoading(false);
    return true;
  }

  /// Retry submitting a failed report
  Future<bool> retrySubmit(String id) async {
    final index = _reports.indexWhere((r) => r.id == id);
    if (index < 0) return false;

    final report = _reports[index];
    if (report.status != ReportStatus.failed) return false;

    // Remove from list and resubmit
    _reports.removeAt(index);
    notifyListeners();

    return submitReport(report);
  }

  /// Get reports by status
  List<TrafficReport> getReportsByStatus(ReportStatus status) {
    return _reports.where((r) => r.status == status).toList();
  }

  /// Get reports by event type
  List<TrafficReport> getReportsByEventType(String eventType) {
    return _reports.where((r) => r.eventType == eventType).toList();
  }

  /// Search reports
  List<TrafficReport> searchReports(String query) {
    final lowerQuery = query.toLowerCase();
    return _reports.where((r) {
      return r.title.toLowerCase().contains(lowerQuery) ||
          r.description.toLowerCase().contains(lowerQuery) ||
          r.eventType.toLowerCase().contains(lowerQuery) ||
          r.state.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
}
