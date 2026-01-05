import 'package:flutter/material.dart';

import 'base_role_screen.dart';

class EmployeeHome extends StatelessWidget {
  const EmployeeHome({super.key, required this.profile, required this.token});
  final Map<String, dynamic>? profile;
  final String token;

  @override
  Widget build(BuildContext context) {
    return BaseRoleScreen(
      title: 'Nhân viên',
      profile: profile,
      token: token,
      color: Colors.green,
    );
  }
}
