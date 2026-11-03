import 'package:flutter/material.dart';

import '../services/admin_api_exception.dart';
import '../models/route_model.dart';
import '../services/route_service.dart';

class AfternoonAssignmentScreen extends StatefulWidget {
  const AfternoonAssignmentScreen({super.key});

  @override
  State<AfternoonAssignmentScreen> createState() =>
      AfternoonAssignmentScreenState();
}

class AfternoonAssignmentScreenState extends State<AfternoonAssignmentScreen> {
  final service = RouteService();

  static const Color navy = Color(0xFF12305A);
  static const Color paleBlue = Color(0xFFF0F6FF);
  static const Color danger = Color(0xFFB42318);

  /// Default slots per destination. Extra slots (A6, V4, S2, T2...) are added
  /// at runtime through the "Add more" button or restored from the backend.
  static const Map<String, List<String>> destinations = {
    'ALANDUR METRO': ['A1', 'A2', 'A3', 'A4', 'A5'],
    'VELACHERY': ['V1', 'V2', 'V3'],
    'SHOLINGANALLUR': ['S1'],
    'TAMBARAM': ['T1'],
  };

  static const Map<String, String> prefixToDestination = {
    'A': 'ALANDUR METRO',
    'V': 'VELACHERY',
    'S': 'SHOLINGANALLUR',
    'T': 'TAMBARAM',
  };

  static const List<String> prefixOrder = ['A', 'V', 'S', 'T'];
  static const int maxSlotNumber = 99;

  static final RegExp _slotPattern = RegExp(r'^([AVST])(\d+)$');

  // ---------------------------------------------------------------------
  // Static slot / AC helpers
  // ---------------------------------------------------------------------

  static String? slotPrefix(String slot) =>
      _slotPattern.firstMatch(slot.trim().toUpperCase())?.group(1);

  static int? slotNumber(String slot) {
    final m = _slotPattern.firstMatch(slot.trim().toUpperCase());
    if (m == null) return null;
    return int.tryParse(m.group(2)!);
  }

  static int compareSlots(String a, String b) {
    final pa = prefixOrder.indexOf(slotPrefix(a) ?? '');
    final pb = prefixOrder.indexOf(slotPrefix(b) ?? '');
    if (pa != pb) return pa.compareTo(pb);
    return (slotNumber(a) ?? 0).compareTo(slotNumber(b) ?? 0);
  }

  /// true = AC, false = Non-AC, null = unknown.
  /// Accepts: AC, NON_AC, NON-AC, "non ac", nonac...
  static bool? isAcValue(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (cleaned.isEmpty) return null;
    if (cleaned.startsWith('NON')) return false;
    if (cleaned == 'AC') return true;
    return null;
  }

  static String acLabel(String? raw) {
    final ac = isAcValue(raw);
    if (ac == null) return raw ?? '';
    return ac ? 'AC' : 'Non-AC';
  }

  /// A, V, S slots are AC only. T slots are Non-AC only.
  static bool slotRequiresAc(String slot) => slotPrefix(slot) != 'T';

  static String slotRuleLabel(String slot) =>
      slotRequiresAc(slot) ? 'AC buses only' : 'Non-AC buses only';

  static bool routeMatchesSlot(RouteModel r, String slot) {
    final ac = isAcValue(r.acType);
    if (ac == null) return false;
    return ac == slotRequiresAc(slot);
  }

  static String? destinationOfSlot(String slot) {
    final prefix = slotPrefix(slot);
    if (prefix == null) return null;
    return prefixToDestination[prefix];
  }

  // ---------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------

  List<RouteModel> routes = [];
  Map<DateTime, List<dynamic>> schedules = {};

