import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nfc_manager/nfc_manager.dart';

import 'login_page.dart';

void main() {
  runApp(const NfcWriterApp());
}

class NfcWriterApp extends StatefulWidget {
  const NfcWriterApp({super.key});

  @override
  State<NfcWriterApp> createState() => _NfcWriterAppState();
}

class _NfcWriterAppState extends State<NfcWriterApp> {
  String? _token;
  String? _baseUrl;
  String? _userEmail;
  String? _role;

  void _handleLogin({required String baseUrl, required String token, String? email, String? role}) {
    setState(() {
      _baseUrl = baseUrl;
      _token = token;
      _userEmail = email;
      _role = role;
    });
  }

  void _handleLogout() {
    setState(() {
      _token = null;
      _baseUrl = null;
      _userEmail = null;
      _role = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo));
    return MaterialApp(
      title: 'NFC Writer',
      theme: theme,
      home: _token == null
          ? LoginPage(onLogin: _handleLogin)
          : NfcWriterPage(
              baseUrl: _baseUrl!,
              token: _token!,
              userEmail: _userEmail,
              role: _role,
              onLogout: _handleLogout,
            ),
    );
  }
}

class NfcWriterPage extends StatefulWidget {
  const NfcWriterPage({super.key, required this.baseUrl, required this.token, this.userEmail, this.role, required this.onLogout});

  final String baseUrl;
  final String token;
  final String? userEmail;
  final String? role;
  final VoidCallback onLogout;

  @override
  State<NfcWriterPage> createState() => _NfcWriterPageState();
}

class _NfcWriterPageState extends State<NfcWriterPage> {
  final TextEditingController _textController = TextEditingController();
  bool _nfcAvailable = true;
  bool _isWriting = false;
  bool _loadingEmployees = false;
  bool _onlyMissingNfc = true;
  bool _onlyNewEmployees = false;
  String? _selectedDeptId;
  String _status = 'Chọn nhân viên và chạm thẻ để ghi.';
  String? _lastTagUid;
  String? _selectedEmployeeId;
  List<_Employee> _employees = const [];
  Map<String, String> _deptOptions = const {};

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  @override
  void dispose() {
    _textController.dispose();
    NfcManager.instance.stopSession();
    super.dispose();
  }

