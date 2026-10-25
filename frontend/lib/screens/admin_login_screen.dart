import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'admin_dashboard_screen.dart';
import '../services/api_config.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final formKey = GlobalKey<FormState>();
  final empId = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    empId.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (!formKey.currentState!.validate() || loading) return;
    setState(() => loading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/auth/login'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'empId': empId.text.trim(),
        }),
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
      } else {
        String message = 'Sign in failed. Check the employee ID.';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['error'] != null) {
            message = body['error'].toString();
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not connect to the server. Check the connection and try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.directions_bus_rounded,
                          size: 66,
                          color: Color(0xFF155EEF),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'SHUBUS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Welcome',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 26),
                        TextFormField(
                          controller: empId,
                          decoration: const InputDecoration(
                            labelText: 'Employee ID',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Enter employee ID'
                              : null,
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 50,
                          child: FilledButton(
                            onPressed: loading ? null : login,
                            child: loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('SIGN IN'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
