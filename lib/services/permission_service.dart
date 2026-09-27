import 'package:permission_handler/permission_handler.dart';

enum MicPermission { granted, denied, permanentlyDenied, unavailable }

/// iOS/Android 마이크 권한 처리.
class PermissionService {
  const PermissionService._();

  static Future<MicPermission> status() async {
    try {
      return _map(await Permission.microphone.status);
    } catch (_) {
      // 플러그인이 없는 환경(위젯 테스트 등)
      return MicPermission.unavailable;
    }
  }

  /// 권한이 없으면 시스템 권한 요청 다이얼로그를 띄운다.
  static Future<MicPermission> ensureMicrophone() async {
    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }
      return _map(status);
    } catch (_) {
      return MicPermission.unavailable;
    }
  }

  static Future<void> openSettings() => openAppSettings();

  static MicPermission _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return MicPermission.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return MicPermission.permanentlyDenied;
    }
    return MicPermission.denied;
  }
}
