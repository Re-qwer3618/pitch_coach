import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/data/built_in_songs.dart';
import 'package:pitch_coach/models/notation.dart';
import 'package:pitch_coach/models/pitch_reading.dart';
import 'package:pitch_coach/models/song.dart';
import 'package:pitch_coach/services/melody_matcher.dart';

void main() {
  group('계이름 악보 파서', () {
    test('기본 옥타브(가운데 도)와 띄어쓰기 자유', () {
      expect(Notation.parse('도레미 파솔라시').midis, [60, 62, 64, 65, 67, 69, 71]);
    });

    test("옥타브: ' , 높은 낮은", () {
      expect(Notation.parse("도' 도'' 솔, 높은레 낮은낮은미").midis, [72, 84, 55, 74, 40]);
    });

    test('반음과 영어 음이름', () {
      expect(Notation.parse('도# 미b G4 C#5 A').midis, [61, 63, 67, 73, 69]);
    });

    test('박자: - _ .', () {
      expect(Notation.parse('솔 미- 레-- 도_ 파. 라.-').beats, [1, 2, 3, 0.5, 1.5, 2.5]);
    });

    test('줄바꿈과 / 는 소절, | 는 무시', () {
      final p = Notation.parse('솔 솔 | 라 라\n솔 솔 미- / 레\n\n');
      expect(p.midis.length, 8);
      expect(p.phraseBreaks, [4, 7]);
    });

    test('잘못된 기호는 위치와 함께 오류', () {
      expect(() => Notation.parse('솔 솔 X'), throwsA(isA<FormatException>()));
      expect(() => Notation.parse("도''''"), throwsA(isA<FormatException>())); // 너무 높음
    });

    test('피아노 건반 토큰 → 다시 파싱하면 같은 음 (C3~C6)', () {
      for (var m = 48; m <= 84; m++) {
        expect(Notation.parse(Notation.tokenFor(m)).midis.single, m, reason: Notation.tokenFor(m));
      }
      expect(Notation.tokenFor(72), "도'");
      expect(Notation.tokenFor(55), '솔,');
    });
  });

  group('가사 음절', () {
    test('한글은 글자마다, 영어는 단어나 - 로', () {
      expect(Notation.syllables('학교종이 땡땡땡!'), ['학', '교', '종', '이', '땡', '땡', '땡']);
      expect(Notation.syllables('Jin-gle bells'), ['Jin', 'gle', 'bells']);
    });

    test('가사가 모자라면 계이름으로 채움', () {
      final song = Song.fromNotation(id: 't', title: 't', notation: '도 레 미', lyrics: '안녕');
      expect(song.lyrics, ['안', '녕', '미']);
    });

    test('가사가 없으면 계이름으로 부름', () {
      final song = Song.fromNotation(id: 't', title: 't', notation: '솔 라');
      expect(song.lyrics, ['솔', '라']);
    });
  });

  group('기본 수록곡', () {
    test('모든 곡이 파싱되고 가사 글자 수 = 음표 수', () {
      expect(builtInSongs.length, greaterThanOrEqualTo(7));
      for (final song in builtInSongs) {
        expect(song.notes.length, greaterThan(4), reason: song.title);
        final syllables = Notation.syllables(song.lyricsText);
        if (syllables.isNotEmpty) {
          expect(syllables.length, song.notes.length, reason: '${song.title} 가사/음표 수');
        }
        expect(builtInCategories, contains(song.category));
      }
      expect(builtInSongs.map((s) => s.id).toSet().length, builtInSongs.length);
    });

    test('학교종은 기존 멜로디·박자 그대로', () {
      expect(schoolBellSong.notes.map((n) => n.name).toList(),
          ['G4', 'G4', 'A4', 'A4', 'G4', 'G4', 'E4', 'G4', 'G4', 'E4', 'E4', 'D4']);
      expect(schoolBellSong.beats, [1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 3]);
      expect(schoolBellSong.phraseBreaks, [7]);
    });

    test('작은별: 도도솔솔라라솔, 가사 42글자', () {
      final star = builtInSongs.firstWhere((s) => s.id == 'little_star');
      expect(star.notes.take(7).map((n) => n.solfege).join(), '도도솔솔라라솔');
      expect(star.lyrics.take(7).join(), '반짝반짝작은별');
      expect(star.notes.length, 42);
    });

    test('난이도: 비행기·학교종은 쉬움, 작은별은 보통', () {
      Song byId(String id) => builtInSongs.firstWhere((s) => s.id == id);
      expect(byId('airplane').difficulty, Difficulty.easy);
      expect(byId('school_bell').difficulty, Difficulty.easy);
      expect(byId('little_star').difficulty, Difficulty.medium);
    });

    test('모든 기본 곡을 정확히 부르면 90점 이상 (채점 엔진이 곡마다 동작)', () {
      const matcher = MelodyMatcher();
      for (final song in builtInSongs) {
        final readings = <PitchReading>[];
        var t = 0;
        for (var i = 0; i < song.notes.length; i++) {
          final frames = (song.beats[i] * 18).round();
          for (var k = 0; k < frames; k++) {
            readings.add(PitchReading(timeMs: t += 23, frequency: song.notes[i].frequency, clarity: 1, rms: 0.1));
          }
          for (var k = 0; k < 4; k++) {
            readings.add(PitchReading(timeMs: t += 23, frequency: null, clarity: 0, rms: 0));
          }
        }
        final result = matcher.evaluate(song, readings);
        expect(result.score, greaterThanOrEqualTo(90), reason: '${song.title}: ${result.score}');
      }
    });
  });

  test('내 노래 JSON 저장/복원', () {
    final song = Song.fromNotation(
      id: 'custom_1',
      title: '나의 노래',
      notation: "솔 솔 라- / 도'",
      lyrics: '가나다라',
      tempoBpm: 90,
      isCustom: true,
    );
    final restored = Song.fromJson(song.toJson());
    expect(restored.id, 'custom_1');
    expect(restored.title, '나의 노래');
    expect(restored.notes, song.notes);
    expect(restored.beats, song.beats);
    expect(restored.lyrics, song.lyrics);
    expect(restored.tempoBpm, 90);
    expect(restored.isCustom, isTrue);
    expect(restored.category, Song.customCategory);
  });
}
