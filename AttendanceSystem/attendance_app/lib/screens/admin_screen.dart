import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../main.dart' show apiBaseUrl;

class AdminHome extends StatefulWidget {
  const AdminHome({super.key, required this.profile, required this.token});
  final Map<String, dynamic>? profile;
  final String token;

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _navIndex = 0;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _departments = [];
  bool _isLoading = false;
  String? _selectedAttendanceEmpId;
  String? _selectedDeptFilter;
  bool _isCheckoutPhase = false;
  bool _isSubmittingAttendance = false;
  String? _attendanceStatus;
  Color? _attendanceStatusColor;
  int _todayAttendanceCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Admin Dashboard', 'Nhân viên', 'Thiết bị', 'Phòng ban', 'Điểm danh'];
    final pages = [
      _buildOverviewTab(),
      _buildEmployeeTab(),
      _buildDeviceTab(),
      _buildDepartmentTab(),
      _buildAttendanceTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_navIndex]),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Tải lại',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(index: _navIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Tổng quan'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Nhân viên'),
          NavigationDestination(icon: Icon(Icons.devices_other_outlined), selectedIcon: Icon(Icons.devices), label: 'Thiết bị'),
          NavigationDestination(icon: Icon(Icons.business_outlined), selectedIcon: Icon(Icons.business), label: 'Phòng ban'),
          NavigationDestination(icon: Icon(Icons.how_to_reg_outlined), selectedIcon: Icon(Icons.how_to_reg), label: 'Điểm danh'),
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Temp holders to avoid partial UI updates on failure
      List<Map<String, dynamic>> employees = [];
      List<Map<String, dynamic>> devices = [];
      List<Map<String, dynamic>> departments = [];
      int todayAttendanceCount = _todayAttendanceCount;
      final todayStr = _formatDate(DateTime.now());

      // Load employees
      final empResponse = await http.get(
        Uri.parse('$apiBaseUrl/employees'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (empResponse.statusCode == 200) {
        final empData = json.decode(empResponse.body);
        if (empData is List) {
          employees = List<Map<String, dynamic>>.from(empData);
        } else if (empData is Map && empData['data'] is List) {
          employees = List<Map<String, dynamic>>.from(empData['data']);
        }
      }

      // Load devices
      final devResponse = await http.get(
        Uri.parse('$apiBaseUrl/devices'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (devResponse.statusCode == 200) {
        final devData = json.decode(devResponse.body);
        if (devData is List) {
          devices = List<Map<String, dynamic>>.from(devData);
        } else if (devData is Map && devData['data'] is List) {
          devices = List<Map<String, dynamic>>.from(devData['data']);
        }
      }

      // Load departments
      try {
        final deptResponse = await http.get(
          Uri.parse('$apiBaseUrl/departments'),
          headers: {'Authorization': 'Bearer ${widget.token}'},
        );
        if (deptResponse.statusCode == 200) {
          final deptData = json.decode(deptResponse.body);
          if (deptData is List) {
            departments = List<Map<String, dynamic>>.from(deptData);
          } else if (deptData is Map && deptData['data'] is List) {
            departments = List<Map<String, dynamic>>.from(deptData['data']);
          }
        }
      } catch (e) {
        debugPrint('Error loading departments: $e');
      }

      // Load today's attendance count
      try {
        final todayResp = await http.get(
          Uri.parse('$apiBaseUrl/attendance').replace(
            queryParameters: {
              'startDate': todayStr,
              'endDate': todayStr,
            },
          ),
          headers: {'Authorization': 'Bearer ${widget.token}'},
        );
        if (todayResp.statusCode == 200) {
          final todayData = json.decode(todayResp.body);
          if (todayData is Map && todayData['count'] is num) {
            todayAttendanceCount = (todayData['count'] as num).toInt();
          } else if (todayData is Map && todayData['data'] is List) {
            todayAttendanceCount = (todayData['data'] as List).length;
          }
        }
      } catch (e) {
        debugPrint('Error loading today attendance: $e');
      }

      if (!mounted) return;
      setState(() {
        _employees = employees;
        _devices = devices;
        _departments = departments;
        _todayAttendanceCount = todayAttendanceCount;
        final hasDeptFilter = _selectedDeptFilter != null && _selectedDeptFilter!.isNotEmpty;
        if (hasDeptFilter) {
          final stillExists = departments.any((d) => _extractDeptId(d) == _selectedDeptFilter);
          if (!stillExists) {
            _selectedDeptFilter = null;
          }
        }
        _selectedAttendanceEmpId = _syncSelectedAttendanceEmployee(_filteredEmployeesByDept());
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chào ${widget.profile?['name'] ?? 'Admin'}!',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Nhân viên',
                  _employees.length.toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Thiết bị',
                  _devices.length.toString(),
                  Icons.devices,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Phòng ban',
                  _departments.length.toString(),
                  Icons.business,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Điểm danh hôm nay',
                  _todayAttendanceCount.toString(),
                  Icons.check_circle,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Hoạt động gần đây',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildActivityCard('Hệ thống khởi động', Icons.info, Colors.blue),
          _buildActivityCard(
            'Đồng bộ dữ liệu thành công',
            Icons.sync,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(String message, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(message),
        subtitle: Text('${DateTime.now().hour}:${DateTime.now().minute}'),
      ),
    );
  }

  Widget _buildEmployeeTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Danh sách nhân viên',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showEmployeeDialog(null),
                icon: const Icon(Icons.add),
                label: const Text('Thêm'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _employees.isEmpty
              ? const Center(child: Text('Chưa có nhân viên nào'))
              : ListView.builder(
                  itemCount: _employees.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final emp = _employees[index];

                    // Debug: print entire employee object
                    debugPrint('=== Employee $index ===');
                    debugPrint(emp.toString());

                    // Try to find name field
                    String displayName = 'N/A';

                    // Check all possible name fields
                    final possibleFields = [
                      'fullname',
                      'name',
                      'fullName',
                      'Name',
                      'username',
                    ];
                    for (var field in possibleFields) {
                      if (emp[field] != null &&
                          emp[field].toString().trim().isNotEmpty &&
                          emp[field] != 'null') {
                        displayName = emp[field].toString();
                        debugPrint(
                          'Found name in field: $field = $displayName',
                        );
                        break;
                      }
                    }

                    // If still N/A, show employee ID or first available field
                    if (displayName == 'N/A') {
                      if (emp['employeeId'] != null) {
                        displayName = emp['employeeId'].toString();
                      } else {
                        // Show first non-id field as fallback
                        displayName = emp.keys.firstWhere(
                          (k) => k != '_id' && k != '__v',
                          orElse: () => '_id',
                        );
                        if (emp[displayName] != null) {
                          displayName =
                              '${emp[displayName].toString().substring(0, 10)}...';
                        }
                      }
                    }

                    String _displayEmail(Map<String, dynamic> emp) {
                      final direct = emp['email']?.toString();
                      if (direct != null && direct.isNotEmpty && direct != 'null') return direct;
                      final user = emp['user'];
                      if (user is Map && user['email'] != null) {
                        final nested = user['email'].toString();
                        if (nested.isNotEmpty && nested != 'null') return nested;
                      }
                      return '';
                    }

                    final email = _displayEmail(emp);
                    final employeeId = emp['employeeId']?.toString() ?? '';
                    final subtitleText = email.isNotEmpty
                        ? email
                        : (employeeId.isNotEmpty ? 'Mã: $employeeId' : null);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(
                            displayName.isNotEmpty
                                ? displayName.substring(0, 1).toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(displayName),
                        subtitle:
                            subtitleText != null ? Text(subtitleText) : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showEmployeeDialog(emp),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteEmployee(emp['_id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDeviceTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Danh sách thiết bị',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showDeviceDialog(null),
                icon: const Icon(Icons.add),
                label: const Text('Thêm'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _devices.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final dev = _devices[index];
              final code = dev['code']?.toString() ?? dev['id']?.toString() ?? '';
              final name = dev['name']?.toString() ?? 'N/A';
              final status = dev['status']?.toString() ?? '';
              final location = dev['location'];
              String locationText = '';
              if (location is Map) {
                locationText = location['address']?.toString() ?? '';
              } else if (location != null) {
                locationText = location.toString();
              }
              final subtitle = code.isNotEmpty ? 'Mã: $code' : '';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.devices,
                    color: status == 'active' ? Colors.green : Colors.grey,
                  ),
                  title: Text(name),
                  subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showDeviceDialog(dev),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteDevice(dev['_id'] ?? code),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Danh sách phòng ban',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showDepartmentDialog(null),
                icon: const Icon(Icons.add),
                label: const Text('Thêm'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _departments.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final dept = _departments[index];
              final code = dept['code']?.toString() ?? '';
              final name = dept['name']?.toString() ?? 'N/A';
              final desc = dept['description']?.toString() ?? '';
              final active = (dept['isActive'] ?? true) == true;
                final manager = (dept['manager'] is Map)
                  ? dept['manager']['fullName']?.toString()
                  : null;
              final subtitleParts = <String>[
                if (code.isNotEmpty) 'Mã: $code',
                if (manager != null && manager.isNotEmpty) 'QL: $manager',
                if (desc.isNotEmpty) desc,
              ];
              final subtitleText = subtitleParts.join(' · ');
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.business,
                    color: active ? Colors.orange : Colors.grey,
                  ),
                  title: Text(name),
                  subtitle: subtitleParts.isNotEmpty
                      ? Text(subtitleText)
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showDepartmentDialog(dept),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteDepartment(
                          dept['_id']?.toString() ?? dept['id']?.toString() ?? '',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceTab() {
    final employees = _filteredEmployeesByDept();
    final deptOptions = _buildDeptFilterOptions();
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const Text('Điểm danh nhân viên', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              final double fieldWidth = isWide
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String>(
                      value: _selectedDeptFilter ?? '',
                      items: deptOptions
                          .map((d) => DropdownMenuItem(
                                value: d['id'],
                                child: Text(d['name'] ?? 'N/A'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedDeptFilter = v == '' ? null : v;
                          _selectedAttendanceEmpId =
                              _syncSelectedAttendanceEmployee(_filteredEmployeesByDept());
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Lọc theo phòng ban',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String>(
                      value: _selectedAttendanceEmpId,
                      items: employees
                          .map((e) => DropdownMenuItem(
                                value: _extractEmployeeBusinessId(e),
                                child: Text(
                                  e['fullName']?.toString() ??
                                      e['name']?.toString() ??
                                      'N/A',
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedAttendanceEmpId = v),
                      decoration: const InputDecoration(
                        labelText: 'Chọn nhân viên',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Chế độ'),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('Check-in'),
                selected: !_isCheckoutPhase,
                onSelected: (_) => setState(() => _isCheckoutPhase = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Check-out'),
                selected: _isCheckoutPhase,
                onSelected: (_) => setState(() => _isCheckoutPhase = true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isSubmittingAttendance ? null : _submitAttendance,
            icon: _isSubmittingAttendance
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_isCheckoutPhase ? Icons.logout : Icons.login),
            label: Text(_isCheckoutPhase ? 'Check-out' : 'Check-in'),
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          if (_attendanceStatus != null) ...[
            const SizedBox(height: 12),
            Text(
              _attendanceStatus!,
              style: TextStyle(color: _attendanceStatusColor ?? Colors.green),
            ),
          ],
        ],
      ),
    );
  }

  void _showEmployeeDialog(Map<String, dynamic>? employee) {
    // Prefer backend field name fullName but fall back for older payloads
    final nameController = TextEditingController(
      text: (employee?['fullName'] ?? employee?['fullname'])?.toString() ?? '',
    );
    String _extractEmail(Map<String, dynamic>? emp) {
      if (emp == null) return '';
      final direct = emp['email']?.toString();
      if (direct != null && direct.isNotEmpty && direct != 'null') return direct;
      final user = emp['user'];
      if (user is Map && user['email'] != null) {
        final nested = user['email'].toString();
        if (nested.isNotEmpty && nested != 'null') return nested;
      }
      return '';
    }

    final emailController = TextEditingController(
      text: _extractEmail(employee),
    );
    final positionController = TextEditingController(
      text: employee?['position']?.toString() ?? '',
    );
    final passwordController = TextEditingController(
      text: employee == null ? '123456' : '',
    );

    String _normalizeDeptId(dynamic value) {
      final str = value?.toString() ?? '';
      if (str.isEmpty || str.toLowerCase() == 'null') return '';
      return str;
    }

    String _extractDeptId(dynamic dept) {
      if (dept is Map) {
        final dynamic id = dept['_id'] ?? dept['id'];
        return _normalizeDeptId(id);
      }
      return _normalizeDeptId(dept);
    }

    String selectedDepartment = _extractDeptId(employee?['department']);
    String selectedRole = employee?['role']?.toString() ?? 'employee';

    final deptOptions = <Map<String, String>>[];
    final seenDeptIds = <String>{};
    for (final dept in _departments) {
      final id = _extractDeptId(dept);
      if (id.isEmpty || !seenDeptIds.add(id)) continue;
      final name = dept['name']?.toString() ?? 'N/A';
      deptOptions.add({'id': id, 'name': name});
    }

    if (selectedDepartment.isNotEmpty &&
        !deptOptions.any((d) => d['id'] == selectedDepartment)) {
      selectedDepartment = '';
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(employee == null ? 'Thêm nhân viên' : 'Sửa nhân viên'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ tên *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: positionController,
                  decoration: const InputDecoration(
                    labelText: 'Chức vụ *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (employee == null)
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu *',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                if (employee == null) const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Quyền *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'employee',
                      child: Text('Nhân viên'),
                    ),
                    DropdownMenuItem(value: 'manager', child: Text('Quản lý')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'device', child: Text('Thiết bị')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedRole = value!;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedDepartment,
                  decoration: const InputDecoration(
                    labelText: 'Phòng ban',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('-- Chọn phòng ban --'),
                    ),
                    ...deptOptions.map((dept) {
                      return DropdownMenuItem(
                        value: dept['id'],
                        child: Text(dept['name'] ?? 'N/A'),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedDepartment = value ?? '';
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty ||
                    positionController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng điền đầy đủ thông tin bắt buộc'),
                    ),
                  );
                  return;
                }
                if (employee == null && (selectedDepartment.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng chọn phòng ban')), // backend cần department
                  );
                  return;
                }
                Navigator.pop(context);
                if (employee == null) {
                  _addEmployee(
                    nameController.text,
                    emailController.text,
                    positionController.text,
                    passwordController.text,
                    selectedRole,
                    selectedDepartment.isEmpty ? null : selectedDepartment,
                  );
                } else {
                  _updateEmployee(
                    employee['_id'],
                    nameController.text,
                    emailController.text,
                    positionController.text,
                    selectedRole,
                    selectedDepartment.isEmpty ? null : selectedDepartment,
                  );
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeviceDialog(Map<String, dynamic>? device) {
    final nameController = TextEditingController(
      text: device?['name']?.toString() ?? '',
    );
    final usernameController = TextEditingController(
      text: (device?['user'] is Map)
          ? device?['user']?['username']?.toString() ?? ''
          : device?['username']?.toString() ?? '',
    );
    final passwordController = TextEditingController();
    final addressController = TextEditingController(
      text: (device?['location'] is Map)
          ? device?['location']?['address']?.toString() ?? ''
          : '',
    );
    String status = device?['status']?.toString() ?? 'active';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(device == null ? 'Thêm thiết bị' : 'Sửa thiết bị'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (device != null) ...[
                  TextField(
                    controller: TextEditingController(
                      text: device['code']?.toString() ?? device['id']?.toString() ?? '',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Mã thiết bị',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                    enableInteractiveSelection: false,
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên thiết bị *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Tài khoản thiết bị *',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: device != null,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText:
                        device == null ? 'Mật khẩu *' : 'Mật khẩu (để trống nếu không đổi)',
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(
                    labelText: 'Trạng thái',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Hoạt động')),
                    DropdownMenuItem(value: 'inactive', child: Text('Tạm dừng')),
                  ],
                  onChanged: (val) => setState(() => status = val ?? 'active'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Vị trí (địa chỉ)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty ||
                    usernameController.text.isEmpty ||
                    (device == null && passwordController.text.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập đủ các trường bắt buộc')),
                  );
                  return;
                }
                Navigator.pop(context);
                if (device == null) {
                  _addDevice(
                    nameController.text,
                    usernameController.text,
                    passwordController.text,
                    status,
                    addressController.text,
                  );
                } else {
                  final deviceId = device['_id']?.toString() ??
                      device['id']?.toString() ??
                      device['code']?.toString() ??
                      '';
                  _updateDevice(
                    deviceId,
                    nameController.text,
                    status,
                    addressController.text,
                    passwordController.text,
                  );
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDepartmentDialog(Map<String, dynamic>? department) {
    final codeController = TextEditingController(
      text: department?['code']?.toString() ?? '',
    );
    final nameController = TextEditingController(
      text: department?['name']?.toString() ?? '',
    );
    final descController = TextEditingController(
      text: department?['description']?.toString() ?? '',
    );
    bool isActive = (department?['isActive'] ?? true) == true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(department == null ? 'Thêm phòng ban' : 'Sửa phòng ban'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Mã phòng ban *',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: department != null,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên phòng ban *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kích hoạt'),
                  value: isActive,
                  onChanged: (val) => setState(() => isActive = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (codeController.text.trim().isEmpty ||
                    nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng nhập mã và tên phòng ban'),
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                if (department == null) {
                  _addDepartment(
                    codeController.text.trim(),
                    nameController.text.trim(),
                    descController.text.trim(),
                    isActive,
                  );
                } else {
                  final deptId = department['_id']?.toString() ??
                      department['id']?.toString() ?? '';
                  _updateDepartment(
                    deptId,
                    nameController.text.trim(),
                    descController.text.trim(),
                    isActive,
                  );
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addDepartment(
    String code,
    String name,
    String description,
    bool isActive,
  ) async {
    try {
      final payload = {
        'code': code,
        'name': name,
        'description': description,
        'isActive': isActive,
      };

      final response = await http.post(
        Uri.parse('$apiBaseUrl/departments'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 201) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thêm phòng ban thành công')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Lỗi thêm phòng ban: ${response.statusCode} - ${response.body}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _updateDepartment(
    String id,
    String name,
    String description,
    bool isActive,
  ) async {
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy ID phòng ban để cập nhật')),
      );
      return;
    }
    try {
      final payload = {
        'name': name,
        'description': description,
        'isActive': isActive,
      };

      final response = await http.put(
        Uri.parse('$apiBaseUrl/departments/$id'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cập nhật phòng ban thành công')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Lỗi cập nhật phòng ban: ${response.statusCode} - ${response.body}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _addDevice(
    String name,
    String username,
    String password,
    String status,
    String address,
  ) async {
    try {
      final Map<String, dynamic> payload = {
        'name': name,
        'username': username,
        'password': password,
        'status': status,
        'deviceType': 'attendance',
      };

      if (address.isNotEmpty) {
        payload['location'] = {'address': address};
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/devices'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 201) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thêm thiết bị thành công')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Lỗi thêm thiết bị: ${response.statusCode} - ${response.body}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _updateDevice(
    String id,
    String name,
    String status,
    String address,
    String password,
  ) async {
    try {
      final Map<String, dynamic> payload = {
        'name': name,
        'status': status,
        'deviceType': 'attendance',
      };

      if (address.isNotEmpty) {
        payload['location'] = {'address': address};
      }
      if (password.isNotEmpty) {
        payload['password'] = password;
      }

      final response = await http.put(
        Uri.parse('$apiBaseUrl/devices/$id'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cập nhật thiết bị thành công')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Lỗi cập nhật thiết bị: ${response.statusCode} - ${response.body}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _addEmployee(
    String name,
    String email,
    String position,
    String password,
    String role,
    String? department,
  ) async {
    if (department == null || department.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn phòng ban')), // phòng ban bắt buộc trên backend
        );
      }
      return;
    }
    try {
      final payload = {
        'fullName': name,
        'position': position,
        'password': password,
        'role': role,
        'department': department,
      };

      if (email.isNotEmpty) payload['email'] = email;

      final response = await http.post(
        Uri.parse('$apiBaseUrl/employees'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );
      if (response.statusCode == 201) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thêm nhân viên thành công')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi tạo nhân viên: ${response.statusCode} - ${response.body}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _updateEmployee(
    String id,
    String name,
    String email,
    String position,
    String role,
    String? department,
  ) async {
    try {
      final payload = {'fullName': name, 'role': role, 'position': position};

      if (email.isNotEmpty) payload['email'] = email;
      if (department != null && department.isNotEmpty)
        payload['department'] = department;

      final response = await http.put(
        Uri.parse('$apiBaseUrl/employees/$id'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );
      if (response.statusCode == 200) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Cập nhật thành công')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: ${response.statusCode} - ${response.body}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _deleteEmployee(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn xóa nhân viên này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final response = await http.delete(
          Uri.parse('$apiBaseUrl/employees/$id'),
          headers: {'Authorization': 'Bearer ${widget.token}'},
        );
        if (response.statusCode == 200) {
          _loadData();
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Xóa thành công')));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      }
    }
  }

  Future<void> _deleteDevice(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn xóa thiết bị này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final response = await http.delete(
          Uri.parse('$apiBaseUrl/devices/$id'),
          headers: {'Authorization': 'Bearer ${widget.token}'},
        );
        if (response.statusCode == 200) {
          _loadData();
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Xóa thiết bị thành công')));
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Không xóa được: ${response.statusCode} - ${response.body}'),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      }
    }
  }

  Future<void> _deleteDepartment(String id) async {
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy ID phòng ban để xóa')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn xóa phòng ban này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/departments/$id'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode == 200) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Xóa phòng ban thành công')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Không xóa được: ${response.statusCode} - ${response.body}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  List<Map<String, String>> _buildDeptFilterOptions() {
    final seen = <String>{};
    final opts = <Map<String, String>>[
      {'id': '', 'name': 'Tất cả phòng ban'},
    ];
    for (final dept in _departments) {
      final id = _extractDeptId(dept);
      if (id.isEmpty || !seen.add(id)) continue;
      opts.add({'id': id, 'name': dept['name']?.toString() ?? id});
    }
    return opts;
  }

  List<Map<String, dynamic>> _filteredEmployeesByDept() {
    final deptFilter = _selectedDeptFilter;
    if (deptFilter == null || deptFilter.isEmpty) return _employees;
    return _employees.where((e) {
      final deptId = _extractDeptId(e['department']);
      return deptId == deptFilter;
    }).toList();
  }

  String _normalizeDeptId(dynamic value) {
    final str = value?.toString() ?? '';
    if (str.isEmpty || str.toLowerCase() == 'null') return '';
    return str;
  }

  String _extractDeptId(dynamic dept) {
    if (dept is Map) {
      final dynamic id = dept['_id'] ?? dept['id'] ?? dept['departmentId'];
      return _normalizeDeptId(id);
    }
    return _normalizeDeptId(dept);
  }

  String _extractEmployeeBusinessId(Map<String, dynamic> emp) {
    final code = emp['code']?.toString();
    if (code != null && code.isNotEmpty && code.toLowerCase() != 'null') return code;
    final empId = emp['employeeId']?.toString();
    if (empId != null && empId.isNotEmpty && empId.toLowerCase() != 'null') return empId;
    final dbId = emp['_id']?.toString() ?? emp['id']?.toString();
    return dbId ?? '';
  }

  String _extractEmployeeId(Map<String, dynamic> emp) {
    final dbId = emp['_id']?.toString() ?? emp['id']?.toString();
    if (dbId != null && dbId.isNotEmpty && dbId.toLowerCase() != 'null') return dbId;
    final empId = emp['employeeId']?.toString();
    if (empId != null && empId.isNotEmpty && empId.toLowerCase() != 'null') return empId;
    final code = emp['code']?.toString();
    if (code != null && code.isNotEmpty && code.toLowerCase() != 'null') return code;
    return '';
  }

  String _extractEmployeeCode(Map<String, dynamic> emp) {
    final code = emp['code']?.toString();
    if (code != null && code.isNotEmpty && code.toLowerCase() != 'null') return code;
    final empId = emp['employeeId']?.toString();
    if (empId != null && empId.isNotEmpty && empId.toLowerCase() != 'null') return empId;
    return '';
  }

  Map<String, dynamic>? _findEmployeeById(String id) {
    for (final e in _employees) {
      final business = _extractEmployeeBusinessId(e);
      final db = _extractEmployeeId(e);
      if (business == id || db == id) return e;
    }
    return null;
  }

  String? _syncSelectedAttendanceEmployee(List<Map<String, dynamic>> employees) {
    final current = _selectedAttendanceEmpId;
    final exists = current != null && employees.any((e) => _extractEmployeeBusinessId(e) == current);
    if (exists) return current;
    if (employees.isEmpty) return null;
    return _extractEmployeeBusinessId(employees.first);
  }

  Future<void> _submitAttendance() async {
    final empId = _selectedAttendanceEmpId;
    if (empId == null || empId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn nhân viên')),
      );
      return;
    }
    setState(() {
      _isSubmittingAttendance = true;
      _attendanceStatus = null;
    });
    try {
      final endpoint = _isCheckoutPhase ? 'check-out' : 'check-in';
      final uri = Uri.parse('$apiBaseUrl/attendance/$endpoint');
      final selectedEmp = _findEmployeeById(empId);
      final empCode = selectedEmp != null ? _extractEmployeeCode(selectedEmp) : '';
      final empObjectId = selectedEmp != null ? _extractEmployeeId(selectedEmp) : '';
      final employeeIdPayload = empCode.isNotEmpty ? empCode : empId;
      final payload = {
        'employeeId': employeeIdPayload,
        'method': 'manual',
        if (empObjectId.isNotEmpty) 'employeeObjectId': empObjectId,
        'managerId': _extractEmployeeId(widget.profile ?? {}),
        if (empCode.isNotEmpty) 'employeeCode': empCode,
        if (widget.profile?['code'] != null) 'managerCode': widget.profile?['code'],
      };
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode(payload),
      );

      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {}

      final success = resp.statusCode == 200 && (body?['success'] == true || body?['status'] == 'success');
      if (success) {
        setState(() {
          _attendanceStatus = _isCheckoutPhase ? 'Đã check-out thành công' : 'Đã check-in thành công';
          _attendanceStatusColor = Colors.green;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_attendanceStatus!)),
          );
        }
      } else {
        String msg = body?['message']?.toString() ?? 'Điểm danh thất bại';
        if (msg.toLowerCase().contains('not found') && empCode.isNotEmpty) {
          msg = '$msg (đã gửi employeeId=$empCode)';
        }
        setState(() {
          _attendanceStatus = msg;
          _attendanceStatusColor = Colors.red;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi điểm danh: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingAttendance = false);
      }
    }
  }
}
