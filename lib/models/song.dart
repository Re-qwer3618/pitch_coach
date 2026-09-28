import 'dart:math' as math;

import 'notation.dart';
import 'note.dart';

enum Difficulty {
  easy('쉬움'),
  medium('보통'),
  hard('어려움');

  const Difficulty(this.label);
  final String label;
}

/// 연습곡: 음표 · 박자 · 가사. 계이름 악보([notation])로부터 만든다.
class Song {
  Song._({
    required this.id,
    required this.title,
    required this.notes,
    required this.lyrics,
    required this.beats,
    required this.phraseBreaks,
    required this.tempoBpm,
    required this.category,
    required this.description,
    required this.isCustom,
    required this.notation,
    required this.lyricsText,
    required this.youtubeId,
  });

  /// 계이름 악보와 가사로 곡을 만든다. 악보 오류 시 [FormatException].
  factory Song.fromNotation({
    required String id,
    required String title,
    required String notation,
    String lyrics = '',
    double tempoBpm = 100,
    String category = customCategory,
    String description = '',
    bool isCustom = false,
    String? youtubeId,
  }) {
    final parsed = Notation.parse(notation);
    if (parsed.midis.isEmpty) throw const FormatException('음표를 하나 이상 입력해 주세요');
    final notes = parsed.midis.map(Note.new).toList(growable: false);
    final syllables = Notation.syllables(lyrics);
    return Song._(
      id: id,
      title: title,
      notes: notes,
      // 가사가 모자라면 계이름으로 채운다.
      lyrics: [for (var i = 0; i < notes.length; i++) i < syllables.length ? syllables[i] : notes[i].solfege],
      beats: parsed.beats,
      phraseBreaks: parsed.phraseBreaks,
      tempoBpm: tempoBpm,
      category: category,
      description: description,
      isCustom: isCustom,
      notation: notation,
      lyricsText: lyrics,
      youtubeId: youtubeId,
    );
  }

  factory Song.fromJson(Map<String, dynamic> json) => Song.fromNotation(
        id: json['id'] as String,
        title: json['title'] as String,
        notation: json['notation'] as String,
        lyrics: json['lyrics'] as String? ?? '',
        tempoBpm: (json['tempo'] as num?)?.toDouble() ?? 100,
        isCustom: true,
        youtubeId: json['youtube'] as String?,
      );

  static const String customCategory = '내 노래';

  final String id;
  final String title;
  final List<Note> notes;

  /// 음표별 가사(가사가 없으면 계이름).
  final List<String> lyrics;

  /// 음표별 박자 수 (4분음표 = 1).
  final List<double> beats;

  /// 새 소절이 시작되는 음표 인덱스 (UI 줄바꿈용).
  final List<int> phraseBreaks;
  final double tempoBpm;
  final String category;
  final String description;
  final bool isCustom;

  /// 원본 계이름 악보 / 가사 (편집용).
  final String notation;
  final String lyricsText;

  /// 원곡 참고 영상(유튜브 영상 ID). 없으면 null.
  final String? youtubeId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notation': notation,
        'lyrics': lyricsText,
        'tempo': tempoBpm,
        if (youtubeId != null) 'youtube': youtubeId,
      };

  Set<int> get pitchClasses => notes.map((n) => n.pitchClass).toSet();

  Duration durationOf(int index) => Duration(milliseconds: (beats[index] * 60000 / tempoBpm).round());

  Note get lowest => notes.reduce((a, b) => a.midi <= b.midi ? a : b);
  Note get highest => notes.reduce((a, b) => a.midi >= b.midi ? a : b);

  String get rangeLabel => '${lowest.solfege}${lowest.octave}–${highest.solfege}${highest.octave}';

  /// 음역 폭과 가장 큰 도약으로 난이도를 매긴다.
  Difficulty get difficulty {
    final span = highest.midi - lowest.midi;
    var maxLeap = 0;
    for (var i = 1; i < notes.length; i++) {
      maxLeap = math.max(maxLeap, (notes[i].midi - notes[i - 1].midi).abs());
    }
    if (span <= 7 && maxLeap <= 4) return Difficulty.easy;
    if (span <= 12 && maxLeap <= 7) return Difficulty.medium;
    return Difficulty.hard;
  }

  /// 소절 단위로 묶은 음표 인덱스.
  List<List<int>> get phrases {
    final result = <List<int>>[];
    var start = 0;
    for (final b in [...phraseBreaks, notes.length]) {
      if (b > start) result.add([for (var i = start; i < b; i++) i]);
      start = b;
    }
    return result;
  }
}
