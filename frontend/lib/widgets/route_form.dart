import 'package:flutter/material.dart';

import '../models/route_model.dart';

class RouteForm extends StatefulWidget {
  final RouteModel? route;
  final List<RouteModel> allRoutes;

  const RouteForm({super.key, this.route, required this.allRoutes});

  @override
  State<RouteForm> createState() => _RouteFormState();
}

class _RouteFormState extends State<RouteForm> {
  final formKey = GlobalKey<FormState>();

  late TextEditingController routeNumberController;
  late TextEditingController routeNameController;

  String acType = 'AC';
  List<String> allowedRoutes = [];

  @override
  void initState() {
    super.initState();

    routeNumberController = TextEditingController(
      text: widget.route?.routeNumber ?? '',
    );

    routeNameController = TextEditingController(
      text: widget.route?.routeName ?? '',
    );

    acType = widget.route?.acType ?? 'AC';

    allowedRoutes = List<String>.from(widget.route?.allowedRoutes ?? []);
  }

  @override
  void dispose() {
    routeNumberController.dispose();
    routeNameController.dispose();
    super.dispose();
  }

  void save() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    Navigator.pop(context, {
      'routeNumber': routeNumberController.text.trim(),
      'routeName': routeNameController.text.trim(),
      'acType': acType,
      'allowedRoutes': allowedRoutes,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.route != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Route' : 'Add Route')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: routeNumberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Route Number',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter route number';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: routeNameController,
              decoration: const InputDecoration(
                labelText: 'Route Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter route name';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: acType,
              decoration: const InputDecoration(
                labelText: 'AC Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'AC', child: Text('AC')),
                DropdownMenuItem(value: 'NON_AC', child: Text('Non-AC')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    acType = value;
                  });
                }
              },
            ),

            const SizedBox(height: 24),

            const Text(
              'Allowed Routes',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.allRoutes.map((route) {
                final selected = allowedRoutes.contains(route.routeNumber);

                return FilterChip(
                  label: Text(route.routeNumber),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        allowedRoutes.add(route.routeNumber);
                      } else {
                        allowedRoutes.remove(route.routeNumber);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 30),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: save,
                icon: const Icon(Icons.save),
                label: Text(isEditing ? 'UPDATE ROUTE' : 'ADD ROUTE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
