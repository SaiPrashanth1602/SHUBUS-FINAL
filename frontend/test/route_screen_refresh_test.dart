import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/routes_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('route list refresh requires a user action', (tester) async {
    var routeRequests = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/admin/routes')) {
        routeRequests++;
      }
      return http.Response(
        jsonEncode([]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: RoutesScreen()));
      await tester.pumpAndSettle();
      expect(routeRequests, 1);

      await tester.pump(const Duration(minutes: 30));
      expect(routeRequests, 1);

      await tester.tap(find.byTooltip('Refresh routes'));
      await tester.pumpAndSettle();
      expect(routeRequests, 2);
    }, () => client);
  });

  testWidgets('route list shows an error when the API request fails', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => http.Response('service unavailable', 503),
    );

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: RoutesScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to load routes'), findsWidgets);
      expect(find.textContaining('503'), findsWidgets);
    }, () => client);
  });
}
