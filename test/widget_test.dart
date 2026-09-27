import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/main.dart';
import 'package:pitch_coach/models/pitch_reading.dart';
import 'package:pitch_coach/models/song.dart';
import 'package:pitch_coach/services/melody_matcher.dart';
import 'package:pitch_coach/views/result_view.dart';

void main() {
  testWidgets('홈 화면에 두 가지 모드가 표시된다', (tester) async {
    await tester.pumpWidget(const PitchCoachApp());
    await tester.pumpAndSettle();
    expect(find.text('🎤 음치탈출'), findsOneWidget);
    expect(find.text('기본 연습 모드'), findsOneWidget);
    expect(find.text("'학교종' 부르기"), findsOneWidget);
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
