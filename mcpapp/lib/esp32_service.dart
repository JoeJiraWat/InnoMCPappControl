import 'dart:async';
import 'dart:convert';
import 'dart:math'; // เพิ่ม import นี้
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:math';

enum ConnectionStatus { disconnected, connecting, connected, error }

class Esp32Service extends ChangeNotifier {
  static const String esp32Ip = '192.168.4.1'; // Updated IP for local server
  ConnectionStatus _status = ConnectionStatus.disconnected;
  Timer? _statusTimer;

  double _temperature = 0; // Updated default temperature to 26
  double _humidity = 0; // Updated default humidity to 24
  Timer? _mockTimer;
  bool _isRelay1On = false;
  bool _isRelay2On = false;
  String? _lastError;

  ConnectionStatus get status => _status;
  double get temperature => _temperature;
  double get humidity => _humidity;
  bool get isRelay1On => _isRelay1On;
  bool get isRelay2On => _isRelay2On;
  String get lastError => _lastError ?? '';

  Future<void> connect() async {
    if (_status == ConnectionStatus.connecting ||
        _status == ConnectionStatus.connected) {
      print('Already connecting or connected.');
      return;
    }

    _setStatus(ConnectionStatus.connecting);
    print('Attempting to connect to ESP32 at $esp32Ip');

    try {
      final response = await http
          .get(Uri.parse('http://$esp32Ip/connect'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        print('Connection successful.');
        _lastError = '';
        _setStatus(ConnectionStatus.connected);
        _startStatusPolling();
        await _checkStatus();
        _stopMockTemperature();
      } else {
        print('Failed to connect. Response code: ${response.statusCode}');
        _lastError = 'Bad response ${response.statusCode}';
        _setStatus(ConnectionStatus.error);
        _startMockTemperature();
      }
    } catch (e) {
      print('Connection error: $e');
      _lastError = e.toString();
      _setStatus(ConnectionStatus.error);
      _startMockTemperature();
    }
  }

  void disconnect() {
    _statusTimer?.cancel();
    _setStatus(ConnectionStatus.disconnected);
    // Reset values on disconnect
    _isRelay1On = false;
    _isRelay2On = false;
    _temperature = 0.0;
    _humidity = 0.0;
    _startMockTemperature();
    notifyListeners();
  }

  void _startMockTemperature() {
    _mockTimer?.cancel();
    double t = 0;
    _mockTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      t += 0.5;
      // อุณหภูมิ mock: 26 + sin wave + random noise
      _temperature = 26 + 2 * sin(t) + Random().nextDouble() * 0.5;
      // ความชื้น mock: 24 + sin wave + random noise
      _humidity = 24 + 3 * sin(t / 1.5) + Random().nextDouble() * 1.0;
      notifyListeners();
    });
  }

  void _stopMockTemperature() {
    _mockTimer?.cancel();
    _mockTimer = null;
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkStatus(),
    );
  }

  Future<void> _checkStatus() async {
    if (_status != ConnectionStatus.connected) {
      print('Not connected. Stopping status polling.');
      _statusTimer?.cancel();
      // mock ค่าอุณหภูมิและความชื้นเมื่อไม่ได้เชื่อมต่อ
      final rnd = Random();
      _temperature = 24 + rnd.nextDouble() * 6; // 24-30°C
      _humidity = 20 + rnd.nextDouble() * 10; // 20-30%
      notifyListeners();
      return;
    }

    try {
      final response = await http
          .get(Uri.parse('http://$esp32Ip/status'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        print('Status check successful.');
        _lastError = '';
        final data = jsonDecode(response.body);
        _temperature = (data['temperature'] as num).toDouble();
        _humidity = (data['humidity'] as num).toDouble();
        _isRelay1On = data['relay1'] as bool? ?? false;
        _isRelay2On = data['relay2'] as bool? ?? false;
        notifyListeners();
      } else {
        print('Status check failed. Response code: ${response.statusCode}');
        try {
          final errorData = jsonDecode(response.body);
          _lastError = errorData['error'] ?? 'Unknown ESP32 error';
        } catch (_) {
          _lastError = 'Status error: ${response.statusCode}';
        }
        // mock ค่าอุณหภูมิและความชื้นเมื่อ response ไม่สำเร็จ
        final rnd = Random();
        _temperature = 24 + rnd.nextDouble() * 6;
        _humidity = 20 + rnd.nextDouble() * 10;
        notifyListeners();
        _setStatus(ConnectionStatus.error);
        _statusTimer?.cancel();
      }
    } catch (e) {
      print('Error during status check: $e');
      _lastError = 'Connection lost';
      // mock ค่าอุณหภูมิและความชื้นเมื่อเกิด exception
      final rnd = Random();
      _temperature = 24 + rnd.nextDouble() * 6;
      _humidity = 20 + rnd.nextDouble() * 10;
      notifyListeners();
      _setStatus(ConnectionStatus.error);
      _statusTimer?.cancel();
    }
  }

  Future<void> updateRelayState(int relayNumber, bool isOn) async {
    if (_status != ConnectionStatus.connected) return;

    final action = isOn ? 'on' : 'off';
    try {
      final response = await http
          .get(Uri.parse('http://$esp32Ip/relay/$relayNumber/$action'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        if (relayNumber == 1) {
          _isRelay1On = isOn;
        } else if (relayNumber == 2) {
          _isRelay2On = isOn;
        }
        notifyListeners();
      }
    } catch (e) {
      _lastError = e.toString();
      print('Error updating relay state: $e');
      disconnect();
    }
  }

  void _setStatus(ConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      if (newStatus == ConnectionStatus.connected) {
        _stopMockTemperature();
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _mockTimer?.cancel();
    super.dispose();
  }
}
