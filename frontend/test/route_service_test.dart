import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/route_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('create route sends its route code and allowed route codes', () async {
    late http.Request captured;
    final service = RouteService(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'id': 12,
            'routeNumber': 'BUS-12',
            'routeCode': 'R12',
            'routeName': 'North',
            'acType': 'AC',
            'allowedRoutes': ['R10'],
            'defaultAfternoon': false,
          }),
          200,
        );
      }),
    );

    await service.createRoute(
      routeNumber: 'BUS-12',
      routeCode: 'R12',
      routeName: 'North',
      acType: 'AC',
      allowedRoutes: ['R10'],
    );

    expect(captured.method, 'POST');
    expect(jsonDecode(captured.body), {
      'routeNumber': 'BUS-12',
      'routeCode': 'R12',
      'routeName': 'North',
      'acType': 'AC',
      'allowedRoutes': ['R10'],
    });
  });

  test('update route sends route code and allowed route codes', () async {
    late http.Request captured;
    final service = RouteService(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'id': 12,
            'routeNumber': 'BUS-12',
            'routeCode': 'R12',
            'routeName': 'Updated',
            'acType': 'AC',
            'allowedRoutes': ['R10', 'R11'],
            'defaultAfternoon': false,
          }),
          200,
        );
      }),
    );

    await service.updateRoute(
      id: 12,
      routeNumber: 'BUS-12',
      routeCode: 'R12',
      routeName: 'Updated',
      acType: 'AC',
      allowedRoutes: ['R10', 'R11'],
    );

    expect(captured.method, 'PUT');
    expect(jsonDecode(captured.body), {
      'routeNumber': 'BUS-12',
      'routeCode': 'R12',
      'routeName': 'Updated',
      'acType': 'AC',
      'allowedRoutes': ['R10', 'R11'],
    });
  });

  test('route response keeps ID, route number, and code distinct', () async {
    final service = RouteService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        return http.Response(
          jsonEncode([
            {
              'id': 7,
              'routeNumber': 'BUS-107',
              'routeCode': 'NORTH',
              'routeName': 'North',
              'acType': 'AC',
              'allowedRoutes': ['SOUTH'],
              'defaultAfternoon': false,
            },
          ]),
          200,
        );
      }),
    );

    final routes = await service.getRoutes();

    expect(routes, hasLength(1));
    expect(routes.single.id, 7);
    expect(routes.single.routeNumber, 'BUS-107');
    expect(routes.single.routeCode, 'NORTH');
    expect(routes.single.allowedRoutes, ['SOUTH']);
  });

  test('assignment range loading uses one inclusive range request', () async {
    var requestCount = 0;
    late Uri requestedUri;
    final service = RouteService(
      client: MockClient((request) async {
        requestCount++;
        requestedUri = request.url;
        return http.Response(
          jsonEncode([
            {'id': 7, 'routeId': 12, 'assignmentDate': '2026-11-01'},
            {'id': 8, 'routeId': 13, 'assignmentDate': '2026-11-30'},
          ]),
          200,
        );
      }),
    );

    final result = await service.getAssignmentsForRange(
      DateTime(2026, 11, 1),
      DateTime(2026, 11, 30),
    );

    expect(requestCount, 1);
    expect(requestedUri.queryParameters, {
      'date': '2026-11-01',
      'endDate': '2026-11-30',
    });
    expect(result[DateTime(2026, 11, 1)], hasLength(1));
    expect(result[DateTime(2026, 11, 30)], hasLength(1));
    expect(result[DateTime(2026, 11, 2)], isEmpty);
  });

  test('reversed date ranges fail before making a request', () async {
    var requestCount = 0;
    final service = RouteService(
      client: MockClient((request) async {
        requestCount++;
        return http.Response('[]', 200);
      }),
    );

    await expectLater(
      service.getAssignmentsForRange(
        DateTime(2026, 11, 30),
        DateTime(2026, 11, 1),
      ),
      throwsArgumentError,
    );
    expect(requestCount, 0);
  });

  test('assignment range errors are surfaced to the caller', () async {
    final service = RouteService(
      client: MockClient((request) async {
        return http.Response('unavailable', 503);
      }),
    );

    await expectLater(
      service.getAssignmentsForRange(
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 30),
      ),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('503'),
        ),
      ),
    );
  });
}
