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
  final service = RouteService();
  int index = 0;
  bool loading = true;
  String? error;
  Map<String, dynamic> data = {};
  DateTime? operationDate;
  List<dynamic> scheduledOperations = [];

  static const navy = Color(0xFF12305A);
  static const blue = Color(0xFF155EEF);
  static const paleBlue = Color(0xFFF0F6FF);

  int n(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  Map<String, dynamic> m(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};
  String fmt(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')} ${_month(value.month)} ${value.year}';
  String _month(int m) => const [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final today = DateUtils.dateOnly(DateTime.now());
      DateTime? nextDate;
      List<dynamic> nextItems = [];
      for (var offset = 1; offset <= 90 && nextDate == null; offset += 7) {
        final offsets = List<int>.generate(
          (91 - offset).clamp(0, 7),
          (i) => offset + i,
        );
        final candidates = await Future.wait(
          offsets.map((dayOffset) async {
            final candidate = today.add(Duration(days: dayOffset));
            return (
              date: candidate,
              items: await service.getTomorrowSchedule(candidate),
            );
          }),
        );
        for (final candidate in candidates) {
          if (candidate.items.isNotEmpty) {
            nextDate = candidate.date;
            nextItems = candidate.items;
            break;
          }
        }
      }
      final result = nextDate == null
          ? <String, dynamic>{}
          : await service.getDashboardOverview(nextDate);
      if (mounted) {
        setState(() {
          data = result;
          operationDate = nextDate;
          scheduledOperations = nextItems;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = '$e';
        });
      }
    }
  }

  void logout() => Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
    (_) => false,
  );

  String _routeNumber(Map<String, dynamic> item) =>
      '${item['routeNumber'] ?? item['busNumber'] ?? item['routeName'] ?? 'Bus'}';
  String _routeName(Map<String, dynamic> item) =>
      '${item['routeName'] ?? ''}'.trim();
  int _bookings(Map<String, dynamic> item) => n(
    item['bookedSeats'] ??
        item['bookings'] ??
        item['bookingCount'] ??
        item['totalBookings'],
  );
  int _capacity(Map<String, dynamic> item) =>
      n(item['totalSeats'] ?? item['capacity'] ?? item['totalCapacity']);
  String _type(Map<String, dynamic> item) =>
      '${item['assignmentType'] ?? 'REGULAR'}'.toUpperCase();
  String _group(Map<String, dynamic> item) =>
      '${item['shuttleGroup'] ?? ''}'.toUpperCase().replaceAll(' ', '');

  List<Map<String, dynamic>> get regularBuses => scheduledOperations
      .map((e) => m(e))
      .where((e) => _type(e) == 'REGULAR')
      .toList();
  List<Map<String, dynamic>> shuttleBuses(String destination) {
    final all = scheduledOperations
        .map((e) => m(e))
        .where((e) => _type(e) != 'REGULAR')
        .toList();
    final key = destination.toUpperCase();
    return all.where((e) {
      final t = _type(e);
      final g = _group(e);
      final combined = '$t $g ${e['routeName'] ?? ''} ${e['routeNumber'] ?? ''}'
          .toUpperCase();
      if (key == 'ALANDUR') {
        return combined.contains('ALANDUR') || g.startsWith('A');
      }
      if (key == 'VELACHERY') {
        return combined.contains('VELACHERY') || g.startsWith('V');
      }
      if (key == 'SHOLINGANALLUR') {
        return combined.contains('SHOLI') || g.startsWith('S');
      }
      return combined.contains('TAMBARAM') || g.startsWith('T');
    }).toList();
  }

  Future<void> showBusDetails(
    String title,
    List<Map<String, dynamic>> buses,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${buses.length} buses • ${buses.fold<int>(0, (sum, b) => sum + _bookings(b))} total bookings',
                style: TextStyle(color: Colors.blueGrey.shade600),
              ),
              const SizedBox(height: 12),
              if (buses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No buses assigned for this operation.'),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: buses.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final b = buses[i];
                      final name = _routeName(b);
                      final cap = _capacity(b);
                      return ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: paleBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.directions_bus, color: blue),
                        ),
                        title: Text(
                          '${_routeNumber(b)}${name.isEmpty || name == _routeNumber(b) ? '' : ' • $name'}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${b['acType'] ?? ''}${b['shuttleGroup'] == null ? '' : ' • ${b['shuttleGroup']}'}${cap > 0 ? ' • Capacity $cap' : ''}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${_bookings(b)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: navy,
                              ),
                            ),
                            const Text(
                              'bookings',
                              style: TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: navy,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
        ),
      ],
    ),
  );

  Widget _metric(String label, String value, IconData icon) => Row(
    children: [
      Icon(icon, size: 17, color: blue),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          label,
          style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 12),
        ),
      ),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w900, color: navy),
      ),
    ],
  );

  Widget _summaryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String count,
    required String bookings,
    required VoidCallback onTap,
    String? footnote,
  }) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE0EAF8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080D2A55),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: paleBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: blue, size: 23),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_outward_rounded,
                  color: Color(0xFF94A3B8),
                  size: 19,
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: navy,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600),
            ),
            const SizedBox(height: 16),
            _metric('Buses', count, Icons.directions_bus_outlined),
            const SizedBox(height: 9),
            _metric(
              'Total bookings',
              bookings,
              Icons.confirmation_number_outlined,
            ),
            if (footnote != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: paleBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  footnote,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: navy,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Tap to view bus-wise bookings  →',
              style: TextStyle(
                fontSize: 11,
                color: blue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget dashboardBody() {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: blue));
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 44, color: blue),
              const SizedBox(height: 12),
              const Text(
                'Dashboard unavailable',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final regular = regularBuses;
    final alandur = shuttleBuses('ALANDUR');
    final velachery = shuttleBuses('VELACHERY');
    final sholi = shuttleBuses('SHOLINGANALLUR');
    final tambaram = shuttleBuses('TAMBARAM');
    final aSlots = alandur
        .map(_group)
        .where((g) => RegExp(r'^A[1-5]$').hasMatch(g))
        .toSet();
    final vSlots = velachery
        .map(_group)
        .where((g) => RegExp(r'^V[1-3]$').hasMatch(g))
        .toSet();
    final aOpen = aSlots.isEmpty
        ? ''
        : 'Open till ${aSlots.reduce((a, b) => int.parse(a.substring(1)) > int.parse(b.substring(1)) ? a : b)}';
    final vOpen = vSlots.isEmpty
        ? ''
        : 'Open till ${vSlots.reduce((a, b) => int.parse(a.substring(1)) > int.parse(b.substring(1)) ? a : b)}';
    final aCapacity = aSlots.length * 55;
    final vCapacity = vSlots.length * 55;
    final aBookings = alandur.fold<int>(0, (s, b) => s + _bookings(b));
    final vBookings = velachery.fold<int>(0, (s, b) => s + _bookings(b));
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          Container(
            padding: const EdgeInsets.all(21),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1765F5), Color(0xFF12305A)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        operationDate == null
                            ? 'UPCOMING OPERATIONS'
                            : 'NEXT SCHEDULED OPERATIONS',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        operationDate == null
                            ? 'No operations scheduled'
                            : fmt(operationDate!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        operationDate == null
                            ? 'No upcoming operation dates have been assigned.'
                            : '${scheduledOperations.length} assigned buses across all services',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.white,
                    size: 29,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (operationDate != null) ...[
            _sectionTitle('Routes Bus', 'Regular afternoon routes'),
            _summaryCard(
              title: 'Regular Routes',
              subtitle: 'All assigned regular buses',
              icon: Icons.directions_bus_filled_rounded,
              count: '${regular.length}',
              bookings: '${regular.fold<int>(0, (s, b) => s + _bookings(b))}',
              onTap: () => showBusDetails('Regular Routes', regular),
            ),
            const SizedBox(height: 18),
            _sectionTitle(
              'Shuttle Services',
              'Live assignment and booking summary',
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 560;
                final cardWidth = wide
                    ? (constraints.maxWidth - 14) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _summaryCard(
                        title: 'Alandur Metro',
                        subtitle: 'Shuttle slots • 55 seats per slot',
                        icon: Icons.train_rounded,
                        count: '${alandur.length}',
                        bookings:
                            '$aBookings${aCapacity > 0 ? ' / $aCapacity' : ''}',
                        footnote: aOpen.isEmpty
                            ? 'No A-slots assigned'
                            : '$aOpen • $aBookings / $aCapacity seats booked',
                        onTap: () => showBusDetails('Alandur Metro', alandur),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _summaryCard(
                        title: 'Velachery',
                        subtitle: 'Shuttle slots • 55 seats per slot',
                        icon: Icons.directions_transit_rounded,
                        count: '${velachery.length}',
                        bookings:
                            '$vBookings${vCapacity > 0 ? ' / $vCapacity' : ''}',
                        footnote: vOpen.isEmpty
                            ? 'No V-slots assigned'
                            : '$vOpen • $vBookings / $vCapacity seats booked',
                        onTap: () => showBusDetails('Velachery', velachery),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _summaryCard(
                        title: 'Sholinganallur',
                        subtitle: 'Single shuttle service',
                        icon: Icons.location_on_outlined,
                        count: '${sholi.length}',
                        bookings:
                            '${sholi.fold<int>(0, (s, b) => s + _bookings(b))}',
                        onTap: () => showBusDetails('Sholinganallur', sholi),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _summaryCard(
                        title: 'Tambaram',
                        subtitle: 'Single shuttle service',
                        icon: Icons.location_on_rounded,
                        count: '${tambaram.length}',
                        bookings:
                            '${tambaram.fold<int>(0, (s, b) => s + _bookings(b))}',
                        onTap: () => showBusDetails('Tambaram', tambaram),
                      ),
                    ),
                  ],
                );
              },
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE0EAF8)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.event_available_outlined, size: 42, color: blue),
                  SizedBox(height: 10),
                  Text(
                    'No operations scheduled',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: navy,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Assign routes for a future operation date to see the dashboard summary here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['SHUBUS ADMIN', 'Assign Afternoon Routes', 'Routes'];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[index],
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (index == 0)
            IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: [
          dashboardBody(),
          const AfternoonAssignmentScreen(),
          const RoutesScreen(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        height: 76,
        width: 76,
        child: FloatingActionButton(
          heroTag: 'assignRaisedButton',
          backgroundColor: blue,
          foregroundColor: Colors.white,
          elevation: 8,
          shape: const CircleBorder(),
          onPressed: () => setState(() => index = 1),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_bus_filled, size: 25),
              SizedBox(height: 2),
              Text(
                'Assign',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 12,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              Expanded(child: _nav(Icons.dashboard_outlined, 'Dashboard', 0)),
              const Expanded(child: SizedBox()),
              Expanded(child: _nav(Icons.route_outlined, 'Routes', 2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nav(IconData icon, String label, int tab) {
    final selected = index == tab;
    return InkWell(
      onTap: () {
        setState(() => index = tab);
        if (tab == 0) refresh();
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: selected ? blue : Colors.blueGrey),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? blue : Colors.blueGrey,
            ),
          ),
        ],
      ),
    );
  }
}
