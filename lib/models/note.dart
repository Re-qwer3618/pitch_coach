import 'dart:math' as math;

/// 음이름 · 주파수 · MIDI 번호 사이의 변환을 담당하는 값 객체.
///
/// MIDI 69 = A4 = 440Hz 기준 12평균율을 사용한다.
class Note {
  const Note(this.midi);

  /// 'G4', 'C#5', 'Bb3' 형태의 음이름을 파싱한다.
  factory Note.parse(String name) {
    final match = RegExp(r'^([A-Ga-g])(#|b)?(-?\d+)$').firstMatch(name.trim());
    if (match == null) {
      throw FormatException('잘못된 음이름: $name');
    }
    const base = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
    var pitchClass = base[match.group(1)!.toUpperCase()]!;
    if (match.group(2) == '#') pitchClass++;
    if (match.group(2) == 'b') pitchClass--;
    final octave = int.parse(match.group(3)!);
    return Note((octave + 1) * 12 + pitchClass);
  }

  static const List<String> names = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', //
  ];
  static const List<String> solfegeNames = [
    '도', '도#', '레', '레#', '미', '파', '파#', '솔', '솔#', '라', '라#', '시', //
  ];
  static const double a4Frequency = 440.0;

  final int midi;

  int get pitchClass => midi % 12;
  int get octave => midi ~/ 12 - 1;
  String get name => '${names[pitchClass]}$octave';
  String get solfege => solfegeNames[pitchClass];
  double get frequency => midiToFrequency(midi.toDouble());

  /// 주파수(Hz) → 실수 MIDI 값. 소수부가 센트 오차를 나타낸다.
  static double frequencyToMidi(double frequency) =>
      69 + 12 * math.log(frequency / a4Frequency) / math.ln2;

  static double midiToFrequency(double midi) =>
      a4Frequency * math.pow(2, (midi - 69) / 12).toDouble();

  @override
  bool operator ==(Object other) => other is Note && other.midi == midi;

  @override
  int get hashCode => midi.hashCode;

  @override
  String toString() => name;
}
