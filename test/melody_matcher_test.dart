import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/models/match_result.dart';
import 'package:pitch_coach/models/note.dart';
import 'package:pitch_coach/models/pitch_reading.dart';
import 'package:pitch_coach/models/song.dart';
import 'package:pitch_coach/services/melody_matcher.dart';

const hopMs = 23;

/// 음표 목록을 PitchService 출력 형태의 프레임 열로 합성한다.
/// [gaps]가 false인 인덱스 뒤에는 무성 구간을 넣지 않는다(이어 부르기).
List<PitchReading> sing(
  List<double> midis, {
  int framesPerNote = 18,
  double centsOffset = 0,
  double jitterCents = 8,
  Set<int> noGapAfter = const {},
  int seed = 1,
}) {
  final rnd = math.Random(seed);
  final readings = <PitchReading>[];
  var t = 0;
  void add(double? midi) {
    readings.add(PitchReading(
      timeMs: t,
      frequency: midi == null ? null : Note.midiToFrequency(midi),
      clarity: midi == null ? 0 : 0.95,
      rms: midi == null ? 0.001 : 0.1,
    ));
    t += hopMs;
  }

  for (var k = 0; k < 10; k++) {
    add(null);
  }
  for (var i = 0; i < midis.length; i++) {
    for (var k = 0; k < framesPerNote; k++) {
      final jitter = (rnd.nextDouble() * 2 - 1) * jitterCents / 100;
      add(midis[i] + centsOffset / 100 + jitter);
    }
    if (!noGapAfter.contains(i)) {
      for (var k = 0; k < 4; k++) {
        add(null);
      }
    }
  }
  for (var k = 0; k < 10; k++) {
    add(null);
  }
  return readings;
}

void main() {
  const matcher = MelodyMatcher();
  final song = schoolBellSong;
  final target = song.notes.map((n) => n.midi.toDouble()).toList();

  test('학교종 타겟 시퀀스', () {
    expect(song.notes.map((n) => n.name).toList(),
        ['G4', 'G4', 'A4', 'A4', 'G4', 'G4', 'E4', 'G4', 'G4', 'E4', 'E4', 'D4']);
    expect(song.lyrics.join(), '학교종이땡땡땡어서모이자');
  });

  test('정확히 부르면 12개 음표 분리 & 95점 이상', () {
    final result = matcher.evaluate(song, sing(target));
    expect(result.detectedNoteCount, 12);
    expect(result.score, greaterThanOrEqualTo(95));
    expect(result.octaveShift, 0);
    expect(result.notes.every((n) => n.grade == NoteGrade.perfect), isTrue);
    expect(result.headline, contains('완벽'));
  });

  test('한 옥타브 낮게(남성 음역) 불러도 옥타브 보정 후 고득점', () {
    final result = matcher.evaluate(song, sing(target.map((m) => m - 12).toList()));
    expect(result.score, greaterThanOrEqualTo(95));
    expect(result.octaveShift, 12);
    expect(result.tips.join(), contains('옥타브'));
  });

  test("'종이', '모이'처럼 같은 음을 이어 불러도 음표를 나눈다", () {
    final readings = sing(target, noGapAfter: {2, 9});
    final result = matcher.evaluate(song, readings);
    expect(result.score, greaterThanOrEqualTo(90));
  });

  test('전체적으로 +45센트 높게 부르면 감점 + 높음 피드백', () {
    final result = matcher.evaluate(song, sing(target, centsOffset: 45, jitterCents: 3));
    expect(result.score, inInclusiveRange(70, 90));
    expect(result.tips.join(), contains('높아요'));
  });

  test('틀린 음 3개 → 해당 음표 off 판정', () {
    final wrong = [...target];
    wrong[2] = 72; // A4 대신 C5
    wrong[6] = 60; // E4 대신 C4
    wrong[11] = 57; // D4 대신 A3
    final result = matcher.evaluate(song, sing(wrong));
    expect(result.score, inInclusiveRange(65, 80));
    expect(result.notes[2].grade, NoteGrade.off);
    expect(result.notes[6].grade, NoteGrade.off);
    expect(result.notes[11].grade, NoteGrade.off);
    expect(result.notes[0].grade, NoteGrade.perfect);
  });

  test('음 2개를 빠뜨려도 나머지는 정렬되어 정상 채점', () {
    final partial = [...target]
      ..removeAt(9)
      ..removeAt(4);
    final result = matcher.evaluate(song, sing(partial));
    expect(result.score, closeTo(10 / 12 * 100, 3));
    expect(result.notes.where((n) => n.grade == NoteGrade.missed).length, 2);
    expect(result.tips.join(), contains('인식되지 않았어요'));
  });

  test('키를 3반음 낮게 시작하면 상대음감 안내', () {
    final result = matcher.evaluate(song, sing(target.map((m) => m - 3).toList()));
    expect(result.score, lessThan(60));
    expect(result.tips.join(), contains('3반음 낮게'));
  });

  test('무음이면 0점', () {
    final silent = List.generate(200, (i) => PitchReading(timeMs: i * hopMs, frequency: null, clarity: 0, rms: 0));
    final result = matcher.evaluate(song, silent);
    expect(result.score, 0);
    expect(result.detectedNoteCount, 0);
    expect(result.headline, contains('감지되지'));
  });
}
