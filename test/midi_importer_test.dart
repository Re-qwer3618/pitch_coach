import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/models/notation.dart';
import 'package:pitch_coach/models/song.dart';
import 'package:pitch_coach/services/midi_importer.dart';

// ───── 테스트용 MIDI 파일 만들기 ─────

const _ppq = 480;
const _rest = -1;

List<int> _vlq(int v) {
  final out = [v & 0x7F];
  for (v >>= 7; v > 0; v >>= 7) {
    out.insert(0, (v & 0x7F) | 0x80);
  }
  return out;
}

List<int> _u16(int v) => [v >> 8 & 0xFF, v & 0xFF];
List<int> _u32(int v) => [v >> 24 & 0xFF, v >> 16 & 0xFF, v >> 8 & 0xFF, v & 0xFF];
List<int> _meta(int type, List<int> data) => [0xFF, type, ..._vlq(data.length), ...data];
List<int> _name(String name) => _meta(0x03, utf8.encode(name));

List<int> _tempo(double bpm) {
  final micros = (60000000 / bpm).round();
  return _meta(0x51, [micros >> 16 & 0xFF, micros >> 8 & 0xFF, micros & 0xFF]);
}

/// (음, 박) 목록 → (delta tick, 이벤트) 목록. 음이 [_rest]면 쉼.
List<(int, List<int>)> _line(List<(int, double)> notes, {int channel = 0, List<String>? words}) {
  final events = <(int, List<int>)>[];
  var wait = 0;
  var w = 0;
  for (final (pitch, beats) in notes) {
    final ticks = (beats * _ppq).round();
    if (pitch == _rest) {
      wait += ticks;
      continue;
    }
    if (words != null) {
      events.add((wait, _meta(0x05, utf8.encode(words[w++]))));
      wait = 0;
    }
    events
      ..add((wait, [0x90 | channel, pitch, 100]))
      ..add((ticks, [0x80 | channel, pitch, 0]));
    wait = 0;
  }
  return events;
}

/// 한 박마다 화음 하나.
List<(int, List<int>)> _chords(List<List<int>> chords, {int channel = 0}) => [
      for (final chord in chords) ...[
        for (final p in chord) (0, [0x90 | channel, p, 90]),
        for (var i = 0; i < chord.length; i++) (i == 0 ? _ppq : 0, [0x80 | channel, chord[i], 0]),
      ],
    ];

List<int> _track(List<(int, List<int>)> events) {
  final body = [
    for (final (delta, bytes) in events) ...[..._vlq(delta), ...bytes],
    0x00, 0xFF, 0x2F, 0x00, // end of track
  ];
  return [...'MTrk'.codeUnits, ..._u32(body.length), ...body];
}

Uint8List _smf(List<List<int>> tracks, {int division = _ppq}) => Uint8List.fromList([
      ...'MThd'.codeUnits, ..._u32(6), ..._u16(tracks.length > 1 ? 1 : 0), ..._u16(tracks.length), ..._u16(division),
      for (final t in tracks) ...t,
    ]);

MidiMelody _only(List<(int, List<int>)> events) => MidiImporter.parse(_smf([_track(events)])).melodies.single;

