import 'note.dart';

/// 연습곡: 음표 시퀀스와 음표별 가사.
class Song {
  Song({
    required this.title,
    required List<String> noteNames,
    required this.lyrics,
    required this.beats,
    this.tempoBpm = 100,
    this.phraseBreaks = const [],
  })  : assert(noteNames.length == lyrics.length && noteNames.length == beats.length),
        notes = noteNames.map(Note.parse).toList(growable: false);

  final String title;
  final List<Note> notes;
  final List<String> lyrics;

  /// 음표별 박자 수 (4분음표 = 1).
  final List<double> beats;
  final double tempoBpm;

  /// 새 소절이 시작되는 음표 인덱스 (UI 줄바꿈용).
  final List<int> phraseBreaks;

  Set<int> get pitchClasses => notes.map((n) => n.pitchClass).toSet();

  Duration durationOf(int index) => Duration(milliseconds: (beats[index] * 60000 / tempoBpm).round());
}

/// 동요 '학교종' — 솔솔라라 솔솔미 / 솔솔미미 레
final Song schoolBellSong = Song(
  title: '학교종',
  noteNames: const [
    'G4', 'G4', 'A4', 'A4', 'G4', 'G4', 'E4', //
    'G4', 'G4', 'E4', 'E4', 'D4',
  ],
  lyrics: const [
    '학', '교', '종', '이', '땡', '땡', '땡', //
    '어', '서', '모', '이', '자',
  ],
  // 솔솔라라 | 솔솔미– | 솔솔미미 | 레–––
  beats: const [1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 3],
  phraseBreaks: const [7],
);
