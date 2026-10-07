import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('SHUBUS Admin app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ShubusAdminApp());

    expect(find.text('SHUBUS'), findsOneWidget);
    expect(find.text('Admin Panel Login'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
  });
}
