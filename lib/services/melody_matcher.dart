import 'dart:math' as math;

import '../models/match_result.dart';
import '../models/pitch_reading.dart';
import '../models/song.dart';

/// 녹음에서 분리해 낸 음표 하나.
class SungNote {
  const SungNote({required this.midi, required this.startMs, required this.endMs, required this.frames});

  /// 구간 중앙값 피치(실수 MIDI).
  final double midi;
  final int startMs;
  final int endMs;
  final int frames;
}

/// 피치 흐름을 음표로 분리하고, 목표 멜로디와 정렬·채점한다.
///
/// 1. 분할: 무성 구간(자음·쉼)이나 지속적인 음높이 변화에서 음표를 나눈다.
/// 2. 정렬: 목표 음표열과 부른 음표열을 DP(Needleman–Wunsch)로 정렬해
///    빠뜨린 음·덧붙인 음이 있어도 나머지를 올바르게 비교한다.
/// 3. 옥타브 보정: 남성/아이 음역을 고려해 ±12·24반음 중 최적 옥타브로 채점한다.
class MelodyMatcher {
  const MelodyMatcher({
    this.gapFrames = 3,
    this.minNoteFrames = 4,
    this.changeThreshold = 0.8,
    this.changeFrames = 3,
  });

  /// 이 프레임 수(≈23ms/프레임) 이상 무성이면 음표를 끊는다.
  final int gapFrames;

  /// 이보다 짧은 구간은 잡음으로 버린다.
  final int minNoteFrames;

  /// 현재 음표 중앙값에서 이 반음 이상 벗어나면 음 변화 후보.
  final double changeThreshold;

  /// 음 변화 후보가 이 프레임 수 이상 지속되면 새 음표로 확정.
  final int changeFrames;

  static const List<int> _octaveShifts = [0, 12, -12, 24, -24];
  static const double _extraNotePenalty = 0.2;

  // ─────────────────────────── 분할 ───────────────────────────

  List<SungNote> segment(List<PitchReading> readings) {
    final notes = <SungNote>[];
    var current = <double>[];
    var currentStart = 0;
    var currentEnd = 0;
    var pending = <double>[];
    var pendingStart = 0;
    var gap = 0;

    void close() {
      if (current.length >= minNoteFrames) {
        notes.add(SungNote(
          midi: _median(current),
          startMs: currentStart,
          endMs: currentEnd,
          frames: current.length,
        ));
      }
      current = [];
      pending = [];
    }

    for (final reading in readings) {
      final midi = reading.midi;
      if (midi == null) {
        gap++;
        if (gap == gapFrames) close();
        continue;
      }
      gap = 0;

      if (current.isEmpty) {
        current.add(midi);
        currentStart = currentEnd = reading.timeMs;
        continue;
      }

      if ((midi - _median(current)).abs() > changeThreshold) {
        if (pending.isEmpty) pendingStart = reading.timeMs;
        pending.add(midi);
        if (pending.length >= changeFrames) {
          final next = pending;
          close();
          current = next;
          currentStart = pendingStart;
          currentEnd = reading.timeMs;
        }
      } else {
        // 짧게 튄 값(글라이드·잡음)은 버린다.
        pending = [];
        current.add(midi);
        currentEnd = reading.timeMs;
      }
    }
    close();
    return _splitHeldNotes(notes);
  }

  /// '종이', '모이'처럼 끊김 없이 이어 부른 같은 음 두 개는 하나의 긴 구간이 된다.
  /// 다른 음표보다 확연히 긴 구간은 길이에 비례해 나눈다(마지막 음 제외).
  List<SungNote> _splitHeldNotes(List<SungNote> notes) {
    if (notes.length < 3) return notes;
    final typical = _median(notes.map((n) => n.frames.toDouble()).toList());
    final result = <SungNote>[];
    for (var i = 0; i < notes.length; i++) {
      final note = notes[i];
      final ratio = note.frames / typical;
      if (i == notes.length - 1 || ratio < 1.7) {
        result.add(note);
        continue;
      }
      final parts = ratio.round().clamp(2, 4);
      final span = (note.endMs - note.startMs) / parts;
      for (var p = 0; p < parts; p++) {
        result.add(SungNote(
          midi: note.midi,
          startMs: (note.startMs + span * p).round(),
          endMs: (note.startMs + span * (p + 1)).round(),
          frames: note.frames ~/ parts,
        ));
      }
    }
    return result;
  }

