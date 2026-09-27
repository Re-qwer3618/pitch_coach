import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/models/note.dart';
import 'package:pitch_coach/models/song.dart';
import 'package:pitch_coach/services/piano_synth.dart';
import 'package:pitch_coach/services/pitch_detector.dart';
import 'package:pitch_coach/views/widgets/piano_keyboard.dart';

void main() {
  group('PianoSynth', () {
    test('합성한 피아노 음을 YIN이 같은 음으로 인식 (C3~C6)', () {
      final detector = YinPitchDetector(sampleRate: PianoSynth.sampleRate);
      for (var midi = 48; midi <= 84; midi += 5) {
        final samples = PianoSynth.synthesize(midi.toDouble(), seconds: 0.5);
        // 어택 직후 구간을 분석
        final frame = Float64List.fromList(samples.sublist(4410, 4410 + 2048));
        YinPitchDetector.removeDcAndRms(frame);
        final est = detector.detect(frame);
        expect(est, isNotNull, reason: Note(midi).name);
        final detected = Note.frequencyToMidi(est!.frequency);
        expect((detected - midi).abs() * 100, lessThan(10), reason: Note(midi).name);
      }
    });

    test('센트 단위 음(부른 음 재현)도 정확히 합성', () {
      final detector = YinPitchDetector(sampleRate: PianoSynth.sampleRate);
      final samples = PianoSynth.synthesize(67 - 0.3, seconds: 0.3); // 솔 -30센트
      final frame = Float64List.fromList(samples.sublist(2000, 4048));
      YinPitchDetector.removeDcAndRms(frame);
      final detected = Note.frequencyToMidi(detector.detect(frame)!.frequency);
      expect(detected, closeTo(66.7, 0.08));
    });

    test('감쇠하고 끝은 무음, 피크는 정규화', () {
      final s = PianoSynth.synthesize(60);
      double rms(int from, int to) =>
          math.sqrt(s.sublist(from, to).map((v) => v * v).reduce((a, b) => a + b) / (to - from));
      expect(rms(441, 4410), greaterThan(rms(44100, 48510) * 3));
      expect(s.last.abs(), lessThan(0.01));
      expect(s.map((v) => v.abs()).reduce(math.max), closeTo(0.8, 0.01));
    });

    test('WAV 헤더', () {
      final wav = PianoSynth.toWav(Float64List(100));
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      final bd = ByteData.sublistView(wav);
      expect(bd.getUint32(24, Endian.little), 44100);
      expect(bd.getUint32(40, Endian.little), 200);
      expect(wav.length, 244);
    });
  });

  group('PianoLayout', () {
    final layout = PianoLayout(lowMidi: 48);

    test('2옥타브 + 끝 C = 흰 건반 15개', () {
      expect(layout.whiteKeyCount, 15);
      expect(layout.whiteIndex(48), 0); // C3
      expect(layout.whiteIndex(72), 14); // C5
      expect(PianoLayout.isBlack(49), isTrue);
      expect(layout.centerX(49), 1.0); // C#3은 C3과 D3 경계
    });

    test('커서는 건반 사이를 연속적으로 이동', () {
      expect(layout.cursorX(55), layout.centerX(55));
      final between = layout.cursorX(55.5);
      expect(between, greaterThan(layout.centerX(55)));
      expect(between, lessThan(layout.centerX(56)));
      var prev = -1.0;
      for (var m = 48.0; m <= 72; m += 0.1) {
        expect(layout.cursorX(m), greaterThanOrEqualTo(prev));
        prev = layout.cursorX(m);
      }
    });

    test('탭 판정: 위쪽은 검은 건반 우선, 아래쪽은 흰 건반', () {
      expect(layout.hitTest(1.0, 0.3), 49); // C#3
      expect(layout.hitTest(1.0, 0.9), 50); // 아래쪽 → D3 (흰 건반 1번)
      expect(layout.hitTest(0.2, 0.3), 48); // C3
    });

    test('창 따라가기', () {
      expect(PianoLayout.follow(48, 60), 48); // 범위 안
      expect(PianoLayout.follow(48, 43), 36); // 아래로
      expect(PianoLayout.follow(48, 79), 60); // 위로 → C4~C6
    });
  });

  testWidgets('건반을 누르면 해당 MIDI가 전달된다', (tester) async {
    int? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: PianoKeyboard(lowMidi: 60, onKeyTap: (m) => tapped = m, targetMidi: 67, sungMidi: 66.8),
        ),
      ),
    ));
    final box = tester.getRect(find.byType(PianoKeyboard));
    final unit = box.width / 15;
    await tester.tapAt(Offset(box.left + unit * 4.5, box.bottom - 10)); // 흰 건반 4번 = G4
    expect(tapped, 67);
  });

  test('학교종 박자: 4+4+4+3 = 15박, 100BPM', () {
    final song = schoolBellSong;
    expect(song.beats.reduce((a, b) => a + b), 15);
    expect(song.durationOf(0), const Duration(milliseconds: 600));
    expect(song.durationOf(11), const Duration(milliseconds: 1800));
  });
}
