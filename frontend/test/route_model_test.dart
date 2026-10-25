import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/route_model.dart';

void main() {
  const routes = [
    RouteModel(
      id: 1,
      routeNumber: 'BUS-101',
      routeCode: 'RTE-A',
      routeName: 'North',
      acType: 'AC',
      allowedRoutes: [],
      defaultAfternoon: false,
    ),
    RouteModel(
      id: 2,
      routeNumber: 'BUS-202',
      routeCode: 'RTE-B',
      routeName: 'South',
      acType: 'NON_AC',
      allowedRoutes: [],
      defaultAfternoon: false,
    ),
  ];

  test('resolves existing route codes without changing them', () {
    expect(resolveAllowedRouteCode('RTE-A', routes), 'RTE-A');
  });

  test('converts saved route numbers to their route codes', () {
    expect(resolveAllowedRouteCode('BUS-202', routes), 'RTE-B');
  });

  test('preserves allowed-route values that cannot be matched', () {
    expect(resolveAllowedRouteCode('LEGACY-UNKNOWN', routes), 'LEGACY-UNKNOWN');
  });

  test('reads route codes from the route API response', () {
    final route = RouteModel.fromJson({
      'id': 3,
      'routeNumber': 'BUS-303',
      'routeCode': 'RTE-C',
      'routeName': 'East',
      'acType': 'AC',
      'allowedRoutes': ['RTE-A'],
      'defaultAfternoon': true,
    });

    expect(route.routeCode, 'RTE-C');
    expect(route.allowedRoutes, ['RTE-A']);
  });

  test('keeps a missing route code visibly unavailable', () {
    final route = RouteModel.fromJson({
      'id': 4,
      'routeNumber': 'BUS-404',
      'routeName': 'West',
      'acType': 'AC',
      'allowedRoutes': [],
      'defaultAfternoon': false,
    });

    expect(route.routeCode, isEmpty);
  });
}
