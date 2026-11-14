import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

const _minFreeStorageGB = 3.5;
const _minTotalRAMGB = 4.0;
const _minAvailRAMGB = 2.0;
const _channelName = 'com.example.finazaap/device_info';

class DeviceCapabilityResult {
  final double freeStorageGB;
  final double? totalRAMGB;
  final double? availRAMGB;
  final bool lowMemory;
  final bool isArm64;
  final int? androidApiLevel;

  const DeviceCapabilityResult({
    required this.freeStorageGB,
    required this.totalRAMGB,
    this.availRAMGB,
    this.lowMemory = false,
    required this.isArm64,
    this.androidApiLevel,
  });

  bool get hasEnoughStorage => freeStorageGB >= _minFreeStorageGB;
  bool get hasEnoughRAM => totalRAMGB == null || totalRAMGB! >= _minTotalRAMGB;
  bool get hasEnoughAvailableRAM =>
      !lowMemory && (availRAMGB == null || availRAMGB! >= _minAvailRAMGB);
  bool get hasCompatProcessor => isArm64;
  bool get canRunModel =>
      hasEnoughStorage && hasEnoughRAM && hasEnoughAvailableRAM && hasCompatProcessor;
}

class DeviceCapabilityService {
  static const _channel = MethodChannel(_channelName);

  static Future<DeviceCapabilityResult> check() async {
    double freeMB = 0.0;
    try {
      if (Platform.isAndroid) {
        freeMB = await _channel.invokeMethod<double>('getFreeDiskSpace') ?? 0.0;
      } else {
        // En iOS u otras plataformas asumimos espacio suficiente para simular
        freeMB = 10.0 * 1024.0; // 10 GB
      }
    } catch (_) {
      // Fallback
      freeMB = 5.0 * 1024.0;
    }

    double? ramGB;
    double? availRAMGB;
    bool lowMemory = false;
    try {
      final infoMap =
          await _channel.invokeMapMethod<String, dynamic>('getDeviceMemoryInfo');
      if (infoMap != null) {
        final totalBytes = (infoMap['totalMem'] as num?)?.toDouble();
        final availBytes = (infoMap['availMem'] as num?)?.toDouble();
        if (totalBytes != null && totalBytes > 0) {
          ramGB = totalBytes / 1e9;
        }
        if (availBytes != null && availBytes >= 0) {
          availRAMGB = availBytes / 1e9;
        }
        lowMemory = infoMap['lowMemory'] == true;
      }
    } catch (_) {
      try {
        final bytes = await _channel.invokeMethod<int>('getTotalRam');
        if (bytes != null && bytes > 0) {
          ramGB = bytes / 1e9;
        }
      } catch (_) {}
    }

    bool isArm64 = false;
    int? apiLevel;
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      isArm64 = info.supportedAbis.contains('arm64-v8a');
      apiLevel = info.version.sdkInt;
    } else if (Platform.isIOS) {
      isArm64 = true;
    }

    return DeviceCapabilityResult(
      freeStorageGB: freeMB / 1024,
      totalRAMGB: ramGB,
      availRAMGB: availRAMGB,
      lowMemory: lowMemory,
      isArm64: isArm64,
      androidApiLevel: apiLevel,
    );
  }
}
