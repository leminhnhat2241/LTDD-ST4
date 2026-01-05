import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:nfc_manager/nfc_manager.dart';

import '../main.dart' show apiBaseUrl;

enum AttendanceMethod { qr, nfc }

class DeviceHome extends StatefulWidget {
  const DeviceHome({super.key, required this.profile, required this.token});
  final Map<String, dynamic>? profile;
  final String token;

  @override
  State<DeviceHome> createState() => _DeviceHomeState();
}

class _DeviceHomeState extends State<DeviceHome> {
  MobileScannerController? scannerController;

  AttendanceMethod _method = AttendanceMethod.qr;
  bool _nfcAvailable = false;
  bool _nfcSessionActive = false;

  bool isCheckoutPhase = false; // false: check-in; true: check-out
  bool isProcessing = false;
  String? statusMessage;

  String? _lastSuccessEmployeeId;
  DateTime? _lastSuccessTime;

  final AudioPlayer _playerSuccess = AudioPlayer(playerId: 'success_player');
  final AudioPlayer _playerError = AudioPlayer(playerId: 'error_player');
  Uint8List? _successTone;
  Uint8List? _errorTone;

  final FlutterTts _tts = FlutterTts();

  DateTime _nowVN() => DateTime.now().toUtc().add(const Duration(hours: 7));

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Uint8List _generateTone({
    required double freqHz,
    required int durationMs,
    int sampleRate = 8000,
  }) {
    final samples = (sampleRate * durationMs / 1000).round();
    final dataSize = samples * 2; // 16-bit mono
    final totalSize = 36 + dataSize;
    final bd = BytesBuilder();

    void writeString(String s) => bd.add(s.codeUnits);
    void writeUint32(int v) {
      final b = ByteData(4)..setUint32(0, v, Endian.little);
      bd.add(b.buffer.asUint8List());
    }

    void writeUint16(int v) {
      final b = ByteData(2)..setUint16(0, v, Endian.little);
      bd.add(b.buffer.asUint8List());
    }

    writeString('RIFF');
    writeUint32(totalSize);
    writeString('WAVE');
    writeString('fmt ');
    writeUint32(16); // PCM chunk size
    writeUint16(1); // PCM format
    writeUint16(1); // channels
    writeUint32(sampleRate);
    writeUint32(sampleRate * 2); // byte rate
    writeUint16(2); // block align
    writeUint16(16); // bits per sample
    writeString('data');
    writeUint32(dataSize);

    final amp = 30000;
    for (int i = 0; i < samples; i++) {
      final t = i / sampleRate;
      final sample = (amp * sin(2 * pi * freqHz * t)).round();
      final b = ByteData(2)..setInt16(0, sample, Endian.little);
      bd.add(b.buffer.asUint8List());
    }

    return bd.toBytes();
  }

  Future<void> _playSuccess() async {
    _successTone ??= _generateTone(freqHz: 880, durationMs: 180);
    await _playerSuccess.play(BytesSource(_successTone!));
  }

  Future<void> _playError() async {
    _errorTone ??= _generateTone(freqHz: 220, durationMs: 250);
    await _playerError.play(BytesSource(_errorTone!));
  }

