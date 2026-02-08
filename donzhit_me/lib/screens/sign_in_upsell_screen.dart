import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../widgets/donzhit_logo.dart';
import '../widgets/platform_sign_in_button.dart';

class SignInUpsellScreen extends StatefulWidget {
  const SignInUpsellScreen({super.key});

  @override
  State<SignInUpsellScreen> createState() => _SignInUpsellScreenState();
}

class _SignInUpsellScreenState extends State<SignInUpsellScreen> {
  static const double _maxContentWidth = 700.0;
  final ApiService _apiService = ApiService();
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    _apiService.initialize();
  }

  Future<void> _handleSignIn() async {
    if (_isSigningIn) return;

    setState(() {
      _isSigningIn = true;
    });

    try {
      final success = await _apiService.signIn();
      if (!success && mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.signInFailed ?? 'Sign in failed. Please try again.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  Widget _wrapWithMaxWidth(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            // Header matching other screens
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.only(left: 24, right: 24, bottom: 11, top: 2),
                decoration: const BoxDecoration(
                  color: Colors.black,
                ),
                child: SafeArea(
                  bottom: false,
                  minimum: const EdgeInsets.only(top: 2),
                  child: _wrapWithMaxWidth(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            DonzHitLogoHorizontal(height: 62),
                            Spacer(),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Center(
                          child: Text(
                            l10n?.reportATrafficIncident ?? 'Report a Traffic Incident',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Content
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _wrapWithMaxWidth(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),

                      // Main headline
                      Text(
                        l10n?.signInRequired ?? 'Sign In Required',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        l10n?.signInToReport ?? 'Help make our roads safer by reporting dangerous driving behavior',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Benefits card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(
                                l10n?.signInTo ?? 'Sign in to:',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildBenefitRow(
                                Icons.videocam,
                                l10n?.benefitUploadMedia ?? 'Upload videos & photos of incidents',
                                colorScheme,
                              ),
                              const SizedBox(height: 16),
                              _buildBenefitRow(
                                Icons.location_on,
                                l10n?.benefitReportDetails ?? 'Report location and incident details',
                                colorScheme,
                              ),
                              const SizedBox(height: 16),
                              _buildBenefitRow(
                                Icons.history,
                                l10n?.benefitTrackReports ?? 'Track your submitted reports',
                                colorScheme,
                              ),
                              const SizedBox(height: 16),
                              _buildBenefitRow(
                                Icons.thumb_up,
                                l10n?.benefitReactComment ?? 'React and comment on reports',
                                colorScheme,
                              ),
                              const SizedBox(height: 24),

                              // Sign in button
                              SizedBox(
                                width: double.infinity,
                                child: _isSigningIn
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : _buildSignInButton(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Privacy note
                      Text(
                        l10n?.privacyNote ?? 'Your privacy is important. We only use your email for authentication.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInButton() {
    // On web, use the Google-rendered sign-in button
    if (kIsWeb) {
      return buildGoogleSignInButton();
    }

    final l10n = AppLocalizations.of(context);

    // On mobile platforms, use a custom button
    return ElevatedButton.icon(
      onPressed: _handleSignIn,
      icon: const Icon(Icons.login, size: 20),
      label: Text(l10n?.signInWithGoogle ?? 'Sign In with Google'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text, ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15),
          ),
        ),
      ],
    );
  }
}
