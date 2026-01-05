import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLogin});

  final void Function({required String baseUrl, required String token, String? email, String? role}) onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const String _defaultBaseUrl = 'https://328bcae359f4.ngrok-free.app/api';
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  String _status = '';
  bool _showAdvanced = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _baseUrlController.text = _defaultBaseUrl;
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final base = (_baseUrlController.text.trim().isEmpty
            ? _defaultBaseUrl
            : _baseUrlController.text.trim())
        .trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (base.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _status = 'Nhập đủ Base URL, email và mật khẩu.');
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Đang đăng nhập...';
    });

    try {
      final uri = Uri.parse(base.endsWith('/') ? '${base}auth/login' : '$base/auth/login');
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        setState(() => _status = 'Đăng nhập thất bại: ${resp.statusCode}');
        return;
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>?;
      final token = body?['data']?['token']?.toString();
      final role = body?['data']?['employee']?['role']?.toString() ?? body?['data']?['device']?['role']?.toString();

      if (token == null || token.isEmpty) {
        setState(() => _status = 'Phản hồi không có token.');
        return;
      }

      widget.onLogin(baseUrl: base, token: token, email: email, role: role);
    } catch (e) {
      setState(() => _status = 'Lỗi đăng nhập: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final fieldFill = theme.colorScheme.surfaceVariant.withOpacity(0.6);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.08),
              theme.colorScheme.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                color: cardColor,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                            child: Icon(Icons.nfc, color: theme.colorScheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chào mừng quay lại',
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'Đăng nhập để ghi thẻ NFC',
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          filled: true,
                          fillColor: fieldFill,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_loading,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          filled: true,
                          fillColor: fieldFill,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: _loading
                                ? null
                                : () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        enabled: !_loading,
                      ),
                      const SizedBox(height: 10),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 200),
                        crossFadeState: _showAdvanced ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                        firstChild: Column(
                          children: [
                            TextField(
                              controller: _baseUrlController,
                              decoration: InputDecoration(
                                labelText: 'API Base URL',
                                helperText: 'VD: http://10.0.2.2:3000/api',
                                filled: true,
                                fillColor: fieldFill,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.link_outlined),
                              ),
                              keyboardType: TextInputType.url,
                              enabled: !_loading,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                        secondChild: const SizedBox.shrink(),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _loading
                              ? null
                              : () => setState(() => _showAdvanced = !_showAdvanced),
                          icon: Icon(_showAdvanced ? Icons.expand_less : Icons.settings_outlined),
                          label: Text(_showAdvanced ? 'Ẩn API Base URL' : 'Tùy chọn nâng cao'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _login,
                          icon: const Icon(Icons.login),
                          label: Text(_loading ? 'Đang đăng nhập...' : 'Đăng nhập'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_status.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _status,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
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
    );
  }
}
