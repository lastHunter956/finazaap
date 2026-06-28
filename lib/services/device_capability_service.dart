import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:disk_space/disk_space.dart';
import 'package:flutter/services.dart';

const _minFreeStorageGB = 3.5;
const _minTotalRAMGB = 4.0;
const _channelName = 'com.example.finazaap/device_info';

class DeviceCapabilityResult {
  final double freeStorageGB;
  final double? totalRAMGB;
  final bool isArm64;
  final int? androidApiLevel;

  const DeviceCapabilityResult({
    required this.freeStorageGB,
    required this.totalRAMGB,
    required this.isArm64,
    this.androidApiLevel,
  });

  bool get hasEnoughStorage => freeStorageGB >= _minFreeStorageGB;
  bool get hasEnoughRAM => totalRAMGB == null || totalRAMGB! >= _minTotalRAMGB;
  bool get hasCompatProcessor => isArm64;
  bool get canRunModel => hasEnoughStorage && hasEnoughRAM && hasCompatProcessor;
}

class DeviceCapabilityService {
  static const _channel = MethodChannel(_channelName);

  static Future<DeviceCapabilityResult> check() async {
    final freeMB = await DiskSpace.getFreeDiskSpace ?? 0.0;

    double? ramGB;
    try {
      final bytes = await _channel.invokeMethod<int>('getTotalRam');
      ramGB = (bytes ?? 0) / 1e9;
    } catch (_) {}

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
      isArm64: isArm64,
      androidApiLevel: apiLevel,
    );
  }
}