  // ─────────────────────────── 채점 ───────────────────────────

  MatchResult evaluate(Song song, List<PitchReading> readings) {
    final sung = segment(readings);
    final targets = song.notes.map((n) => n.midi.toDouble()).toList();
    final sungMidis = sung.map((n) => n.midi).toList();

    // 옥타브만 보정한 본 채점
    var best = _align(targets, sungMidis, 0);
    for (final shift in _octaveShifts.skip(1)) {
      final candidate = _align(targets, sungMidis, shift);
      if (candidate.total > best.total + 1e-9) best = candidate;
    }

    // 참고용: 임의의 키로 옮겼을 때(상대음감) 최고 점수
    var bestTransposed = best;
    for (var shift = -24; shift <= 24; shift++) {
      final candidate = _align(targets, sungMidis, shift);
      if (candidate.total > bestTransposed.total + 1e-9) bestTransposed = candidate;
    }

    final matches = <NoteMatch>[];
    for (var i = 0; i < song.notes.length; i++) {
      final j = best.assignment[i];
      final sungMidi = j == null ? null : sungMidis[j] + best.shift;
      final cents = sungMidi == null ? null : (sungMidi - targets[i]) * 100;
      matches.add(NoteMatch(
        target: song.notes[i],
        lyric: song.lyrics[i],
        sungMidi: sungMidi,
        grade: _grade(cents),
        points: cents == null ? 0 : _points(cents),
      ));
    }

    final n = song.notes.length;
    final score = (best.total / n * 100).clamp(0.0, 100.0);
    final transposedScore = (bestTransposed.total / n * 100).clamp(0.0, 100.0);

    return MatchResult(
      score: score,
      notes: matches,
      octaveShift: best.shift,
      detectedNoteCount: sung.length,
      headline: _headline(score, sung.length),
      tips: _tips(matches, best.shift, score, transposedScore, bestTransposed.shift),
    );
  }

  /// 센트 오차 → 음표 점수(0~1).
  static double _points(double cents) {
    final c = cents.abs();
    if (c <= 30) return 1.0;
    if (c <= 60) return 0.8;
    if (c <= 100) return 0.5;
    if (c <= 150) return 0.25;
    return 0;
  }

  static NoteGrade _grade(double? cents) {
    if (cents == null) return NoteGrade.missed;
    final c = cents.abs();
    if (c <= 30) return NoteGrade.perfect;
    if (c <= 60) return NoteGrade.good;
    return NoteGrade.off;
  }

