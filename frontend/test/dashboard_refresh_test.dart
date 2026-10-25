import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/admin_dashboard_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'dashboard loads one range, next-date details, and refreshes manually',
    (tester) async {
      final requestedUris = <Uri>[];
      final today = DateUtils.dateOnly(DateTime.now());
      final nextDate = today.add(const Duration(days: 1));
      final laterDate = today.add(const Duration(days: 3));
      final manualRangeResponse = Completer<http.Response>();
      String date(DateTime value) {
        return value.toIso8601String().substring(0, 10);
      }

      final client = MockClient((request) async {
        requestedUris.add(request.url);
        if (request.url.path.endsWith('/afternoon-routes')) {
          if (requestedUris
                  .where((uri) => uri.path.endsWith('/afternoon-routes'))
                  .length ==
              2) {
            return manualRangeResponse.future;
          }
          return http.Response(
            jsonEncode([
              {'id': 1, 'assignmentDate': date(nextDate)},
              {'id': 2, 'assignmentDate': date(laterDate)},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/admin/schedule')) {
          return http.Response(
            jsonEncode([
              {
                'routeNumber': 'BUS-1',
                'routeCode': 'R1',
                'routeName': 'North',
                'totalSeats': 50,
                'bookedSeats': 1,
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('[]', 200);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(home: AdminDashboardScreen()),
        );
        await tester.pumpAndSettle();

        List<Uri> requestsFor(String suffix) =>
            requestedUris.where((uri) => uri.path.endsWith(suffix)).toList();

        expect(requestsFor('/afternoon-routes'), hasLength(1));
        expect(requestsFor('/admin/schedule'), hasLength(1));
        expect(requestsFor('/afternoon-routes').single.queryParameters, {
          'date': date(nextDate),
          'endDate': date(today.add(const Duration(days: 90))),
        });
        expect(
          requestsFor('/admin/schedule').single.queryParameters['date'],
          date(nextDate),
        );

        await tester.tap(find.text('Routes'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Shuttle Operations'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(minutes: 30));
        expect(requestsFor('/afternoon-routes'), hasLength(1));
        expect(requestsFor('/admin/schedule'), hasLength(1));

        await tester.tap(find.byTooltip('Refresh operations'));
        await tester.pump();
        expect(requestsFor('/afternoon-routes'), hasLength(2));
        await tester.tap(find.byTooltip('Refresh operations'));
        await tester.pump();
        expect(requestsFor('/afternoon-routes'), hasLength(2));

        manualRangeResponse.complete(
          http.Response(
            jsonEncode([
              {'id': 1, 'assignmentDate': date(nextDate)},
              {'id': 2, 'assignmentDate': date(laterDate)},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          ),
        );
        await tester.pumpAndSettle();
        expect(requestsFor('/admin/schedule'), hasLength(2));
      }, () => client);
    },
  );

  testWidgets('dashboard shows a useful error when loading fails', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => http.Response('service unavailable', 503),
    );

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: AdminDashboardScreen()));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not refresh operations'),
        findsOneWidget,
      );
      expect(find.textContaining('503'), findsOneWidget);
    }, () => client);
  });

  testWidgets(
    'empty dashboard range shows an empty state without detail calls',
    (tester) async {
      final requestedUris = <Uri>[];
      final client = MockClient((request) async {
        requestedUris.add(request.url);
        return http.Response('[]', 200);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(home: AdminDashboardScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('No upcoming date found'), findsOneWidget);
        expect(
          requestedUris.where((uri) => uri.path.endsWith('/admin/schedule')),
          isEmpty,
        );
      }, () => client);
    },
  );
}