  DateTime selectedDate = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );

  final Set<int> regular = {};
  final Set<int> selectedAssignmentIds = {};

  final Set<int> pendingRegular = {};

  /// Slots currently displayed for each destination (defaults + extras).
  final Map<String, List<String>> destinationSlots = {
    for (final e in destinations.entries) e.key: List<String>.from(e.value),
  };

  final Map<String, Set<int>> pendingShuttle = {
    for (final slots in destinations.values)
      for (final slot in slots) slot: <int>{},
  };

  final Map<String, Set<int>> shuttle = {
    for (final slots in destinations.values)
      for (final slot in slots) slot: <int>{},
  };

  int assignmentCategory = 0;
  String selectedDestination = destinations.keys.first;

  bool loading = true;
  bool _loadInProgress = false;
  String? loadError;
  bool saving = false;

  OverlayEntry? _loadingEntry;
  OverlayEntry? _toastEntry;

  final ScrollController scrollController = ScrollController();

  final TextEditingController routeSearch = TextEditingController();
  final TextEditingController assignedSearch = TextEditingController();

  final Map<String, TextEditingController> slotSearch = {
    for (final slots in destinations.values)
      for (final slot in slots) slot: TextEditingController(),
  };

  StateSetter? _editSheetSetState;

  Set<int> shuttleSet(String slot) => shuttle.putIfAbsent(slot, () => <int>{});

  Set<int> pendingSet(String slot) =>
      pendingShuttle.putIfAbsent(slot, () => <int>{});

  TextEditingController searchControllerFor(String slot) =>
      slotSearch.putIfAbsent(slot, () => TextEditingController());

  void _ensureSlotState(String slot) {
    shuttleSet(slot);
    pendingSet(slot);
    searchControllerFor(slot);
  }

  @override
  void initState() {
    super.initState();
    _initializeOperationalDate();
  }

  Future<void> _initializeOperationalDate() async {
    String? operationalDateError;
    try {
      final operationalDate = await service.getCurrentOperationalDate();

      if (!mounted) return;

      setState(() {
        selectedDate = day(operationalDate);
      });
    } catch (e) {
      operationalDateError = adminErrorMessage(
        e,
        fallback: 'Please try again.',
      );
    }

    await load();

    if (operationalDateError != null && mounted) {
      setState(() {
        final scheduleError = loadError;
        const dateError =
            'Could not load the operational date. The current default date is shown.';
        loadError = scheduleError == null
            ? '$dateError $operationalDateError'
            : '$dateError $operationalDateError\n$scheduleError';
      });
    }
  }

  @override
  void dispose() {
    _hideGlobalLoading();
    _hideToast();

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

  void _showToast(String text, {bool isError = false}) {
    if (!mounted) return;

    _hideToast();

    final entry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          left: 20,
          right: 20,
          bottom: 28,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: isError ? const Color(0xFFB42318) : navy,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    _toastEntry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);

    Future.delayed(Duration(seconds: isError ? 7 : 3), () {
      if (_toastEntry == entry) {
        _hideToast();
      }
    });
  }

  void _hideToast() {
    _toastEntry?.remove();
    _toastEntry = null;
  }

  void _showGlobalLoading() {
    if (!mounted || _loadingEntry != null) return;

    final entry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned.fill(
          child: AbsorbPointer(
            absorbing: true,
            child: Container(
              color: navy.withValues(alpha: 0.30),
              child: Center(
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 22,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 52,
                                height: 52,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3.4,
                                  color: navy,
                                  backgroundColor: Colors.transparent,
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                              const Icon(
                                Icons.directions_bus_filled_rounded,
                                size: 22,
                                color: navy,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          saving ? 'Saving changes…' : 'Loading…',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: navy,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Please wait',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF758198),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _loadingEntry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  void _hideGlobalLoading() {
    _loadingEntry?.remove();
    _loadingEntry = null;
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
      _showGlobalLoading();
    }

    try {
      final discoveryStart = day(selectedDate);
      final discoveryEnd = day(selectedDate).add(const Duration(days: 365));

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

        _rebuildDestinationSlots();

        loading = false;
        loadError = null;
      });
    } catch (e) {
      if (mounted) {
        final error = adminErrorMessage(
          e,
          fallback: 'Check your connection and try again.',
        );
        setState(() {
          loading = false;
          loadError = 'Could not load schedules. $error';
        });
        _showToast('Could not load schedules. $error', isError: true);
      }
    } finally {
      if (showLoading) {
        _hideGlobalLoading();
      }
      _loadInProgress = false;
    }
  }

  /// Rebuilds the displayed slots from the defaults plus whatever the backend
  /// has for the selected date (and any slot that currently has a selection).
  /// Because compaction happens on the backend, a reload after a delete
  /// automatically shrinks the list (A6 disappears when only A1-A5 remain).
  void _rebuildDestinationSlots() {
    for (final entry in destinations.entries) {
      final dest = entry.key;
      final defaults = entry.value;
      final prefix = slotPrefix(defaults.first)!;

      var maxNumber = defaults.length;

      for (final a in scheduleFor(selectedDate)) {
        if (a is! Map) continue;
        if ('${a['assignmentType'] ?? ''}'.toUpperCase() != 'SHUTTLE') continue;

        final group = '${a['shuttleGroup'] ?? ''}'.trim().toUpperCase();
        if (slotPrefix(group) != prefix) continue;

        final n = slotNumber(group);
        if (n != null && n > maxNumber && n <= maxSlotNumber) {
          maxNumber = n;
        }
      }

      for (final s in shuttle.entries) {
        if (s.value.isEmpty || slotPrefix(s.key) != prefix) continue;
        final n = slotNumber(s.key);
        if (n != null && n > maxNumber && n <= maxSlotNumber) {
          maxNumber = n;
        }
      }

      final slots = [for (var i = 1; i <= maxNumber; i++) '$prefix$i'];
      destinationSlots[dest] = slots;

      for (final slot in slots) {
        _ensureSlotState(slot);
      }
    }
  }

  List<dynamic> scheduleFor(DateTime d) => schedules[day(d)] ?? [];

  bool assignedOn(DateTime d, int id) =>
      scheduleFor(d).any((a) => asInt(a['routeId']) == id);

  bool isShuttleSlotFilled(DateTime date, String slot) {
    return scheduleFor(date).any(
      (a) =>
          '${a['assignmentType'] ?? ''}'.toUpperCase() == 'SHUTTLE' &&
          '${a['shuttleGroup'] ?? ''}'.trim().toUpperCase() ==
              slot.toUpperCase(),
    );
  }

  bool isShuttleSlotSelected(String slot) {
    return shuttle[slot]?.isNotEmpty == true;
  }

  bool isShuttleSlotAlreadyAssigned(String slot) {
    return isShuttleSlotFilled(selectedDate, slot);
  }

  bool isShuttleSlotFilledOrPending(DateTime date, String slot) {
    return isShuttleSlotFilled(date, slot) ||
        pendingShuttle[slot]?.isNotEmpty == true;
  }

  bool isShuttleSlotLocked(String slot) {
    if (isShuttleSlotAlreadyAssigned(slot)) {
      return true;
    }

    final prefix = slotPrefix(slot);
    final number = slotNumber(slot);
    if (prefix == null || number == null || number < 1) return true;

    for (var i = 1; i < number; i++) {
      final previousSlot = '$prefix$i';

      final filled =
          isShuttleSlotFilled(selectedDate, previousSlot) ||
          isShuttleSlotSelected(previousSlot);

      if (!filled) {
        return true;
      }
    }

    return false;
  }

  // ---------------------------------------------------------------------
  // Add more
  // ---------------------------------------------------------------------

  List<String> slotsOf(String destination) =>
      destinationSlots[destination] ?? const [];

  String? nextSlotFor(String destination) {
    final slots = slotsOf(destination);
    if (slots.isEmpty) return null;

    final prefix = slotPrefix(slots.first)!;
    var maxNumber = 0;
    for (final s in slots) {
      final n = slotNumber(s) ?? 0;
      if (n > maxNumber) maxNumber = n;
    }

    if (maxNumber + 1 > maxSlotNumber) return null;
    return '$prefix${maxNumber + 1}';
  }

  /// A slot is "ready" if it is saved in the backend OR has a bus selected.
  bool isSlotReady(String slot) =>
      isShuttleSlotFilled(selectedDate, slot) || isShuttleSlotSelected(slot);

  List<String> emptySlotsOf(String destination) =>
      slotsOf(destination).where((s) => !isSlotReady(s)).toList();

  /// Enabled when every displayed slot has a bus (saved or selected now).
  bool canAddMoreSlot(String destination) {
    if (saving || loading) return false;
    if (nextSlotFor(destination) == null) return false;
    return emptySlotsOf(destination).isEmpty;
  }

  void addMoreSlot(String destination) {
    if (!canAddMoreSlot(destination)) {
      _showToast('Fill all current slots before adding a new one.');
      return;
    }

    final next = nextSlotFor(destination);
    if (next == null) return;

    setState(() {
      slotsOf(destination); // ensure key exists
      destinationSlots[destination] = [...slotsOf(destination), next];
      _ensureSlotState(next);
    });
  }

  bool canRemoveExtraSlot(String destination, String slot) {
    final slots = slotsOf(destination);
    final defaultCount = (destinations[destination] ?? const []).length;
    if (slots.isEmpty || slots.last != slot) return false;
    if ((slotNumber(slot) ?? 0) <= defaultCount) return false;
    if (isShuttleSlotFilled(selectedDate, slot)) return false;
    return true;
  }

  void removeExtraSlot(String destination, String slot) {
    if (!canRemoveExtraSlot(destination, slot)) return;

    setState(() {
      shuttleSet(slot).clear();
      pendingSet(slot).clear();
      searchControllerFor(slot).clear();
      destinationSlots[destination] = slotsOf(
        destination,
      ).where((s) => s != slot).toList();
    });
  }

  // ---------------------------------------------------------------------
  // Selection state
  // ---------------------------------------------------------------------

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
    if (isShuttleSlotLocked(slot)) {
      _showToast(
        isShuttleSlotAlreadyAssigned(slot)
            ? '$slot is already assigned.'
            : 'Fill the previous shuttle slot first.',
      );
      return;
    }

    final route = routes.where((r) => r.id == id).firstOrNull;
    if (route == null || !routeMatchesSlot(route, slot)) {
      _showToast('$slot accepts ${slotRuleLabel(slot)}.');
      return;
    }

    setState(() {
      final set = shuttleSet(slot);

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

  void _moveSelectionToPending() {
    clearPendingAdditions();

    pendingRegular.addAll(regular);

    for (final entry in shuttle.entries) {
      if (entry.value.isEmpty) continue;
      pendingSet(entry.key).addAll(entry.value);
    }
  }

  // ---------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------

  /// Returns an error message, or null when the shuttle slot is valid to send.
  /// [submitted] holds slots already saved successfully in the current run.
  String? validateShuttleSubmission(
    DateTime date,
    String slot,
    Set<int> ids,
    Set<String> submitted,
  ) {
    final prefix = slotPrefix(slot);
    final number = slotNumber(slot);

    if (prefix == null ||
        number == null ||
        number < 1 ||
        number > maxSlotNumber ||
        destinationOfSlot(slot) == null) {
      return 'invalid shuttle slot.';
    }

    if (ids.length != 1) {
      return 'each shuttle slot must have exactly one bus.';
    }

    final routeId = ids.first;
    final route = routes.where((r) => r.id == routeId).firstOrNull;

    if (route == null) {
      return 'selected bus no longer exists.';
    }

    if (!routeMatchesSlot(route, slot)) {
      return '${route.routeNumber} is ${acLabel(route.acType)}; '
          '$slot accepts ${slotRuleLabel(slot)}.';
    }

    if (isShuttleSlotFilled(date, slot)) {
      return 'shuttle slot is already assigned.';
    }

    if (assignedOn(date, routeId)) {
      return '${route.routeNumber} is already assigned on this date.';
    }

    for (var i = 1; i < number; i++) {
      final previous = '$prefix$i';
      if (!isShuttleSlotFilled(date, previous) &&
          !submitted.contains(previous)) {
        return 'previous slot $previous must be assigned first.';
      }
    }

    return null;
  }

  List<String> _sortedSlotsWith(Map<String, Set<int>> source) {
    final slots = source.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => e.key)
        .toList();
    slots.sort(compareSlots);
    return slots;
  }

  Future<void> assignToSelectedDate() async {
    if (pendingCount == 0 || saving) return;

    setState(() => saving = true);
    _showGlobalLoading();

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
          failures.add(
            '$dateLabel — Regular: '
            '${adminErrorMessage(e, fallback: 'Could not assign the selected buses.')}',
          );
        }
      }

      final submitted = <String>{};

      // Numeric order per prefix: A1, A2, ... A6, V1, ... S1, ... T1, ...
      for (final slot in _sortedSlotsWith(pendingShuttle)) {
        final ids = pendingSet(slot);

        final error = validateShuttleSubmission(date, slot, ids, submitted);
        if (error != null) {
          failures.add('$dateLabel — $slot: $error');
          continue;
        }

        try {
          await service.assignRoutes(
            date: date,
            routeIds: ids.toList(),
            assignmentType: 'SHUTTLE',
            shuttleGroup: slot,
          );

          submitted.add(slot);
          created += ids.length;
        } catch (e) {
          failures.add(
            '$dateLabel — $slot: '
            '${adminErrorMessage(e, fallback: 'Could not assign this shuttle slot.')}',
          );
        }
      }

      clearPendingAdditions();
      await load(showLoading: false);
      _refreshEditSheet();

      if (failures.isEmpty) {
        _showToast(
          'Added $created bus${created == 1 ? '' : 'es'} to $dateLabel.',
        );
      } else {
        _showToast(
          'Added $created bus${created == 1 ? '' : 'es'}; '
          '${failures.length} batch(es) failed. ${failures.first}',
          isError: true,
        );
      }
    } finally {
      _hideGlobalLoading();
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> assignCurrentSelectionToSelectedDate() async {
    if (selectedCount == 0 || saving) return;

    _moveSelectionToPending();
    clearSelections();
    await assignToSelectedDate();
  }

  Future<void> assignToRange(DateTime endDate) async {
    if (selectedCount == 0 || saving) return;

    final startDate = day(selectedDate);
    final safeEndDate = day(endDate);

    if (safeEndDate.isBefore(startDate)) {
      _showToast('End date cannot be before the selected date.');
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

    final shuttleSlots = _sortedSlotsWith(shuttle);

    setState(() => saving = true);
    _showGlobalLoading();

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
            failures.add(
              '$dateLabel — Regular: '
              '${adminErrorMessage(e, fallback: 'Could not assign the selected buses.')}',
            );
          }
        }

        final submitted = <String>{};

        for (final slot in shuttleSlots) {
          final ids = shuttleSet(slot);

          final error = validateShuttleSubmission(date, slot, ids, submitted);

          if (error != null) {
            skipped += ids.length;
            continue;
          }

          try {
            await service.assignRoutes(
              date: date,
              routeIds: ids.toList(),
              assignmentType: 'SHUTTLE',
              shuttleGroup: slot,
            );
            submitted.add(slot);
            created += ids.length;
          } catch (e) {
            failures.add(
              '$dateLabel — $slot: '
              '${adminErrorMessage(e, fallback: 'Could not assign this shuttle slot.')}',
            );
          }
        }
      }

      clearSelections();
      await load(showLoading: false);

      if (failures.isEmpty) {
        final skipText = skipped > 0
            ? ' Skipped $skipped already-assigned or invalid bus/date pair(s).'
            : '';

        _showToast(
          'Created $created assignment(s) across '
          '${targetDates.length} date(s).$skipText',
        );
      } else {
        _showToast(
          'Created $created assignment(s); '
          '${failures.length} batch(es) failed. ${failures.first}',
          isError: true,
        );
      }
    } finally {
      _hideGlobalLoading();
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
                        return id != null && selectedAssignmentIds.contains(id);
                      })
                    ? true
                    : items.any(
                        (a) =>
                            selectedAssignmentIds.contains(assignmentIdOf(a)),
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
                onPressed: selectedIds.isEmpty || saving
                    ? null
                    : () => deassignSelectedAssignments(date),
                style: FilledButton.styleFrom(
                  backgroundColor: selectedIds.isEmpty
                      ? Colors.grey.shade300
                      : danger,
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
              ? const Center(child: CircularProgressIndicator(color: navy))
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
                      ...filteredItems.map((a) => assignmentCard(date, a)),
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
                      ...pendingRoutes.map((route) => _pendingRouteCard(route)),
                    ],
                  ],
                ),
        ),
        if (pendingCount > 0)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                              onPressed: () => Navigator.pop(addSheetContext),
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
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
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

                                      _moveSelectionToPending();
                                      clearSelections();

                                      if (addSheetContext.mounted) {
                                        Navigator.pop(addSheetContext);
                                      }

                                      await assignToSelectedDate();
                                    } else {
                                      final choice =
                                          await _chooseAssignmentPeriod();

                                      if (choice == null) return;

                                      if (choice == 'THIS_DATE') {
                                        if (addSheetContext.mounted) {
                                          Navigator.pop(addSheetContext);
                                        }

                                        await assignCurrentSelectionToSelectedDate();
                                      } else {
                                        final endDate =
                                            await _pickRangeEndDate();

                                        if (endDate == null) return;

                                        final confirmed =
                                            await _confirmRangeAssignment(
                                              endDate,
                                            );

                                        if (confirmed != true) return;

                                        if (addSheetContext.mounted) {
                                          Navigator.pop(addSheetContext);
                                        }

                                        await assignToRange(endDate);
                                      }
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

  Future<String?> _chooseAssignmentPeriod() {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Text(
                'Choose assignment period',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: navy,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close',
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assign $selectedCount bus${selectedCount == 1 ? '' : 'es'} '
              'for ${fmt(selectedDate)}?',
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF4A586E)),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, 'THIS_DATE'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: navy,
                      side: const BorderSide(color: navy),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'This date only',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, 'TILL_DATE'),
                    style: FilledButton.styleFrom(
                      backgroundColor: navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Till a date',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

  Future<void> deassign(DateTime date, dynamic a) async {
    final id = assignmentIdOf(a);

    if (id == null) {
      _showToast('Assignment ID was not returned by the backend.');
      return;
    }

    final isShuttle = '${a['assignmentType'] ?? ''}'.toUpperCase() == 'SHUTTLE';

    final yes =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove assignment?'),
            content: Text(
              'Remove ${a['routeNumber'] ?? 'this route'} '
              'from operation date ${fmt(date)}?'
              '${isShuttle ? '\n\nLater shuttle buses will move forward to fill the empty slot.' : ''}',
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

    setState(() => saving = true);
    _showGlobalLoading();

    try {
      await service.deleteAssignment(id);

      await load(showLoading: false);

      _refreshEditSheet();
      _showToast('Assignment removed.');
    } catch (e) {
      await load(showLoading: false);
      _showToast(
        adminErrorMessage(
          e,
          fallback: 'Could not remove the assignment. Please try again.',
        ),
        isError: true,
      );
    } finally {
      _hideGlobalLoading();
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> deassignSelectedAssignments(DateTime date) async {
    if (saving) return;

    final dateAssignmentIds = scheduleFor(
      date,
    ).map(assignmentIdOf).whereType<int>().toSet();

    final ids = selectedAssignmentIds.intersection(dateAssignmentIds);

    if (ids.isEmpty) {
      _showToast('Select at least one assignment on ${fmt(date)} to delete.');
      return;
    }

    final selectedItems = scheduleFor(date)
        .where(
          (a) => assignmentIdOf(a) != null && ids.contains(assignmentIdOf(a)),
        )
        .toList();

    final hasShuttle = selectedItems.any(
      (a) => '${a['assignmentType'] ?? ''}'.toUpperCase() == 'SHUTTLE',
    );

    final yes =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Remove ${ids.length} selected assignment(s)?'),
            content: Text(
              'Only the checked assignments for ${fmt(date)} will be removed.'
              '${hasShuttle ? '\n\nLater shuttle buses will move forward to fill empty slots.' : ''}',
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
    _showGlobalLoading();

    var removed = 0;
    final failed = <int, String>{};

    try {
      // Delete one at a time. The backend compacts shuttle slots after each
      // delete, so we always reload from the backend afterwards.
      for (final id in ids) {
        try {
          await service.deleteAssignment(id);
          removed++;
        } catch (e) {
          final assignment = selectedItems
              .where((item) => assignmentIdOf(item) == id)
              .firstOrNull;
          final routeNumber = assignment == null
              ? 'Assignment $id'
              : '${assignment['routeNumber'] ?? 'Assignment $id'}';
          failed[id] =
              '$routeNumber: ${adminErrorMessage(e, fallback: 'Could not remove this assignment.')}';
        }
      }

      selectedAssignmentIds.removeAll(
        ids.where((id) => !failed.containsKey(id)),
      );

      await load(showLoading: false);

      _refreshEditSheet();

      if (failed.isEmpty) {
        _showToast('Removed $removed assignment(s).');
      } else {
        final reasons = failed.values.take(3).join('\n');
        final remaining = failed.length > 3
            ? '\nAnd ${failed.length - 3} more could not be removed.'
            : '';
        _showToast(
          'Removed $removed assignment(s). Could not remove:\n$reasons$remaining',
          isError: true,
        );
      }
    } finally {
      _hideGlobalLoading();
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
    style: const TextStyle(fontSize: 13, color: Color(0xFF22314A)),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF8993A5)),
      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: navy),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
        borderSide: const BorderSide(color: navy, width: 1.4),
      ),
    ),
  );

  Widget _routeNumberBadge(String routeNumber, {bool selected = false}) {
    return SizedBox(
      width: 44,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
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
                    acLabel(r.acType),
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

  String _routeSearchText(RouteModel r) =>
      '${r.routeNumber} ${r.routeName} ${r.acType} ${acLabel(r.acType)}'
          .toLowerCase();

  Widget regularRoutesSection({required VoidCallback onChanged}) {
    final query = routeSearch.text.trim().toLowerCase();

    final list = routes
        .where(
          (r) =>
              !shuttle.values.any((s) => s.contains(r.id)) &&
              !assignedOn(selectedDate, r.id) &&
              _routeSearchText(r).contains(query),
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
                style: TextStyle(fontSize: 12, color: Color(0xFF758198)),
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

  Widget _addMoreSection(VoidCallback onChanged) {
    final dest = selectedDestination;
    final next = nextSlotFor(dest);
    final canAdd = canAddMoreSlot(dest);
    final unsaved = emptySlotsOf(dest);

    String? hint;
    if (next == null) {
      hint = 'Maximum number of slots reached.';
    } else if (!canAdd && unsaved.isNotEmpty) {
      hint = unsaved.length == 1
          ? 'Select a bus for ${unsaved.first} to add $next.'
          : 'Select buses for ${unsaved.first}–${unsaved.last} to add $next.';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: canAdd
                  ? () {
                      addMoreSlot(dest);
                      onChanged();
                    }
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: navy,
                side: BorderSide(
                  color: canAdd ? navy : const Color(0xFFD5DCE8),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                next == null ? 'Add more' : 'Add more ($next)',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                hint,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF758198),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget shuttleSection({required VoidCallback onChanged}) {
    final slots = slotsOf(selectedDestination);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: destinations.keys.map((dest) {
              final isChosen = selectedDestination == dest;

              final count = slotsOf(dest).fold<int>(
                0,
                (sum, s) =>
                    sum +
                    (isShuttleSlotFilled(selectedDate, s) ? 1 : 0) +
                    (shuttle[s]?.length ?? 0),
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
          final chosen = shuttleSet(slot);
          final alreadyAssigned = isShuttleSlotAlreadyAssigned(slot);
          final locked = isShuttleSlotLocked(slot);

          final chosenRoute = routes
              .where((r) => chosen.contains(r.id))
              .toList();

          final searchController = searchControllerFor(slot);
          final query = searchController.text.trim().toLowerCase();

          final candidates = locked
              ? <RouteModel>[]
              : routes
                    .where(
                      (r) =>
                          routeMatchesSlot(r, slot) &&
                          !regular.contains(r.id) &&
                          !assignedOn(selectedDate, r.id) &&
                          !shuttle.entries.any(
                            (e) => e.key != slot && e.value.contains(r.id),
                          ) &&
                          _routeSearchText(r).contains(query),
                    )
                    .toList();

          final removable = canRemoveExtraSlot(selectedDestination, slot);

          return _ShuttleSlotTile(
            key: ValueKey('slot-$slot'),
            slot: slot,
            locked: locked,
            alreadyAssigned: alreadyAssigned,
            acRule: slotRuleLabel(slot),
            chosen: chosen,
            chosenRoute: chosenRoute,
            candidates: candidates,
            slotSearchController: searchController,
            onClear: () {
              chosen.clear();
              onChanged();
            },
            onToggle: (id) {
              toggleSlot(slot, id);
              onChanged();
            },
            onRemoveSlot: removable
                ? () {
                    removeExtraSlot(selectedDestination, slot);
                    onChanged();
                  }
                : null,
          );
        }),
        _addMoreSection(onChanged),
      ],
    );
  }

  Widget assignmentCard(DateTime d, dynamic a, {bool selectable = true}) {
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        leading: selectable
            ? Checkbox(
                value: isSelected,
                onChanged: (checked) {
                  if (id == null) {
                    _showToast(
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
          '${acLabel('${a['acType'] ?? ''}')} • ${a['assignmentType'] ?? ''}'
          '${a['shuttleGroup'] == null ? '' : ' • ${a['shuttleGroup']}'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5, color: Color(0xFF758198)),
        ),
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
                  slot == null
                      ? acLabel(route.acType)
                      : '${acLabel(route.acType)} • $slot',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF758198),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
      return const Center(child: CircularProgressIndicator(color: navy));
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
                if (loadError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4F2),
                      borderRadius: BorderRadius.circular(12),
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
                            style: const TextStyle(color: Color(0xFF7A271A)),
                          ),
                        ),
                        TextButton(
                          onPressed: _initializeOperationalDate,
                          child: const Text('Retry'),
                        ),
                      ],
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
                            onPressed: saving ? null : () => openAddBusSheet(),
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
                              style: TextStyle(fontWeight: FontWeight.w600),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                              onPressed: saving ? null : () => openEditSheet(),
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

class _ShuttleSlotTile extends StatefulWidget {
  const _ShuttleSlotTile({
    super.key,
    required this.slot,
    required this.locked,
    required this.alreadyAssigned,
    required this.acRule,
    required this.chosen,
    required this.chosenRoute,
    required this.candidates,
    required this.slotSearchController,
    required this.onClear,
    required this.onToggle,
    this.onRemoveSlot,
  });

  final String slot;
  final bool locked;
  final bool alreadyAssigned;
  final String acRule;
  final Set<int> chosen;
  final List<RouteModel> chosenRoute;
  final List<RouteModel> candidates;
  final TextEditingController slotSearchController;
  final VoidCallback onClear;
  final void Function(int) onToggle;
  final VoidCallback? onRemoveSlot;

  @override
  State<_ShuttleSlotTile> createState() => _ShuttleSlotTileState();
}

class _ShuttleSlotTileState extends State<_ShuttleSlotTile> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final hasBus = widget.chosen.isNotEmpty;
    final locked = widget.locked;

    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: IgnorePointer(
        ignoring: locked,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasBus
                  ? AfternoonAssignmentScreenState.navy.withValues(alpha: 0.45)
                  : locked
                  ? const Color(0xFFE5EAF2)
                  : AfternoonAssignmentScreenState.navy.withValues(alpha: 0.25),
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
            onExpansionChanged: locked
                ? null
                : (value) => setState(() => expanded = value),
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: hasBus
                    ? AfternoonAssignmentScreenState.navy
                    : widget.alreadyAssigned
                    ? Colors.grey.shade400
                    : locked
                    ? Colors.grey.shade300
                    : AfternoonAssignmentScreenState.paleBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.slot,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                  color: hasBus
                      ? Colors.white
                      : AfternoonAssignmentScreenState.navy,
                ),
              ),
            ),
            title: Text(
              widget.chosenRoute.isEmpty
                  ? (widget.alreadyAssigned
                        ? 'Already assigned'
                        : locked
                        ? 'Fill the previous slot first'
                        : 'Tap to assign one bus')
                  : '${widget.chosenRoute.first.routeNumber} • '
                        '${widget.chosenRoute.first.routeName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: widget.chosenRoute.isEmpty
                    ? const Color(0xFF8993A5)
                    : const Color(0xFF22314A),
              ),
            ),
            subtitle: Text(
              widget.alreadyAssigned
                  ? 'This shuttle slot is already occupied'
                  : locked
                  ? 'Locked until previous slot is filled'
                  : 'One bus per slot • ${widget.acRule}',
              style: const TextStyle(fontSize: 10),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onRemoveSlot != null && !hasBus)
                  IconButton(
                    tooltip: 'Remove ${widget.slot}',
                    onPressed: widget.onRemoveSlot,
                    icon: const Icon(
                      Icons.remove_circle_outline_rounded,
                      color: AfternoonAssignmentScreenState.danger,
                      size: 19,
                    ),
                  ),
                if (hasBus)
                  IconButton(
                    tooltip: 'Clear ${widget.slot}',
                    onPressed: widget.onClear,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AfternoonAssignmentScreenState.danger,
                      size: 19,
                    ),
                  ),
                if (locked)
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 17,
                    color: Color(0xFF8993A5),
                  )
                else
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: Color(0xFF697990),
                    ),
                  ),
              ],
            ),
            children: [
              TextField(
                controller: widget.slotSearchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 13, color: Color(0xFF22314A)),
                decoration: InputDecoration(
                  hintText: 'Search available bus for ${widget.slot}',
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8993A5),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: AfternoonAssignmentScreenState.navy,
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
                      color: AfternoonAssignmentScreenState.navy,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (widget.candidates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text(
                      'No available ${widget.acRule.toLowerCase().replaceAll(' only', '')} found.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF758198),
                      ),
                    ),
                  ),
                )
              else
                ...widget.candidates.map(
                  (r) => _shuttleRouteTile(r, widget.chosen, widget.onToggle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _shuttleRouteTile(
  RouteModel r,
  Set<int> selected,
  void Function(int) toggle,
) {
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
        color: isSelected
            ? AfternoonAssignmentScreenState.paleBlue
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AfternoonAssignmentScreenState.navy
              : const Color(0xFFE5EAF2),
          width: isSelected ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? AfternoonAssignmentScreenState.navy
                    : AfternoonAssignmentScreenState.paleBlue,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: isSelected
                      ? AfternoonAssignmentScreenState.navy
                      : AfternoonAssignmentScreenState.navy.withValues(
                          alpha: 0.20,
                        ),
                ),
              ),
              child: Text(
                r.routeNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isSelected
                      ? Colors.white
                      : AfternoonAssignmentScreenState.navy,
                ),
              ),
            ),
          ),
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
                  AfternoonAssignmentScreenState.acLabel(r.acType),
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
            color: isSelected
                ? AfternoonAssignmentScreenState.navy
                : const Color(0xFFBBC5D4),
          ),
        ],
      ),
    ),
  );
}