  /// 목표열 [t]와 부른 음열 [s](+shift)을 전역 정렬한다.
  /// - 대각: 두 음을 짝지음 → _points
  /// - 목표만 소비: 빠뜨린 음 → 0점
  /// - 부른 음만 소비: 덧붙인 음 → 감점 (직전과 같은 음이면 늘여 부른 것으로 보고 감점 없음)
  _Alignment _align(List<double> t, List<double> s, int shift) {
    final n = t.length;
    final m = s.length;
    final score = List.generate(n + 1, (_) => List<double>.filled(m + 1, 0));
    final move = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0)); // 0 diag, 1 up, 2 left

    double extraCost(int j) =>
        (j > 0 && (s[j] - s[j - 1]).abs() <= 0.5) ? 0 : _extraNotePenalty;

    for (var j = 1; j <= m; j++) {
      score[0][j] = score[0][j - 1] - extraCost(j - 1);
      move[0][j] = 2;
    }
    for (var i = 1; i <= n; i++) {
      score[i][0] = score[i - 1][0];
      move[i][0] = 1;
      for (var j = 1; j <= m; j++) {
        final diag = score[i - 1][j - 1] + _points((s[j - 1] + shift - t[i - 1]) * 100);
        final up = score[i - 1][j];
        final left = score[i][j - 1] - extraCost(j - 1);
        if (diag >= up && diag >= left) {
          score[i][j] = diag;
          move[i][j] = 0;
        } else if (up >= left) {
          score[i][j] = up;
          move[i][j] = 1;
        } else {
          score[i][j] = left;
          move[i][j] = 2;
        }
      }
    }

    final assignment = List<int?>.filled(n, null);
    var i = n;
    var j = m;
    while (i > 0 || j > 0) {
      final mv = move[i][j];
      if (i > 0 && j > 0 && mv == 0) {
        assignment[i - 1] = j - 1;
        i--;
        j--;
      } else if (i > 0 && (j == 0 || mv == 1)) {
        i--;
      } else {
        j--;
      }
    }
    return _Alignment(math.max(0, score[n][m]), assignment, shift);
  }

  // ─────────────────────────── 피드백 ───────────────────────────

  static String _headline(double score, int detected) {
    if (detected == 0) return '소리가 거의 감지되지 않았어요. 마이크 가까이에서 또렷하게 불러주세요 🎤';
    if (score >= 90) return '완벽해요! 음치 탈출 성공! 🎉';
    if (score >= 75) return '아주 좋아요! 거의 다 왔어요 👏';
    if (score >= 50) return '좋은 시작이에요! 조금만 더 연습해 봐요 💪';
    if (score >= 25) return '음정이 많이 흔들렸어요. 기본 연습 모드에서 한 음씩 맞춰 봐요 🎯';
    return '멜로디와 많이 달랐어요. 천천히 한 음씩 따라 불러 봐요 🐢';
  }

  static List<String> _tips(
    List<NoteMatch> matches,
    int octaveShift,
    double score,
    double transposedScore,
    int transposeShift,
  ) {
    final tips = <String>[];

    if (octaveShift != 0) {
      final octaves = (octaveShift.abs() / 12).round();
      final direction = octaveShift > 0 ? '낮게' : '높게';
      tips.add('$octaves옥타브 $direction 불러서 옥타브를 맞춰 채점했어요. (정상이에요!)');
    }

    if (transposedScore - score >= 15 && transposeShift % 12 != 0) {
      // 가장 가까운 옥타브 기준 반음 차이(-5~+6)
      var semis = transposeShift % 12;
      if (semis > 6) semis -= 12;
      final direction = semis > 0 ? '낮게' : '높게';
      tips.add('멜로디 흐름은 잘 맞았지만 전체 음높이가 ${semis.abs()}반음 $direction 시작됐어요. '
          '키를 맞추면 ${transposedScore.round()}점이에요. 첫 음 솔(G4)을 먼저 잡고 시작해 보세요.');
    }

    final sung = matches.where((m) => m.centsError != null && m.centsError!.abs() <= 150).toList();
    if (sung.isNotEmpty) {
      final mean = sung.map((m) => m.centsError!).reduce((a, b) => a + b) / sung.length;
      if (mean > 20) {
        tips.add('전체적으로 음이 조금 높아요 (평균 +${mean.round()}센트). 힘을 빼고 살짝 낮게 불러 보세요.');
      } else if (mean < -20) {
        tips.add('전체적으로 음이 조금 낮아요 (평균 ${mean.round()}센트). 배에 힘을 주고 조금 더 높게 불러 보세요.');
      }
    }

    final offNotes = matches.where((m) => m.grade == NoteGrade.off).toList();
    if (offNotes.isNotEmpty) {
      offNotes.sort((a, b) => b.centsError!.abs().compareTo(a.centsError!.abs()));
      final worst = offNotes.first;
      final cents = worst.centsError!.round();
      final sign = cents > 0 ? '+' : '';
      tips.add("'${worst.lyric}' (${worst.target.solfege}, ${worst.target.name}) 음이 가장 많이 벗어났어요 "
          '($sign$cents센트, ${cents > 0 ? '높음' : '낮음'}).');
    }

    final missed = matches.where((m) => m.grade == NoteGrade.missed).length;
    if (missed > 0) {
      tips.add('$missed개의 음이 인식되지 않았어요. 같은 음이 반복될 때는 음절마다 살짝 끊어서 불러 보세요.');
    }

    if (tips.isEmpty && score >= 90) {
      tips.add('모든 음을 정확하게 불렀어요. 다음엔 조금 더 빠르게 불러 보세요!');
    }
    return tips;
  }

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
  }
}

class _Alignment {
  const _Alignment(this.total, this.assignment, this.shift);

  final double total;

  /// 목표 음표 i에 짝지어진 부른 음표 인덱스 (없으면 null).
  final List<int?> assignment;
  final int shift;
}
