import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class Esp32Service {
  static const String serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String charUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';

  final _devicesController = StreamController<List<Esp32Device>>.broadcast();
  final _dataController = StreamController<SensorData>.broadcast();
  final List<Esp32Device> _discoveredDevices = [];
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _scanSub;

  Stream<List<Esp32Device>> get devicesStream => _devicesController.stream;
  Stream<SensorData> get dataStream => _dataController.stream;
  List<Esp32Device> get discoveredDevices => List.unmodifiable(_discoveredDevices);
  bool get isConnected => _connectedDevice != null;

  Future<bool> get isBluetoothOn async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    _discoveredDevices.clear();
    _devicesController.add([]);

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = r.device.platformName;
        if (name.isEmpty) continue;

        final exists = _discoveredDevices.any(
            (d) => d.remoteId == r.device.remoteId.str);
        if (!exists) {
          _discoveredDevices.add(Esp32Device(
            name: name,
            remoteId: r.device.remoteId.str,
            rssi: r.rssi,
            device: r.device,
          ));
          _devicesController.add(List.of(_discoveredDevices));
        }
      }
    });

    await FlutterBluePlus.startScan(timeout: timeout);
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _scanSub?.cancel();
  }

  Future<bool> connect(Esp32Device esp32) async {
    try {
      await esp32.device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = esp32.device;

      final services = await esp32.device.discoverServices();
      for (final service in services) {
        if (service.uuid.toString() == serviceUuid) {
          for (final char in service.characteristics) {
            if (char.uuid.toString() == charUuid && char.properties.notify) {
              await char.setNotifyValue(true);
              char.onValueReceived.listen((value) {
                _parseAndEmit(utf8.decode(value));
              });
            }
          }
        }
      }
      return true;
    } catch (e) {
      _connectedDevice = null;
      return false;
    }
  }

  void _parseAndEmit(String raw) {
    try {
      final data = jsonDecode(raw);
      final sensorData = SensorData(
        temperature: (data['temp'] as num?)?.toDouble(),
        pressure: (data['psi'] as num?)?.toDouble(),
        timestamp: DateTime.now(),
        raw: raw,
      );
      _dataController.add(sensorData);
    } catch (_) {
      // Try CSV format: temp,pressure
      final parts = raw.split(',');
      if (parts.length >= 2) {
        final temp = double.tryParse(parts[0].trim());
        final pres = double.tryParse(parts[1].trim());
        if (temp != null && pres != null) {
          _dataController.add(SensorData(
            temperature: temp,
            pressure: pres,
            timestamp: DateTime.now(),
            raw: raw,
          ));
        }
      }
    }
  }

  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
  }

  void dispose() {
    stopScan();
    disconnect();
    _devicesController.close();
    _dataController.close();
  }
}

class Esp32Device {
  final String name;
  final String remoteId;
  final int rssi;
  final BluetoothDevice device;

  const Esp32Device({
    required this.name,
    required this.remoteId,
    required this.rssi,
    required this.device,
  });

  int get signalStrength {
    if (rssi >= -50) return 3;
    if (rssi >= -70) return 2;
    return 1;
  }
}

class SensorData {
  final double? temperature;
  final double? pressure;
  final DateTime timestamp;
  final String raw;

  const SensorData({
    this.temperature,
    this.pressure,
    required this.timestamp,
    required this.raw,
  });

  bool get isComplete => temperature != null && pressure != null;
}
