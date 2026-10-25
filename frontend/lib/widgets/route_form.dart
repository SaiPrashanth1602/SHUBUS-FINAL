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
  late final TextEditingController codeController;
  late final TextEditingController nameController;
  String acType = 'AC';
  List<String> allowed = [];

  @override
  void initState() {
    super.initState();
    numberController = TextEditingController(
      text: widget.route?.routeNumber ?? '',
    );
    codeController = TextEditingController(text: widget.route?.routeCode ?? '');
    nameController = TextEditingController(text: widget.route?.routeName ?? '');
    acType = widget.route?.acType ?? 'AC';
    allowed = {
      for (final savedValue in widget.route?.allowedRoutes ?? const <String>[])
        resolveAllowedRouteCode(savedValue, widget.allRoutes),
    }.toList();
  }

  @override
  void dispose() {
    numberController.dispose();
    codeController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void save() {
    if (!keyForm.currentState!.validate()) return;
    Navigator.pop(context, {
      'routeNumber': numberController.text.trim(),
      'routeCode': codeController.text.trim(),
      'routeName': nameController.text.trim(),
      'acType': acType,
      'allowedRoutes': allowed,
    });
  }

  String _displayRouteCode(String savedValue, List<RouteModel> routes) {
    final normalizedValue = savedValue.trim().toLowerCase();

    for (final route in routes) {
      if (route.routeCode.trim().toLowerCase() == normalizedValue) {
        return route.routeCode;
      }
    }
    for (final route in routes) {
      if (route.routeNumber.trim().toLowerCase() == normalizedValue) {
        return route.routeCode.trim().isEmpty ? '' : route.routeCode;
      }
    }

    return savedValue;
  }

  String? _validateRouteCode(String? value) {
    final routeCode = value?.trim() ?? '';
    if (routeCode.isEmpty) return 'Enter route code';

    final duplicate = widget.allRoutes.any(
      (route) =>
          route.id != widget.route?.id &&
          route.routeCode.trim().toLowerCase() == routeCode.toLowerCase(),
    );
    return duplicate ? 'Route code already exists' : null;
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.route != null;
    final choices = widget.allRoutes
        .where((r) => r.id != widget.route?.id)
        .toList();
    final selectedRouteCodes = allowed
        .map((savedValue) => _displayRouteCode(savedValue, choices))
        .toSet()
        .toList();
    final hasRoutesWithoutCodes = choices.any(
      (route) => route.routeCode.trim().isEmpty,
    );

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
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter route number' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('routeCodeField'),
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Route Code',
                prefixIcon: Icon(Icons.qr_code_2_rounded),
              ),
              validator: _validateRouteCode,
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
            const Text(
              'ALLOWED AFTERNOON ROUTES',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Selected routes',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (selectedRouteCodes.isEmpty)
              Text(
                'None selected',
                style: TextStyle(color: Colors.blueGrey.shade600),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedRouteCodes.map((routeCode) {
                  final hasCode = routeCode.trim().isNotEmpty;
                  return Chip(
                    label: Text(hasCode ? routeCode : 'Route code unavailable'),
                  );
                }).toList(),
              ),
            const SizedBox(height: 14),
            const Text(
              'Select route codes',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            if (hasRoutesWithoutCodes) ...[
              const SizedBox(height: 6),
              const Text(
                'Some routes have no route code from the server. Refresh or update those route records before selecting them.',
                style: TextStyle(color: Color(0xFFB54708), fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: choices.map((route) {
                final routeCode = route.routeCode.trim();
                return FilterChip(
                  label: Text(
                    routeCode.isEmpty ? 'Route code unavailable' : routeCode,
                  ),
                  selected: routeCode.isNotEmpty && allowed.contains(routeCode),
                  onSelected: routeCode.isEmpty
                      ? null
                      : (selected) {
                          setState(() {
                            if (selected) {
                              if (!allowed.contains(routeCode)) {
                                allowed.add(routeCode);
                              }
                            } else {
                              allowed.remove(routeCode);
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
