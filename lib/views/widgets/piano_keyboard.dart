import 'package:flutter/material.dart';

import '../../models/note.dart';
import 'tuner_gauge.dart';

/// 건반 배치 계산 (위젯 폭과 무관한 '흰 건반 단위' 좌표).
class PianoLayout {
  PianoLayout({required this.lowMidi, this.octaves = 2})
      : assert(lowMidi % 12 == 0, 'lowMidi는 C여야 한다'),
        highMidi = lowMidi + octaves * 12;

  final int lowMidi;
  final int octaves;

  /// 맨 오른쪽 C까지 포함.
  final int highMidi;

  static const List<int> _whiteIndexInOctave = [0, -1, 1, -1, 2, 3, -1, 4, -1, 5, -1, 6];

  static bool isBlack(int midi) => _whiteIndexInOctave[midi % 12] == -1;

  int get whiteKeyCount => octaves * 7 + 1;

  /// 흰 건반이면 자기 인덱스, 검은 건반이면 왼쪽 흰 건반 인덱스.
  int whiteIndex(int midi) {
    final octave = (midi - lowMidi) ~/ 12;
    var pc = midi % 12;
    if (isBlack(midi)) pc -= 1;
    return octave * 7 + _whiteIndexInOctave[pc];
  }

  /// 건반 중심 x (흰 건반 폭 = 1 단위).
  double centerX(int midi) => isBlack(midi) ? whiteIndex(midi) + 1.0 : whiteIndex(midi) + 0.5;

  /// 실수 MIDI의 x. 인접한 두 건반 중심 사이를 보간하므로 음이 어긋난 정도가 그대로 보인다.
  double cursorX(double midi) {
    final clamped = midi.clamp(lowMidi.toDouble(), highMidi.toDouble());
    final lo = clamped.floor();
    if (lo >= highMidi) return centerX(highMidi);
    final t = clamped - lo;
    return centerX(lo) + (centerX(lo + 1) - centerX(lo)) * t;
  }

  bool contains(double midi) => midi >= lowMidi - 0.5 && midi <= highMidi + 0.5;

  /// 탭 위치 → 건반. x는 흰 건반 단위, yRatio는 0(위)~1(아래).
  int? hitTest(double x, double yRatio) {
    if (x < 0 || x > whiteKeyCount) return null;
    if (yRatio < PianoKeyboard.blackKeyHeightRatio) {
      for (var m = lowMidi; m <= highMidi; m++) {
        if (isBlack(m) && (x - centerX(m)).abs() <= PianoKeyboard.blackKeyWidthRatio / 2) return m;
      }
    }
    final wi = x.floor().clamp(0, whiteKeyCount - 1);
    for (var m = lowMidi; m <= highMidi; m++) {
      if (!isBlack(m) && whiteIndex(m) == wi) return m;
    }
    return null;
  }

  /// [midi]가 보이도록 필요할 때만 창을 옥타브 단위로 옮긴다.
  static int follow(int currentLow, double midi, {int octaves = 2}) {
    if (midi < currentLow - 0.5) return (midi.round() ~/ 12) * 12;
    if (midi > currentLow + octaves * 12 + 0.5) return (midi.round() ~/ 12) * 12 - (octaves - 1) * 12;
    return currentLow;
  }
}

/// 피아노 건반. 목표 음·누른 음을 칠하고, 부르는 음을 연속 커서로 보여준다.
class PianoKeyboard extends StatelessWidget {
  const PianoKeyboard({
    super.key,
    required this.lowMidi,
    this.octaves = 2,
    this.sungMidi,
    this.targetMidi,
    this.pressedMidi,
    this.onKeyTap,
    this.height = 120,
  });

  static const double blackKeyHeightRatio = 0.6;
  static const double blackKeyWidthRatio = 0.6;

  final int lowMidi;
  final int octaves;

  /// 지금 부르는 음(실수 MIDI). null이면 커서 숨김.
  final double? sungMidi;
  final int? targetMidi;

