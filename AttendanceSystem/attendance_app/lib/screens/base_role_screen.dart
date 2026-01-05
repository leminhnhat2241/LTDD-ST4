import 'package:flutter/material.dart';

class BaseRoleScreen extends StatelessWidget {
  const BaseRoleScreen({
    super.key,
    required this.title,
    required this.profile,
    required this.token,
    required this.color,
  });

  final String title;
  final Map<String, dynamic>? profile;
  final String token;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/');
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vai trò: ${title.toUpperCase()}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Tên: ${profile?['fullName'] ?? profile?['name'] ?? '-'}'),
            Text('Mã nhân viên/thiết bị: ${profile?['employeeId'] ?? profile?['code'] ?? '-'}'),
            Text('Token (rút gọn): ${token.substring(0, token.length > 24 ? 24 : token.length)}...'),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'TODO: Thêm tính năng $title tại đây (dashboard, hành động, realtime).',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
