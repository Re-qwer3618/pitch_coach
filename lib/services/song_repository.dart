import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/song.dart';

/// 사용자가 추가한 노래를 앱 문서 폴더의 JSON 파일에 저장한다.
class SongRepository extends ChangeNotifier {
  SongRepository._();

  static final SongRepository instance = SongRepository._();

  final List<Song> _custom = [];
  bool _loaded = false;

  List<Song> get customSongs => List.unmodifiable(_custom);

  static String newId() => 'custom_${DateTime.now().microsecondsSinceEpoch}';

  Future<File?> _file() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/custom_songs.json');
    } catch (_) {
      return null; // 플러그인이 없는 환경(테스트)
    }
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final file = await _file();
    if (file == null || !await file.exists()) return;
    try {
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      for (final item in list) {
        try {
          _custom.add(Song.fromJson(item as Map<String, dynamic>));
        } catch (e) {
          debugPrint('저장된 노래를 읽지 못했어요: $e');
        }
      }
    } catch (e) {
      debugPrint('노래 목록 파일이 손상됐어요: $e');
    }
    notifyListeners();
  }

  /// 같은 id가 있으면 바꾸고, 없으면 추가한다.
  Future<void> save(Song song) async {
    final index = _custom.indexWhere((s) => s.id == song.id);
    if (index >= 0) {
      _custom[index] = song;
    } else {
      _custom.add(song);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> delete(String id) async {
    _custom.removeWhere((s) => s.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final file = await _file();
    if (file == null) return;
    await file.writeAsString(jsonEncode(_custom.map((s) => s.toJson()).toList()), flush: true);
  }
}
