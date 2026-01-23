import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/dropdown_options.dart';
import '../providers/settings_provider.dart';
import '../providers/report_provider.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Appearance Section
              _buildSectionHeader(context, 'Appearance'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Enable dark theme'),
                      secondary: const Icon(Icons.dark_mode),
                      value: settings.darkMode,
                      onChanged: (value) => settings.setDarkMode(value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Notifications Section
              _buildSectionHeader(context, 'Notifications'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Push Notifications'),
                      subtitle: const Text('Receive updates on your reports'),
                      secondary: const Icon(Icons.notifications),
                      value: settings.notifications,
                      onChanged: (value) => settings.setNotifications(value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Default Values Section
              _buildSectionHeader(context, 'Default Values'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.location_on),
                      title: const Text('Default State/Province'),
                      subtitle: Text(
                        settings.defaultState.isEmpty
                            ? 'Not set'
                            : settings.defaultState,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showStateSelector(context, settings),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Auto-save Drafts'),
                      subtitle:
                          const Text('Automatically save form data as draft'),
                      secondary: const Icon(Icons.save),
                      value: settings.autoSaveDraft,
                      onChanged: (value) => settings.setAutoSaveDraft(value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Data Section
              _buildSectionHeader(context, 'Data'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: const Text('Clear All Drafts'),
                      subtitle: const Text('Remove all saved drafts'),
                      onTap: () => _clearDrafts(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_forever,
                          color: Colors.red),
                      title: const Text(
                        'Clear All Data',
                        style: TextStyle(color: Colors.red),
                      ),
                      subtitle: const Text('Delete all reports and settings'),
                      onTap: () => _clearAllData(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // About Section
              _buildSectionHeader(context, 'About'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Version'),
                      subtitle: const Text('1.0.0'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: const Text('Privacy Policy'),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () => _showPrivacyPolicy(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.gavel_outlined),
                      title: const Text('Terms of Service'),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () => _showTermsOfService(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: const Text('Help & Support'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showHelpSupport(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Reset Section
              Center(
                child: TextButton(
                  onPressed: () => _resetSettings(context, settings),
                  child: const Text('Reset to Default Settings'),
                ),
              ),
              const SizedBox(height: 32),

              // App Logo/Branding
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.traffic,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'DonzHit.me',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Report traffic violations safely',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          fontSize: 14,
        ),
      ),
    );
  }

  void _showStateSelector(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Default State',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      settings.setDefaultState('');
                      Navigator.pop(context);
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  // US States Header
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.grey[200],
                    child: const Text(
                      'United States',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  ...DropdownOptions.usStates.map(
                    (state) => ListTile(
                      title: Text(state),
                      trailing: settings.defaultState == state
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () {
                        settings.setDefaultState(state);
                        Navigator.pop(context);
                      },
                    ),
                  ),

                  // Canadian Provinces Header
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.grey[200],
                    child: const Text(
                      'Canada',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  ...DropdownOptions.canadianProvinces.map(
                    (province) => ListTile(
                      title: Text(province),
                      trailing: settings.defaultState == province
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () {
                        settings.setDefaultState(province);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearDrafts(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Drafts'),
        content: const Text(
            'This will remove all saved drafts. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ReportProvider>().clearDraft();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Drafts cleared')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _clearAllData(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
            'This will delete all your reports, drafts, and settings. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await StorageService().clearAll();
              if (context.mounted) {
                await context.read<SettingsProvider>().init();
                await context.read<ReportProvider>().init();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data cleared')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            '''Privacy Policy for DonzHit.me

Last updated: January 2024

1. Information We Collect
We collect information you provide when reporting traffic violations, including:
- Incident details (title, description, date/time)
- Location information (state/province)
- Media files (photos and videos)

2. How We Use Your Information
- To process and manage traffic violation reports
- To improve our services
- To communicate with you about your reports

3. Data Storage
Your reports are stored securely on our servers and may be shared with relevant authorities.

4. Your Rights
You have the right to:
- Access your data
- Request deletion of your data
- Update your information

5. Contact Us
For privacy-related inquiries, contact us at privacy@donzhit.me
''',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            '''Terms of Service for DonzHit.me

Last updated: January 2024

1. Acceptance of Terms
By using DonzHit.me, you agree to these terms.

2. Use of Service
- You must provide accurate information
- You must not submit false reports
- You are responsible for the content you upload

3. Content Guidelines
- Only submit genuine traffic violations
- Do not include personal identifying information of others
- Media must be captured legally and safely

4. Disclaimer
DonzHit.me is a reporting tool and does not guarantee action on reports.

5. Limitation of Liability
We are not liable for any damages arising from the use of this service.

6. Changes to Terms
We may update these terms at any time. Continued use constitutes acceptance.

7. Contact
For questions, contact support@donzhit.me
''',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelpSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Help & Support',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email Support'),
              subtitle: const Text('support@donzhit.me'),
              onTap: () {
                // Implement email intent
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('FAQ'),
              subtitle: const Text('Frequently asked questions'),
              onTap: () {
                Navigator.pop(context);
                _showFAQ(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.feedback),
              title: const Text('Send Feedback'),
              subtitle: const Text('Help us improve'),
              onTap: () {
                Navigator.pop(context);
                _showFeedbackDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFAQ(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('FAQ'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFAQItem(
                'How do I submit a report?',
                'Tap the "+" button to create a new report. Fill in all required fields and upload any photos or videos, then tap Submit.',
              ),
              _buildFAQItem(
                'What happens after I submit?',
                'Your report is sent to our system for review. You can track its status in the History section.',
              ),
              _buildFAQItem(
                'Can I edit a submitted report?',
                'Once submitted, reports cannot be edited. You can delete and create a new one if needed.',
              ),
              _buildFAQItem(
                'Is my information private?',
                'Yes, we take privacy seriously. Please review our Privacy Policy for details.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(answer),
        ],
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Tell us what you think...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you for your feedback!')),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _resetSettings(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
            'This will reset all settings to their default values.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              settings.resetSettings();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
