import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/afternoon_assignment_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'assignment discovery loads a year range and refresh is manual without duplicate requests',
    (tester) async {
      final requestedUris = <Uri>[];
      final mutationMethods = <String>[];
      final repeatedRangeResponse = Completer<http.Response>();
      final today = DateUtils.dateOnly(DateTime.now());
      String date(DateTime value) {
        return value.toIso8601String().substring(0, 10);
      }

      final client = MockClient((request) async {
        requestedUris.add(request.url);
        if (request.method != 'GET') {
          mutationMethods.add(request.method);
        }
        if (request.url.path.endsWith('/afternoon-routes') &&
            requestedUris
                    .where((uri) => uri.path.endsWith('/afternoon-routes'))
                    .length ==
                2) {
          return repeatedRangeResponse.future;
        }
        return http.Response(
          jsonEncode([]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: AfternoonAssignmentScreen())),
        );
        await tester.pumpAndSettle();

        List<Uri> rangeRequests() => requestedUris
            .where((uri) => uri.path.endsWith('/afternoon-routes'))
            .toList();

        expect(rangeRequests(), hasLength(1));
        expect(
          rangeRequests().single.queryParameters['date'],
          date(today.add(const Duration(days: 1))),
        );
        expect(
          rangeRequests().single.queryParameters['endDate'],
          date(today.add(const Duration(days: 365))),
        );

        await tester.pump(const Duration(minutes: 30));
        expect(rangeRequests(), hasLength(1));
        expect(mutationMethods, isEmpty);

        await tester.tap(find.byTooltip('Refresh assignments'));
        await tester.pump();
        expect(rangeRequests(), hasLength(2));

        await tester.tap(find.byTooltip('Refresh assignments'));
        await tester.pump();
        expect(rangeRequests(), hasLength(2));

        repeatedRangeResponse.complete(
          http.Response(
            jsonEncode([]),
            200,
            headers: {'content-type': 'application/json'},
          ),
        );
        await tester.pumpAndSettle();
      }, () => client);
    },
  );

  testWidgets('assignment loading displays a useful API error', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/admin/routes')) {
        return http.Response('[]', 200);
      }
      if (request.url.path.endsWith('/afternoon-routes')) {
        return http.Response('service unavailable', 503);
      }
      return http.Response('[]', 200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AfternoonAssignmentScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not load schedules'), findsOneWidget);
      expect(find.textContaining('503'), findsOneWidget);
    }, () => client);
  });

  testWidgets('manual assignment refresh preserves the route search filter', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/admin/routes')) {
        return http.Response(
          jsonEncode([
            {
              'id': 4,
              'routeNumber': 'BUS-4',
              'routeCode': 'R4',
              'routeName': 'North',
              'acType': 'AC',
              'allowedRoutes': [],
              'defaultAfternoon': false,
            },
          ]),
          200,
        );
      }
      return http.Response(
        jsonEncode([]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AfternoonAssignmentScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final routeSearch = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText ==
                'Search route number, destination or AC type',
      );
      expect(routeSearch, findsOneWidget);
      await tester.enterText(routeSearch, 'North');
      await tester.tap(find.byTooltip('Refresh assignments'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(routeSearch).controller!.text,
        'North',
      );
    }, () => client);
  });
}
