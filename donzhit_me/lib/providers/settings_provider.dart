import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';

/// Provider for managing app settings
class SettingsProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();

  bool _darkMode = true; // Default to dark mode
  bool _notifications = true;
  String _defaultState = '';
  bool _autoSaveDraft = true;
  String _localeCode = 'en'; // Default to English

  // Getters
  bool get darkMode => _darkMode;
  bool get notifications => _notifications;
  String get defaultState => _defaultState;
  bool get autoSaveDraft => _autoSaveDraft;
  String get localeCode => _localeCode;
  Locale get locale => Locale(_localeCode);

  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;

  /// Initialize settings from storage
  Future<void> init() async {
    final settings = await _storageService.loadSettings();
    _darkMode = settings['darkMode'] as bool? ?? true; // Default to dark mode
    _notifications = settings['notifications'] as bool? ?? true;
    _defaultState = settings['defaultState'] as String? ?? '';
    _autoSaveDraft = settings['autoSaveDraft'] as bool? ?? true;
    _localeCode = settings['localeCode'] as String? ?? 'en';
    notifyListeners();
  }

  /// Toggle dark mode
  Future<void> toggleDarkMode() async {
    _darkMode = !_darkMode;
    await _saveSettings();
    notifyListeners();
  }

  /// Set dark mode
  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    await _saveSettings();
    notifyListeners();
  }

  /// Toggle notifications
  Future<void> toggleNotifications() async {
    _notifications = !_notifications;
    await _saveSettings();
    notifyListeners();
  }

  /// Set notifications
  Future<void> setNotifications(bool value) async {
    _notifications = value;
    await _saveSettings();
    notifyListeners();
  }

  /// Set default state
  Future<void> setDefaultState(String state) async {
    _defaultState = state;
    await _saveSettings();
    notifyListeners();
  }

  /// Set auto save draft
  Future<void> setAutoSaveDraft(bool value) async {
    _autoSaveDraft = value;
    await _saveSettings();
    notifyListeners();
  }

  /// Set locale code
  Future<void> setLocale(String localeCode) async {
    _localeCode = localeCode;
    await _saveSettings();
    notifyListeners();
  }

  /// Save settings to storage
  Future<void> _saveSettings() async {
    await _storageService.saveSettings({
      'darkMode': _darkMode,
      'notifications': _notifications,
      'defaultState': _defaultState,
      'autoSaveDraft': _autoSaveDraft,
      'localeCode': _localeCode,
    });
  }

  /// Reset all settings to defaults
  Future<void> resetSettings() async {
    _darkMode = true; // Default to dark mode
    _notifications = true;
    _defaultState = '';
    _autoSaveDraft = true;
    _localeCode = 'en';
    await _saveSettings();
    notifyListeners();
  }
}
