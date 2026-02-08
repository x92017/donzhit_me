// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DonzHit.me';

  @override
  String get navHome => 'Home';

  @override
  String get navReport => 'Report';

  @override
  String get navPosts => 'Posts';

  @override
  String get navSettings => 'Settings';

  @override
  String get navAdmin => 'Admin';

  @override
  String get homeSubtitle => 'Report pedestrian/traffic violations';

  @override
  String get allLocations => 'All Locations';

  @override
  String get stateProvince => 'State/Province';

  @override
  String get cityOptional => 'City (Optional)';

  @override
  String filterByCity(String state) {
    return 'Filter by city in $state';
  }

  @override
  String get eventTypeAll => 'All';

  @override
  String get eventTypePedestrianIntersection => 'Pedestrian Intersection';

  @override
  String get eventTypeRedLight => 'Red Light';

  @override
  String get eventTypeSpeeding => 'Speeding';

  @override
  String get eventTypeOnPhone => 'On Phone';

  @override
  String get eventTypeReckless => 'Reckless';

  @override
  String get uploaded => 'Uploaded';

  @override
  String get incident => 'Incident';

  @override
  String get signIn => 'Sign In';

  @override
  String get signInWithGoogle => 'Sign In with Google';

  @override
  String get signOut => 'Sign Out';

  @override
  String get signInFailed => 'Sign in failed. Please try again.';

  @override
  String get signInRequired => 'Sign In Required';

  @override
  String get signInToReport =>
      'Help make our roads safer by reporting dangerous driving behavior';

  @override
  String get signInTo => 'Sign in to:';

  @override
  String get benefitUploadMedia => 'Upload videos & photos of incidents';

  @override
  String get benefitReportDetails => 'Report location and incident details';

  @override
  String get benefitTrackReports => 'Track your submitted reports';

  @override
  String get benefitReactComment => 'React and comment on reports';

  @override
  String get privacyNote =>
      'Your privacy is important. We only use your email for authentication.';

  @override
  String get reportTitle => 'Report a Traffic Violation';

  @override
  String get reportSubtitle =>
      'Fill out the form below with details about the incident';

  @override
  String get reportATrafficIncident => 'Report a Traffic Incident';

  @override
  String get formTitle => 'Title';

  @override
  String get formTitleHint => 'Enter a brief title for the incident';

  @override
  String get formTitleRequired => 'Please enter a title';

  @override
  String get formDescription => 'Description';

  @override
  String get formDescriptionHint => 'Describe what happened in detail';

  @override
  String get formDescriptionRequired => 'Please enter a description';

  @override
  String get formDateTime => 'Date/Time';

  @override
  String get formRoadUsage => 'Road Usage (select all that apply)';

  @override
  String get formRoadUsageRequired =>
      'Please select at least one road usage type';

  @override
  String get formEventType => 'Event Type (select all that apply)';

  @override
  String get formEventTypeRequired => 'Please select at least one event type';

  @override
  String get formInjuries => 'Any Injuries';

  @override
  String get formInjuriesHint =>
      'Describe any injuries that occurred (or \"None\")';

  @override
  String get formInjuriesRequired =>
      'Please describe any injuries (or enter \"None\")';

  @override
  String get formStateRequired => 'Please select a state or province';

  @override
  String get submitReport => 'Submit Report';

  @override
  String get submitting => 'Submitting...';

  @override
  String get reportSubmitted => 'Report submitted successfully!';

  @override
  String get reportSubmitFailed => 'Failed to submit report';

  @override
  String get yourPastPosts => 'Your Past Posts';

  @override
  String get searchReports => 'Search reports...';

  @override
  String get noReportsFound => 'No reports found';

  @override
  String get noReportsYet => 'You haven\'t submitted any reports yet';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get spanish => 'Spanish';

  @override
  String get defaultStateProvince => 'Default State/Province';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get admin => 'Admin';

  @override
  String get pendingReports => 'Pending Reports';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String get clearFilters => 'Clear Filters';

  @override
  String get noApprovedReports => 'No approved reports yet';

  @override
  String get noMatchingReports => 'No approved reports match your filters';

  @override
  String get comments => 'Comments';

  @override
  String get addComment => 'Add a comment...';

  @override
  String get pleaseSignInToComment => 'Please sign in to comment';

  @override
  String get pleaseSignInToReact => 'Please sign in to react';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get close => 'Close';

  @override
  String get ok => 'OK';

  @override
  String get error => 'Error';

  @override
  String get loading => 'Loading...';

  @override
  String get retry => 'Retry';
}
