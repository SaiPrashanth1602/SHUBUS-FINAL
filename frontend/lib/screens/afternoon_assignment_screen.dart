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
  final service = RouteService();
  static const Color blue = Color(0xFF155EEF);
  static const Map<String, List<String>> destinations = {
    'ALANDUR METRO': ['A1', 'A2', 'A3', 'A4', 'A5'],
    'VELACHERY': ['V1', 'V2', 'V3'],
    'SHOLINGANALLUR': ['S1'],
    'TAMBARAM': ['T1'],
  };
  List<RouteModel> routes = [];
  Map<DateTime, List<dynamic>> schedules = {};
  DateTime fromDate = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );
  late DateTime toDate = fromDate;
  DateTime? viewedScheduleDate;
  final Set<int> regular = {};
  final Map<String, Set<int>> shuttle = {
    for (final slot in [
      'A1',
      'A2',
      'A3',
      'A4',
      'A5',
      'V1',
      'V2',
      'V3',
      'S1',
      'T1',
    ])
      slot: <int>{},
  };
  String? activeSlot;
  int assignmentCategory = 0;
  String selectedDestination = destinations.keys.first;
  bool loading = true;
  bool saving = false;
  bool addingToExistingDate = false;
  final TextEditingController routeSearch = TextEditingController();
  final Map<String, TextEditingController> slotSearch = {
    for (final slot in [
      'A1',
      'A2',
      'A3',
      'A4',
      'A5',
      'V1',
      'V2',
      'V3',
      'S1',
      'T1',
    ])
      slot: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    routeSearch.dispose();
    for (final controller in slotSearch.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int? asInt(dynamic v) => v is int ? v : int.tryParse('$v');
  DateTime day(DateTime d) => DateUtils.dateOnly(d);
  String fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  List<DateTime> get operationDates {
    final result = <DateTime>[];
    for (
      var d = day(fromDate);
      !d.isAfter(day(toDate));
      d = d.add(const Duration(days: 1))
    ) {
      result.add(d);
    }
    return result;
  }

  void msg(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> chooseRange() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final effectiveFirstDate = fromDate.isBefore(now) ? fromDate : now;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: effectiveFirstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: fromDate, end: toDate),
      helpText: 'Choose operation dates',
      saveText: 'SHOW SCHEDULE',
    );
    if (picked == null) return;
    setState(() {
      fromDate = day(picked.start);
      toDate = day(picked.end);
      addingToExistingDate = false;
      routeSearch.clear();
      for (final c in slotSearch.values) {
        c.clear();
      }
    });
    await load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() => loading = true);
    }
    try {
      final routeData = await service.getRoutes();
      final loaded = <DateTime, List<dynamic>>{};
      for (final d in operationDates) {
        loaded[d] = await service.getTomorrowSchedule(d);
      }
      if (!mounted) return;
      setState(() {
        routes = routeData;
        schedules = loaded;
        if (viewedScheduleDate == null ||
            !loaded.containsKey(day(viewedScheduleDate!))) {
          viewedScheduleDate = operationDates.isEmpty
              ? null
              : operationDates.first;
        }
        regular.clear();
        activeSlot = null;
        for (final s in shuttle.values) {
          s.clear();
        }
        regular.addAll(
          routes.where((r) => r.defaultAfternoon).map((r) => r.id),
        );
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        msg('Could not load schedules: $e');
      }
    }
  }

  List<dynamic> scheduleFor(DateTime d) => schedules[day(d)] ?? [];
  bool assignedOn(DateTime d, int id) =>
      scheduleFor(d).any((a) => asInt(a['routeId']) == id);
  bool assignedSomewhere(int id) =>
      operationDates.any((d) => assignedOn(d, id));
  int get selectedCount =>
      regular.length + shuttle.values.fold(0, (n, s) => n + s.length);
  List<RouteModel> get selectedRoutes => routes
      .where(
        (r) =>
            regular.contains(r.id) ||
            shuttle.values.any((s) => s.contains(r.id)),
      )
      .toList();
  List<RouteModel> availableFor(DateTime d) =>
      routes.where((r) => !assignedOn(d, r.id)).toList();

  void toggleRegular(int id) => setState(() {
    regular.contains(id) ? regular.remove(id) : regular.add(id);
  });
  void toggleSlot(String slot, int id) => setState(() {
    final set = shuttle[slot]!;
    if (set.contains(id)) {
      set.remove(id);
    } else {
      regular.remove(id);
      for (final e in shuttle.entries) {
        if (e.key != slot) e.value.remove(id);
      }
      set.add(id);
    }
  });

  List<DateTime> get datesToAssign {
    final fallbackDate = operationDates.isEmpty
        ? DateTime.now()
        : operationDates.first;
    return addingToExistingDate
        ? [day(viewedScheduleDate ?? fallbackDate)]
        : operationDates;
  }

  Future<void> assign() async {
    if (selectedCount == 0 || saving) return;
    final conflicts = <String>[];
    for (final d in datesToAssign) {
      for (final r in selectedRoutes) {
        if (assignedOn(d, r.id)) conflicts.add('${fmt(d)}: ${r.routeNumber}');
      }
    }
    if (conflicts.isNotEmpty) {
      final proceed =
          await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Some routes are already assigned'),
              content: Text(
                '${conflicts.take(8).join('\n')}${conflicts.length > 8 ? '\n…and ${conflicts.length - 8} more' : ''}\n\nThese routes will be skipped for dates where they already exist. Continue?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('CANCEL'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('CONTINUE'),
                ),
              ],
            ),
          ) ??
          false;
      if (!proceed) return;
    }
    setState(() => saving = true);
    var created = 0;
    final failures = <String>[];
    try {
      for (final d in datesToAssign) {
        final dayRegular = regular.where((id) => !assignedOn(d, id)).toList();
        if (dayRegular.isNotEmpty) {
          try {
            await service.assignRoutes(
              date: d,
              routeIds: dayRegular,
              assignmentType: 'REGULAR',
            );
            created += dayRegular.length;
          } catch (e) {
            failures.add('${fmt(d)} regular: $e');
          }
        }
        for (final entry in shuttle.entries) {
          final ids = entry.value.where((id) => !assignedOn(d, id)).toList();
          if (ids.isNotEmpty) {
            try {
              await service.assignRoutes(
                date: d,
                routeIds: ids,
                assignmentType: 'SHUTTLE',
                shuttleGroup: entry.key,
              );
              created += ids.length;
            } catch (e) {
              failures.add('${fmt(d)} ${entry.key}: $e');
            }
          }
        }
      }
      await load();
      if (failures.isEmpty) {
        msg(
          addingToExistingDate
              ? 'Added $created assignment(s) for ${fmt(datesToAssign.first)}.'
              : 'Assigned $created route entries across ${operationDates.length} operation date(s).',
        );
      } else {
        msg(
          'Created $created assignments. ${failures.length} batch(es) failed; check backend response.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> editAssignment(DateTime date, dynamic a) async {
    final id = asInt(a['assignmentId']);
    final routeId = asInt(a['routeId']);
    if (id == null || routeId == null) {
      msg('Backend did not return the assignment and route IDs.');
      return;
    }
    const assignmentTypes = {'REGULAR', 'SHUTTLE'};
    final shuttleGroups = destinations.values
        .expand((groups) => groups)
        .toSet();
    var type = '${a['assignmentType'] ?? 'REGULAR'}';
    if (!assignmentTypes.contains(type)) type = 'REGULAR';
    var group = '${a['shuttleGroup'] ?? 'A1'}';
    if (!shuttleGroups.contains(group)) group = 'A1';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('Edit ${a['routeNumber'] ?? 'route'}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Operation date: ${fmt(date)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: _dropdownDecoration('Assignment type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'REGULAR',
                      child: Text('Regular bus'),
                    ),
                    DropdownMenuItem(value: 'SHUTTLE', child: Text('Shuttle')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialog(() => type = value);
                  },
                ),
                if (type == 'SHUTTLE') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: group,
                    isExpanded: true,
                    decoration: _dropdownDecoration('Shuttle slot'),
                    items: destinations.entries
                        .expand(
                          (entry) => entry.value.map(
                            (slot) => DropdownMenuItem(
                              value: slot,
                              child: Text(
                                '${entry.key} — $slot',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialog(() => group = value);
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, {'type': type, 'group': group}),
              child: const Text('SAVE CHANGES'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    try {
      await service.deleteAssignment(id);
      await service.assignRoutes(
        date: date,
        routeIds: [routeId],
        assignmentType: result['type']!,
        shuttleGroup: result['type'] == 'SHUTTLE' ? result['group'] : null,
      );
      await load();
      msg('Assignment updated.');
    } catch (e) {
      await load();
      msg(
        'Could not complete edit: $e. Please verify the assignment for ${fmt(date)}.',
      );
    }
  }

  Future<void> deassign(DateTime date, dynamic a) async {
    final id = asInt(a['assignmentId']);
    if (id == null) {
      msg('Assignment ID was not returned by the backend.');
      return;
    }
    final yes =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove assignment?'),
            content: Text(
              'Remove ${a['routeNumber'] ?? 'this route'} from operation date ${fmt(date)}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('CANCEL'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('REMOVE'),
              ),
            ],
          ),
        ) ??
        false;
    if (!yes) return;
    try {
      await service.deleteAssignment(id);
      await load();
      msg('Assignment removed.');
    } catch (e) {
      msg('Could not remove assignment: $e');
    }
  }

  Future<void> deassignWholeDate(DateTime date) async {
    final items = List<dynamic>.from(scheduleFor(date));
    if (items.isEmpty) {
      msg('There are no assignments to remove for ${fmt(date)}.');
      return;
    }
    final yes =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('De-assign entire operation date?'),
            content: Text(
              'This will remove all ${items.length} assignment(s) for ${fmt(date)}. Other operation dates in the selected range will not be changed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('CANCEL'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('REMOVE ALL'),
              ),
            ],
          ),
        ) ??
        false;
    if (!yes) return;
    setState(() => saving = true);
    var removed = 0;
    final failures = <String>[];
    try {
      for (final item in items) {
        final id = asInt(item['assignmentId']);
        if (id == null) {
          failures.add(
            '${item['routeNumber'] ?? 'Route'} (missing assignment ID)',
          );
          continue;
        }
        try {
          await service.deleteAssignment(id);
          removed++;
        } catch (e) {
          failures.add('${item['routeNumber'] ?? 'Route'}');
        }
      }
      await load();
      msg(
        failures.isEmpty
            ? 'Removed all $removed assignments for ${fmt(date)}.'
            : 'Removed $removed assignment(s); ${failures.length} could not be removed.',
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _searchField({
    required TextEditingController controller,
    required String hint,
    required VoidCallback onChanged,
  }) => TextField(
    controller: controller,
    onChanged: (_) => onChanged(),
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search_rounded, size: 20),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF7F9FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDCE4EF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDCE4EF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: blue, width: 1.5),
      ),
    ),
  );

  InputDecoration _dropdownDecoration(String label) => InputDecoration(
    labelText: label,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDCE4EF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: blue, width: 1.5),
    ),
  );

  Widget sectionLabel(
    String title,
    String subtitle, {
    IconData icon = Icons.tune_rounded,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF1FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: blue, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF12233F),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget routeTile(RouteModel r, Set<int> selected, void Function(int) toggle) {
    final isSelected = selected.contains(r.id);
    return InkWell(
      key: ValueKey<int>(r.id),
      borderRadius: BorderRadius.circular(12),
      onTap: () => toggle(r.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF4FF) : const Color(0xFFFAFBFE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? blue : const Color(0xFFE5EAF2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? blue : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Icon(
                Icons.directions_bus_rounded,
                size: 20,
                color: isSelected ? Colors.white : const Color(0xFF63728A),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r.routeNumber}  ·  ${r.routeName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF182941),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.acType,
                    style: TextStyle(
                      color: Colors.blueGrey.shade600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 20,
              color: isSelected ? blue : const Color(0xFFBBC5D4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countPill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF1FF),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: blue,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget regularRoutesSection() {
    final query = routeSearch.text.trim().toLowerCase();
    final list = routes
        .where(
          (r) =>
              !shuttle.values.any((s) => s.contains(r.id)) &&
              ('${r.routeNumber} ${r.routeName} ${r.acType}')
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _searchField(
          controller: routeSearch,
          hint: 'Search route number, destination or AC type',
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 10),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('No matching routes found.')),
          )
        else
          ...list.map((r) => routeTile(r, regular, toggleRegular)),
      ],
    );
  }

  Widget shuttleSection() {
    final slots = destinations[selectedDestination] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontal Destination Selector Tabs (replaces deeply nested expansion cards)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: destinations.keys.map((dest) {
              final isChosen = selectedDestination == dest;
              final count = (destinations[dest] ?? []).fold<int>(
                0,
                (sum, s) => sum + (shuttle[s]?.length ?? 0),
              );
              return Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 4),
                child: ChoiceChip(
                  label: Text('$dest ($count)'),
                  selected: isChosen,
                  selectedColor: const Color(0xFFEAF1FF),
                  backgroundColor: const Color(0xFFF4F6FA),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isChosen ? FontWeight.w800 : FontWeight.w600,
                    color: isChosen ? blue : const Color(0xFF5B6B84),
                  ),
                  side: BorderSide(
                    color: isChosen ? blue : const Color(0xFFE2E8F0),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onSelected: (val) {
                    if (val) setState(() => selectedDestination = dest);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),

        // Flat slots list (Single accordion level only)
        ...slots.map((slot) {
          final chosen = shuttle[slot]!;
          final chosenRoute = routes
              .where((r) => chosen.contains(r.id))
              .toList();
          final query = slotSearch[slot]!.text.trim().toLowerCase();
          final candidates = routes
              .where(
                (r) =>
                    !regular.contains(r.id) &&
                    !shuttle.entries.any(
                      (e) => e.key != slot && e.value.contains(r.id),
                    ) &&
                    ('${r.routeNumber} ${r.routeName} ${r.acType}')
                        .toLowerCase()
                        .contains(query),
              )
              .toList();

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFE),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: chosen.isNotEmpty
                    ? blue.withOpacity(0.4)
                    : const Color(0xFFE5EAF2),
              ),
            ),
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 2,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              leading: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: chosen.isNotEmpty ? blue : const Color(0xFFE7ECF4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  slot,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: chosen.isNotEmpty
                        ? Colors.white
                        : const Color(0xFF475467),
                  ),
                ),
              ),
              title: Text(
                chosenRoute.isEmpty
                    ? 'Tap to assign bus'
                    : '${chosenRoute.first.routeNumber} · ${chosenRoute.first.routeName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: chosenRoute.isEmpty
                      ? Colors.blueGrey.shade400
                      : const Color(0xFF182941),
                ),
              ),
              trailing: chosen.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear $slot',
                      onPressed: () => setState(() {
                        chosen.clear();
                        if (activeSlot == slot) activeSlot = null;
                      }),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.red,
                        size: 20,
                      ),
                    )
                  : const Icon(Icons.expand_more_rounded, size: 20),
              children: [
                _searchField(
                  controller: slotSearch[slot]!,
                  hint: 'Search bus for slot $slot',
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 8),
                if (candidates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Text(
                        'No matching buses found.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ...candidates.map(
                    (r) => routeTile(r, chosen, (id) => toggleSlot(slot, id)),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget rangeAssignmentsPanel() {
    final date = operationDates.isEmpty
        ? DateTime.now()
        : (viewedScheduleDate ?? operationDates.first);
    final items = scheduleFor(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<DateTime>(
          value: operationDates.contains(date)
              ? date
              : (operationDates.isNotEmpty ? operationDates.first : null),
          isExpanded: true,
          decoration: _dropdownDecoration('Operation date'),
          items: operationDates
              .map((d) => DropdownMenuItem(value: d, child: Text(fmt(d))))
              .toList(),
          onChanged: (d) {
            if (d != null) setState(() => viewedScheduleDate = d);
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                '${items.length} assigned bus${items.length == 1 ? '' : 'es'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: saving
                  ? null
                  : () => setState(() {
                      addingToExistingDate = true;
                      regular.clear();
                      for (final set in shuttle.values) {
                        set.clear();
                      }
                    }),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add buses', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Clear all assignments for this date',
              onPressed: saving || items.isEmpty
                  ? null
                  : () => deassignWholeDate(date),
              icon: const Icon(
                Icons.delete_sweep_outlined,
                color: Colors.red,
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No buses assigned for ${fmt(date)}',
                style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13),
              ),
            ),
          )
        else
          ...items.map((a) => assignmentCard(date, a)),
      ],
    );
  }

  Widget assignmentCard(DateTime d, dynamic a) => Container(
    key: ValueKey('assignment-${a['assignmentId'] ?? a['routeId']}'),
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFD),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE8EDF4)),
    ),
    child: ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF1FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.directions_bus_rounded, color: blue, size: 18),
      ),
      title: Text(
        '${a['routeNumber'] ?? ''} · ${a['routeName'] ?? ''}',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      subtitle: Text(
        '${a['acType'] ?? ''}  •  ${a['assignmentType'] ?? ''}${a['shuttleGroup'] == null ? '' : '  •  ${a['shuttleGroup']}'}',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Manage bus',
        onSelected: (v) {
          if (v == 'edit') editAssignment(d, a);
          if (v == 'remove') deassign(d, a);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit bus')),
          PopupMenuItem(value: 'remove', child: Text('De-assign bus')),
        ],
      ),
    ),
  );

  Widget _categoryButton(
    String title,
    IconData icon,
    bool active,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [
                  const BoxShadow(
                    color: Color(0x100B2450),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? blue : const Color(0xFF697990),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: active ? blue : const Color(0xFF697990),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1764F5), Color(0xFF12305A)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: blue.withOpacity(0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'SHUBUS OPS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Afternoon assignments',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Plan buses across your operation dates.',
                  style: TextStyle(color: Color(0xFFDCE8FF), fontSize: 13),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.date_range_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              operationDates.length == 1
                                  ? fmt(fromDate)
                                  : '${fmt(fromDate)}  —  ${fmt(toDate)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${operationDates.length} date${operationDates.length == 1 ? '' : 's'} selected',
                              style: const TextStyle(
                                color: Color(0xFFDCE8FF),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: chooseRange,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'CHANGE',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Existing Assignments Section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE7ECF4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionLabel(
                  'Existing assignments',
                  'Review and manage buses assigned for each date.',
                  icon: Icons.event_available_rounded,
                ),
                rangeAssignmentsPanel(),
                if (operationDates.isNotEmpty &&
                    scheduleFor(
                      viewedScheduleDate ??
                          (operationDates.isEmpty
                              ? DateTime.now()
                              : operationDates.first),
                    ).isNotEmpty &&
                    !addingToExistingDate) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() {
                        addingToExistingDate = true;
                        regular.clear();
                        for (final set in shuttle.values) {
                          set.clear();
                        }
                      }),
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        size: 18,
                      ),
                      label: const Text('ADD BUSES TO THIS DATE'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: blue,
                        side: const BorderSide(color: blue, width: 1.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Bus Selection Section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE7ECF4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (addingToExistingDate) ...[
                  Row(
                    children: [
                      Expanded(
                        child: sectionLabel(
                          'Add buses',
                          'Adding to ${fmt(viewedScheduleDate ?? (operationDates.isEmpty ? DateTime.now() : operationDates.first))}.',
                          icon: Icons.add_road_rounded,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          addingToExistingDate = false;
                          regular.clear();
                          for (final set in shuttle.values) {
                            set.clear();
                          }
                        }),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text(
                          'CANCEL',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ] else
                  sectionLabel(
                    'Choose buses',
                    'Select buses to apply across operation dates.',
                    icon: Icons.directions_bus_rounded,
                  ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF0F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _categoryButton(
                          'Regular (${regular.length})',
                          Icons.directions_bus_filled_rounded,
                          assignmentCategory == 0,
                          () => setState(() => assignmentCategory = 0),
                        ),
                      ),
                      Expanded(
                        child: _categoryButton(
                          'Shuttle (${shuttle.values.fold<int>(0, (n, s) => n + s.length)})',
                          Icons.alt_route_rounded,
                          assignmentCategory == 1,
                          () => setState(() => assignmentCategory = 1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (assignmentCategory == 0)
                  regularRoutesSection()
                else
                  shuttleSection(),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Action Summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F5FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCE7FF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.checklist_rounded, color: blue, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Assignment summary',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    _countPill('$selectedCount buses'),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  addingToExistingDate
                      ? '$selectedCount selected bus/slot assignment(s) will be added to ${fmt(viewedScheduleDate ?? (operationDates.isEmpty ? DateTime.now() : operationDates.first))}.'
                      : '$selectedCount selected bus/slot assignment(s) will be applied across ${operationDates.length} operation date(s). Existing assignments are skipped.',
                  style: TextStyle(
                    color: Colors.blueGrey.shade700,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: selectedCount == 0 || saving ? null : assign,
                    style: FilledButton.styleFrom(
                      backgroundColor: blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      saving
                          ? 'SAVING…'
                          : (addingToExistingDate
                                ? 'ADD SELECTED BUSES'
                                : 'ASSIGN BUSES'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: .3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