  /// 방금 누른(재생 중인) 건반.
  final int? pressedMidi;
  final ValueChanged<int>? onKeyTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final layout = PianoLayout(lowMidi: lowMidi, octaves: octaves);
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final unit = constraints.maxWidth / layout.whiteKeyCount;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: onKeyTap == null
                ? null
                : (d) {
                    final midi = layout.hitTest(d.localPosition.dx / unit, d.localPosition.dy / height);
                    if (midi != null) onKeyTap!(midi);
                  },
            child: CustomPaint(
              size: Size(constraints.maxWidth, height),
              painter: _PianoPainter(
                layout: layout,
                sungMidi: sungMidi,
                targetMidi: targetMidi,
                pressedMidi: pressedMidi,
                scheme: scheme,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PianoPainter extends CustomPainter {
  _PianoPainter({
    required this.layout,
    required this.sungMidi,
    required this.targetMidi,
    required this.pressedMidi,
    required this.scheme,
  });

  final PianoLayout layout;
  final double? sungMidi;
  final int? targetMidi;
  final int? pressedMidi;
  final ColorScheme scheme;

  static const Color _pressed = Color(0xFFFFC107);

  Color? _fill(int midi) {
    if (midi == pressedMidi) return _pressed;
    final sung = sungMidi;
    if (sung != null && sung.round() == midi) {
      return TunerGauge.colorFor((sung - midi) * 100, scheme).withValues(alpha: 0.75);
    }
    if (midi == targetMidi) return scheme.primary.withValues(alpha: 0.55);
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / layout.whiteKeyCount;
    final border = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 흰 건반
    for (var m = layout.lowMidi; m <= layout.highMidi; m++) {
      if (PianoLayout.isBlack(m)) continue;
      final x = layout.whiteIndex(m) * unit;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, 0, unit, size.height),
        bottomLeft: const Radius.circular(5),
        bottomRight: const Radius.circular(5),
      );
      canvas.drawRRect(rect, Paint()..color = _fill(m) ?? Colors.white);
      canvas.drawRRect(rect, border);

      final note = Note(m);
      _label(canvas, note.solfege, Offset(x + unit / 2, size.height - 20), unit,
          bold: m == targetMidi, color: Colors.black87, fontSize: 11);
      if (note.pitchClass == 0) {
        _label(canvas, note.name, Offset(x + unit / 2, size.height - 34), unit, color: Colors.black45, fontSize: 9);
      }
    }

    // 검은 건반
    final bw = unit * PianoKeyboard.blackKeyWidthRatio;
    final bh = size.height * PianoKeyboard.blackKeyHeightRatio;
    for (var m = layout.lowMidi; m <= layout.highMidi; m++) {
      if (!PianoLayout.isBlack(m)) continue;
      final cx = layout.centerX(m) * unit;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - bw / 2, 0, bw, bh),
        bottomLeft: const Radius.circular(3),
        bottomRight: const Radius.circular(3),
      );
      canvas.drawRRect(rect, Paint()..color = _fill(m) ?? const Color(0xFF222222));
    }

    // 목표 음 표시(위쪽 삼각형)
    final target = targetMidi;
    if (target != null && target >= layout.lowMidi && target <= layout.highMidi) {
      final cx = layout.centerX(target) * unit;
      final path = Path()
        ..moveTo(cx - 7, 0)
        ..lineTo(cx + 7, 0)
        ..lineTo(cx, 10)
        ..close();
      canvas.drawPath(path, Paint()..color = scheme.primary);
    }

    // 부르는 음 커서
    final sung = sungMidi;
    if (sung != null && layout.contains(sung)) {
      final x = layout.cursorX(sung) * unit;
      final color = TunerGauge.colorFor((sung - sung.round()) * 100, scheme);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = color
          ..strokeWidth = 3,
      );
      canvas.drawCircle(Offset(x, 6), 6, Paint()..color = color);
      canvas.drawCircle(
        Offset(x, 6),
        6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _label(Canvas canvas, String text, Offset center, double maxWidth,
      {required Color color, double fontSize = 11, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_PianoPainter old) =>
      old.sungMidi != sungMidi ||
      old.targetMidi != targetMidi ||
      old.pressedMidi != pressedMidi ||
      old.layout.lowMidi != layout.lowMidi ||
      old.scheme != scheme;
}
