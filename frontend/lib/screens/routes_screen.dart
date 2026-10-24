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
  String query = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() => loading = true);
    try {
      final result = await service.getRoutes();
      if (mounted) setState(() => routes = result);
    } catch (e) {
      if (mounted) message('Failed to load routes: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<RouteModel> get filtered => routes
      .where((r) => '${r.routeNumber} ${r.routeName} ${r.acType}'
          .toLowerCase()
          .contains(query.toLowerCase()))
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
          builder: (_) => RouteForm(route: route, allRoutes: routes)),
    );
    if (data == null) return;
    try {
      await service.updateRoute(
        id: route.id,
        routeNumber: data['routeNumber'],
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
              child: const Text('CANCEL')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('DELETE')),
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
        title: const Text('Routes',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
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
                hintText: 'Search route number, name or type',
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
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
                                    child: Text(route.routeNumber,
                                        style: const TextStyle(
                                            color: Color(0xFF155EEF),
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(route.routeName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                      '${route.acType}\nAllowed: ${route.allowedRoutes.isEmpty ? 'None' : route.allowedRoutes.join(', ')}'),
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
                                          value: 'edit', child: Text('Edit')),
                                      PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete')),
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
