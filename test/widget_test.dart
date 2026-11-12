import 'package:flutter_test/flutter_test.dart';
import 'package:mediready/main.dart';

void main() {
  testWidgets('MediReady app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MediReadyApp());

    expect(find.text('Welcome to MediReady'), findsOneWidget);
    expect(find.text('Patient Registration'), findsOneWidget);
    expect(find.text('My Medications'), findsOneWidget);
    expect(find.text('Pharmacy Staff Login'), findsOneWidget);
  });
}