void main() {
  group('MIDI → 계이름 악보', () {
    test('학교종 첫 소절과 템포', () {
      final result = MidiImporter.parse(_smf([
        _track([
          (0, _tempo(100)),
          ..._line([(67, 1), (67, 1), (69, 1), (69, 1), (67, 1), (67, 1), (64, 2)]),
        ]),
      ]));
      expect(result.tempoBpm, closeTo(100, 0.01));
      final melody = result.melodies.single;
      expect(melody.notation, '솔 솔 라 라 솔 솔 미-');
      expect(melody.noteCount, 7);
      expect(melody.octaveShift, 0);
      expect(melody.lyrics, '');
      expect(melody.rangeLabel, 'E4–A4');
    });

    test('템포가 없으면 120', () {
      expect(MidiImporter.parse(_smf([_track(_line([(60, 1), (62, 1), (64, 1), (65, 1)]))])).tempoBpm, 120);
    });

    test('박자: 반 박, 점음표, 긴 음', () {
      expect(_only(_line([(60, 0.5), (62, 1.5), (64, 1), (65, 3), (67, 2.5)])).notation, '도_ 레. 미 파-- 솔.-');
    });

    test('짧은 쉼은 앞 음에 붙이고, 한 박 이상 쉬면 소절을 나눈다', () {
      final melody = _only(_line([(60, 1), (62, 0.5), (_rest, 0.5), (64, 1), (_rest, 2), (65, 1)]));
      expect(melody.notation, '도 레 미\n파');
      expect(Notation.parse(melody.notation).phraseBreaks, [3]);
    });

    test('running status와 velocity 0 note-off', () {
      final melody = _only([
        (0, [0x90, 60, 100]),
        (_ppq, [60, 0]),
        (0, [62, 100]),
        (_ppq, [62, 0]),
        (0, [64, 100]),
        (_ppq, [64, 0]),
        (0, [65, 100]),
        (_ppq, [65, 0]),
      ]);
      expect(melody.notation, '도 레 미 파');
    });

    test('너무 높은 멜로디는 부르기 편한 옥타브로 옮긴다', () {
      final melody = _only(_line([(84, 1), (86, 1), (88, 1), (89, 1)]));
      expect(melody.octaveShift, -2);
      expect(melody.notation, '도 레 미 파');
    });

    test('만든 악보로 바로 노래를 만들 수 있다 (음 높이 보존)', () {
      final pitches = [60, 61, 63, 66, 68, 70, 72, 55, 57];
      final melody = _only(_line([for (final p in pitches) (p, 1)]));
      final song = Song.fromNotation(id: 't', title: 't', notation: melody.notation);
      expect(song.notes.map((n) => n.midi), pitches.map((p) => p + 12 * melody.octaveShift));
    });
  });

  group('파트 고르기', () {
    test('드럼은 빼고, 화음 반주보다 선율을 먼저 추천한다', () {
      final result = MidiImporter.parse(_smf([
        _track([(0, _tempo(90)), (0, _name('Conductor'))]),
        _track([
          (0, _name('Piano')),
          ..._chords([
            [60, 64, 67],
            [60, 65, 69],
            [59, 62, 67],
            [60, 64, 67],
          ]),
        ]),
        _track([
          (0, _name('Flute')),
          ..._line([(72, 1), (74, 1), (76, 1), (77, 1), (79, 1), (77, 1), (76, 1), (74, 1)], channel: 1),
        ]),
        _track(_line([for (var i = 0; i < 8; i++) (36, 1)], channel: 9)),
      ]));
      expect(result.tempoBpm, closeTo(90, 0.01));
      expect(result.melodies.map((m) => m.name), ['Flute', 'Piano']);
      // 화음은 가장 높은 음만 남는다: G4 A4 G4 G4
      expect(result.melodies[1].notation, '솔 라 솔 솔');
    });

    test('트랙 이름이 멜로디/보컬이면 우선', () {
      final result = MidiImporter.parse(_smf([
        _track([(0, _name('Strings')), ..._line([for (var i = 0; i < 10; i++) (60 + i, 1)])]),
        _track([(0, _name('보컬')), ..._line([(67, 1), (67, 1), (69, 1), (69, 1)], channel: 1)]),
      ]));
      expect(result.melodies.first.name, '보컬');
    });

    test('한 트랙에 채널이 여럿이면 채널별로 나눈다 (format 0)', () {
      final result = MidiImporter.parse(_smf([
        _track([
          ..._line([(67, 1), (67, 1), (69, 1), (69, 1)]),
          ..._line([(48, 1), (43, 1), (48, 1), (43, 1)], channel: 2),
        ]),
      ]));
      expect(result.melodies.map((m) => m.name), ['트랙 1 · 채널 1', '트랙 1 · 채널 3']);
    });
  });

  group('가사', () {
    test('음표마다 가사 이벤트가 있으면 가져온다', () {
      final melody = _only(_line([(67, 1), (67, 1), (69, 1), (69, 1)], words: ['학', '교', '종', '이']));
      expect(melody.lyrics, '학 교 종 이');
      final song = Song.fromNotation(id: 't', title: 't', notation: melody.notation, lyrics: melody.lyrics);
      expect(song.lyrics, ['학', '교', '종', '이']);
    });

    test('음절 수가 음표 수와 안 맞으면 가사를 버린다', () {
      final melody = _only(_line([(67, 1), (67, 1), (69, 1), (69, 1)], words: ['학', '교', '종', '이다']));
      expect(melody.lyrics, '');
    });
  });

  group('잘못된 파일', () {
    test('MIDI가 아니면 오류', () {
      expect(() => MidiImporter.parse(Uint8List.fromList(utf8.encode('hello, this is not midi'))),
          throwsA(isA<FormatException>()));
    });

    test('SMPTE 시간 단위는 지원하지 않는다', () {
      final bytes = _smf([_track(_line([(60, 1), (62, 1), (64, 1), (65, 1)]))], division: 0xE728);
      expect(() => MidiImporter.parse(bytes), throwsA(isA<FormatException>()));
    });

    test('잘린 파일은 오류', () {
      final bytes = _smf([_track(_line([(60, 1), (62, 1), (64, 1), (65, 1)]))]);
      expect(() => MidiImporter.parse(Uint8List.sublistView(bytes, 0, bytes.length - 5)),
          throwsA(isA<FormatException>()));
    });

    test('음표가 없거나 드럼뿐이면 오류', () {
      expect(() => MidiImporter.parse(_smf([_track([(0, _tempo(100))])])), throwsA(isA<FormatException>()));
      expect(() => MidiImporter.parse(_smf([_track(_line([for (var i = 0; i < 8; i++) (36, 1)], channel: 9))])),
          throwsA(isA<FormatException>()));
    });
  });
}
