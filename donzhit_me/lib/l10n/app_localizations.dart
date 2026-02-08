import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'DonzHit.me'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get navReport;

  /// No description provided for @navPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get navPosts;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get navAdmin;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Report pedestrian/traffic violations'**
  String get homeSubtitle;

  /// No description provided for @allLocations.
  ///
  /// In en, this message translates to:
  /// **'All Locations'**
  String get allLocations;

  /// No description provided for @stateProvince.
  ///
  /// In en, this message translates to:
  /// **'State/Province'**
  String get stateProvince;

  /// No description provided for @cityOptional.
  ///
  /// In en, this message translates to:
  /// **'City (Optional)'**
  String get cityOptional;

  /// No description provided for @filterByCity.
  ///
  /// In en, this message translates to:
  /// **'Filter by city in {state}'**
  String filterByCity(String state);

  /// No description provided for @eventTypeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get eventTypeAll;

  /// No description provided for @eventTypePedestrianIntersection.
  ///
  /// In en, this message translates to:
  /// **'Pedestrian Intersection'**
  String get eventTypePedestrianIntersection;

  /// No description provided for @eventTypeRedLight.
  ///
  /// In en, this message translates to:
  /// **'Red Light'**
  String get eventTypeRedLight;

  /// No description provided for @eventTypeSpeeding.
  ///
  /// In en, this message translates to:
  /// **'Speeding'**
  String get eventTypeSpeeding;

  /// No description provided for @eventTypeOnPhone.
  ///
  /// In en, this message translates to:
  /// **'On Phone'**
  String get eventTypeOnPhone;

  /// No description provided for @eventTypeReckless.
  ///
  /// In en, this message translates to:
  /// **'Reckless'**
  String get eventTypeReckless;

  /// No description provided for @uploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get uploaded;

  /// No description provided for @incident.
  ///
  /// In en, this message translates to:
  /// **'Incident'**
  String get incident;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign In with Google'**
  String get signInWithGoogle;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed. Please try again.'**
  String get signInFailed;

  /// No description provided for @signInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign In Required'**
  String get signInRequired;

  /// No description provided for @signInToReport.
  ///
  /// In en, this message translates to:
  /// **'Help make our roads safer by reporting dangerous driving behavior'**
  String get signInToReport;

  /// No description provided for @signInTo.
  ///
  /// In en, this message translates to:
  /// **'Sign in to:'**
  String get signInTo;

  /// No description provided for @benefitUploadMedia.
  ///
  /// In en, this message translates to:
  /// **'Upload videos & photos of incidents'**
  String get benefitUploadMedia;

  /// No description provided for @benefitReportDetails.
  ///
  /// In en, this message translates to:
  /// **'Report location and incident details'**
  String get benefitReportDetails;

  /// No description provided for @benefitTrackReports.
  ///
  /// In en, this message translates to:
  /// **'Track your submitted reports'**
  String get benefitTrackReports;

  /// No description provided for @benefitReactComment.
  ///
  /// In en, this message translates to:
  /// **'React and comment on reports'**
  String get benefitReactComment;

  /// No description provided for @privacyNote.
  ///
  /// In en, this message translates to:
  /// **'Your privacy is important. We only use your email for authentication.'**
  String get privacyNote;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report a Traffic Violation'**
  String get reportTitle;

  /// No description provided for @reportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fill out the form below with details about the incident'**
  String get reportSubtitle;

  /// No description provided for @reportATrafficIncident.
  ///
  /// In en, this message translates to:
  /// **'Report a Traffic Incident'**
  String get reportATrafficIncident;

  /// No description provided for @formTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get formTitle;

  /// No description provided for @formTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a brief title for the incident'**
  String get formTitleHint;

  /// No description provided for @formTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get formTitleRequired;

  /// No description provided for @formDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get formDescription;

  /// No description provided for @formDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe what happened in detail'**
  String get formDescriptionHint;

  /// No description provided for @formDescriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a description'**
  String get formDescriptionRequired;

  /// No description provided for @formDateTime.
  ///
  /// In en, this message translates to:
  /// **'Date/Time'**
  String get formDateTime;

  /// No description provided for @formRoadUsage.
  ///
  /// In en, this message translates to:
  /// **'Road Usage (select all that apply)'**
  String get formRoadUsage;

  /// No description provided for @formRoadUsageRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one road usage type'**
  String get formRoadUsageRequired;

  /// No description provided for @formEventType.
  ///
  /// In en, this message translates to:
  /// **'Event Type (select all that apply)'**
  String get formEventType;

  /// No description provided for @formEventTypeRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one event type'**
  String get formEventTypeRequired;

  /// No description provided for @formInjuries.
  ///
  /// In en, this message translates to:
  /// **'Any Injuries'**
  String get formInjuries;

  /// No description provided for @formInjuriesHint.
  ///
  /// In en, this message translates to:
  /// **'Describe any injuries that occurred (or \"None\")'**
  String get formInjuriesHint;

  /// No description provided for @formInjuriesRequired.
  ///
  /// In en, this message translates to:
  /// **'Please describe any injuries (or enter \"None\")'**
  String get formInjuriesRequired;

  /// No description provided for @formStateRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a state or province'**
  String get formStateRequired;

  /// No description provided for @submitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get submitReport;

  /// No description provided for @submitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get submitting;

  /// No description provided for @reportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report submitted successfully!'**
  String get reportSubmitted;

  /// No description provided for @reportSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit report'**
  String get reportSubmitFailed;

  /// No description provided for @yourPastPosts.
  ///
  /// In en, this message translates to:
  /// **'Your Past Posts'**
  String get yourPastPosts;

  /// No description provided for @searchReports.
  ///
  /// In en, this message translates to:
  /// **'Search reports...'**
  String get searchReports;

  /// No description provided for @noReportsFound.
  ///
  /// In en, this message translates to:
  /// **'No reports found'**
  String get noReportsFound;

  /// No description provided for @noReportsYet.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t submitted any reports yet'**
  String get noReportsYet;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @spanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get spanish;

  /// No description provided for @defaultStateProvince.
  ///
  /// In en, this message translates to:
  /// **'Default State/Province'**
  String get defaultStateProvince;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @pendingReports.
  ///
  /// In en, this message translates to:
  /// **'Pending Reports'**
  String get pendingReports;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear Filters'**
  String get clearFilters;

  /// No description provided for @noApprovedReports.
  ///
  /// In en, this message translates to:
  /// **'No approved reports yet'**
  String get noApprovedReports;

  /// No description provided for @noMatchingReports.
  ///
  /// In en, this message translates to:
  /// **'No approved reports match your filters'**
  String get noMatchingReports;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @addComment.
  ///
  /// In en, this message translates to:
  /// **'Add a comment...'**
  String get addComment;

  /// No description provided for @pleaseSignInToComment.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to comment'**
  String get pleaseSignInToComment;

  /// No description provided for @pleaseSignInToReact.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to react'**
  String get pleaseSignInToReact;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
