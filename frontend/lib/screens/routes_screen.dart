import 'package:flutter/material.dart';

import '../models/route_model.dart';
import '../services/route_service.dart';
import '../widgets/route_form.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => RoutesScreenState();
}

class RoutesScreenState extends State<RoutesScreen> {
  final service = RouteService();
  List<RouteModel> routes = [];
  bool loading = true;
  bool _loadInProgress = false;
  String? loadError;
  String query = '';

  static const navy = Color(0xFF12305A);
  static const paleBlue = Color(0xFFF0F6FF);

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (_loadInProgress) return;
    _loadInProgress = true;
    if (mounted) setState(() => loading = true);

    try {
      final result = await service.getRoutes();

      if (mounted) {
        setState(() {
          routes = result;
          loadError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loadError = 'Failed to load routes: $e');
        message('Failed to load routes: $e');
      }
    } finally {
      _loadInProgress = false;
      if (mounted) setState(() => loading = false);
    }
  }

  List<RouteModel> get filtered => routes
      .where(
        (r) => '${r.routeCode} ${r.routeNumber} ${r.routeName} ${r.acType}'
            .toLowerCase()
            .contains(query.toLowerCase()),
      )
      .toList();

  List<String> allowedRouteCodes(RouteModel route) => route.allowedRoutes
      .map((savedValue) => resolveAllowedRouteCode(savedValue, routes))
      .toList();

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> add() async {
    final data = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => RouteForm(allRoutes: routes)),
    );

    if (data == null) return;

    try {
      await service.createRoute(
        routeNumber: data['routeNumber'],
        routeCode: data['routeCode'],
        routeName: data['routeName'],
        acType: data['acType'],
        allowedRoutes: List<String>.from(data['allowedRoutes']),
      );

      message('Route created');
      await load();
    } catch (e) {
      message('Create failed: $e');
    }
  }

  Future<void> edit(RouteModel route) async {
    final data = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => RouteForm(route: route, allRoutes: routes),
      ),
    );

    if (data == null) return;

    try {
      await service.updateRoute(
        id: route.id,
        routeNumber: data['routeNumber'],
        routeCode: data['routeCode'],
        routeName: data['routeName'],
        acType: data['acType'],
        allowedRoutes: List<String>.from(data['allowedRoutes']),
      );

      message('Route updated');
      await load();
    } catch (e) {
      message('Update failed: $e');
    }
  }

  Future<void> remove(RouteModel route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete route?'),
        content: Text('Delete ${route.routeNumber} — ${route.routeName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await service.deleteRoute(route.id);
      message('Route deleted');
      await load();
    } catch (e) {
      message('Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (loading && routes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: navy.withValues(alpha: 0.15),
                color: navy,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: TextField(
            onChanged: (v) => setState(() => query = v),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF22314A),
            ),
            decoration: InputDecoration(
              hintText: 'Search route code, number, name or type',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF8993A5),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: navy,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDCE4EF)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDCE4EF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: navy,
                  width: 1.4,
                ),
              ),
            ),
          ),
        ),
        if (loadError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Material(
              color: const Color(0xFFFFF4F2),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
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
            ),
          ),
        Expanded(
          child: loading && routes.isEmpty
              ? _buildLoadingState()
              : RefreshIndicator(
                  onRefresh: load,
                  child: filtered.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(child: Text('No routes found')),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 100),
                          itemCount: filtered.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final route = filtered[index];

                            return _RouteCard(
                              route: route,
                              allowedRoutes: allowedRouteCodes(route),
                              onEdit: () => edit(route),
                              onDelete: () => remove(route),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: navy,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.alt_route_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                SizedBox(height: 12),
                Text(
                  'Loading routes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Getting the latest route details…',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                  child: LinearProgressIndicator(
                    minHeight: 5,
                    backgroundColor: Color(0x55FFFFFF),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < 3; i++) ...[
            Container(
              padding: const EdgeInsets.all(15),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0EAF8)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: paleBlue,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const SizedBox(
                      height: 10,
                      width: 34,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFFE1E8F2),
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 11,
                          width: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE1E8F2),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 8,
                          width: 180,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9EEF6),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.allowedRoutes,
    required this.onEdit,
    required this.onDelete,
  });

  final RouteModel route;
  final List<String> allowedRoutes;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const navy = Color(0xFF12305A);
  static const paleBlue = Color(0xFFF0F6FF);

  @override
  Widget build(BuildContext context) {
    final routeCode = route.routeCode.trim().isEmpty
        ? 'N/A'
        : route.routeCode.trim();

    final allowedText = allowedRoutes.isEmpty
        ? 'None'
        : allowedRoutes.join(', ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 4, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE3E9F2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: paleBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  routeCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: navy,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.routeName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF22314A),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _SmallChip(
                          label: route.routeNumber,
                          icon: Icons.directions_bus_outlined,
                        ),
                        _SmallChip(
                          label: route.acType,
                          icon: Icons.ac_unit_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Allowed: $allowedText',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.2,
                        color: Color(0xFF758198),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else {
                    onDelete();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: const Color(0xFF12305A)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF12305A),
            ),
          ),
        ],
      ),
    );
  }
}