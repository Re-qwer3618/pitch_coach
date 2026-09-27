import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/main.dart';
import 'package:pitch_coach/models/pitch_reading.dart';
import 'package:pitch_coach/data/built_in_songs.dart';
import 'package:pitch_coach/services/melody_matcher.dart';
import 'package:pitch_coach/views/result_view.dart';
import 'package:pitch_coach/views/song_editor_view.dart';
import 'package:pitch_coach/views/song_list_view.dart';
import 'package:pitch_coach/views/widgets/piano_keyboard.dart';

void main() {
  testWidgets('홈 화면에 두 가지 모드가 표시된다', (tester) async {
    await tester.pumpWidget(const PitchCoachApp());
    await tester.pumpAndSettle();
    expect(find.text('🎤 음치탈출'), findsOneWidget);
    expect(find.text('기본 연습 모드'), findsOneWidget);
    expect(find.text('노래 연습'), findsOneWidget);
  });

  testWidgets('노래 목록에 기본 곡과 내 노래 섹션이 보인다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SongListView()));
    await tester.pumpAndSettle();
    expect(find.text('학교종'), findsOneWidget);
    expect(find.text('작은별'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('아직 추가한 노래가 없어요.'), 300);
    expect(find.text('내 노래'), findsOneWidget);
  });

  testWidgets('노래 추가 화면: 건반을 누르면 악보에 음이 들어가고 미리 보기가 생긴다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SongEditorView()));
    await tester.pumpAndSettle();
    final piano = tester.getRect(find.byType(PianoKeyboard));
    final unit = piano.width / 15; // C3~C5, 흰 건반 15개
    await tester.tapAt(Offset(piano.left + unit * 11.5, piano.bottom - 8)); // G4
    await tester.tapAt(Offset(piano.left + unit * 12.5, piano.bottom - 8)); // A4
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(field.controller!.text, '솔 라');
    await tester.scrollUntilVisible(find.text('미리 보기'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('미리 보기'), findsOneWidget);
    expect(find.textContaining('2음'), findsOneWidget);
  });

  testWidgets('결과 화면이 점수와 12개 음표를 렌더링한다', (tester) async {
    final song = schoolBellSong;
    final readings = <PitchReading>[];
    var t = 0;
    for (final note in song.notes) {
      for (var k = 0; k < 15; k++) {
        readings.add(PitchReading(timeMs: t += 23, frequency: note.frequency, clarity: 1, rms: 0.1));
      }
      for (var k = 0; k < 4; k++) {
        readings.add(PitchReading(timeMs: t += 23, frequency: null, clarity: 0, rms: 0));
      }
    }
    final result = const MelodyMatcher().evaluate(song, readings);

    await tester.pumpWidget(MaterialApp(home: ResultView(song: song, result: result)));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('0¢'), findsNWidgets(12));
  });
}
