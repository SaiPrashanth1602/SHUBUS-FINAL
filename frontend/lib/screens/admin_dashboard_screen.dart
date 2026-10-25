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
  bool loading = false;
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
    if (loading) return;

    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final today = DateUtils.dateOnly(DateTime.now());
      final startDate = today.add(const Duration(days: 1));
      final endDate = today.add(const Duration(days: 90));

      final assignments = await service.getAssignmentsForRange(
        startDate,
        endDate,
      );

      final scheduledEntries = assignments.entries
          .where((entry) => entry.value.isNotEmpty)
          .toList();

      final scheduledEntry = scheduledEntries.isEmpty
          ? null
          : scheduledEntries.first;

      final nextDate = scheduledEntry?.key;
      final nextItems = scheduledEntry?.value ?? <dynamic>[];

      final schedule = nextDate == null
          ? <dynamic>[]
          : await service.getDashboardSchedule(nextDate);

      if (mounted) {
        setState(() {
          data = {'date': nextDate, 'schedule': schedule};
          operationDate = nextDate;
          scheduledOperations = schedule.isNotEmpty ? schedule : nextItems;
          error = null;
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

      final combined =
          '$t $g ${e['routeName'] ?? ''} ${e['routeNumber'] ?? ''}'
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
                    child: Text(
                      'No buses assigned for this operation.',
                    ),
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
                          child: const Icon(
                            Icons.directions_bus,
                            color: blue,
                          ),
                        ),
                        title: Text(
                          '${_routeNumber(b)}${name.isEmpty || name == _routeNumber(b) ? '' : ' • $name'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          '${b['acType'] ?? ''}'
                          '${b['shuttleGroup'] == null ? '' : ' • ${b['shuttleGroup']}'}'
                          '${cap > 0 ? ' • Capacity $cap' : ''}',
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
              style: TextStyle(
                fontSize: 11,
                color: Colors.blueGrey.shade600,
              ),
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
        : 'Open till ${aSlots.reduce(
            (a, b) =>
                int.parse(a.substring(1)) > int.parse(b.substring(1))
                    ? a
                    : b,
          )}';

    final vOpen = vSlots.isEmpty
        ? ''
        : 'Open till ${vSlots.reduce(
            (a, b) =>
                int.parse(a.substring(1)) > int.parse(b.substring(1))
                    ? a
                    : b,
          )}';

    final aCapacity = alandur.fold<int>(
      0,
      (sum, bus) => sum + _capacity(bus),
    );

    final vCapacity = velachery.fold<int>(
      0,
      (sum, bus) => sum + _capacity(bus),
    );

    final aBookings = alandur.fold<int>(0, (s, b) => s + _bookings(b));
    final vBookings = velachery.fold<int>(0, (s, b) => s + _bookings(b));

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        children: [
          if (loading) ...[
            const LinearProgressIndicator(
              minHeight: 3,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            const SizedBox(height: 12),
          ],
          if (error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFD4CC)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: Color(0xFFB42318),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Could not refresh operations. Existing dashboard is still available.\n$error',
                      style: const TextStyle(color: Color(0xFF7A271A)),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Retry',
                    onPressed: refresh,
                    icon: const Icon(
                      Icons.refresh,
                      color: Color(0xFFB42318),
                    ),
                  ),
                ],
              ),
            ),
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
                        loading
                            ? 'LOADING OPERATIONS'
                            : operationDate == null
                            ? 'SHUTTLE OPERATIONS'
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
                            ? 'Operations Overview'
                            : fmt(operationDate!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loading
                            ? 'Updating schedule and booking totals…'
                            : operationDate == null
                            ? 'No upcoming date found. You can still view service groups and assign buses.'
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
          _sectionTitle(
            'Regular Routes',
            'Regular afternoon bus assignments',
          ),
          _summaryCard(
            title: 'Regular Routes',
            subtitle: 'All assigned regular buses',
            icon: Icons.directions_bus_filled_rounded,
            count: '${regular.length}',
            bookings:
                '${regular.fold<int>(0, (s, b) => s + _bookings(b))}',
            onTap: () => showBusDetails('Regular Routes', regular),
          ),
          const SizedBox(height: 20),
          _sectionTitle(
            'Shuttle Services',
            'Choose a destination to view its shuttle buses',
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
                      subtitle:
                          'Shuttle buses • student-bookable capacity',
                      icon: Icons.train_rounded,
                      count: '${alandur.length}',
                      bookings:
                          '$aBookings${aCapacity > 0 ? ' / $aCapacity' : ''}',
                      footnote: aOpen.isEmpty
                          ? 'No Alandur slots in the selected schedule'
                          : '$aOpen • $aBookings / $aCapacity seats booked',
                      onTap: () =>
                          showBusDetails('Alandur Metro', alandur),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _summaryCard(
                      title: 'Velachery',
                      subtitle:
                          'Shuttle buses • student-bookable capacity',
                      icon: Icons.directions_transit_rounded,
                      count: '${velachery.length}',
                      bookings:
                          '$vBookings${vCapacity > 0 ? ' / $vCapacity' : ''}',
                      footnote: vOpen.isEmpty
                          ? 'No Velachery slots in the selected schedule'
                          : '$vOpen • $vBookings / $vCapacity seats booked',
                      onTap: () => showBusDetails('Velachery', velachery),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _summaryCard(
                      title: 'Sholinganallur',
                      subtitle: 'Shuttle buses',
                      icon: Icons.location_on_outlined,
                      count: '${sholi.length}',
                      bookings:
                          '${sholi.fold<int>(0, (s, b) => s + _bookings(b))}',
                      onTap: () =>
                          showBusDetails('Sholinganallur', sholi),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _summaryCard(
                      title: 'Tambaram',
                      subtitle: 'Shuttle buses',
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
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAssignment = index == 1;
    final isRoutes = index == 2;

    return Scaffold(
      appBar: AppBar(
        leading: index == 0
            ? null
            : IconButton(
                tooltip: 'Back to Shuttle Operations',
                onPressed: () {
                  setState(() => index = 0);
                },
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        title: Text(
          isAssignment
              ? 'Assign Afternoon Routes'
              : isRoutes
              ? 'Routes'
              : 'Shuttle Operations',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (index == 0)
            IconButton(
              tooltip: 'Refresh operations',
              onPressed: loading ? null : refresh,
              icon: const Icon(Icons.refresh),
            ),
          IconButton(
            tooltip: 'Logout',
            onPressed: logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
        bottom: (index == 0 || isRoutes)
            ? PreferredSize(
                preferredSize: const Size.fromHeight(58),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment<int>(
                          value: 0,
                          icon: Icon(
                            Icons.directions_bus_filled_rounded,
                          ),
                          label: Text('Shuttle Operations'),
                        ),
                        ButtonSegment<int>(
                          value: 2,
                          icon: Icon(Icons.alt_route_rounded),
                          label: Text('Routes'),
                        ),
                      ],
                      selected: {index},
                      onSelectionChanged: (selection) {
                        final next = selection.first;
                        setState(() => index = next);
                      },
                      style: ButtonStyle(
                        textStyle: WidgetStateProperty.all(
                          const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        foregroundColor:
                            WidgetStateProperty.resolveWith(
                              (states) =>
                                  states.contains(WidgetState.selected)
                                  ? Colors.white
                                  : navy,
                            ),
                        backgroundColor:
                            WidgetStateProperty.resolveWith(
                              (states) =>
                                  states.contains(WidgetState.selected)
                                  ? blue
                                  : Colors.white,
                            ),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: index == 0
          ? dashboardBody()
          : index == 1
          ? const AfternoonAssignmentScreen()
          : const RoutesScreen(),
      bottomNavigationBar: index == 0
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              child: SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => setState(() => index = 1),
                  icon: const Icon(
                    Icons.directions_bus_filled_rounded,
                  ),
                  label: const Text(
                    'Assign Buses',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}