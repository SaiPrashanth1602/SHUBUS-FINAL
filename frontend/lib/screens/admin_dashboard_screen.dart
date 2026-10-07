import 'package:flutter/material.dart';

import '../services/route_service.dart';
import 'routes_screen.dart';
import 'afternoon_assignment_screen.dart';
import 'admin_login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final RouteService routeService = RouteService();

  int currentIndex = 0;

  bool loading = true;

  Map<String, dynamic> dashboard = {};

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  // ============================================================
  // LOAD DASHBOARD
  // ============================================================

  Future<void> loadDashboard() async {
    try {
      final tomorrow = DateTime.now().add(const Duration(days: 1));

      final data = await routeService.getDashboardOverview(tomorrow);

      if (!mounted) return;

      setState(() {
        dashboard = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load dashboard: $e')));
    }
  }

  // ============================================================
  // FORMAT TOMORROW
  // ============================================================

  String get tomorrowLabel {
    final tomorrow = DateTime.now().add(const Duration(days: 1));

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

    return '${tomorrow.day.toString().padLeft(2, '0')} '
        '${months[tomorrow.month - 1]} '
        '${tomorrow.year}';
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget dashboardScreen() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final int regularBuses = dashboard['regularBuses'] ?? 0;

    final int regularCapacity = dashboard['regularCapacity'] ?? 0;

    final int regularBookings = dashboard['regularBookings'] ?? 0;

    final int totalCapacity = dashboard['totalCapacity'] ?? 0;

    final int totalBookings = dashboard['totalBookings'] ?? 0;

    final Map<String, dynamic> velachery = dashboard['velachery'] ?? {};

    final Map<String, dynamic> alandur = dashboard['alandurMetro'] ?? {};

    final int velacheryBuses = velachery['buses'] ?? 0;

    final int velacheryBookings = velachery['bookings'] ?? 0;

    final int velacheryCapacity = velachery['capacity'] ?? 0;

    final int alandurBuses = alandur['buses'] ?? 0;

    final int alandurBookings = alandur['bookings'] ?? 0;

    final int alandurCapacity = alandur['capacity'] ?? 0;

    return RefreshIndicator(
      onRefresh: loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ======================================================
          // HEADER
          // ======================================================
          const Text(
            'DASHBOARD',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 4),

          Text(
            'Tomorrow • $tomorrowLabel',
            style: TextStyle(color: Colors.grey.shade600),
          ),

          const SizedBox(height: 20),

          // ======================================================
          // OVERALL
          // ======================================================
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OVERALL',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: overviewItem('Bookings', '$totalBookings'),
                      ),
                      Expanded(
                        child: overviewItem('Capacity', '$totalCapacity'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ======================================================
          // REGULAR
          // ======================================================
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'REGULAR BUSES',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(child: overviewItem('Buses', '$regularBuses')),
                      Expanded(
                        child: overviewItem(
                          'Bookings',
                          '$regularBookings / '
                              '$regularCapacity',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ======================================================
          // VELACHERY
          // ======================================================
          shuttleCard(
            title: 'VELACHERY',
            buses: velacheryBuses,
            bookings: velacheryBookings,
            capacity: velacheryCapacity,
          ),

          const SizedBox(height: 12),

          // ======================================================
          // ALANDUR
          // ======================================================
          shuttleCard(
            title: 'ALANDUR METRO',
            buses: alandurBuses,
            bookings: alandurBookings,
            capacity: alandurCapacity,
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ============================================================
  // OVERVIEW ITEM
  // ============================================================

  Widget overviewItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 4),

        Text(label, style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }

  // ============================================================
  // SHUTTLE CARD
  // ============================================================

  Widget shuttleCard({
    required String title,
    required int buses,
    required int bookings,
    required int capacity,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(child: overviewItem('Buses', '$buses')),

                Expanded(
                  flex: 2,
                  child: overviewItem('Bookings', '$bookings / $capacity'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  void logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (route) => false,
    );
  }

  // ============================================================
  // CURRENT PAGE
  // ============================================================

  Widget currentPage() {
    switch (currentIndex) {
      case 1:
        return const RoutesScreen();

      case 2:
        return const AfternoonAssignmentScreen();

      default:
        return dashboardScreen();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentIndex == 0
              ? 'SHUBUS ADMIN'
              : currentIndex == 1
              ? 'Routes'
              : 'Assign Afternoon',
        ),

        actions: [
          IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
        ],
      ),

      body: currentPage(),

      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,

        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });

          // Refresh dashboard whenever
          // dashboard tab is opened.
          if (index == 0) {
            loadDashboard();
          }
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),

          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Routes',
          ),

          NavigationDestination(
            icon: Icon(Icons.directions_bus_outlined),
            selectedIcon: Icon(Icons.directions_bus),
            label: 'Assign',
          ),
        ],
      ),
    );
  }
}
