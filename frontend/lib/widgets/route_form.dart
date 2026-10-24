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
  final keyForm = GlobalKey<FormState>();
  late final TextEditingController numberController;
  late final TextEditingController nameController;
  String acType = 'AC';
  List<String> allowed = [];

  @override
  void initState() {
    super.initState();
    numberController =
        TextEditingController(text: widget.route?.routeNumber ?? '');
    nameController =
        TextEditingController(text: widget.route?.routeName ?? '');
    acType = widget.route?.acType ?? 'AC';
    allowed = List<String>.from(widget.route?.allowedRoutes ?? []);
  }

  @override
  void dispose() {
    numberController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void save() {
    if (!keyForm.currentState!.validate()) return;
    Navigator.pop(context, {
      'routeNumber': numberController.text.trim(),
      'routeName': nameController.text.trim(),
      'acType': acType,
      'allowedRoutes': allowed,
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.route != null;
    final choices =
        widget.allRoutes.where((r) => r.id != widget.route?.id).toList();

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit Route' : 'Add Route')),
      body: Form(
        key: keyForm,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: numberController,
              decoration: const InputDecoration(
                labelText: 'Route Number',
                prefixIcon: Icon(Icons.tag),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter route number'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Route Name',
                prefixIcon: Icon(Icons.route_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter route name' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: acType,
              decoration: const InputDecoration(labelText: 'Bus Type'),
              items: const [
                DropdownMenuItem(value: 'AC', child: Text('AC')),
                DropdownMenuItem(value: 'NON_AC', child: Text('Non-AC')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => acType = v);
              },
            ),
            const SizedBox(height: 22),
            const Text('ALLOWED AFTERNOON ROUTES',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: choices.map((route) {
                return FilterChip(
                  label: Text(route.routeNumber),
                  selected: allowed.contains(route.routeNumber),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        if (!allowed.contains(route.routeNumber)) {
                          allowed.add(route.routeNumber);
                        }
                      } else {
                        allowed.remove(route.routeNumber);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 26),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: save,
                icon: const Icon(Icons.save_outlined),
                label: Text(editing ? 'SAVE CHANGES' : 'CREATE ROUTE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
