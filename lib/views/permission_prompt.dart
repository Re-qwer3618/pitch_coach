import 'package:flutter/material.dart';

import '../services/permission_service.dart';

/// 권한 거부 시 안내. 영구 거부면 설정 앱으로 안내한다.
Future<void> showPermissionDeniedDialog(BuildContext context, MicPermission permission) {
  final permanent = permission == MicPermission.permanentlyDenied;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.mic_off_rounded),
      title: const Text('마이크 권한이 필요해요'),
      content: Text(permanent
          ? '음정을 분석하려면 마이크가 필요해요.\n설정 > 권한에서 마이크를 허용해 주세요.'
          : '음정을 분석하려면 마이크 권한을 허용해 주세요.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
        if (permanent)
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              PermissionService.openSettings();
            },
            child: const Text('설정 열기'),
          ),
      ],
    ),
  );
}
