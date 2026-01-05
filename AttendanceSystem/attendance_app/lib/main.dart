import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'screens/admin_screen.dart';
import 'screens/device_screen.dart';
import 'screens/employee_screen.dart';
import 'screens/manager_screen.dart';

const String apiBaseUrl = 'https://328bcae359f4.ngrok-free.app/api';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Đăng nhập điểm danh',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  String? errorMessage;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Call backend login API and navigate to role-specific screen.
  Future<void> _login() async {
    final emailOrUsername = emailController.text.trim();
    final password = passwordController.text.trim();

    if (emailOrUsername.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = 'Email/username và mật khẩu không được trống.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final uri = Uri.parse('$apiBaseUrl/auth/login');
      final Map<String, String> payload = {
        'password': password,
      };

      // Backend accepts either email or username; pick based on input shape.
      if (emailOrUsername.contains('@')) {
        payload['email'] = emailOrUsername;
      } else {
        payload['username'] = emailOrUsername;
      }

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final Map<String, dynamic> json = jsonDecode(response.body);

      if (response.statusCode == 200 && json['success'] == true) {
        final String? token = json['data']?['token'] as String?;
        final Map<String, dynamic>? profile =
            (json['data']?['employee'] ?? json['data']?['device'])
                as Map<String, dynamic>?;
        final String role = (profile?['role'] as String?) ?? 'employee';

        if (token != null) {
          // Navigate based on role
          _goToRoleScreen(role: role, profile: profile, token: token);
        } else {
          setState(() {
            errorMessage = 'Phản hồi không hợp lệ từ server.';
          });
        }
      } else {
        setState(() {
          errorMessage = json['message']?.toString() ?? 'Đăng nhập thất bại.';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Không thể kết nối máy chủ: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _goToRoleScreen({required String role, Map<String, dynamic>? profile, required String token}) {
    Widget target;
    switch (role) {
      case 'admin':
        target = AdminHome(profile: profile, token: token);
        break;
      case 'manager':
        target = ManagerHome(profile: profile, token: token);
        break;
      case 'device':
        target = DeviceHome(profile: profile, token: token);
        break;
      case 'employee':
      default:
        target = EmployeeHome(profile: profile, token: token);
        break;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => target),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color primary = const Color(0xFF2F80ED);
    final Color secondary = const Color(0xFF56CCF2);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      body: SafeArea(
        child: Stack(
          children: [
            // Gradient header
            Container(
              height: 230,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, secondary],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'MEDDU',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Login card
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            'LOGIN',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email hoặc Username',
                              hintText: 'example@email.com',
                              prefixIcon: Icon(Icons.person_outline),
                              border: UnderlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscurePassword ? Icons.visibility_off : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() => obscurePassword = !obscurePassword);
                                },
                              ),
                              border: const UnderlineInputBorder(),
                            ),
                            onSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {},
                              child: const Text('Quên mật khẩu?'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: isLoading ? null : _login,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                    )
                                  : const Text('LOGIN'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: () {},
                              child: const Text("Don't have an account? Sign up"),
                            ),
                          ),
                          if (errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.error_outline, color: theme.colorScheme.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: TextStyle(color: theme.colorScheme.error),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Realtime: $apiBaseUrl/auth/login',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Role screens moved to lib/screens/*.dart
