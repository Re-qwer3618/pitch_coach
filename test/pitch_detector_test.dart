import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/models/note.dart';
import 'package:pitch_coach/models/pitch_reading.dart';
import 'package:pitch_coach/services/pitch_detector.dart';
import 'package:pitch_coach/services/pitch_service.dart';

const sampleRate = 44100;

/// 배음이 섞인 사람 목소리 비슷한 합성 신호.
Float64List voice(double f0, int length, {double amplitude = 0.3, int offset = 0}) {
  final out = Float64List(length);
  for (var i = 0; i < length; i++) {
    final t = (i + offset) / sampleRate;
    out[i] = amplitude *
        (math.sin(2 * math.pi * f0 * t) +
            0.5 * math.sin(2 * math.pi * 2 * f0 * t) +
            0.25 * math.sin(2 * math.pi * 3 * f0 * t)) /
        1.75;
  }
  return out;
}

double centsBetween(double a, double b) => 1200 * math.log(a / b) / math.ln2;

void main() {
  group('Note 변환', () {
    test('음이름 ↔ MIDI ↔ 주파수', () {
      expect(Note.parse('A4').midi, 69);
      expect(Note.parse('G4').midi, 67);
      expect(Note.parse('C#5').name, 'C#5');
      expect(Note.parse('G4').solfege, '솔');
      expect(Note.parse('A4').frequency, closeTo(440, 1e-9));
      expect(Note.parse('G4').frequency, closeTo(392.00, 0.01));
      expect(Note.frequencyToMidi(261.63), closeTo(60, 0.01));
    });

    test('PitchReading 센트 오차', () {
      final sharp = Note.midiToFrequency(67.2); // G4 +20센트
      final r = PitchReading(timeMs: 0, frequency: sharp, clarity: 1, rms: 0.1);
      expect(r.note!.name, 'G4');
      expect(r.cents, closeTo(20, 0.01));
    });
  });

  group('YIN 피치 검출', () {
    final detector = YinPitchDetector(sampleRate: sampleRate);

    for (final f0 in [82.41, 146.83, 196.0, 261.63, 293.66, 329.63, 392.0, 440.0, 659.25, 880.0]) {
      test('${f0}Hz 를 ±5센트 이내로 검출', () {
        final frame = voice(f0, 2048);
        YinPitchDetector.removeDcAndRms(frame);
        final estimate = detector.detect(frame);
        expect(estimate, isNotNull);
        expect(centsBetween(estimate!.frequency, f0).abs(), lessThan(5));
        expect(estimate.clarity, greaterThan(0.85));
      });
    }

    test('백색 잡음은 대부분 무성으로 판정', () {
      final rnd = math.Random(42);
      var voiced = 0;
      for (var k = 0; k < 50; k++) {
        final frame = Float64List.fromList(List.generate(2048, (_) => (rnd.nextDouble() * 2 - 1) * 0.2));
        if (detector.detect(frame) != null) voiced++;
      }
      expect(voiced, lessThan(5));
    });
  });

  group('PitchService 파이프라인 (마이크 대신 합성 PCM 주입)', () {
    Future<List<PitchReading>> run(List<Float64List> chunks) async {
      final service = PitchService();
      final readings = <PitchReading>[];
      final sub = service.readings.listen(readings.add);
      for (final c in chunks) {
        service.processSamples(c);
      }
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      return readings;
    }

    test('1초 분량의 G4 → 약 43회/초 G4 판정', () async {
      // 마이크 청크처럼 불규칙한 크기로 나눠서 주입
      final signal = voice(392.0, sampleRate);
      final chunks = <Float64List>[];
      var pos = 0;
      var size = 700;
      while (pos < signal.length) {
        final end = math.min(pos + size, signal.length);
        chunks.add(Float64List.sublistView(signal, pos, end));
        pos = end;
        size = size == 700 ? 1733 : 700;
      }
      final readings = await run(chunks);

      expect(readings.length, inInclusiveRange(40, 44));
      expect(readings.every((r) => r.note?.name == 'G4'), isTrue);
      expect(readings.every((r) => r.cents!.abs() < 5), isTrue);
      // 타임스탬프는 hop(≈23ms) 간격으로 증가
      expect(readings[1].timeMs - readings[0].timeMs, inInclusiveRange(22, 24));
    });

    test('무음 구간은 frequency == null', () async {
      final readings = await run([Float64List(sampleRate ~/ 2)]);
      expect(readings, isNotEmpty);
      expect(readings.every((r) => r.frequency == null), isTrue);
    });
  });
}
