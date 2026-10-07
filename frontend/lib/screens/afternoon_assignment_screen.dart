import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../services/route_service.dart';

class AfternoonAssignmentScreen extends StatefulWidget {
  const AfternoonAssignmentScreen({super.key});

  @override
  State<AfternoonAssignmentScreen> createState() =>
      _AfternoonAssignmentScreenState();
}

class _AfternoonAssignmentScreenState extends State<AfternoonAssignmentScreen> {
  final RouteService routeService = RouteService();

  List<RouteModel> routes = [];
  List<dynamic> schedule = [];

  final Set<int> selectedRegularRoutes = {};
  final Set<int> selectedVelacheryRoutes = {};
  final Set<int> selectedAlandurRoutes = {};

  bool loading = true;
  bool assigning = false;

  @override
  void initState() {
    super.initState();
    loadScreen();
  }

  // ============================================================
  // LOAD EVERYTHING
  // ============================================================

  Future<void> loadScreen() async {
    setState(() {
      loading = true;
    });

    try {
      final tomorrow = DateTime.now().add(const Duration(days: 1));

      final routeData = await routeService.getRoutes();

      final scheduleData = await routeService.getTomorrowSchedule(tomorrow);

      setState(() {
        routes = routeData;
        schedule = scheduleData;

        selectedRegularRoutes.clear();
        selectedVelacheryRoutes.clear();
        selectedAlandurRoutes.clear();

        // Default routes are only pre-selected.
        // Existing DB assignments are NOT selected here.
        for (final route in routes) {
          if (route.defaultAfternoon) {
            selectedRegularRoutes.add(route.id);
          }
        }

        // Remove routes that are already assigned tomorrow
        // from the new-assignment selections.
        for (final bus in schedule) {
          final routeId = bus['routeId'];

          if (routeId == null) continue;

          selectedRegularRoutes.remove(routeId);
          selectedVelacheryRoutes.remove(routeId);
          selectedAlandurRoutes.remove(routeId);
        }

        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load afternoon data: $e')),
      );
    }
  }

  // ============================================================
  // TOMORROW DATE
  // ============================================================

  String get tomorrowLabel {
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    return '${tomorrow.day.toString().padLeft(2, '0')} '
        '${_monthName(tomorrow.month)} '
        '${tomorrow.year}';
  }

  String _monthName(int month) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];