  DateTime? _parseBackendTime(Map<String, dynamic>? data) {
    if (data == null) return null;
    final localTime = data['checkOutTimeLocal'] ?? data['checkInTimeLocal'];
    if (localTime is String && localTime.isNotEmpty) {
      return DateTime.tryParse(localTime);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _initScanner();
    _initTts();
    _checkNfcAvailability();
  }

  void _initScanner() {
    scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _playerSuccess.dispose();
    _playerError.dispose();
    _tts.stop();
    _stopNfcSession();
    scannerController?.dispose();
    super.dispose();
  }

  Future<void> _checkNfcAvailability() async {
    try {
      final available = await NfcManager.instance.isAvailable();
      if (mounted) setState(() => _nfcAvailable = available);
    } catch (_) {
      if (mounted) setState(() => _nfcAvailable = false);
    }
  }

  Future<void> _initTts() async {
    try {
      // Try Vietnamese; fall back if not available on device.
      final langResult = await _tts.setLanguage('vi-VN');
      if (langResult == null ||
          (langResult is String && langResult.toLowerCase().contains('fail'))) {
        await _tts.setLanguage('vi_VN');
      }
      await _tts.setSpeechRate(0.6);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      await _tts.setQueueMode(1); // 1 = queue, avoids overlap
    } catch (_) {
      // Ignore init errors; will silently fail on speak.
    }
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> _captureAndSend(
    String employeeId, {
    required String method,
  }) async {
    await _sendAttendance(employeeId, method: method, photoBase64: null);
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

  Future<void> _sendAttendance(
    String employeeId, {
    required String method,
    String? photoBase64,
  }) async {
    try {
      final endpoint = isCheckoutPhase ? 'check-out' : 'check-in';
      final uri = Uri.parse('$apiBaseUrl/attendance/$endpoint');

      final payload = {
        'method': method,
        'deviceCode': widget.profile?['code'],
      };

      if (method == 'nfc') {
        payload['nfcUid'] = employeeId;
      } else {
        payload['employeeId'] = employeeId;
      }

      if (photoBase64 != null) {
        payload['photoBase64'] = photoBase64;
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      };

      final resp = await http
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 10));

      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      } catch (e) {
        debugPrint('Error parsing attendance response: $e');
      }

      if (resp.statusCode == 200 && body?['success'] == true) {
        final Map<String, dynamic>? data =
            body?['data'] as Map<String, dynamic>?;
        final resolvedId =
            (employeeId.isNotEmpty
                    ? employeeId
                    : (body?['data']?['employeeId']?.toString() ?? ''))
                .trim();
        final resolvedTime = _parseBackendTime(data) ?? _nowVN();

        if (!mounted) return;
        setState(() {
          if (!isCheckoutPhase) {
            isCheckoutPhase = true;
            statusMessage =
                'Check-in thành công cho ${resolvedId.isNotEmpty ? resolvedId : employeeId}. Sẵn sàng check-out.';
          } else {
            statusMessage =
                'Check-out thành công cho ${resolvedId.isNotEmpty ? resolvedId : employeeId}. Tiếp tục check-out hoặc chuyển sang check-in thủ công.';
          }
          _lastSuccessEmployeeId = resolvedId.isNotEmpty
              ? resolvedId
              : employeeId;
          _lastSuccessTime = resolvedTime;
        });
        unawaited(_playSuccess());
        unawaited(_speak(statusMessage ?? ''));
      } else {
        if (!mounted) return;
        setState(() {
          final rawMsg = body?['message']?.toString();
          String localized;
          switch (rawMsg) {
            case 'Already checked in today':
              localized = 'Hôm nay đã check-in rồi.';
              break;
            case 'Already checked out today':
              localized = 'Hôm nay đã check-out rồi.';
              break;
            default:
              localized = rawMsg ?? 'Điểm danh thất bại.';
          }
          statusMessage = localized;
        });
        unawaited(_playError());
        unawaited(_speak(statusMessage ?? ''));
      }
    } catch (e) {
      debugPrint('Error sending attendance: $e');
      if (!mounted) return;
      setState(() {
        if (e.toString().contains('TimeoutException')) {
          statusMessage =
              'Lỗi: Không kết nối được server (timeout). Kiểm tra backend đã chạy chưa.';
        } else if (e.toString().contains('SocketException')) {
          statusMessage =
              'Lỗi: Không kết nối được server. Kiểm tra backend và địa chỉ API.';
        } else {
          statusMessage = 'Lỗi gửi dữ liệu: ${e.toString()}';
        }
      });
      unawaited(_playError());
      unawaited(_speak(statusMessage ?? ''));
    }
  }

