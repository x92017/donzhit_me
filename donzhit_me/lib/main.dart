import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'providers/report_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/admin_screen.dart';
import 'screens/report_form_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sign_in_upsell_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure status bar and navigation bar are visible
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  // Configure status bar to be visible with light icons
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light, // Light icons for dark backgrounds
    statusBarBrightness: Brightness.dark, // For iOS
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(const DonzHitMeApp());
}

class DonzHitMeApp extends StatelessWidget {
  const DonzHitMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ReportProvider()..init()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'DonzHit.me',
            debugShowCheckedModeBanner: false,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            themeMode: settings.themeMode,
            locale: settings.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('es'),
            ],
            home: const MainNavigationScreen(),
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1565C0),
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1565C0),
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _apiService.initialize();
    _apiService.addAuthStateListener(_onAuthStateChanged);
  }

  @override
  void dispose() {
    _apiService.removeAuthStateListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (!mounted) return;

    setState(() {
      // Rebuild navigation when auth state changes
      // Determine screen count based on role:
      // - Viewer (not signed in): 3 screens (Home, Report/Upsell, Settings)
      // - Contributor: 4 screens (Home, Report, History, Settings)
      // - Admin: 5 screens (+ Admin)
      int screenCount;
      if (!_apiService.isSignedIn) {
        screenCount = 3;
      } else if (_apiService.isAdmin) {
        screenCount = 5;
      } else {
        screenCount = 4;
      }

      // Reset index if current tab is no longer available
      if (_currentIndex >= screenCount) {
        _currentIndex = 0;
      }
    });

    // Fetch reports from server when user signs in
    if (_apiService.isSignedIn) {
      context.read<ReportProvider>().fetchReports();
    }
  }

  List<Widget> _buildScreens() {
    final isSignedIn = _apiService.isSignedIn;
    final isAdmin = _apiService.isAdmin;
    debugPrint('Building screens - isAdmin: $isAdmin, isSignedIn: $isSignedIn, email: ${_apiService.userEmail}, role: ${_apiService.userRole}');

    // Viewer (not signed in): Home, Report (upsell), Settings
    if (!isSignedIn) {
      return const [
        GalleryScreen(),
        SignInUpsellScreen(),
        SettingsScreen(),
      ];
    }

    // Contributor (signed in): Home, Report, History, Settings
    final screens = <Widget>[
      const GalleryScreen(),
      const ReportFormScreen(),
      const HistoryScreen(),
      const SettingsScreen(),
    ];

    // Admin: Add Admin screen
    if (isAdmin) {
      screens.add(const AdminScreen());
    }

    return screens;
  }

  List<NavigationDestination> _buildDestinations(BuildContext context) {
    final isSignedIn = _apiService.isSignedIn;
    final isAdmin = _apiService.isAdmin;
    final l10n = AppLocalizations.of(context);

    // Viewer (not signed in): Home, Report, Settings
    if (!isSignedIn) {
      return [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home),
          label: l10n?.navHome ?? 'Home',
        ),
        NavigationDestination(
          icon: const Icon(Icons.add_circle_outline),
          selectedIcon: const Icon(Icons.add_circle),
          label: l10n?.navReport ?? 'Report',
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: l10n?.navSettings ?? 'Settings',
        ),
      ];
    }

    // Contributor (signed in): Home, Report, History, Settings
    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: l10n?.navHome ?? 'Home',
      ),
      NavigationDestination(
        icon: const Icon(Icons.add_circle_outline),
        selectedIcon: const Icon(Icons.add_circle),
        label: l10n?.navReport ?? 'Report',
      ),
      NavigationDestination(
        icon: const Icon(Icons.history_outlined),
        selectedIcon: const Icon(Icons.history),
        label: l10n?.navPosts ?? 'Posts',
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: l10n?.navSettings ?? 'Settings',
      ),
    ];

    // Admin: Add Admin destination
    if (isAdmin) {
      destinations.add(
        NavigationDestination(
          icon: const Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: const Icon(Icons.admin_panel_settings),
          label: l10n?.navAdmin ?? 'Admin',
        ),
      );
    }

    return destinations;
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens();
    final destinations = _buildDestinations(context);

    // Ensure current index is valid when admin status changes
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: destinations,
      ),
    );
  }
}
