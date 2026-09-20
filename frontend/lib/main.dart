import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const ShubusAdminApp());
}

class ShubusAdminApp extends StatelessWidget {
  const ShubusAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SHUBUS Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const AdminLoginScreen(),
    );
  }
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final empIdController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool hidePassword = true;

  // Change this to your computer's local IP when testing on mobile.
  final String apiUrl = 'http://192.168.0.4:8081';

  Future<void> loginAdmin() async {
    final empId = empIdController.text.trim();
    final password = passwordController.text;

    if (empId.isEmpty || password.isEmpty) {
      showMessage('Enter employee ID and password');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/api/admin/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'empId': empId, 'password': password}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
        );
      } else {
        showMessage('Invalid employee ID or password');
      }
    } catch (error) {
      showMessage('Unable to connect to backend');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    empIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.directions_bus_rounded,
                  size: 90,
                  color: Colors.indigo,
                ),

                const SizedBox(height: 20),

                const Text(
                  'SHUBUS',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Admin Panel Login',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),

                const SizedBox(height: 40),

                TextField(
                  controller: empIdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Employee ID',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 18),

                TextField(
                  controller: passwordController,
                  obscureText: hidePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        hidePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          hidePassword = !hidePassword;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : loginAdmin,
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : const Text(
                            'LOGIN',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final String apiUrl = 'http://192.168.0.4:8081';

  List<dynamic> buses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchBuses();
  }

  Future<void> fetchBuses() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse('$apiUrl/api/buses'));

      if (response.statusCode == 200) {
        setState(() {
          buses = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        showMessage('Failed to load buses');
      }
    } catch (error) {
      showMessage('Unable to connect to backend');
    } finally {
      setState(() {
        isLoading = false;
      });
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
        title: const Text('SHUBUS Admin'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchBuses),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminLoginScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : buses.isEmpty
          ? const Center(child: Text('No buses found'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: buses.length,
              itemBuilder: (context, index) {
                final bus = buses[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(
                      'Bus ${bus['busNumber'] ?? 'N/A'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${bus['routeName']}\n'
                      'Type: ${bus['busType']} | '
                      '${bus['acType']}\n'
                      'Seats: ${bus['seatCapacity']} | '
                      'Active: ${bus['active']}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          showMessage('Edit coming next');
                        } else if (value == 'delete') {
                          showMessage('Delete coming next');
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
