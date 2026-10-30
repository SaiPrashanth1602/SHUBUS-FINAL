import 'package:flutter/material.dart';

import '../models/route_model.dart';
import '../services/route_service.dart';

class AfternoonAssignmentScreen extends StatefulWidget {
  const AfternoonAssignmentScreen({super.key});

  @override
  State<AfternoonAssignmentScreen> createState() =>
      AfternoonAssignmentScreenState();
}

class AfternoonAssignmentScreenState
    extends State<AfternoonAssignmentScreen> {
  final service = RouteService();

  static const Color navy = Color(0xFF12305A);
  static const Color paleBlue = Color(0xFFF0F6FF);
  static const Color danger = Color(0xFFB42318);

  static const Map<String, List<String>> destinations = {
    'ALANDUR METRO': ['A1', 'A2', 'A3', 'A4', 'A5'],
    'VELACHERY': ['V1', 'V2', 'V3'],
    'SHOLINGANALLUR': ['S1'],
    'TAMBARAM': ['T1'],
  };

  List<RouteModel> routes = [];
  Map<DateTime, List<dynamic>> schedules = {};

  DateTime selectedDate = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );

  final Set<int> regular = {};
  final Set<int> selectedAssignmentIds = {};

  final Set<int> pendingRegular = {};
  final Map<String, Set<int>> pendingShuttle = {
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

  int assignmentCategory = 0;
  String selectedDestination = destinations.keys.first;

  bool loading = true;
  bool _loadInProgress = false;
  String? loadError;
  bool saving = false;

  final ScrollController scrollController = ScrollController();

  final TextEditingController routeSearch = TextEditingController();
  final TextEditingController assignedSearch = TextEditingController();

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

  StateSetter? _editSheetSetState;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    scrollController.dispose();
    routeSearch.dispose();
    assignedSearch.dispose();

    for (final controller in slotSearch.values) {
      controller.dispose();
    }

    super.dispose();
  }

  int? asInt(dynamic v) => v is int ? v : int.tryParse('$v');

  int? assignmentIdOf(dynamic item) {
    if (item is! Map) return null;
    return asInt(item['assignmentId'] ?? item['id']);
  }

  DateTime day(DateTime d) => DateUtils.dateOnly(d);

  String fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  void msg(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text)),
      );
    }
  }

  Future<void> chooseDate() async {
    final today = DateUtils.dateOnly(DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(today) ? today : selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Select operational date',
      confirmText: 'Set date',
    );

    if (picked == null) return;

    setState(() {
      selectedDate = day(picked);
      selectedAssignmentIds.clear();
      routeSearch.clear();
      assignedSearch.clear();

      for (final c in slotSearch.values) {
        c.clear();
      }
    });

    await load();
  }

  Future<void> load({bool showLoading = true}) async {
    if (_loadInProgress) return;
    _loadInProgress = true;

    if (mounted && showLoading) {
      setState(() => loading = true);
    }

    try {
      final today = DateUtils.dateOnly(DateTime.now());
      final discoveryStart = today.add(const Duration(days: 1));
      final discoveryEnd = today.add(const Duration(days: 365));

      final routeData = await service.getRoutes();
      final loaded = <DateTime, List<dynamic>>{};

      final range = await service.getAssignmentsForRange(
        discoveryStart,
        discoveryEnd,
      );

      loaded.addAll(range);

      if (!mounted) return;

      setState(() {
        routes = routeData;
        schedules = loaded;

        if (!loaded.containsKey(selectedDate)) {
          schedules[selectedDate] = [];
        }

        final allAssignmentIds = loaded.values
            .expand((items) => items)
            .map(assignmentIdOf)
            .whereType<int>()
            .toSet();

        selectedAssignmentIds.removeWhere(
          (id) => !allAssignmentIds.contains(id),
        );

        loading = false;
        loadError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          loadError = 'Could not load schedules: $e';
        });
        msg('Could not load schedules: $e');
      }
    } finally {
      _loadInProgress = false;
    }
  }

  List<dynamic> scheduleFor(DateTime d) => schedules[day(d)] ?? [];

  bool assignedOn(DateTime d, int id) =>
      scheduleFor(d).any((a) => asInt(a['routeId']) == id);

  int get selectedCount =>
      regular.length + shuttle.values.fold(0, (n, s) => n + s.length);

  int get pendingCount =>
      pendingRegular.length +
      pendingShuttle.values.fold(0, (n, s) => n + s.length);

  List<RouteModel> get pendingRoutes => routes
      .where(
        (r) =>
            pendingRegular.contains(r.id) ||
            pendingShuttle.values.any((s) => s.contains(r.id)),
      )
      .toList();

  void toggleRegular(int id) {
    setState(() {
      if (regular.contains(id)) {
        regular.remove(id);
      } else {
        regular.add(id);

        for (final slotSet in shuttle.values) {
          slotSet.remove(id);
        }
      }
    });
  }

  void toggleSlot(String slot, int id) {
    setState(() {
      final set = shuttle[slot]!;

      if (set.contains(id)) {
        set.remove(id);
        return;
      }

      set.clear();
      regular.remove(id);

      for (final entry in shuttle.entries) {
        if (entry.key != slot) {
          entry.value.remove(id);
        }
      }

      set.add(id);
    });
  }

  void clearSelections() {
    regular.clear();

    for (final set in shuttle.values) {
      set.clear();
    }

    routeSearch.clear();
    assignedSearch.clear();

    for (final controller in slotSearch.values) {
      controller.clear();
    }
  }

  void clearPendingAdditions() {
    pendingRegular.clear();

    for (final set in pendingShuttle.values) {
      set.clear();
    }
  }

  Future<void> assignToSelectedDate() async {
    if (pendingCount == 0 || saving) return;

    setState(() => saving = true);

    var created = 0;
    final failures = <String>[];

    try {
      final date = selectedDate;
      final dateLabel = fmt(date);

      if (pendingRegular.isNotEmpty) {
        try {
          await service.assignRoutes(
            date: date,
            routeIds: pendingRegular.toList(),
            assignmentType: 'REGULAR',
          );
          created += pendingRegular.length;
        } catch (e) {
          failures.add('$dateLabel — Regular: $e');
        }
      }

      for (final entry in pendingShuttle.entries) {
        if (entry.value.isEmpty) continue;

        try {
          await service.assignRoutes(
            date: date,
            routeIds: entry.value.toList(),
            assignmentType: 'SHUTTLE',
            shuttleGroup: entry.key,
          );
          created += entry.value.length;
        } catch (e) {
          failures.add('$dateLabel — ${entry.key}: $e');
        }
      }

      clearPendingAdditions();
      await load(showLoading: false);
      _refreshEditSheet();

      if (failures.isEmpty) {
        msg('Added $created bus${created == 1 ? '' : 'es'} to $dateLabel.');
      } else {
        msg(
          'Added $created bus${created == 1 ? '' : 'es'}; '
          '${failures.length} batch(es) failed.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> assignToRange(DateTime endDate) async {
    if (selectedCount == 0 || saving) return;

    final startDate = day(selectedDate);
    final safeEndDate = day(endDate);

    if (safeEndDate.isBefore(startDate)) {
      msg('End date cannot be before the selected date.');
      return;
    }

    final targetDates = <DateTime>[];

    for (
      var d = startDate;
      !d.isAfter(safeEndDate);
      d = d.add(const Duration(days: 1))
    ) {
      targetDates.add(d);
    }

    setState(() => saving = true);

    var created = 0;
    var skipped = 0;
    final failures = <String>[];

    try {
      for (final date in targetDates) {
        final dateLabel = fmt(date);

        final dayRegular = regular
            .where((id) => !assignedOn(date, id))
            .toList();

        skipped += regular.length - dayRegular.length;

        if (dayRegular.isNotEmpty) {
          try {
            await service.assignRoutes(
              date: date,
              routeIds: dayRegular,
              assignmentType: 'REGULAR',
            );
            created += dayRegular.length;
          } catch (e) {
            failures.add('$dateLabel — Regular: $e');
          }
        }

        for (final entry in shuttle.entries) {
          final ids = entry.value
              .where((id) => !assignedOn(date, id))
              .toList();

          skipped += entry.value.length - ids.length;

          if (ids.isEmpty) continue;

          try {
            await service.assignRoutes(
              date: date,
              routeIds: ids,
              assignmentType: 'SHUTTLE',
              shuttleGroup: entry.key,
            );
            created += ids.length;
          } catch (e) {
            failures.add('$dateLabel — ${entry.key}: $e');
          }
        }
      }

      clearSelections();
      await load(showLoading: false);

      if (failures.isEmpty) {
        final skipText = skipped > 0
            ? ' Skipped $skipped already-assigned bus/date pair(s).'
            : '';

        msg(
          'Created $created assignment(s) across ${targetDates.length} date(s).$skipText',
        );
      } else {
        msg(
          'Created $created assignment(s); ${failures.length} batch(es) failed.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _refreshEditSheet() {
    if (_editSheetSetState != null) {
      _editSheetSetState!(() {});
    }
  }

  Future<void> openEditSheet() async {
    selectedAssignmentIds.clear();
    clearPendingAdditions();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            _editSheetSetState = setSheetState;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.88,
                maxChildSize: 0.95,
                minChildSize: 0.60,
                builder: (context, sheetScrollController) {
                  return _buildEditSheet(
                    sheetContext,
                    sheetScrollController,
                    setSheetState,
                  );
                },
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _editSheetSetState = null;
    });
  }

  Widget _buildEditSheet(
    BuildContext sheetContext,
    ScrollController sheetScrollController,
    StateSetter setSheetState,
  ) {
    final date = selectedDate;
    final items = scheduleFor(date);

    final query = assignedSearch.text.trim().toLowerCase();

    final filteredItems = items.where((a) {
      if (query.isEmpty) return true;

      final text =
          '${a['routeNumber'] ?? ''} '
                  '${a['routeName'] ?? ''} '
                  '${a['acType'] ?? ''} '
                  '${a['assignmentType'] ?? ''} '
                  '${a['shuttleGroup'] ?? ''}'
              .toLowerCase();

      return text.contains(query);
    }).toList();

    final selectedIds = items
        .map(assignmentIdOf)
        .whereType<int>()
        .where(selectedAssignmentIds.contains)
        .toSet();

    return Column(
      children: [
        Container(
          width: 44,
          margin: const EdgeInsets.only(top: 10),
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit assigned buses',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fmt(date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF68758A),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(sheetContext),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Checkbox(
                tristate: true,
                value: items.isEmpty
                    ? false
                    : items.every((a) {
                        final id = assignmentIdOf(a);
                        return id != null &&
                            selectedAssignmentIds.contains(id);
                      })
                    ? true
                    : items.any(
                        (a) => selectedAssignmentIds
                            .contains(assignmentIdOf(a)),
                      )
                    ? null
                    : false,
                onChanged: (value) => setSheetState(() {
                  final ids = items
                      .map(assignmentIdOf)
                      .whereType<int>()
                      .toSet();

                  if (value == true) {
                    selectedAssignmentIds.addAll(ids);
                  } else {
                    selectedAssignmentIds.removeAll(ids);
                  }
                }),
                activeColor: navy,
                visualDensity: VisualDensity.compact,
              ),
              Text(
                'Selected: ${selectedIds.length}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: saving
                    ? null
                    : () {
                        openAddBusSheet(
                          parentContext: sheetContext,
                          setSheetState: setSheetState,
                        );
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: navy,
                  side: const BorderSide(color: navy),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add bus'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed:
                    selectedIds.isEmpty || saving
                        ? null
                        : () => deassignSelectedAssignments(date),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      selectedIds.isEmpty ? Colors.grey.shade300 : danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete'),
              ),
            ],
          ),
        ),
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _searchField(
              controller: assignedSearch,
              hint: 'Search assigned buses',
              onChanged: () => setSheetState(() {}),
            ),
          ),
        Expanded(
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: navy),
                )
              : items.isEmpty
                  ? Center(
                      child: Text(
                        'No buses assigned for ${fmt(date)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF758198),
                        ),
                      ),
                    )
                  : ListView(
                      controller: sheetScrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      children: [
                        if (filteredItems.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'No matching assigned buses found.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF758198),
                                ),
                              ),
                            ),
                          )
                        else
                          ...filteredItems.map(
                            (a) => assignmentCard(date, a),
                          ),
                        if (pendingCount > 0) ...[
                          const SizedBox(height: 14),
                          const Text(
                            'NEWLY SELECTED BUSES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: navy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...pendingRoutes.map(
                            (route) => _pendingRouteCard(route),
                          ),
                        ],
                      ],
                    ),
        ),
        if (pendingCount > 0)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: saving ? null : assignToSelectedDate,
                style: FilledButton.styleFrom(
                  backgroundColor: navy,
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
                    : const Icon(Icons.check_circle_rounded),
                label: Text(
                  saving
                      ? 'Saving…'
                      : 'Confirm changes • Add $pendingCount bus${pendingCount == 1 ? '' : 'es'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> openAddBusSheet({
    BuildContext? parentContext,
    StateSetter? setSheetState,
  }) async {
    clearSelections();

    final hasAssignments = scheduleFor(selectedDate).isNotEmpty;

    if (!hasAssignments) {
      regular.addAll(
        routes
            .where((route) => route.defaultAfternoon)
            .map((route) => route.id),
      );
    }

    final sheetParent = parentContext ?? context;

    await showModalBottomSheet<void>(
      context: sheetParent,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (addSheetContext) {
        return StatefulBuilder(
          builder: (addSheetContext, setAddSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(addSheetContext).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.88,
                maxChildSize: 0.95,
                minChildSize: 0.60,
                builder: (context, sheetScrollController) {
                  return Column(
                    children: [
                      Container(
                        width: 44,
                        margin: const EdgeInsets.only(top: 10),
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hasAssignments
                                        ? 'Add buses'
                                        : 'Assign buses',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: navy,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${fmt(selectedDate)} • $selectedCount selected',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF68758A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  Navigator.pop(addSheetContext),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: paleBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _categoryButton(
                                'Regular (${regular.length})',
                                Icons.directions_bus_filled_rounded,
                                assignmentCategory == 0,
                                () => setAddSheetState(
                                  () => assignmentCategory = 0,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _categoryButton(
                                'Shuttle (${shuttle.values.fold<int>(0, (n, s) => n + s.length)})',
                                Icons.alt_route_rounded,
                                assignmentCategory == 1,
                                () => setAddSheetState(
                                  () => assignmentCategory = 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: sheetScrollController,
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            100,
                          ),
                          child: assignmentCategory == 0
                              ? regularRoutesSection(
                                  onChanged: () => setAddSheetState(() {}),
                                )
                              : shuttleSection(
                                  onChanged: () => setAddSheetState(() {}),
                                ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: selectedCount == 0 || saving
                                ? null
                                : () async {
                                    if (hasAssignments) {
                                      final confirmed =
                                          await _confirmAddSelection();

                                      if (confirmed != true) return;

                                      pendingRegular.clear();
                                      for (final set
                                          in pendingShuttle.values) {
                                        set.clear();
                                      }

                                      pendingRegular.addAll(regular);

                                      for (final entry in shuttle.entries) {
                                        pendingShuttle[entry.key]!
                                            .addAll(entry.value);
                                      }

                                      clearSelections();

                                      if (mounted) {
                                        Navigator.pop(addSheetContext);
                                      }

                                      _refreshEditSheet();
                                    } else {
                                      final endDate =
                                          await _pickRangeEndDate();

                                      if (endDate == null) return;

                                      final confirmed =
                                          await _confirmRangeAssignment(
                                        endDate,
                                      );

                                      if (confirmed != true) return;

                                      if (mounted) {
                                        Navigator.pop(addSheetContext);
                                      }

                                      await assignToRange(endDate);
                                    }
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: navy,
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
                                : const Icon(Icons.check_circle_rounded),
                            label: Text(
                              saving
                                  ? 'Saving…'
                                  : hasAssignments
                                      ? 'Confirm selection'
                                      : 'Assign $selectedCount bus${selectedCount == 1 ? '' : 'es'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<bool?> _confirmAddSelection() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm selection?'),
        content: Text(
          'Add $selectedCount bus${selectedCount == 1 ? '' : 'es'} '
          'to ${fmt(selectedDate)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: navy),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _pickRangeEndDate() {
    return showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: selectedDate,
      lastDate: selectedDate.add(const Duration(days: 365)),
      helpText: 'Select end date',
      confirmText: 'Set end date',
    );
  }

  Future<bool?> _confirmRangeAssignment(DateTime endDate) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign buses?'),
        content: Text(
          'Assign $selectedCount bus${selectedCount == 1 ? '' : 'es'} '
          'from ${fmt(selectedDate)} to ${fmt(endDate)}?\n\n'
          'Existing assignments will be skipped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: navy),
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  Future<void> editAssignment(DateTime date, dynamic a) async {
    final id = assignmentIdOf(a);
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

    if (!assignmentTypes.contains(type)) {
      type = 'REGULAR';
    }

    var group = '${a['shuttleGroup'] ?? 'A1'}';

    if (!shuttleGroups.contains(group)) {
      group = 'A1';
    }

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
                    DropdownMenuItem(
                      value: 'SHUTTLE',
                      child: Text('Shuttle'),
                    ),
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
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, {'type': type, 'group': group}),
              style: FilledButton.styleFrom(backgroundColor: navy),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    try {
      await service.updateAssignment(
        id: id,
        assignmentType: result['type']!,
        shuttleGroup: result['type'] == 'SHUTTLE' ? result['group'] : null,
      );

      await load();
      _refreshEditSheet();
      msg('Assignment updated.');
    } catch (e) {
      await load();
      _refreshEditSheet();
      msg(
        'Could not complete edit: $e. '
        'Please verify the assignment for ${fmt(date)}.',
      );
    }
  }

  Future<void> deassign(DateTime date, dynamic a) async {
    final id = assignmentIdOf(a);

    if (id == null) {
      msg('Assignment ID was not returned by the backend.');
      return;
    }

    final yes = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove assignment?'),
            content: Text(
              'Remove ${a['routeNumber'] ?? 'this route'} '
              'from operation date ${fmt(date)}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: navy),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;

    if (!yes) return;

    try {
      await service.deleteAssignment(id);
      await load();
      _refreshEditSheet();
      msg('Assignment removed.');
    } catch (e) {
      msg('Could not remove assignment: $e');
    }
  }

  Future<void> deassignSelectedAssignments(DateTime date) async {
    if (saving) return;

    final dateAssignmentIds = scheduleFor(date)
        .map(assignmentIdOf)
        .whereType<int>()
        .toSet();

    final ids = selectedAssignmentIds.intersection(dateAssignmentIds);

    if (ids.isEmpty) {
      msg('Select at least one assignment on ${fmt(date)} to delete.');
      return;
    }

    final yes = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Remove ${ids.length} selected assignment(s)?'),
            content: Text(
              'Only the checked assignments for ${fmt(date)} will be removed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: navy),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remove selected'),
              ),
            ],
          ),
        ) ??
        false;

    if (!yes) return;

    setState(() => saving = true);

    var removed = 0;
    final failed = <int>[];

    try {
      for (final id in ids) {
        try {
          await service.deleteAssignment(id);
          removed++;
        } catch (_) {
          failed.add(id);
        }
      }

      selectedAssignmentIds
          .removeAll(ids.where((id) => !failed.contains(id)));

      await load();
      _refreshEditSheet();

      msg(
        failed.isEmpty
            ? 'Removed $removed assignment(s).'
            : 'Removed $removed assignment(s); ${failed.length} could not be removed.',
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _searchField({
    required TextEditingController controller,
    required String hint,
    required VoidCallback onChanged,
  }) =>
      TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF22314A),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 12,
            color: Color(0xFF8993A5),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: navy,
          ),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
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
            borderSide: const BorderSide(
              color: navy,
              width: 1.4,
            ),
          ),
        ),
      );

  InputDecoration _dropdownDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 12,
          color: Color(0xFF68758A),
        ),
        floatingLabelStyle: const TextStyle(
          color: navy,
          fontWeight: FontWeight.w700,
        ),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDCE4EF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: navy,
            width: 1.4,
          ),
        ),
      );

  Widget _routeNumberBadge(
    String routeNumber, {
    bool selected = false,
  }) {
    return SizedBox(
      width: 44,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 3,
          vertical: 7,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? navy : paleBlue,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected ? navy : navy.withValues(alpha: 0.20),
          ),
        ),
        child: Text(
          routeNumber,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : navy,
          ),
        ),
      ),
    );
  }

  Widget routeTile(RouteModel r, Set<int> selected, void Function(int) toggle) {
    final isSelected = selected.contains(r.id);

    return InkWell(
      key: ValueKey<int>(r.id),
      borderRadius: BorderRadius.circular(12),
      onTap: () => toggle(r.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? paleBlue : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? navy : const Color(0xFFE5EAF2),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            _routeNumberBadge(r.routeNumber, selected: isSelected),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.routeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: Color(0xFF22314A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.acType,
                    style: const TextStyle(
                      color: Color(0xFF758198),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 19,
              color: isSelected ? navy : const Color(0xFFBBC5D4),
            ),
          ],
        ),
      ),
    );
  }

  Widget regularRoutesSection({required VoidCallback onChanged}) {
    final query = routeSearch.text.trim().toLowerCase();

    final list = routes
        .where(
          (r) =>
              !shuttle.values.any((s) => s.contains(r.id)) &&
              !assignedOn(selectedDate, r.id) &&
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
          onChanged: onChanged,
        ),
        const SizedBox(height: 10),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No available buses found.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF758198),
                ),
              ),
            ),
          )
        else
          ...list.map(
            (r) => routeTile(r, regular, (id) {
              toggleRegular(id);
              onChanged();
            }),
          ),
      ],
    );
  }

  Widget shuttleSection({required VoidCallback onChanged}) {
    final slots = destinations[selectedDestination] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  selectedColor: navy,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isChosen ? FontWeight.w800 : FontWeight.w600,
                    color: isChosen ? Colors.white : const Color(0xFF5B6B84),
                  ),
                  side: BorderSide(
                    color: isChosen ? navy : const Color(0xFFE2E8F0),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onSelected: (val) {
                    if (val) {
                      selectedDestination = dest;
                    }
                    onChanged();
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
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
                    !assignedOn(selectedDate, r.id) &&
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: chosen.isNotEmpty
                    ? navy.withValues(alpha: 0.45)
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: chosen.isNotEmpty ? navy : paleBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  slot,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    color: chosen.isNotEmpty ? Colors.white : navy,
                  ),
                ),
              ),
              title: Text(
                chosenRoute.isEmpty
                    ? 'Tap to assign one bus'
                    : '${chosenRoute.first.routeNumber} • ${chosenRoute.first.routeName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: chosenRoute.isEmpty
                      ? const Color(0xFF8993A5)
                      : const Color(0xFF22314A),
                ),
              ),
              subtitle: const Text(
                'One bus per slot',
                style: TextStyle(fontSize: 10),
              ),
              trailing: chosen.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear $slot',
                      onPressed: () {
                        chosen.clear();
                        onChanged();
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        color: danger,
                        size: 19,
                      ),
                    )
                  : const Icon(Icons.expand_more_rounded, size: 19),
              children: [
                _searchField(
                  controller: slotSearch[slot]!,
                  hint: 'Search available bus for $slot',
                  onChanged: onChanged,
                ),
                const SizedBox(height: 8),
                if (candidates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Text(
                        'No available buses found.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF758198),
                        ),
                      ),
                    ),
                  )
                else
                  ...candidates.map(
                    (r) => routeTile(r, chosen, (id) {
                      toggleSlot(slot, id);
                      onChanged();
                    }),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget assignmentCard(
    DateTime d,
    dynamic a, {
    bool selectable = true,
  }) {
    final id = assignmentIdOf(a);
    final isSelected =
        selectable && id != null && selectedAssignmentIds.contains(id);

    final routeNumber = '${a['routeNumber'] ?? ''}';
    final routeName = '${a['routeName'] ?? ''}';

    return Container(
      key: ValueKey(
        'assignment-${a['assignmentId'] ?? a['id'] ?? a['routeId']}',
      ),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? navy.withValues(alpha: 0.45)
              : const Color(0xFFE8EDF4),
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 0,
        ),
        leading: selectable
            ? Checkbox(
                value: isSelected,
                onChanged: (checked) {
                  if (id == null) {
                    msg(
                      'This assignment has no ID, so it cannot be selected for bulk deletion.',
                    );
                    return;
                  }

                  _editSheetSetState?.call(() {
                    if (checked == true) {
                      selectedAssignmentIds.add(id);
                    } else {
                      selectedAssignmentIds.remove(id);
                    }
                  });
                },
                activeColor: navy,
                visualDensity: VisualDensity.compact,
              )
            : _routeNumberBadge(routeNumber),
        title: Text(
          selectable ? '$routeNumber • $routeName' : routeName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
            color: Color(0xFF22314A),
          ),
        ),
        subtitle: Text(
          '${a['acType'] ?? ''} • ${a['assignmentType'] ?? ''}'
          '${a['shuttleGroup'] == null ? '' : ' • ${a['shuttleGroup']}'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10.5,
            color: Color(0xFF758198),
          ),
        ),
        trailing: selectable
            ? PopupMenuButton<String>(
                tooltip: 'Manage bus',
                onSelected: (v) {
                  if (v == 'edit') editAssignment(d, a);
                  if (v == 'remove') deassign(d, a);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit bus'),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Text('De-assign bus'),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _pendingRouteCard(RouteModel route) {
    String? slot;

    for (final entry in pendingShuttle.entries) {
      if (entry.value.contains(route.id)) {
        slot = entry.key;
        break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: paleBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: navy.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          _routeNumberBadge(route.routeNumber, selected: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route.routeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: Color(0xFF22314A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  slot == null ? route.acType : '${route.acType} • $slot',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF758198),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: navy,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'NEW',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: active ? navy : const Color(0xFF697990),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: active ? navy : const Color(0xFF697990),
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
    if (loading && routes.isEmpty && schedules.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: navy),
      );
    }

    final items = scheduleFor(selectedDate);

    final query = assignedSearch.text.trim().toLowerCase();

    final filteredItems = items.where((a) {
      if (query.isEmpty) return true;

      final text =
          '${a['routeNumber'] ?? ''} '
                  '${a['routeName'] ?? ''} '
                  '${a['acType'] ?? ''} '
                  '${a['assignmentType'] ?? ''} '
                  '${a['shuttleGroup'] ?? ''}'
              .toLowerCase();

      return text.contains(query);
    }).toList();

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              children: [
                if (loading) ...[
                  const ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: Color(0x2212305A),
                      color: navy,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.all(17),
                  decoration: BoxDecoration(
                    color: navy,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PICK OPERATIONAL DATE',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(13),
                          onTap: loading || saving ? null : chooseDate,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  size: 20,
                                  color: navy,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    fmt(selectedDate),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: navy,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.expand_more_rounded,
                                  size: 20,
                                  color: navy,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE7ECF4)),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.event_busy_outlined,
                          size: 34,
                          color: Color(0xFF8993A5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No buses assigned for ${fmt(selectedDate)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF22314A),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: FilledButton.icon(
                            onPressed: saving
                                ? null
                                : () => openAddBusSheet(),
                            style: FilledButton.styleFrom(
                              backgroundColor: navy,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text(
                              'Assign buses',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE7ECF4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ASSIGNED BUSES',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                      color: Color(0xFF68758A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${items.length} bus${items.length == 1 ? '' : 'es'} assigned',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: navy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.icon(
                              onPressed:
                                  saving ? null : () => openEditSheet(),
                              style: FilledButton.styleFrom(
                                backgroundColor: navy,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 9,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 17),
                              label: const Text(
                                'Edit',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _searchField(
                          controller: assignedSearch,
                          hint: 'Search assigned buses',
                          onChanged: () => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        if (filteredItems.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: Text(
                                'No matching assigned buses found.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF758198),
                                ),
                              ),
                            ),
                          )
                        else
                          ...filteredItems.map(
                            (a) => assignmentCard(
                              selectedDate,
                              a,
                              selectable: false,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}