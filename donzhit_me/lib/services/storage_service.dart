import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/traffic_report.dart';

/// Local storage service for caching reports and settings
class StorageService {
  static const String _reportsKey = 'traffic_reports';
  static const String _settingsKey = 'app_settings';
  static const String _draftKey = 'draft_report';

  // Singleton pattern
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  /// Initialize the storage service
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Ensure prefs is initialized
  Future<SharedPreferences> get prefs async {
    await init();
    return _prefs!;
  }

  /// Save a list of reports to local storage
  Future<bool> saveReports(List<TrafficReport> reports) async {
    final p = await prefs;
    final jsonList = reports.map((r) => r.toJson()).toList();
    return p.setString(_reportsKey, jsonEncode(jsonList));
  }

  /// Load all saved reports from local storage
  Future<List<TrafficReport>> loadReports() async {
    final p = await prefs;
    final jsonString = p.getString(_reportsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((r) => TrafficReport.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Add a single report to storage
  Future<bool> addReport(TrafficReport report) async {
    final reports = await loadReports();
    reports.insert(0, report);
    return saveReports(reports);
  }

  /// Update a report in storage
  Future<bool> updateReport(TrafficReport report) async {
    final reports = await loadReports();
    final index = reports.indexWhere((r) => r.id == report.id);
    if (index >= 0) {
      reports[index] = report;
      return saveReports(reports);
    }
    return false;
  }

  /// Delete a report from storage
  Future<bool> deleteReport(String id) async {
    final reports = await loadReports();
    reports.removeWhere((r) => r.id == id);
    return saveReports(reports);
  }

  /// Save a draft report
  Future<bool> saveDraft(TrafficReport report) async {
    final p = await prefs;
    return p.setString(_draftKey, jsonEncode(report.toJson()));
  }

  /// Load the draft report
  Future<TrafficReport?> loadDraft() async {
    final p = await prefs;
    final jsonString = p.getString(_draftKey);
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }
    try {
      return TrafficReport.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );
    } catch (e) {
      return null;
    }
  }

  /// Clear the draft report
  Future<bool> clearDraft() async {
    final p = await prefs;
    return p.remove(_draftKey);
  }

  /// Save app settings
  Future<bool> saveSettings(Map<String, dynamic> settings) async {
    final p = await prefs;
    return p.setString(_settingsKey, jsonEncode(settings));
  }

  /// Load app settings
  Future<Map<String, dynamic>> loadSettings() async {
    final p = await prefs;
    final jsonString = p.getString(_settingsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return _defaultSettings;
    }
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return _defaultSettings;
    }
  }

  /// Default settings
  static const Map<String, dynamic> _defaultSettings = {
    'darkMode': false,
    'notifications': true,
    'defaultState': '',
    'autoSaveDraft': true,
  };

  /// Clear all data
  Future<bool> clearAll() async {
    final p = await prefs;
    return p.clear();
  }
}
