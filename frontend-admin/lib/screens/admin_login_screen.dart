import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_config.dart';
import 'admin_dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final formKey = GlobalKey<FormState>();
  final empId = TextEditingController();
  bool loading = false;

  static const navy = Color(0xFF12305A);

  @override
  void dispose() {
    empId.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (!formKey.currentState!.validate() || loading) return;

    setState(() => loading = true);

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/admin/auth/login'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'empId': empId.text.trim()}),
          )
          .timeout(const Duration(seconds: 20));

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

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not connect to the server. Check the connection and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Align(
          alignment: const Alignment(0, -0.25),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'VIT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                      color: navy,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE3E9F2)),
                    ),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Icon(
                              Icons.directions_bus_rounded,
                              size: 64,
                              color: navy,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'SHUBUS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: navy,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Admin sign in',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF68758A),
                            ),
                          ),
                          const SizedBox(height: 26),
                          TextFormField(
                            controller: empId,
                            textCapitalization: TextCapitalization.characters,
                            autocorrect: false,
                            enableSuggestions: false,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF22314A),
                            ),
                            decoration: InputDecoration(
                              labelText: 'Employee ID',
                              labelStyle: const TextStyle(
                                color: Color(0xFF68758A),
                                fontSize: 13,
                              ),
                              floatingLabelStyle: const TextStyle(
                                color: navy,
                                fontWeight: FontWeight.w800,
                              ),
                              hintText: 'Enter your employee ID',
                              hintStyle: const TextStyle(
                                color: Color(0xFFA8B2C3),
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.badge_outlined,
                                color: navy,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFDCE4EF),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFDCE4EF),
                                  width: 1.3,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: navy,
                                  width: 1.6,
                                ),
                              ),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Enter employee ID'
                                : null,
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: loading ? null : login,
                              style: FilledButton.styleFrom(
                                backgroundColor: navy,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: navy.withValues(
                                  alpha: 0.55,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: loading
                                  ? const SizedBox(
                                      width: 21,
                                      height: 21,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Sign in',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
