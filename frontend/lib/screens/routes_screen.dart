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
  final RouteService routeService = RouteService();

  List<RouteModel> routes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadRoutes();
  }

  Future<void> loadRoutes() async {
    setState(() {
      isLoading = true;
    });

    try {
      final result = await routeService.getRoutes();

      if (!mounted) return;

      setState(() {
        routes = result;
      });
    } catch (error) {
      if (!mounted) return;

      showMessage('Failed to load routes');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> openAddRoute() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RouteForm(allRoutes: routes)),
    );

    if (result == null) return;

    try {
      await routeService.createRoute(
        routeNumber: result['routeNumber'],
        routeName: result['routeName'],
        acType: result['acType'],
        allowedRoutes: List<String>.from(result['allowedRoutes']),
      );

      if (!mounted) return;

      showMessage('Route added successfully');

      await loadRoutes();
    } catch (error) {
      if (!mounted) return;

      showMessage('Failed to add route');
    }
  }

  Future<void> openEditRoute(RouteModel route) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteForm(route: route, allRoutes: routes),
      ),
    );

    if (result == null) return;

    try {
      await routeService.updateRoute(
        id: route.id,
        routeNumber: result['routeNumber'],
        routeName: result['routeName'],
        acType: result['acType'],
        allowedRoutes: List<String>.from(result['allowedRoutes']),
      );

      if (!mounted) return;

      showMessage('Route updated successfully');

      await loadRoutes();
    } catch (error) {
      if (!mounted) return;

      showMessage('Failed to update route');
    }
  }

  Future<void> deleteRoute(RouteModel route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Route'),
          content: Text(
            'Are you sure you want to delete Route ${route.routeNumber} - ${route.routeName}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await routeService.deleteRoute(route.id);

      if (!mounted) return;

      showMessage('Route deleted successfully');

      await loadRoutes();
    } catch (error) {
      if (!mounted) return;

      showMessage('Failed to delete route');
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Routes'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: loadRoutes),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: openAddRoute,
        icon: const Icon(Icons.add),
        label: const Text('Add Route'),
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : routes.isEmpty
          ? const Center(child: Text('No routes found'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: routes.length,
              itemBuilder: (context, index) {
                final route = routes[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(route.routeNumber)),

                    title: Text(
                      route.routeName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),

                    subtitle: Text(
                      'Route: ${route.routeNumber}\n'
                      'Type: ${route.acType}\n'
                      'Allowed: ${route.allowedRoutes.join(', ')}',
                    ),

                    isThreeLine: true,

                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => openEditRoute(route),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => deleteRoute(route),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
