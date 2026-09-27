import 'note.dart';

/// 계이름 악보 파싱 결과.
class ParsedNotation {
  const ParsedNotation({required this.midis, required this.beats, required this.phraseBreaks});

  final List<int> midis;
  final List<double> beats;
  final List<int> phraseBreaks;
}

/// 한국식 계이름 악보 표기법.
///
/// ```
/// 솔 솔 라 라 솔 솔 미-
/// 솔 솔 미 미 레--
/// ```
/// - 음: 도 레 미 파 솔 라 시 — 기본은 가운데 도 옥타브(C4~B4)
/// - 높은/낮은 옥타브: `도'`, `솔,` 또는 `높은도`, `낮은솔` (여러 번 가능)
/// - 반음: `도#`, `미b`
/// - 길이: 기본 1박, `-` 하나당 +1박, `_` 반박, `.` 점음표(1.5배)
/// - 줄바꿈 또는 `/`: 소절 나누기, `|`: 무시(마디선)
/// - 영어 음이름도 가능: `G4`, `C#5`, `A` (숫자 생략 시 4옥타브)
class Notation {
  const Notation._();

  static const Map<String, int> _solfege = {'도': 0, '레': 2, '미': 4, '파': 5, '솔': 7, '라': 9, '시': 11};
  static const Map<String, int> _letters = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
  static const int _middleC = 60;

  static ParsedNotation parse(String text) {
    final midis = <int>[];
    final beats = <double>[];
    final breaks = <int>[];
    var i = 0;
    var octavePrefix = 0;

    void phraseBreak() {
      if (midis.isNotEmpty && (breaks.isEmpty || breaks.last != midis.length)) {
        breaks.add(midis.length);
      }
    }

    while (i < text.length) {
      final ch = text[i];
      if (ch == '\n' || ch == '/') {
        phraseBreak();
        i++;
        continue;
      }
      if (ch.trim().isEmpty || ch == '|') {
        i++;
        continue;
      }
      if (text.startsWith('높은', i)) {
        octavePrefix++;
        i += 2;
        continue;
      }
      if (text.startsWith('낮은', i)) {
        octavePrefix--;
        i += 2;
        continue;
      }

      final start = i;
      int pitchClass;
      int? explicitOctave;
      var accidental = 0;
      if (_solfege.containsKey(ch)) {
        pitchClass = _solfege[ch]!;
        i++;
      } else if (_letters.containsKey(ch)) {
        pitchClass = _letters[ch]!;
        i++;
        // 영어 표기는 반음 기호가 옥타브 숫자 앞에 온다: C#5, Bb3
        while (i < text.length && '#♯b♭'.contains(text[i])) {
          accidental += '#♯'.contains(text[i]) ? 1 : -1;
          i++;
        }
        if (i < text.length && _isDigit(text[i])) {
          explicitOctave = int.parse(text[i]);
          i++;
        }
      } else {
        throw FormatException("알 수 없는 기호 '$ch' (${start + 1}번째 글자)", text, start);
      }

      var octaveShift = octavePrefix;
      var dashes = 0;
      var half = false;
      var dotted = false;
      octavePrefix = 0;
      modifiers:
      while (i < text.length) {
        switch (text[i]) {
          case '#' || '♯':
            accidental++;
          case 'b' || '♭':
            accidental--;
          case "'" || '’' || '^':
            octaveShift++;
          case ',':
            octaveShift--;
          case '-' || '~':
            dashes++;
          case '_':
            half = true;
          case '.':
            dotted = true;
          default:
            break modifiers;
        }
        i++;
      }

      final base = explicitOctave != null ? (explicitOctave + 1) * 12 : _middleC;
      final midi = base + pitchClass + accidental + 12 * octaveShift;
      if (midi < 36 || midi > 96) {
        throw FormatException("'${text.substring(start, i)}' 음이 너무 높거나 낮아요", text, start);
      }
      midis.add(midi);
      beats.add((half ? 0.5 : 1.0) * (dotted ? 1.5 : 1.0) + dashes);
    }
    if (breaks.isNotEmpty && breaks.last == midis.length) breaks.removeLast();
    return ParsedNotation(midis: midis, beats: beats, phraseBreaks: breaks);
  }

  /// 피아노 건반 하나를 악보 토큰으로 (예: 72 → "도'", 55 → "솔,", 61 → "도#").
  static String tokenFor(int midi) {
    final note = Note(midi);
    final shift = note.octave - 4;
    return note.solfege + (shift > 0 ? "'" * shift : ',' * -shift);
  }

  /// 가사를 음절로 나눈다. 한글은 한 글자 = 한 음, 영어는 단어 또는 '-'로 나눈 음절.
  static List<String> syllables(String lyrics) {
    final out = <String>[];
    final buffer = StringBuffer();
    void flush() {
      if (buffer.isNotEmpty) {
        out.add(buffer.toString());
        buffer.clear();
      }
    }

    for (final rune in lyrics.runes) {
      final c = String.fromCharCode(rune);
      if (rune >= 0xAC00 && rune <= 0xD7A3) {
        flush();
        out.add(c);
      } else if (RegExp(r"[A-Za-z0-9']").hasMatch(c)) {
        buffer.write(c);
      } else {
        flush();
      }
    }
    flush();
    return out;
  }

  static bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
}