    return months[month - 1];
  }

  // ============================================================
  // SCHEDULE FILTERS
  // ============================================================

  List<dynamic> get regularSchedule {
    return schedule.where((bus) => bus['assignmentType'] == 'REGULAR').toList();
  }

  List<dynamic> get velacherySchedule {
    return schedule
        .where(
          (bus) =>
              bus['assignmentType'] == 'SHUTTLE' &&
              bus['shuttleGroup'] == 'VELACHERY',
        )
        .toList();
  }

  List<dynamic> get alandurSchedule {
    return schedule
        .where(
          (bus) =>
              bus['assignmentType'] == 'SHUTTLE' &&
              bus['shuttleGroup'] == 'ALANDUR_METRO',
        )
        .toList();
  }

  // ============================================================
  // DE-ASSIGN
  // ============================================================

  Future<void> deassignRoute(int assignmentId) async {
    try {
      await routeService.deleteAssignment(assignmentId);

      await loadScreen();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route de-assigned successfully')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to de-assign route: $e')));
    }
  }

  // ============================================================
  // SCHEDULE ROUTE CARD
  // ============================================================

  Widget scheduleRouteCard(dynamic bus) {
    final int assignmentId = bus['assignmentId'];

    final String routeNumber = bus['routeNumber'];

    final String routeName = bus['routeName'];

    final String acType = bus['acType'];

    final int totalSeats = bus['totalSeats'];

    final int bookedSeats = bus['bookedSeats'];

    final int availableSeats = bus['availableSeats'];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          '$routeNumber - $routeName',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '$acType • '
          '$bookedSeats booked • '
          '$availableSeats available / '
          '$totalSeats',
        ),
        trailing: TextButton(
          onPressed: () {
            deassignRoute(assignmentId);
          },
          child: const Text('DE-ASSIGN'),
        ),
      ),
    );
  }

  // ============================================================
  // SCHEDULE SECTION
  // ============================================================

  Widget scheduleSection({
    required String title,
    required List<dynamic> buses,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${buses.length} routes assigned'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: buses.map((bus) => scheduleRouteCard(bus)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SELECTION
  // ============================================================

  void toggleRegularRoute(int id) {
    setState(() {
      if (selectedRegularRoutes.contains(id)) {
        selectedRegularRoutes.remove(id);
      } else {
        selectedRegularRoutes.add(id);
        selectedVelacheryRoutes.remove(id);
        selectedAlandurRoutes.remove(id);
      }
    });
  }

  void toggleVelacheryRoute(int id) {
    setState(() {
      if (selectedVelacheryRoutes.contains(id)) {
        selectedVelacheryRoutes.remove(id);
      } else {
        selectedVelacheryRoutes.add(id);
        selectedRegularRoutes.remove(id);
        selectedAlandurRoutes.remove(id);
      }
    });
  }

  void toggleAlandurRoute(int id) {
    setState(() {
      if (selectedAlandurRoutes.contains(id)) {
        selectedAlandurRoutes.remove(id);
      } else {
        selectedAlandurRoutes.add(id);
        selectedRegularRoutes.remove(id);
        selectedVelacheryRoutes.remove(id);
      }
    });
  }

  // ============================================================
  // AVAILABLE ROUTES
  // ============================================================

  List<RouteModel> get regularRoutes {
    return routes.where((route) {
      return !selectedVelacheryRoutes.contains(route.id) &&
          !selectedAlandurRoutes.contains(route.id) &&
          !isAssignedTomorrow(route.id);
    }).toList();
  }

  List<RouteModel> get velacheryRoutes {
    return routes.where((route) {
      return !selectedRegularRoutes.contains(route.id) &&
          !selectedAlandurRoutes.contains(route.id) &&
          !isAssignedTomorrow(route.id);
    }).toList();
  }

  List<RouteModel> get alandurRoutes {
    return routes.where((route) {
      return !selectedRegularRoutes.contains(route.id) &&
          !selectedVelacheryRoutes.contains(route.id) &&
          !isAssignedTomorrow(route.id);
    }).toList();
  }

  bool isAssignedTomorrow(int routeId) {
    return schedule.any((bus) => bus['routeId'] == routeId);
  }

  // ============================================================
  // SELECTED
  // ============================================================

  int get totalSelectedRoutes {
    return selectedRegularRoutes.length +
        selectedVelacheryRoutes.length +
        selectedAlandurRoutes.length;
  }

  List<RouteModel> get selectedRoutes {
    return routes.where((route) {
      return selectedRegularRoutes.contains(route.id) ||
          selectedVelacheryRoutes.contains(route.id) ||
          selectedAlandurRoutes.contains(route.id);
    }).toList();
  }

  String selectedType(int id) {
    if (selectedRegularRoutes.contains(id)) {
      return 'Regular';
    }

    if (selectedVelacheryRoutes.contains(id)) {
      return 'Velachery';
    }

    return 'Alandur Metro';
  }

  // ============================================================
  // ASSIGN
  // ============================================================

  Future<void> assignAllRoutes() async {
    if (totalSelectedRoutes == 0 || assigning) {
      return;
    }

    setState(() {
      assigning = true;
    });

    try {
      final tomorrow = DateTime.now().add(const Duration(days: 1));

      if (selectedRegularRoutes.isNotEmpty) {
        await routeService.assignRoutes(
          date: tomorrow,
          routeIds: selectedRegularRoutes.toList(),
          assignmentType: 'REGULAR',
        );
      }

      if (selectedVelacheryRoutes.isNotEmpty) {
        await routeService.assignRoutes(
          date: tomorrow,
          routeIds: selectedVelacheryRoutes.toList(),
          assignmentType: 'SHUTTLE',
          shuttleGroup: 'VELACHERY',
        );
      }

      if (selectedAlandurRoutes.isNotEmpty) {
        await routeService.assignRoutes(
          date: tomorrow,
          routeIds: selectedAlandurRoutes.toList(),
          assignmentType: 'SHUTTLE',
          shuttleGroup: 'ALANDUR_METRO',
        );
      }

      await loadScreen();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Afternoon routes assigned successfully')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to assign routes: $e')));
    } finally {
      if (mounted) {
        setState(() {
          assigning = false;
        });
      }
    }
  }

  // ============================================================
  // ROUTE TILE
  // ============================================================

  Widget routeTile(
    RouteModel route, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return CheckboxListTile(
      dense: true,
      value: selected,
      onChanged: (_) => onTap(),
      title: Text('${route.routeNumber} - ${route.routeName}'),
      subtitle: Text(route.acType),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  // ============================================================
  // ASSIGNMENT DROPDOWN
  // ============================================================

  Widget assignmentDropdown({
    required String title,
    required int selectedCount,
    required List<RouteModel> routeList,
    required Set<int> selectedSet,
    required void Function(int) onToggle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$selectedCount selected'),
        children: [
          ...routeList.map(
            (route) => routeTile(
              route,
              selected: selectedSet.contains(route.id),
              onTap: () {
                onToggle(route.id);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SELECTED SECTION
  // ============================================================

  Widget selectedSection() {
    return Card(
      child: ExpansionTile(
        title: const Text(
          'SELECTED ROUTES',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('$totalSelectedRoutes routes selected'),
        children: [
          if (selectedRoutes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No routes selected'),
            )
          else
            ...selectedRoutes.map(
              (route) => ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle),
                title: Text(
                  '${route.routeNumber} - '
                  '${route.routeName}',
                ),
                trailing: Text(
                  selectedType(route.id),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assign Afternoon Routes')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ==================================================
                // TOMORROW SCHEDULE
                // ==================================================
                Text(
                  'TOMORROW • $tomorrowLabel',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                if (schedule.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: Text('No routes assigned for tomorrow.'),
                      ),
                    ),
                  )
                else ...[
                  scheduleSection(
                    title: 'REGULAR BUSES',
                    buses: regularSchedule,
                  ),

                  scheduleSection(title: 'VELACHERY', buses: velacherySchedule),

                  scheduleSection(
                    title: 'ALANDUR METRO',
                    buses: alandurSchedule,
                  ),
                ],

                const SizedBox(height: 20),

                const Divider(),

                const SizedBox(height: 20),

                // ==================================================
                // ASSIGN NEW
                // ==================================================
                const Text(
                  'ASSIGN NEW ROUTES',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                selectedSection(),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: totalSelectedRoutes == 0 || assigning
                        ? null
                        : assignAllRoutes,
                    child: assigning
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'ASSIGN SELECTED '
                            '($totalSelectedRoutes)',
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                assignmentDropdown(
                  title: 'Regular Buses',
                  selectedCount: selectedRegularRoutes.length,
                  routeList: regularRoutes,
                  selectedSet: selectedRegularRoutes,
                  onToggle: toggleRegularRoute,
                ),

                assignmentDropdown(
                  title: 'Velachery',
                  selectedCount: selectedVelacheryRoutes.length,
                  routeList: velacheryRoutes,
                  selectedSet: selectedVelacheryRoutes,
                  onToggle: toggleVelacheryRoute,
                ),

                assignmentDropdown(
                  title: 'Alandur Metro',
                  selectedCount: selectedAlandurRoutes.length,
                  routeList: alandurRoutes,
                  selectedSet: selectedAlandurRoutes,
                  onToggle: toggleAlandurRoute,
                ),

                const SizedBox(height: 20),
              ],
            ),
    );
  }
}
