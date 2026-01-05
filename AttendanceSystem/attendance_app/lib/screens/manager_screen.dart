import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../main.dart' show apiBaseUrl;

class ManagerHome extends StatefulWidget {
  const ManagerHome({super.key, required this.profile, required this.token});
  final Map<String, dynamic>? profile;
  final String token;

  @override
  State<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _employees = [];
  int _tabIndex = 0;
  String? _managerDeptId;
  String? _managerDeptName;
  String? _managerDeptCode;
  String? _selectedAttendanceEmpId;
  bool _isCheckoutPhase = false;
  bool _isSubmittingAttendance = false;
  String? _attendanceStatus;
  Color? _attendanceStatusColor;
  List<Map<String, dynamic>> _attendanceRecords = [];
  DateTime _historyDate = DateTime.now();
  bool _isLoadingHistory = false;
  bool _isQrMode = false;
  String _employeeSearch = '';
  bool _isQrCheckoutPhase = false;
  bool _isSubmittingQr = false;
  String? _qrStatus;
  Color? _qrStatusColor;
  String? _lastScannedId;
  DateTime? _lastQrScanTime;
  final MobileScannerController _qrController = MobileScannerController();

  @override
  void initState() {
    super.initState();
    _updateManagerDeptFromProfile();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const titles = ['Quản lý', 'Nhân viên', 'Điểm danh', 'Lịch sử'];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        title: Text(titles[_tabIndex]),
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
          : IndexedStack(
              index: _tabIndex,
              children: [
                _buildOverview(theme),
                _buildEmployeesTab(),
                _buildAttendanceTab(),
                _buildAttendanceHistoryTab(),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        onTap: (i) => setState(() => _tabIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_customize), label: 'Tổng quan'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt), label: 'Nhân viên'),
          BottomNavigationBarItem(icon: Icon(Icons.how_to_reg), label: 'Điểm danh'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Lịch sử'),
        ],
      ),
      floatingActionButton: _tabIndex == 1
          ? FloatingActionButton(
              onPressed: () => _showEmployeeDialog(null),
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildOverview(ThemeData theme) {
    final todayParam = _formatDateParam(DateTime.now());
    final statusMap = _buildEmployeeStatusMap(_attendanceRecords, _employees, todayParam);
    final checkedOut = statusMap.values.where((s) => s.label == 'Đã check-out').length;
    final checkedIn = statusMap.values.where((s) => s.label != 'Chưa điểm danh').length;
    final pending = (_employees.length - checkedIn).clamp(0, _employees.length);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            const SizedBox(height: 16),
            _buildStats(checkedIn: checkedIn, checkedOut: checkedOut, pending: pending),
            const SizedBox(height: 16),
            _buildQuickActions(),
            const SizedBox(height: 12),
            const Text('Kéo xuống để tải lại', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final profile = widget.profile ?? {};
    final name = profile['fullName'] ?? profile['name'] ?? '-';
    final code = profile['employeeId'] ?? profile['code'] ?? '-';
    final tokenShort = widget.token.isNotEmpty
        ? widget.token.substring(0, widget.token.length > 24 ? 24 : widget.token.length)
        : '';
    final deptLabel = _managerDeptName ?? _managerDeptCode ?? _managerDeptId ?? '-';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vai trò: QUẢN LÝ', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Tên: $name'),
            Text('Mã nhân viên/thiết bị: $code'),
            Text('Phòng ban: $deptLabel'),
            Text('Token (rút gọn): ${tokenShort.isNotEmpty ? '$tokenShort...' : '-'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildStats({required int checkedIn, required int checkedOut, required int pending}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              title: 'Nhân viên',
              value: _employees.length.toString(),
              icon: Icons.people_alt,
              color: Colors.blueAccent,
              width: cardWidth,
            ),
            _buildStatCard(
              title: 'Đã check-in',
              value: checkedIn.toString(),
              icon: Icons.login,
              color: Colors.green,
              width: cardWidth,
            ),
            _buildStatCard(
              title: 'Chưa check-in',
              value: pending.toString(),
              icon: Icons.access_time,
              color: Colors.orange,
              width: cardWidth,
            ),
            _buildStatCard(
              title: 'Đã check-out',
              value: checkedOut.toString(),
              icon: Icons.logout,
              color: Colors.purple,
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                foregroundColor: color,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: () => setState(() {
            _tabIndex = 2;
            _isQrMode = true;
            _qrStatus = null;
          }),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Điểm danh nhanh'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
        ),
        OutlinedButton.icon(
          onPressed: () => setState(() => _tabIndex = 1),
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Thêm nhân viên'),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        TextButton.icon(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Tải lại'),
        )
      ],
    );
  }

  Widget _buildEmployees({bool compact = false}) {
    if (_employees.isEmpty) {
      return const Text('Chưa có dữ liệu');
    }
    final list = compact ? _employees.take(5).toList() : _employees;
    return ListView.separated(
      shrinkWrap: compact,
      physics: compact ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
      padding: compact ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: list.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
      itemBuilder: (_, index) {
        final emp = list[index];
        final name = emp['fullName']?.toString() ?? emp['name']?.toString() ?? 'N/A';
        final email = _extractEmail(emp);
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(name),
          subtitle: Text(email.isNotEmpty ? email : ''),
          onTap: compact ? null : () => _showEmployeeDetails(emp),
          trailing: compact
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                      onPressed: () => _showEmployeeDialog(emp),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _deleteEmployee(_extractEmployeeId(emp)),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildEmployeesTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _employees.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: const [Text('Chưa có dữ liệu')],
            )
          : _buildEmployees(),
    );
  }

  Widget _buildAttendanceTab() {
    final employees = _employees;
    final filteredEmployees = _employeeSearch.isEmpty
        ? employees
        : employees.where((e) => _matchesEmployeeSearch(e, _employeeSearch)).toList();
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const Text('Điểm danh', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Hình thức'),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('Thủ công'),
                selected: !_isQrMode,
                onSelected: (_) => setState(() => _isQrMode = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Quét QR'),
                selected: _isQrMode,
                onSelected: (_) => setState(() => _isQrMode = true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_isQrMode) ...[
            TextField(
              decoration: const InputDecoration(
                labelText: 'Tìm nhân viên (mã hoặc tên)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _employeeSearch = v.trim()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedAttendanceEmpId,
              items: filteredEmployees
                  .map((e) => DropdownMenuItem(
                        value: _extractEmployeeBusinessId(e),
                        child: Text(e['fullName']?.toString() ?? e['name']?.toString() ?? 'N/A'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedAttendanceEmpId = v),
              decoration: const InputDecoration(
                labelText: 'Chọn nhân viên',
                border: OutlineInputBorder(),
              ),
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
          ] else ...[
            Row(
              children: [
                const Text('Chế độ'),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Check-in'),
                  selected: !_isQrCheckoutPhase,
                  onSelected: (_) => setState(() => _isQrCheckoutPhase = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Check-out'),
                  selected: _isQrCheckoutPhase,
                  onSelected: (_) => setState(() => _isQrCheckoutPhase = true),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 320,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    MobileScanner(
                      controller: _qrController,
                      onDetect: _isQrMode ? _onQrDetect : null,
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_qrStatus != null)
              Text(
                _qrStatus!,
                style: TextStyle(color: _qrStatusColor ?? Colors.green),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceHistoryTab() {
    final dateLabel = _formatDateLabel(_historyDate);
    final today = _formatDateParam(_historyDate);
    final employeeStatus = _buildEmployeeStatusMap(_attendanceRecords, _employees, today);

    return RefreshIndicator(
      onRefresh: _loadAttendanceHistory,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Lịch sử điểm danh', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _pickHistoryDate,
                icon: const Icon(Icons.date_range),
                label: Text(dateLabel),
              ),
            ],
          ),
          if (_isLoadingHistory)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_employees.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Chưa có nhân viên thuộc quyền quản lý'),
            )
          else ...[
            const SizedBox(height: 8),
            const Text('Trạng thái trong ngày', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._employees.map((e) {
              final status = employeeStatus[_extractEmployeeBusinessId(e)] ?? employeeStatus[_extractEmployeeId(e)];
              final empBizId = _extractEmployeeBusinessId(e);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(e['fullName']?.toString() ?? e['name']?.toString() ?? 'N/A'),
                  subtitle: Text(status?.label ?? 'Chưa điểm danh'),
                  trailing: status != null && status.timeLabel != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(status.timeLabel!),
                            if (status.methodLabel != null)
                              Text(status.methodLabel!, style: const TextStyle(color: Colors.grey)),
                          ],
                        )
                      : null,
                  onTap: () => _showEmployeeHistory(empBizId, e),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String? _extractDeptId(dynamic dept) {
    String normalize(dynamic v) {
      if (v == null) return '';
      final str = v.toString();
      if (str.isEmpty || str.toLowerCase() == 'null') return '';
      return str;
    }

    if (dept is Map) {
      return normalize(dept['_id'] ?? dept['id'] ?? dept['departmentId']);
    }
    return normalize(dept);
  }

  String? _extractDeptName(dynamic dept) {
    if (dept is Map) {
      final name = dept['name']?.toString();
      if (name != null && name.isNotEmpty && name.toLowerCase() != 'null') {
        return name;
      }
    }
    return null;
  }

  String? _extractDeptCode(dynamic dept) {
    if (dept is Map) {
      final code = dept['code']?.toString();
      if (code != null && code.isNotEmpty && code.toLowerCase() != 'null') {
        return code;
      }
    } else if (dept is String) {
      if (dept.isNotEmpty && dept.toLowerCase() != 'null') return dept;
    }
    return null;
  }

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

  String _extractEmployeeId(Map<String, dynamic> emp) {
    // Prefer database id first (backend attendance may expect _id), then business ids
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

  String _extractEmployeeBusinessId(Map<String, dynamic> emp) {
    // For attendance payloads: prefer code/employeeId
    final code = emp['code']?.toString();
    if (code != null && code.isNotEmpty && code.toLowerCase() != 'null') return code;
    final empId = emp['employeeId']?.toString();
    if (empId != null && empId.isNotEmpty && empId.toLowerCase() != 'null') return empId;
    final dbId = emp['_id']?.toString() ?? emp['id']?.toString();
    return dbId ?? '';
  }

  String _extractRole(Map<String, dynamic> emp) {
    final role = emp['role']?.toString();
    if (role != null && role.isNotEmpty && role.toLowerCase() != 'null') return role;
    final user = emp['user'];
    if (user is Map) {
      final nested = user['role']?.toString();
      if (nested != null && nested.isNotEmpty && nested.toLowerCase() != 'null') return nested;
    }
    return '';
  }

  String _formatDateParam(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDateLabel(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  Map<String, dynamic>? _findEmployeeById(String id) {
    for (final e in _employees) {
      final business = _extractEmployeeBusinessId(e);
      final db = _extractEmployeeId(e);
      if (business == id || db == id) return e;
    }
    return null;
  }

  String? _formatTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return null;
    try {
      final dt = DateTime.parse(isoString);
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    } catch (_) {
      return null;
    }
  }

  _EmpDailyStatus _determineStatus(Map<String, dynamic> record) {
    final inTime = _formatTime(record['checkInTimeLocal']?.toString());
    final outTime = _formatTime(record['checkOutTimeLocal']?.toString());
    final inMethod = record['checkInMethod']?.toString();
    final outMethod = record['checkOutMethod']?.toString();

    if (outTime != null) {
      return _EmpDailyStatus(
        label: 'Đã check-out',
        timeLabel: 'Out $outTime',
        methodLabel: outMethod != null ? 'Bằng $outMethod' : null,
      );
    }
    if (inTime != null) {
      return _EmpDailyStatus(
        label: 'Đã check-in',
        timeLabel: 'In $inTime',
        methodLabel: inMethod != null ? 'Bằng $inMethod' : null,
      );
    }
    return _EmpDailyStatus(label: 'Chưa điểm danh');
  }

  Map<String, _EmpDailyStatus> _buildEmployeeStatusMap(
    List<Map<String, dynamic>> records,
    List<Map<String, dynamic>> employees,
    String targetDate,
  ) {
    final map = <String, _EmpDailyStatus>{};
    for (final r in records) {
      if (r['date']?.toString() != targetDate) continue;
      final id = r['employeeId']?.toString();
      if (id == null || id.isEmpty) continue;
      map[id] = _determineStatus(r);
    }
    return map;
  }

  void _showEmployeeHistory(String employeeBizId, Map<String, dynamic> employee) {
    final name = employee['fullName']?.toString() ?? employee['name']?.toString() ?? 'N/A';
    final filtered = _attendanceRecords.where((r) => r['employeeId']?.toString() == employeeBizId).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: filtered.isEmpty
            ? const Text('Không có bản ghi cho ngày này')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final r = filtered[i];
                  final checkIn = _formatTime(r['checkInTimeLocal']?.toString());
                  final checkOut = _formatTime(r['checkOutTimeLocal']?.toString());
                  final inMethod = r['checkInMethod']?.toString();
                  final outMethod = r['checkOutMethod']?.toString();
                  final status = r['status']?.toString() ?? '';
                  final recordId = r['_id']?.toString();
                  final canClearIn = recordId != null && recordId.isNotEmpty && checkIn != null;
                  final canClearOut = recordId != null && recordId.isNotEmpty && checkOut != null;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('In: ${checkIn ?? '—'} ${inMethod != null ? '(bằng $inMethod)' : ''}')),
                              if (status.isNotEmpty) Text(status, style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          Text('Out: ${checkOut ?? '—'} ${outMethod != null ? '(bằng $outMethod)' : ''}'),
                          if (recordId != null && recordId.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (canClearIn)
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                    onPressed: () => _confirmClearAttendance(recordId, 'checkin'),
                                    icon: const Icon(Icons.delete_outline, size: 16),
                                    label: const Text('Xóa check-in'),
                                  ),
                                if (canClearOut)
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                    onPressed: () => _confirmClearAttendance(recordId, 'checkout'),
                                    icon: const Icon(Icons.delete_outline, size: 16),
                                    label: const Text('Xóa check-out'),
                                  ),
                                TextButton.icon(
                                  onPressed: () => _confirmDeleteAttendance(recordId),
                                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                                  label: const Text('Xóa tất cả', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _confirmDeleteAttendance(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa điểm danh'),
        content: const Text('Xóa bản ghi điểm danh này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _deleteAttendance(id);
    }
  }

  Future<void> _deleteAttendance(String id) async {
    try {
      final resp = await http.delete(
        Uri.parse('$apiBaseUrl/attendance/$id'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (resp.statusCode == 200) {
        await _loadAttendanceHistory();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Đã xóa bản ghi')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Xóa thất bại: ${resp.statusCode} - ${resp.body}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi xóa: $e')));
      }
    }
  }

  Future<void> _confirmClearAttendance(String id, String field) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xóa ${field == 'checkin' ? 'check-in' : 'check-out'}'),
        content: Text('Xóa ${field == 'checkin' ? 'check-in' : 'check-out'} của bản ghi này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _clearAttendance(id, field);
    }
  }

  Future<void> _clearAttendance(String id, String field) async {
    try {
      final uri = Uri.parse('$apiBaseUrl/attendance/$id').replace(queryParameters: {'field': field});
      final resp = await http.patch(
        uri,
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (resp.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Đã xóa ${field == 'checkin' ? 'check-in' : 'check-out'}')));
        }
        await _loadAttendanceHistory();
      } else {
        final body = resp.body;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Xóa thất bại: ${resp.statusCode} - $body')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xóa: $e')),
        );
      }
    }
  }

  void _updateManagerDeptFromProfile() {
    final profile = widget.profile ?? {};
    _managerDeptId = _extractDeptId(profile['department'] ?? profile['departmentId']);
    _managerDeptName = _extractDeptName(profile['department']) ?? profile['departmentName']?.toString();
    _managerDeptCode = _extractDeptCode(profile['department']) ?? profile['departmentCode']?.toString();
  }

  String? _managerDeptValue() {
    if (_managerDeptId != null && _managerDeptId!.isNotEmpty) return _managerDeptId;
    if (_managerDeptCode != null && _managerDeptCode!.isNotEmpty) return _managerDeptCode;
    return null;
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showEmployeeDetails(Map<String, dynamic> emp) {
    final name = emp['fullName']?.toString() ?? emp['name']?.toString() ?? 'N/A';
    final email = _extractEmail(emp);
    final position = emp['position']?.toString() ?? '';
    final deptName = emp['department'] is Map ? emp['department']['name']?.toString() ?? '' : '';
    final role = emp['role']?.toString() ?? (emp['user'] is Map ? emp['user']['role']?.toString() : '') ?? '';
    final code = _extractEmployeeId(emp);
    final qrData = code.isNotEmpty ? code : name;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Thông tin nhân viên', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: QrImageView(
                  data: qrData,
                  size: 160,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              _infoRow('Tên', name),
              _infoRow('Email', email.isNotEmpty ? email : '—'),
              _infoRow('Mã/ID', code.isNotEmpty ? code : '—'),
              _infoRow('Chức vụ', position.isNotEmpty ? position : '—'),
              _infoRow('Phòng ban', deptName.isNotEmpty ? deptName : '—'),
              _infoRow('Quyền', role.isNotEmpty ? role : '—'),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmployeeDialog(Map<String, dynamic>? employee) {
    final nameController = TextEditingController(
      text: (employee?['fullName'] ?? employee?['fullname'])?.toString() ?? '',
    );
    final emailController = TextEditingController(text: _extractEmail(employee));
    final positionController = TextEditingController(text: employee?['position']?.toString() ?? '');
    final passwordController = TextEditingController(text: employee == null ? '123456' : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              if (employee == null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu *',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              final deptValue = _managerDeptValue();
              if (nameController.text.isEmpty || positionController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập họ tên và chức vụ')),
                );
                return;
              }
              if (deptValue == null || deptValue.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thiếu thông tin phòng ban để tạo/sửa nhân viên')),
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
                  deptValue,
                );
              } else {
                _updateEmployee(
                  _extractEmployeeId(employee),
                  nameController.text,
                  emailController.text,
                  positionController.text,
                  deptValue,
                );
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _addEmployee(
    String name,
    String email,
    String position,
    String password,
    String department,
  ) async {
    if (department.isEmpty) return;
    try {
      final payload = {
        'fullName': name,
        'position': position,
        'password': password,
        'role': 'employee',
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
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Thêm nhân viên thành công')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi tạo nhân viên: ${response.statusCode} - ${response.body}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  void _onQrDetect(BarcodeCapture capture) {
    if (!_isQrMode) return;
    if (capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue ?? '';
    if (raw.isEmpty) return;

    final now = DateTime.now();
    if (_lastScannedId == raw && _lastQrScanTime != null && now.difference(_lastQrScanTime!).inSeconds < 2) {
      return;
    }
    _lastScannedId = raw;
    _lastQrScanTime = now;
    if (_isSubmittingQr) return;
    _submitQrAttendance(raw);
  }

  Future<void> _submitQrAttendance(String scannedValue) async {
    final emp = _findEmployeeById(scannedValue);
    if (emp == null) {
      setState(() {
        _qrStatus = 'QR không thuộc nhân viên bạn quản lý';
        _qrStatusColor = Colors.red;
      });
      return;
    }

    final empBizId = _extractEmployeeBusinessId(emp);
    final empObjectId = _extractEmployeeId(emp);
    final empCode = _extractEmployeeCode(emp);
    final empName = emp['fullName']?.toString() ?? emp['name']?.toString() ?? empBizId;

    setState(() {
      _isSubmittingQr = true;
      _qrStatus = 'Đang gửi điểm danh cho $empName...';
      _qrStatusColor = Colors.blue;
    });

    try {
      final endpoint = _isQrCheckoutPhase ? 'check-out' : 'check-in';
      final uri = Uri.parse('$apiBaseUrl/attendance/$endpoint');
      final payload = {
        'employeeId': empBizId.isNotEmpty ? empBizId : scannedValue,
        'method': 'qr',
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

      final success = (resp.statusCode == 200 || resp.statusCode == 201) &&
          (body?['success'] == true || body?['status'] == 'success' || body == null);

      if (success) {
        setState(() {
          _qrStatus = _isQrCheckoutPhase
              ? 'Đã check-out cho $empName'
              : 'Đã check-in cho $empName';
          _qrStatusColor = Colors.green;
        });
        await _loadAttendanceHistory();
      } else {
        final msg = body?['message']?.toString() ?? 'Điểm danh thất bại';
        setState(() {
          _qrStatus = msg;
          _qrStatusColor = Colors.red;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _qrStatus = 'Lỗi điểm danh: $e';
          _qrStatusColor = Colors.red;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingQr = false);
      }
    }
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

  bool _matchesEmployeeSearch(Map<String, dynamic> emp, String query) {
    final q = query.toLowerCase();
    final name = (emp['fullName'] ?? emp['name'] ?? '').toString().toLowerCase();
    final code = _extractEmployeeBusinessId(emp).toLowerCase();
    return name.contains(q) || code.contains(q);
  }

  Future<void> _updateEmployee(
    String id,
    String name,
    String email,
    String position,
    String department,
  ) async {
    if (id.isEmpty || department.isEmpty) return;
    try {
      final payload = {
        'fullName': name,
        'role': 'employee',
        'position': position,
        'department': department,
      };
      if (email.isNotEmpty) payload['email'] = email;

      final response = await http.put(
        Uri.parse('$apiBaseUrl/employees/$id'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Cập nhật thành công')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: ${response.statusCode} - ${response.body}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _deleteEmployee(String id) async {
    if (id.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn xóa nhân viên này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
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
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Xóa thành công')));
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi: ${response.statusCode} - ${response.body}')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final headers = {'Authorization': 'Bearer ${widget.token}'};

      final responses = await Future.wait([
        http.get(Uri.parse('$apiBaseUrl/employees'), headers: headers),
        http.get(Uri.parse('$apiBaseUrl/departments'), headers: headers),
      ]);

      List<Map<String, dynamic>> employees = [];
      List<Map<String, dynamic>> departments = [];

      final empResp = responses[0];
      if (empResp.statusCode == 200) {
        final data = json.decode(empResp.body);
        if (data is List) {
          employees = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['data'] is List) {
          employees = List<Map<String, dynamic>>.from(data['data']);
        }
      }

      // Filter employees: only same department as manager and exclude admins
      final managerDept = _managerDeptId;
      final managerDeptCode = _managerDeptCode;
      employees = employees.where((emp) {
        final role = _extractRole(emp);
        if (role == 'admin') return false;
        // Bỏ qua chính quản lý đang đăng nhập
        final empId = _extractEmployeeId(emp);
        final selfId = _extractEmployeeId(widget.profile ?? {});
        if (selfId.isNotEmpty && empId.isNotEmpty && empId == selfId) return false;
        if ((managerDept == null || managerDept.isEmpty) && (managerDeptCode == null || managerDeptCode.isEmpty)) {
          return false;
        }
        final empDeptId = _extractDeptId(emp['department']);
        final empDeptCode = _extractDeptCode(emp['department']);
        final matchId = managerDept != null && managerDept.isNotEmpty && empDeptId == managerDept;
        final matchCode = managerDeptCode != null && managerDeptCode.isNotEmpty && empDeptCode == managerDeptCode;
        return matchId || matchCode;
      }).toList();

      final deptResp = responses[1];
      if (deptResp.statusCode == 200) {
        final data = json.decode(deptResp.body);
        if (data is List) {
          departments = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['data'] is List) {
          departments = List<Map<String, dynamic>>.from(data['data']);
        }
      }

      // Enrich manager department info using loaded departments
      if (departments.isNotEmpty) {
        Map<String, dynamic>? best;
        if (_managerDeptId != null && _managerDeptId!.isNotEmpty) {
          best = departments.firstWhere(
            (d) => _extractDeptId(d) == _managerDeptId,
            orElse: () => <String, dynamic>{},
          );
        }
        if ((best == null || best.isEmpty) && _managerDeptCode != null && _managerDeptCode!.isNotEmpty) {
          best = departments.firstWhere(
            (d) => _extractDeptCode(d) == _managerDeptCode,
            orElse: () => <String, dynamic>{},
          );
        }
        if (best != null && best.isNotEmpty) {
          _managerDeptName ??= _extractDeptName(best);
          _managerDeptCode ??= _extractDeptCode(best);
          _managerDeptId ??= _extractDeptId(best);
        }
      }

      if (!mounted) return;
      setState(() {
        _employees = employees;
        _selectedAttendanceEmpId = _syncSelectedAttendanceEmployee(employees);
        _isLoading = false;
      });

      // Load history after employees so we know manager dept and employee list
      await _loadAttendanceHistory();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    }
  }

  String? _syncSelectedAttendanceEmployee(List<Map<String, dynamic>> employees) {
    // Keep current selection if still present; otherwise pick the first employee business id
    final current = _selectedAttendanceEmpId;
    final exists = current != null && employees.any((e) => _extractEmployeeBusinessId(e) == current);
    if (exists) return current;
    if (employees.isEmpty) return null;
    return _extractEmployeeBusinessId(employees.first);
  }

  Future<void> _pickHistoryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _historyDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _historyDate = picked);
      await _loadAttendanceHistory();
    }
  }

  Future<void> _loadAttendanceHistory() async {
    final deptId = _managerDeptId;
    setState(() {
      _isLoadingHistory = true;
      _attendanceRecords = [];
    });
    try {
      final date = _formatDateParam(_historyDate);
      final query = {
        'startDate': date,
        'endDate': date,
        if (deptId != null && deptId.isNotEmpty) 'departmentId': deptId,
      };
      final uri = Uri.parse('$apiBaseUrl/attendance').replace(queryParameters: query);
      final resp = await http.get(uri, headers: {'Authorization': 'Bearer ${widget.token}'});
      List<Map<String, dynamic>> records = [];
      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        if (decoded is List) {
          records = List<Map<String, dynamic>>.from(decoded);
        } else if (decoded is Map && decoded['data'] is List) {
          records = List<Map<String, dynamic>>.from(decoded['data']);
        }
      }
      if (mounted) {
        setState(() => _attendanceRecords = records);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải lịch sử: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  @override
  void dispose() {
    _qrController.dispose();
    super.dispose();
  }
}

class _EmpDailyStatus {
  final String label;
  final String? timeLabel;
  final String? methodLabel;

  _EmpDailyStatus({required this.label, this.timeLabel, this.methodLabel});
}

