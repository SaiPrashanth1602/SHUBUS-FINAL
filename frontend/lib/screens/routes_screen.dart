import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../services/route_service.dart';
import '../widgets/route_form.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});
  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final service = RouteService();
  List<RouteModel> routes = [];
  bool loading = true;
  bool _loadInProgress = false;
  String? loadError;
  String query = '';

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Routes',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh routes',
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: add,
        icon: const Icon(Icons.add),
        label: const Text('Add route'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search route code, number, name or type',
              ),
            ),
          ),
          if (loading && routes.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
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
                          style: const TextStyle(color: Color(0xFF7A271A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: loading && routes.isEmpty
                ? RefreshIndicator(
                    onRefresh: load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1765F5), Color(0xFF12305A)],
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.alt_route_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Loading routes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Getting the latest route details…',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 18),
                              ClipRRect(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(6),
                                ),
                                child: LinearProgressIndicator(
                                  minHeight: 6,
                                  backgroundColor: Color(0x55FFFFFF),
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        for (var i = 0; i < 3; i++) ...[
                          Container(
                            padding: const EdgeInsets.all(18),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE0EAF8),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF1FF),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: const Icon(
                                    Icons.alt_route_rounded,
                                    color: Color(0xFF155EEF),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: 12,
                                        width: 120,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE1E8F2),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 9),
                                      Container(
                                        height: 8,
                                        width: 190,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE9EEF6),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                  )
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
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: filtered.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final route = filtered[index];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFFEAF1FF),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        route.routeCode.trim().isEmpty
                                            ? 'N/A'
                                            : route.routeCode.trim(),
                                        style: const TextStyle(
                                          color: Color(0xFF155EEF),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    route.routeName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${route.acType}\nAllowed: ${allowedRouteCodes(route).isEmpty ? 'None' : allowedRouteCodes(route).join(', ')}',
                                  ),
                                  isThreeLine: true,
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        edit(route);
                                      } else {
                                        remove(route);
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
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
