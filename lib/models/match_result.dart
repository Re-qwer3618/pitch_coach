import 'note.dart';

enum NoteGrade { perfect, good, off, missed }

/// 목표 음표 하나와 사용자가 부른 음의 비교 결과.
class NoteMatch {
  const NoteMatch({
    required this.target,
    required this.lyric,
    required this.sungMidi,
    required this.grade,
    required this.points,
  });

  final Note target;
  final String lyric;

  /// 옥타브 보정이 적용된 부른 음(실수 MIDI). 인식 실패 시 null.
  final double? sungMidi;
  final NoteGrade grade;

  /// 이 음표에서 얻은 점수(0~1).
  final double points;

  double? get centsError => sungMidi == null ? null : (sungMidi! - target.midi) * 100;
  Note? get sungNote => sungMidi == null ? null : Note(sungMidi!.round());
}

/// 곡 전체 채점 결과.
class MatchResult {
  const MatchResult({
    required this.score,
    required this.notes,
    required this.octaveShift,
    required this.detectedNoteCount,
    required this.headline,
    required this.tips,
  });

  /// 일치율(0~100).
  final double score;
  final List<NoteMatch> notes;

  /// 채점 시 부른 음에 더한 반음 수(±12의 배수). 0이면 원래 옥타브.
  final int octaveShift;

  /// 녹음에서 분리된 음표 개수.
  final int detectedNoteCount;
  final String headline;
  final List<String> tips;
}
