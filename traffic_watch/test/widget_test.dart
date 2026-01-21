import 'package:flutter_test/flutter_test.dart';
import 'package:traffic_watch/main.dart';

void main() {
  testWidgets('App loads and shows navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const TrafficWatchApp());
    await tester.pumpAndSettle();

    // Verify that the navigation bar is present
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Can navigate to Report screen', (WidgetTester tester) async {
    await tester.pumpWidget(const TrafficWatchApp());
    await tester.pumpAndSettle();

    // Tap on Report navigation item
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();

    // Verify Report screen is shown
    expect(find.text('Report Incident'), findsOneWidget);
  });
}