  Future<void> _fetchEmployees() async {
    setState(() {
      _loadingEmployees = true;
      _status = 'Đang tải danh sách nhân viên...';
    });

    try {
      final uri = Uri.parse(widget.baseUrl.endsWith('/') ? '${widget.baseUrl}employees' : '${widget.baseUrl}/employees');
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer ${widget.token}',
      }).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        setState(() {
          _status = 'Tải nhân viên thất bại: ${resp.statusCode}';
        });
        return;
      }

      final data = jsonDecode(resp.body);
      final list = (data is Map ? data['data'] : null) as List<dynamic>?;
      if (list == null) {
        setState(() => _status = 'Phản hồi không hợp lệ từ backend.');
        return;
      }

      final employees = list
          .map((e) => _Employee.fromJson(e as Map<String, dynamic>))
          .toList();

      final depts = <String, String>{};
      for (final e in employees) {
        if (e.departmentId != null && e.departmentId!.isNotEmpty) {
          final name = (e.departmentName ?? e.departmentId)!;
          depts[e.departmentId!] = name;
        }
      }

      setState(() {
        _employees = employees;
        _status = 'Đã tải ${employees.length} nhân viên.';
        _selectedEmployeeId = null;
        // keep current dept filter if still present
        if (_selectedDeptId != null && !depts.keys.contains(_selectedDeptId)) {
          _selectedDeptId = null;
        }
        _deptOptions = depts;
      });
    } catch (e) {
      setState(() => _status = 'Lỗi tải nhân viên: $e');
    } finally {
      setState(() => _loadingEmployees = false);
    }
  }

  List<_Employee> get _filteredEmployees {
    final now = DateTime.now();
    return _employees.where((e) {
      if (_onlyMissingNfc && (e.nfcUid != null && e.nfcUid!.isNotEmpty)) {
        return false;
      }

      if (_selectedDeptId != null && _selectedDeptId!.isNotEmpty) {
        if (e.departmentId == null || e.departmentId != _selectedDeptId) return false;
      }

      if (_onlyNewEmployees) {
        final created = e.createdAt;
        if (created == null) return false;
        if (now.difference(created).inDays > 7) return false;
      }

      return true;
    }).toList();
  }

  Widget _buildFilterCheckbox({
    required bool value,
    required String label,
    required bool disabled,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: disabled ? null : onChanged,
        ),
        Text(label),
      ],
    );
  }

  Future<void> _checkAvailability() async {
    try {
      final available = await NfcManager.instance.isAvailable();
      if (mounted) setState(() => _nfcAvailable = available);
    } catch (_) {
      if (mounted) setState(() => _nfcAvailable = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onLogout();
    }
  }

  Future<void> _writeToTag() async {
    final selected = _employees.firstWhere(
      (e) => e.id == _selectedEmployeeId,
      orElse: () => _Employee.empty,
    );
    if (selected == _Employee.empty) {
      setState(() => _status = 'Chọn nhân viên cần ghi thẻ.');
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _status = 'Nội dung trống, hãy nhập mã hoặc thông điệp.');
      return;
    }
    if (_isWriting) return;

    setState(() {
      _isWriting = true;
      _status = 'Đang chờ thẻ... chạm thẻ vào mặt sau thiết bị.';
    });

    final available = await NfcManager.instance.isAvailable();
    if (!available) {
      if (mounted) {
        setState(() {
          _nfcAvailable = false;
          _isWriting = false;
          _status = 'Thiết bị không hỗ trợ hoặc chưa bật NFC.';
        });
      }
      return;
    }

    try {
      await NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
        try {
          final uid = _tagIdFromNfcTag(tag);
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            setState(() => _status = 'Thẻ không hỗ trợ định dạng NDEF.');
            await NfcManager.instance.stopSession(errorMessage: 'Tag is not NDEF.');
            return;
          }
          if (!ndef.isWritable) {
            setState(() => _status = 'Thẻ hiện tại không cho phép ghi.');
            await NfcManager.instance.stopSession(errorMessage: 'Tag is read-only.');
            return;
          }

          final message = NdefMessage([NdefRecord.createText(text)]);
          await ndef.write(message);

          await _linkEmployee(uid, selected);
          await NfcManager.instance.stopSession();
        } catch (e) {
          if (mounted) {
            setState(() => _status = 'Lỗi ghi thẻ: $e');
          }
          await NfcManager.instance.stopSession(errorMessage: 'Write failed');
        } finally {
          if (mounted) setState(() => _isWriting = false);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Không khởi động được phiên NFC: $e';
          _isWriting = false;
        });
      }
      await NfcManager.instance.stopSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredEmployees = _filteredEmployees;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ghi thẻ NFC'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _checkAvailability,
            icon: const Icon(Icons.refresh),
            tooltip: 'Kiểm tra lại NFC',
          ),
          IconButton(
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.nfc,
                          color: _nfcAvailable
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                          size: 32,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _nfcAvailable ? 'NFC sẵn sàng' : 'NFC không khả dụng',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          onPressed: _checkAvailability,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Kiểm tra NFC',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              minimumSize: const Size(0, 40),
                            ),
                            onPressed: _loadingEmployees ? null : _fetchEmployees,
                            icon: const Icon(Icons.cloud_download),
                            label: Text(_loadingEmployees ? 'Đang tải...' : 'Tải nhân viên'),
                          ),
                          const SizedBox(width: 12),
                          _buildFilterCheckbox(
                            value: _onlyMissingNfc,
                            label: 'Chưa có NFC',
                            disabled: _loadingEmployees || _isWriting,
                            onChanged: (v) => setState(() => _onlyMissingNfc = v ?? true),
                          ),
                          const SizedBox(width: 6),
                          _buildFilterCheckbox(
                            value: _onlyNewEmployees,
                            label: 'Mới (7 ngày)',
                            disabled: _loadingEmployees || _isWriting,
                            onChanged: (v) => setState(() => _onlyNewEmployees = v ?? false),
                          ),
                          if (_deptOptions.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 200,
                              child: DropdownButtonFormField<String?>(
                                value: _selectedDeptId,
                                decoration: const InputDecoration(
                                  labelText: 'Phòng ban',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Tất cả'),
                                  ),
                                  ..._deptOptions.entries
                                      .map((e) => DropdownMenuItem<String?>(
                                            value: e.key,
                                            child: Text(e.value),
                                          ))
                                      .toList(),
                                ],
                                onChanged: _loadingEmployees || _isWriting
                                    ? null
                                    : (v) => setState(() => _selectedDeptId = v),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: filteredEmployees.isEmpty
                          ? const Center(child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('Chưa có dữ liệu nhân viên.'),
                            ))
                          : SizedBox(
                              height: 260,
                              child: ListView(
                                children: filteredEmployees
                                  .map(
                                      (e) => RadioListTile<String>(
                                        value: e.id,
                                        groupValue: _selectedEmployeeId,
                                        onChanged: _isWriting
                                            ? null
                                            : (v) {
                                                setState(() {
                                                  _selectedEmployeeId = v;
                                                  final content = (e.nfcUid != null && e.nfcUid!.isNotEmpty)
                                                      ? e.nfcUid!
                                                      : '';
                                                  _textController.text = content;
                                                });
                                              },
                                        title: Text(e.fullName, style: theme.textTheme.titleMedium),
                                        subtitle: Text(
                                          e.nfcUid == null || e.nfcUid!.isEmpty
                                              ? 'Chưa gán NFC'
                                              : 'Đã gán NFC',
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 56,
                      child: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          labelText: 'Nội dung sắp ghi lên thẻ NFC',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        maxLines: 1,
                        readOnly: true,
                        enableInteractiveSelection: false,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isWriting ? null : _writeToTag,
                        icon: const Icon(Icons.save_alt),
                        label: Text(_isWriting ? 'Đang chờ thẻ...' : 'Ghi thẻ'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_lastTagUid != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'UID mới nhất: $_lastTagUid (dùng để liên kết nhân viên trong backend)',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _status,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lưu ý: chỉ ghi được thẻ hỗ trợ NDEF và chưa bị khóa ghi.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        ),
        ),
      ),
    );
  }

  Future<void> _linkEmployee(String? uid, _Employee employee) async {
    if (uid == null) {
      if (mounted) {
        setState(() => _status = 'Không đọc được UID, nhưng đã ghi NDEF.');
      }
      return;
    }

    final base = widget.baseUrl;
    final token = widget.token;

    try {
      final uri = Uri.parse(base.endsWith('/') ? '${base}employees/${employee.id}' : '$base/employees/${employee.id}');
      final resp = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'nfcUid': uid}),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        if (mounted) {
          setState(() {
            _status = 'Ghi thành công và đã gán UID $uid cho ${employee.employeeId}.';
            _lastTagUid = uid;
            _employees = _employees
                .map((e) => e.id == employee.id ? e.copyWith(nfcUid: uid) : e)
                .toList();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _status = 'Ghi xong nhưng gán backend lỗi: ${resp.statusCode}';
            _lastTagUid = uid;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Ghi xong nhưng gán backend lỗi: $e';
          _lastTagUid = uid;
        });
      }
    }
  }

  String? _tagIdFromNfcTag(NfcTag tag) {
    try {
      final data = tag.data;
      if (data is Map) {
        final direct = data['identifier'];
        if (direct is Uint8List && direct.isNotEmpty) {
          return _bytesToHex(direct);
        }

        for (final value in data.values) {
          if (value is Map) {
            final id = value['identifier'];
            if (id is Uint8List && id.isNotEmpty) {
              return _bytesToHex(id);
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  String _bytesToHex(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString().toUpperCase();
  }
}

class _Employee {
  final String id;
  final String employeeId;
  final String fullName;
  final String? nfcUid;
  final String? departmentId;
  final String? departmentName;
  final DateTime? createdAt;

  const _Employee({
    required this.id,
    required this.employeeId,
    required this.fullName,
    this.nfcUid,
    this.departmentId,
    this.departmentName,
    this.createdAt,
  });

  static const empty = _Employee(id: '', employeeId: '', fullName: '');

  _Employee copyWith({String? nfcUid}) {
    return _Employee(
      id: id,
      employeeId: employeeId,
      fullName: fullName,
      nfcUid: nfcUid ?? this.nfcUid,
      departmentId: departmentId,
      departmentName: departmentName,
      createdAt: createdAt,
    );
  }

  factory _Employee.fromJson(Map<String, dynamic> json) {
    String? deptId;
    String? deptName;
    final dept = json['department'];
    if (dept is Map<String, dynamic>) {
      deptId = (dept['_id'] ?? dept['id'])?.toString();
      deptName = dept['name']?.toString();
    } else if (dept is String) {
      deptId = dept;
    }

    deptId ??= json['departmentId']?.toString();
    deptName ??= json['departmentName']?.toString();

    DateTime? created;
    final createdRaw = json['createdAt'];
    if (createdRaw is String) {
      created = DateTime.tryParse(createdRaw);
    }

    return _Employee(
      id: (json['_id'] ?? '').toString(),
      employeeId: (json['employeeId'] ?? '').toString(),
      fullName: (json['fullName'] ?? '').toString(),
      nfcUid: json['nfcUid']?.toString(),
      departmentId: deptId,
      departmentName: deptName,
      createdAt: created,
    );
  }
}