  Future<void> _handleScan(String raw) async {
    if (_method != AttendanceMethod.qr) return;
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
      statusMessage = 'Đang xử lý...';
    });

    try {
      String? employeeId;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          employeeId = decoded['employeeId']?.toString();
        }
      } catch (_) {}

      employeeId ??= raw.trim();
      if (employeeId.isEmpty) {
        setState(() {
          statusMessage = 'QR không hợp lệ: không tìm thấy mã nhân viên.';
        });
        return;
      }

      await _captureAndSend(employeeId, method: 'qr');
    } catch (e) {
      setState(() {
        statusMessage = 'Lỗi: $e';
      });
      unawaited(_playError());
      unawaited(_speak(statusMessage ?? ''));
    } finally {
      isProcessing = false;
    }
  }

  Future<void> _handleNfcTag(NfcTag tag) async {
    if (_method != AttendanceMethod.nfc) return;
    if (isProcessing) return;

    final tagId = _tagIdFromNfcTag(tag);
    if (tagId == null) {
      if (!mounted) return;
      setState(() {
        statusMessage = 'Không đọc được mã thẻ. Thử lại.';
      });
      unawaited(_playError());
      unawaited(_speak(statusMessage ?? ''));
      await _restartNfcSession();
      return;
    }

    setState(() {
      isProcessing = true;
      statusMessage = 'Đang xử lý thẻ NFC...';
    });

    try {
      await _captureAndSend(tagId, method: 'nfc');
    } finally {
      isProcessing = false;
      await _restartNfcSession();
    }
  }

  Future<void> _startNfcSession() async {
    if (_method != AttendanceMethod.nfc) return;

    try {
      final available = await NfcManager.instance.isAvailable();
      if (!available) {
        if (!mounted) return;
        setState(() {
          _nfcAvailable = false;
          statusMessage = 'Thiết bị không hỗ trợ hoặc chưa bật NFC.';
          _nfcSessionActive = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _nfcAvailable = true;
      });

      if (_nfcSessionActive) return;

      await NfcManager.instance.startSession(
        onDiscovered: (tag) async {
          await _handleNfcTag(tag);
        },
        pollingOptions: const {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
      );

      if (!mounted) return;
      setState(() {
        _nfcSessionActive = true;
        statusMessage ??= 'Đặt thẻ NFC gần thiết bị.';
      });
    } catch (e) {
      debugPrint('Error starting NFC session: $e');
      if (!mounted) return;
      setState(() {
        statusMessage = 'Không thể khởi động NFC: $e';
        _nfcSessionActive = false;
      });
    }
  }

  Future<void> _stopNfcSession() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _nfcSessionActive = false;
      });
    }
  }

  Future<void> _restartNfcSession() async {
    await _stopNfcSession();
    if (_method == AttendanceMethod.nfc && mounted) {
      await Future.delayed(const Duration(milliseconds: 150));
      await _startNfcSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thiết bị - Điểm danh'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Phương thức',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('QR'),
                          selected: _method == AttendanceMethod.qr,
                          onSelected: (v) {
                            if (v) {
                              setState(() => _method = AttendanceMethod.qr);
                              scannerController?.start();
                              _stopNfcSession();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('NFC'),
                          selected: _method == AttendanceMethod.nfc,
                          onSelected: (v) {
                            if (v) {
                              setState(() => _method = AttendanceMethod.nfc);
                              scannerController?.stop();
                              _startNfcSession();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Chế độ',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Check-in'),
                          selected: !isCheckoutPhase,
                          onSelected: (v) {
                            if (v) setState(() => isCheckoutPhase = false);
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Check-out'),
                          selected: isCheckoutPhase,
                          onSelected: (v) {
                            if (v) setState(() => isCheckoutPhase = true);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            if (_method == AttendanceMethod.qr)
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: scannerController != null
                      ? MobileScanner(
                          controller: scannerController!,
                          onDetect: (capture) {
                            if (_method != AttendanceMethod.qr) return;
                            final barcodes = capture.barcodes;
                            if (barcodes.isNotEmpty) {
                              final raw = barcodes.first.rawValue;
                              if (raw != null) {
                                _handleScan(raw);
                              }
                            }
                          },
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.nfc,
                      size: 96,
                      color: _nfcAvailable
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      !_nfcAvailable
                          ? 'Thiết bị không hỗ trợ hoặc chưa bật NFC.'
                          : _nfcSessionActive
                              ? 'Giữ thẻ NFC gần thiết bị để điểm danh.'
                              : 'Đang khởi động NFC, hãy bật NFC nếu chưa bật.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (_nfcAvailable && !_nfcSessionActive)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (statusMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statusMessage!),
              ),
            if (_lastSuccessEmployeeId != null && _lastSuccessTime != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Đã điểm danh: $_lastSuccessEmployeeId lúc ${_formatTime(_lastSuccessTime!)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Thiết bị: ${widget.profile?['name'] ?? '-'}'),
                Text(isCheckoutPhase ? 'Chờ check-out' : 'Sẵn sàng check-in'),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Giờ VN: ${_nowVN().toLocal().toString().substring(11, 19)}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
