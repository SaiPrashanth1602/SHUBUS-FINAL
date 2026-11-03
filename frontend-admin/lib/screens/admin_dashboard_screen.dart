import 'package:flutter/material.dart';

import '../services/admin_api_exception.dart';
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

  final GlobalKey<RoutesScreenState> _routesKey =
      GlobalKey<RoutesScreenState>();

  final GlobalKey<AfternoonAssignmentScreenState> _assignmentKey =
      GlobalKey<AfternoonAssignmentScreenState>();

  int index = 0;
  bool loading = false;
  String? error;
  Map<String, dynamic> data = {};
  DateTime? operationDate;
  List<dynamic> scheduledOperations = [];

  static const navy = Color(0xFF12305A);
  static const paleBlue = Color(0xFFF0F6FF);
  static const teal = Color(0xFF0F766E);

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
      final operationalDate = await service.getCurrentOperationalDate();

      final startDate = operationalDate;
      final endDate = operationalDate.add(const Duration(days: 90));

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

      final nextDate = scheduledEntry?.key ?? operationalDate;
      final nextItems = scheduledEntry?.value ?? <dynamic>[];

      final schedule = nextItems.isEmpty
          ? <dynamic>[]
          : await service.getDashboardSchedule(nextDate);

      if (mounted) {
        setState(() {
          data = {'date': nextDate, 'schedule': schedule};
          operationDate = scheduledEntry?.key;
          scheduledOperations = schedule.isNotEmpty ? schedule : nextItems;
          error = null;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = adminErrorMessage(
            e,
            fallback: 'Check your connection and try again.',
          );
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

  /// Highest slot number for a prefix, e.g. A1..A7 -> "Open till A7".
  /// Works for any number of extra slots (A6, A7, V4, S2, T2 ...).
  String _openTill(List<Map<String, dynamic>> buses, String prefix) {
    final pattern = RegExp(
      '^$prefix'
      r'(\d+)$',
    );
    var highest = 0;

    for (final bus in buses) {
      final match = pattern.firstMatch(_group(bus));
      final number = match == null ? 0 : int.parse(match.group(1)!);
      if (number > highest) highest = number;
    }

    return highest == 0 ? '' : 'Open till $prefix$highest';
  }

  String _slotFootnote(
    List<Map<String, dynamic>> buses,
    String prefix,
    String destinationLabel,
  ) {
    final open = _openTill(buses, prefix);
    if (open.isEmpty) {
      return 'No $destinationLabel slots in the selected schedule';
    }

    final booked = buses.fold<int>(0, (s, b) => s + _bookings(b));
    final capacity = buses.fold<int>(0, (s, b) => s + _capacity(b));
    return '$open • $booked / $capacity seats booked';
  }

  String _bookingsLabel(List<Map<String, dynamic>> buses) {
    final booked = buses.fold<int>(0, (s, b) => s + _bookings(b));
    final capacity = buses.fold<int>(0, (s, b) => s + _capacity(b));
    return '$booked${capacity > 0 ? ' / $capacity' : ''}';
  }

  Future<void> showBusDetails(
    String title,
    List<Map<String, dynamic>> buses,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                '${buses.length} buses • ${buses.fold<int>(0, (sum, b) => sum + _bookings(b))} total bookings',
                style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
              ),
              const SizedBox(height: 12),
              if (buses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No buses assigned for this operation.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF68758A)),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: buses.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0xFFE9EDF3)),
                    itemBuilder: (_, i) {
                      final b = buses[i];
                      final busNo = _routeNumber(b);
                      final name = _routeName(b);
                      final cap = _capacity(b);
                      final bookings = _bookings(b);

                      final subtitle = [
                        if ((b['acType'] ?? '').toString().trim().isNotEmpty)
                          b['acType'].toString(),
                        if ((b['shuttleGroup'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty)
                          b['shuttleGroup'].toString(),
                        if (cap > 0) 'Capacity $cap',
                      ].join(' • ');

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: paleBlue,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Text(
                                busNo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: navy,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.isEmpty || name == busNo
                                        ? busNo
                                        : name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF22314A),
                                    ),
                                  ),
                                  if (subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF758198),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '$bookings',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: navy,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                const Text(
                                  'bookings',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF8993A5),
                                  ),
                                ),
                              ],
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

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: navy,
      ),
    ),
  );

  Widget _metric(String label, String value, IconData icon) => Row(
    children: [
      Icon(icon, size: 15, color: teal),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          label,
          style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 11),
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: navy,
        ),
      ),
    ],
  );

  Widget _summaryCard({
    required String title,
    required String subtitle,
    required String count,
    required String bookings,
    required VoidCallback onTap,
    String? footnote,
  }) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE0EAF8)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080D2A55),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: navy,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade600),
            ),
            const SizedBox(height: 12),
            _metric('Buses', count, Icons.directions_bus_outlined),
            const SizedBox(height: 7),
            _metric(
              'Total bookings',
              bookings,
              Icons.confirmation_number_outlined,
            ),
            if (footnote != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: paleBlue,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  footnote,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: navy,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Tap to view bus-wise bookings',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: navy.withValues(alpha: 0.45),
                ),
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
                      'Could not refresh operations.\n$error',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A271A),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Retry',
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh, color: Color(0xFFB42318)),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: navy,
              borderRadius: BorderRadius.circular(22),
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
                          fontSize: 10,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        operationDate == null
                            ? 'Operations Overview'
                            : fmt(operationDate!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        loading
                            ? 'Updating schedule and booking totals…'
                            : operationDate == null
                            ? 'No operations scheduled yet.'
                            : '${scheduledOperations.length} assigned buses across all services',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Regular Routes'),
          _summaryCard(
            title: 'Regular Routes',
            subtitle: 'All assigned regular buses',
            count: '${regular.length}',
            bookings: '${regular.fold<int>(0, (s, b) => s + _bookings(b))}',
            onTap: () => showBusDetails('Regular Routes', regular),
          ),
          const SizedBox(height: 18),
          _sectionTitle('Shuttle Services'),
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
                      subtitle: 'Shuttle buses',
                      count: '${alandur.length}',
                      bookings: _bookingsLabel(alandur),
                      footnote: _slotFootnote(alandur, 'A', 'Alandur'),
                      onTap: () => showBusDetails('Alandur Metro', alandur),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _summaryCard(
                      title: 'Velachery',
                      subtitle: 'Shuttle buses',
                      count: '${velachery.length}',
                      bookings: _bookingsLabel(velachery),
                      footnote: _slotFootnote(velachery, 'V', 'Velachery'),
                      onTap: () => showBusDetails('Velachery', velachery),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _summaryCard(
                      title: 'Sholinganallur',
                      subtitle: 'Shuttle buses',
                      count: '${sholi.length}',
                      bookings: _bookingsLabel(sholi),
                      footnote: _slotFootnote(sholi, 'S', 'Sholinganallur'),
                      onTap: () => showBusDetails('Sholinganallur', sholi),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _summaryCard(
                      title: 'Tambaram',
                      subtitle: 'Shuttle buses',
                      count: '${tambaram.length}',
                      bookings: _bookingsLabel(tambaram),
                      footnote: _slotFootnote(tambaram, 'T', 'Tambaram'),
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

    return PopScope<Object?>(
      canPop: !isAssignment,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (isAssignment) {
          setState(() => index = 0);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: isAssignment
              ? IconButton(
                  tooltip: 'Back to Shuttle Operations',
                  onPressed: () => setState(() => index = 0),
                  icon: const Icon(Icons.arrow_back_rounded),
                )
              : null,
          title: Text(
            isAssignment
                ? 'Assign Buses'
                : isRoutes
                ? 'Routes'
                : 'Shuttle Operations',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            if (index == 0 || isRoutes || isAssignment)
              IconButton(
                tooltip: isAssignment
                    ? 'Refresh assignments'
                    : isRoutes
                    ? 'Refresh routes'
                    : 'Refresh operations',
                onPressed: loading
                    ? null
                    : () {
                        if (isAssignment) {
                          _assignmentKey.currentState?.load();
                        } else if (isRoutes) {
                          _routesKey.currentState?.load();
                        } else {
                          refresh();
                        }
                      },
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
                            icon: Icon(Icons.directions_bus_filled_rounded),
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
                          foregroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? Colors.white
                                : navy,
                          ),
                          backgroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? teal
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
            ? AfternoonAssignmentScreen(key: _assignmentKey)
            : RoutesScreen(key: _routesKey),
        bottomNavigationBar: index == 0
            ? SafeArea(
                minimum: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                child: SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: () => setState(() => index = 1),
                    icon: const Icon(Icons.directions_bus_filled_rounded),
                    label: const Text(
                      'Assign Buses',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: navy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
