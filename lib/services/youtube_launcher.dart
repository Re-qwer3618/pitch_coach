import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 유튜브 앱(없으면 브라우저)으로 연다. 앱 안에서 재생하지 않으므로 인터넷 권한이 필요 없다.
Future<void> openYoutube(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  bool opened;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened) messenger.showSnackBar(const SnackBar(content: Text('유튜브를 열지 못했어요')));
}
