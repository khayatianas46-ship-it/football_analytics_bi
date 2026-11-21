
import 'package:flutter_test/flutter_test.dart';
import 'package:football_analytics_bi/main.dart';

void main() {
  testWidgets('Football Analytics BI dashboard test',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FootballAnalyticsApp());

    expect(find.text('Football Analytics'), findsOneWidget);
    expect(find.text('Dashboard Overview'), findsOneWidget);
  });
}
