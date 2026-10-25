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
  final Set<int> selectedAssignmentIds = {};

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
  bool selectionMade = false;
  bool sectionDefaultsInitialized = false;
  bool existingAssignmentsExpanded = true;
  bool assignMoreExpanded = true;

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

  Future<void> chooseStartDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: fromDate.isBefore(today) ? today : fromDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Select START date',
      confirmText: 'SET START',
    );
    if (picked == null) return;

    setState(() {
      fromDate = day(picked);
      if (toDate.isBefore(fromDate)) toDate = fromDate;
      viewedScheduleDate = fromDate;
      routeSearch.clear();
      assignedSearch.clear();
      for (final c in slotSearch.values) {
        c.clear();
      }
    });
    await load();
  }

  Future<void> chooseEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: toDate.isBefore(fromDate) ? fromDate : toDate,
      firstDate: fromDate,
      lastDate: DateUtils.dateOnly(
        DateTime.now(),
      ).add(const Duration(days: 365)),
      helpText: 'Select END date',
      confirmText: 'SET END',
    );
    if (picked == null) return;

    setState(() {
      toDate = day(picked);
      viewedScheduleDate = fromDate;
      routeSearch.clear();
      assignedSearch.clear();
      for (final c in slotSearch.values) {
        c.clear();
      }
    });
    await load();
  }

  Future<void> load({
    bool showLoading = true,
    bool preserveFormState = false,
  }) async {
    if (_loadInProgress) return;
    _loadInProgress = true;

    if (mounted && showLoading) {
      setState(() => loading = true);
    }

    try {
      final today = DateUtils.dateOnly(DateTime.now());
      final selectedDates = operationDates;
      final discoveryStart = today.add(const Duration(days: 1));
      final discoveryEnd = today.add(const Duration(days: 365));
      final startDate =
          selectedDates.isEmpty || !selectedDates.first.isBefore(discoveryStart)
          ? discoveryStart
          : selectedDates.first;
      final endDate =
          selectedDates.isEmpty || !selectedDates.last.isAfter(discoveryEnd)
          ? discoveryEnd
          : selectedDates.last;
      final routeData = await service.getRoutes();
      final loaded = <DateTime, List<dynamic>>{};

      final range = await service.getAssignmentsForRange(startDate, endDate);
      loaded.addAll(range);

      if (!mounted) return;

      setState(() {
        routes = routeData;
        schedules = loaded;
        final today = DateUtils.dateOnly(DateTime.now());
        final futureAssignmentDates =
            loaded.entries
                .where(
                  (entry) =>
                      DateUtils.dateOnly(entry.key).isAfter(today) &&
                      entry.value.isNotEmpty,
                )
                .map((entry) => DateUtils.dateOnly(entry.key))
                .toList()
              ..sort();

        if (!sectionDefaultsInitialized) {
          final hasFutureAssignments = futureAssignmentDates.isNotEmpty;
          existingAssignmentsExpanded = hasFutureAssignments;
          assignMoreExpanded = !hasFutureAssignments;
          sectionDefaultsInitialized = true;
        }

        final allAssignmentIds = loaded.values
            .expand((items) => items)
            .map(assignmentIdOf)
            .whereType<int>()
            .toSet();
        selectedAssignmentIds.removeWhere(
          (id) => !allAssignmentIds.contains(id),
        );

        final viewedDateIsLoaded =
            viewedScheduleDate != null &&
            loaded.containsKey(day(viewedScheduleDate!));
        if (futureAssignmentDates.isNotEmpty && !viewedDateIsLoaded) {
          viewedScheduleDate = futureAssignmentDates.first;
        } else if (viewedScheduleDate == null ||
            !loaded.containsKey(day(viewedScheduleDate!))) {
          viewedScheduleDate = operationDates.isEmpty
              ? null
              : operationDates.first;
        }

        if (!preserveFormState) {
          regular.clear();
          selectionMade = false;
          for (final s in shuttle.values) {
            s.clear();
          }
          regular.addAll(
            routes.where((r) => r.defaultAfternoon).map((r) => r.id),
          );
        }

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

  List<DateTime> get assignmentViewDates {
    final dates = <DateTime>{
      ...operationDates.map(day),
      for (final entry in schedules.entries)
        if (entry.value.isNotEmpty) day(entry.key),
    }.toList()..sort();
    return dates;
  }

  bool get hasFutureAssignments {
    final today = DateUtils.dateOnly(DateTime.now());
    return schedules.entries.any(
      (entry) =>
          DateUtils.dateOnly(entry.key).isAfter(today) &&
          entry.value.isNotEmpty,
    );
  }

  bool assignedOn(DateTime d, int id) =>
      scheduleFor(d).any((a) => asInt(a['routeId']) == id);

  // A bus remains selectable for a date range if at least one date still
  // needs it. assign() skips only the already-assigned bus/date pairs.
  bool assignedOnEveryDate(int id) =>
      operationDates.isNotEmpty &&
      operationDates.every((d) => assignedOn(d, id));

  int get selectedCount =>
      regular.length + shuttle.values.fold(0, (n, s) => n + s.length);

  List<RouteModel> get selectedRoutes => routes
      .where(
        (r) =>
            regular.contains(r.id) ||
            shuttle.values.any((s) => s.contains(r.id)),
      )
      .toList();

  DateTime get activeDate {
    if (operationDates.isEmpty) {
      return DateTime.now();
    }

    return day(viewedScheduleDate ?? operationDates.first);
  }

  void toggleRegular(int id) {
    setState(() {
      selectionMade = true;
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
      selectionMade = true;
      final set = shuttle[slot]!;

      if (set.contains(id)) {
        set.remove(id);
        return;
      }

      // Only one bus is allowed per shuttle slot.
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
    selectionMade = false;
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

  List<DateTime> get datesToAssign => operationDates;

  Future<void> assign() async {
    if (selectedCount == 0 || saving) return;

    final targetDates = datesToAssign;
    if (targetDates.isEmpty) {
      msg('Choose a valid start and end date first.');
      return;
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
          final ids = entry.value.where((id) => !assignedOn(date, id)).toList();
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

      // Move to the existing-assignments view only when the operation was
      // successful or all requested items were already assigned. If every
      // batch failed, keep the form visible so the admin can correct/retry.
      final shouldShowExisting =
          created > 0 || (failures.isEmpty && skipped > 0);
      if (mounted && shouldShowExisting) {
        setState(() {
          assignMoreExpanded = false;
          existingAssignmentsExpanded = true;
        });
      }
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
          'Created $created assignment(s); ${failures.length} batch(es) failed. Check the selected dates and refresh.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> openAddBusSheet() async {
    clearSelections();

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
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.85,
                maxChildSize: 0.95,
                minChildSize: 0.60,
                builder: (context, sheetScrollController) {
                  return Column(
                    children: [
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: LinearProgressIndicator(minHeight: 3),
                        ),
                      if (loadError != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFD4CC)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.cloud_off_outlined,
                                color: Color(0xFFB42318),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  loadError!,
                                  style: const TextStyle(
                                    color: Color(0xFF7A271A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                                    'Add buses',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF12233F),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Adding to ${operationDates.length} date${operationDates.length == 1 ? '' : 's'} (${fmt(fromDate)} – ${fmt(toDate)})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blueGrey.shade600,
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
                      const SizedBox(height: 8),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
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
                                () =>
                                    setSheetState(() => assignmentCategory = 0),
                              ),
                            ),
                            Expanded(
                              child: _categoryButton(
                                'Shuttle (${shuttle.values.fold<int>(0, (n, s) => n + s.length)})',
                                Icons.alt_route_rounded,
                                assignmentCategory == 1,
                                () =>
                                    setSheetState(() => assignmentCategory = 1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: sheetScrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          child: assignmentCategory == 0
                              ? regularRoutesSection(
                                  onChanged: () => setSheetState(() {}),
                                )
                              : shuttleSection(
                                  onChanged: () => setSheetState(() {}),
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
                                    Navigator.pop(sheetContext);
                                    await assign();
                                  },
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
                                : const Icon(Icons.check_circle_rounded),
                            label: Text(
                              saving
                                  ? 'SAVING…'
                                  : 'ADD $selectedCount BUS'
                                        '${selectedCount == 1 ? '' : 'ES'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: .3,
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
      await service.updateAssignment(
        id: id,
        assignmentType: result['type']!,
        shuttleGroup: result['type'] == 'SHUTTLE' ? result['group'] : null,
      );

      await load();
      msg('Assignment updated.');
    } catch (e) {
      await load();
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

    final yes =
        await showDialog<bool>(
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

  Future<void> deassignSelectedAssignments(DateTime date) async {
    if (saving) return;

    // Bulk deletion is intentionally scoped to the currently displayed date.
    // Selections on other dates remain checked and cannot be deleted by this action.
    final dateAssignmentIds = scheduleFor(
      date,
    ).map(assignmentIdOf).whereType<int>().toSet();
    final ids = selectedAssignmentIds.intersection(dateAssignmentIds);
    if (ids.isEmpty) {
      msg('Select at least one assignment on ${fmt(date)} to delete.');
      return;
    }
    final yes =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Remove ${ids.length} selected assignment(s)?'),
            content: Text(
              'Only the checked assignments for ${fmt(date)} will be removed. Selections and assignments on every other date will remain unchanged.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('CANCEL'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('REMOVE SELECTED'),
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
      selectedAssignmentIds.removeAll(ids.where((id) => !failed.contains(id)));
      await load();
      msg(
        failed.isEmpty
            ? 'Removed $removed assignment(s).'
            : 'Removed $removed assignment(s); ${failed.length} could not be removed.',
      );
    } finally {
      if (mounted) setState(() => saving = false);
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
              'This will remove all ${items.length} assignment(s) '
              'for ${fmt(date)}. Other operation dates in the selected '
              'range will not be changed.',
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
        final id = assignmentIdOf(item);

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
            : 'Removed $removed assignment(s); '
                  '${failures.length} could not be removed.',
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

  Widget regularRoutesSection({required VoidCallback onChanged}) {
    final query = routeSearch.text.trim().toLowerCase();

    final list = routes
        .where(
          (r) =>
              !shuttle.values.any((s) => s.contains(r.id)) &&
              !assignedOnEveryDate(r.id) &&
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
            child: Center(child: Text('No available buses found.')),
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
                    !assignedOnEveryDate(r.id) &&
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
                    ? blue.withValues(alpha: 0.4)
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
                    ? 'Tap to assign one bus'
                    : '${chosenRoute.first.routeNumber} · '
                          '${chosenRoute.first.routeName}',
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
              subtitle: const Text(
                'Only one bus can be selected for this slot.',
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
                        color: Colors.red,
                        size: 20,
                      ),
                    )
                  : const Icon(Icons.expand_more_rounded, size: 20),
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
                        style: TextStyle(fontSize: 12, color: Colors.grey),
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

  Widget rangeAssignmentsPanel() {
    final date = activeDate;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<DateTime>(
          initialValue: assignmentViewDates.contains(date)
              ? date
              : (assignmentViewDates.isNotEmpty
                    ? assignmentViewDates.first
                    : null),
          isExpanded: true,
          decoration: _dropdownDecoration('Operation date'),
          items: assignmentViewDates
              .map((d) => DropdownMenuItem(value: d, child: Text(fmt(d))))
              .toList(),
          onChanged: (d) {
            if (d != null) {
              setState(() => viewedScheduleDate = d);
            }
          },
        ),
        const SizedBox(height: 10),
        if (items.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  '${items.length} assigned bus'
                  '${items.length == 1 ? '' : 'es'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Clear all assignments for this date',
                onPressed: saving ? null : () => deassignWholeDate(date),
                icon: const Icon(
                  Icons.delete_sweep_outlined,
                  color: Colors.red,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                tristate: true,
                value: items.isEmpty
                    ? false
                    : items.every((a) {
                        final id = assignmentIdOf(a);
                        return id != null && selectedAssignmentIds.contains(id);
                      })
                    ? true
                    : items.any(
                        (a) =>
                            selectedAssignmentIds.contains(assignmentIdOf(a)),
                      )
                    ? null
                    : false,
                onChanged: (value) => setState(() {
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
              ),
              const Expanded(
                child: Text(
                  'Select all buses on this date',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              if (items.any((a) {
                final id = assignmentIdOf(a);
                return id != null && selectedAssignmentIds.contains(id);
              }))
                FilledButton.tonalIcon(
                  onPressed: saving
                      ? null
                      : () => deassignSelectedAssignments(date),
                  icon: const Icon(Icons.delete_outline_rounded, size: 17),
                  label: Text(
                    'Delete (${items.where((a) {
                      final id = assignmentIdOf(a);
                      return id != null && selectedAssignmentIds.contains(id);
                    }).length})',
                  ),
                  style: FilledButton.styleFrom(foregroundColor: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _searchField(
            controller: assignedSearch,
            hint: 'Search assigned buses',
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 8),
        ],
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
        else if (filteredItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('No matching assigned buses found.')),
          )
        else
          ...filteredItems.map((a) => assignmentCard(date, a)),
      ],
    );
  }

  Widget assignmentCard(DateTime d, dynamic a) => Container(
    key: ValueKey('assignment-${a['assignmentId'] ?? a['id'] ?? a['routeId']}'),
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFD),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE8EDF4)),
    ),
    child: ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      leading: Checkbox(
        value:
            assignmentIdOf(a) != null &&
            selectedAssignmentIds.contains(assignmentIdOf(a)),
        onChanged: (checked) {
          final id = assignmentIdOf(a);
          if (id == null) {
            msg(
              'This assignment has no ID, so it cannot be selected for bulk deletion.',
            );
            return;
          }
          setState(() {
            if (checked == true) {
              selectedAssignmentIds.add(id);
            } else {
              selectedAssignmentIds.remove(id);
            }
          });
        },
        activeColor: blue,
        visualDensity: VisualDensity.compact,
      ),
      title: Text(
        '${a['routeNumber'] ?? ''} · ${a['routeName'] ?? ''}',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      subtitle: Text(
        '${a['acType'] ?? ''}  •  '
        '${a['assignmentType'] ?? ''}'
        '${a['shuttleGroup'] == null ? '' : '  •  ${a['shuttleGroup']}'}',
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

  Widget _dateRangeButton({
    required String label,
    required String value,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: loading || saving ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: blue,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: Color(0xFF12233F),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading && routes.isEmpty && schedules.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: blue));
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
              children: [
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
                        color: blue.withValues(alpha: 0.16),
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
                              color: Colors.white.withValues(alpha: 0.16),
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
                              color: Colors.white.withValues(alpha: 0.14),
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
                          IconButton(
                            tooltip: 'Refresh assignments',
                            onPressed: loading || saving
                                ? null
                                : () => load(preserveFormState: true),
                            icon: loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.refresh_rounded,
                                    color: Colors.white,
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
                        'Review future assignments or assign more buses.',
                        style: TextStyle(
                          color: Color(0xFFDCE8FF),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (hasFutureAssignments)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE7ECF4)),
                    ),
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: existingAssignmentsExpanded,
                        onExpansionChanged: (expanded) => setState(
                          () => existingAssignmentsExpanded = expanded,
                        ),
                        leading: const Icon(
                          Icons.event_available_rounded,
                          color: blue,
                        ),
                        title: const Text(
                          'Existing assignments',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text(
                          'Review or edit buses assigned to a future date.',
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          14,
                          0,
                          14,
                          14,
                        ),
                        children: [rangeAssignmentsPanel()],
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE7ECF4)),
                  ),
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: assignMoreExpanded,
                      onExpansionChanged: (expanded) {
                        if (expanded && !assignMoreExpanded) {
                          clearSelections();
                          regular.addAll(
                            routes
                                .where((route) => route.defaultAfternoon)
                                .map((route) => route.id),
                          );
                        }
                        setState(() => assignMoreExpanded = expanded);
                      },
                      leading: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: blue,
                      ),
                      title: const Text(
                        'Assign more',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text(
                        'Choose buses and assign them to this date range.',
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F7FC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE0EAF8)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.date_range_rounded,
                                    color: blue,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'ASSIGNMENT DATE RANGE',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: .7,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Refresh schedules',
                                    onPressed: saving ? null : load,
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      color: blue,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _dateRangeButton(
                                      label: 'START DATE',
                                      value: fmt(fromDate),
                                      onPressed: chooseStartDate,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _dateRangeButton(
                                      label: 'END DATE',
                                      value: fmt(toDate),
                                      onPressed: chooseEndDate,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${operationDates.length} date${operationDates.length == 1 ? '' : 's'} selected: ${fmt(fromDate)} – ${fmt(toDate)}',
                                  style: const TextStyle(
                                    color: Color(0xFF475467),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        sectionLabel(
                          'Select buses',
                          'Selected buses will be assigned across every date from ${fmt(fromDate)} to ${fmt(toDate)}. Existing bus/date assignments are skipped.',
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
                          regularRoutesSection(onChanged: () => setState(() {}))
                        else
                          shuttleSection(onChanged: () => setState(() {})),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (assignMoreExpanded)
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: saving
                          ? null
                          : () => setState(() {
                              assignMoreExpanded = false;
                              clearSelections();
                            }),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: selectedCount == 0 || saving ? null : assign,
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                        'ASSIGN $selectedCount BUS${selectedCount == 1 ? '' : 'ES'}',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
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
