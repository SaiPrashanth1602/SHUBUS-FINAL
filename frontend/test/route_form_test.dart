import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/route_model.dart';
import 'package:frontend/widgets/route_form.dart';

void main() {
  const currentRoute = RouteModel(
    id: 1,
    routeNumber: 'BUS-101',
    routeCode: 'RTE-A',
    routeName: 'North',
    acType: 'AC',
    allowedRoutes: ['RTE-B'],
    defaultAfternoon: false,
  );
  const allowedRoute = RouteModel(
    id: 2,
    routeNumber: 'BUS-202',
    routeCode: 'RTE-B',
    routeName: 'South',
    acType: 'NON_AC',
    allowedRoutes: [],
    defaultAfternoon: false,
  );

  testWidgets('shows saved route codes under the allowed routes heading', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RouteForm(
          route: currentRoute,
          allRoutes: [currentRoute, allowedRoute],
        ),
      ),
    );

    expect(find.text('ALLOWED AFTERNOON ROUTES'), findsOneWidget);
    expect(find.text('Selected routes'), findsOneWidget);
    expect(find.text('RTE-B'), findsNWidgets(2));
    expect(find.text('BUS-202'), findsNothing);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'RTE-B').last)
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('routeCodeField')))
          .controller!
          .text,
      'RTE-A',
    );
  });

  testWidgets('does not render an empty option when a route code is missing', (
    tester,
  ) async {
    const routeWithoutCode = RouteModel(
      id: 3,
      routeNumber: 'BUS-303',
      routeCode: '',
      routeName: 'East',
      acType: 'AC',
      allowedRoutes: [],
      defaultAfternoon: false,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: RouteForm(allRoutes: [currentRoute, routeWithoutCode]),
      ),
    );

    expect(find.text('Route code unavailable'), findsOneWidget);
    expect(find.text('BUS-303'), findsNothing);
    expect(
      find.text(
        'Some routes have no route code from the server. Refresh or update those route records before selecting them.',
      ),
      findsOneWidget,
    );
  });
}
