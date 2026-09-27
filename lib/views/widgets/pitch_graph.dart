import 'package:flutter/material.dart';

import '../../models/note.dart';

/// 최근 피치 흐름을 오른쪽으로 흘러가는 선 그래프로 그린다.
/// 가로줄 하나가 반음 하나이며, [highlightPitchClasses]에 속한 음은 강조한다.
class PitchGraph extends StatelessWidget {
  const PitchGraph({
    super.key,
    required this.history,
    required this.centerMidi,
    this.visibleFrames = 220,
    this.span = 14,
    this.highlightPitchClasses = const {},
  });

  /// 오래된 것 → 최신 순의 실수 MIDI 값 (무성은 null).
  final List<double?> history;
  final double centerMidi;
  final int visibleFrames;

  /// 화면에 보이는 반음 수.
  final double span;
  final Set<int> highlightPitchClasses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        child: CustomPaint(
          size: Size.infinite,
          painter: _PitchGraphPainter(
            history: history,
            centerMidi: centerMidi,
            visibleFrames: visibleFrames,
            span: span,
            highlight: highlightPitchClasses,
            scheme: theme.colorScheme,
            labelStyle: theme.textTheme.labelSmall!,
          ),
        ),
      ),
    );
  }
}

class _PitchGraphPainter extends CustomPainter {
  _PitchGraphPainter({
    required this.history,
    required this.centerMidi,
    required this.visibleFrames,
    required this.span,
    required this.highlight,
    required this.scheme,
    required this.labelStyle,
  });

  final List<double?> history;
  final double centerMidi;
  final int visibleFrames;
  final double span;
  final Set<int> highlight;
  final ColorScheme scheme;
  final TextStyle labelStyle;

  static const double _labelWidth = 44;

  @override
  void paint(Canvas canvas, Size size) {
    final low = centerMidi - span / 2;
    final laneHeight = size.height / span;
    double yFor(double midi) => size.height * (1 - (midi - low) / span);

    // 반음 레인
    for (var m = low.floor(); m <= (low + span).ceil(); m++) {
      final y = yFor(m.toDouble());
      final note = Note(m);
      final isHighlight = highlight.contains(note.pitchClass);
      if (isHighlight) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset(size.width / 2, y), width: size.width, height: laneHeight * 0.8),
          Paint()..color = scheme.primary.withValues(alpha: 0.10),
        );
      }
      final isNatural = !note.name.contains('#');
      canvas.drawLine(
        Offset(_labelWidth, y),
        Offset(size.width, y),
        Paint()
          ..color = scheme.outlineVariant.withValues(alpha: isNatural ? 0.8 : 0.35)
          ..strokeWidth = isNatural ? 1 : 0.6,
      );
      if (isNatural || isHighlight) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${note.solfege} ${note.name}',
            style: labelStyle.copyWith(
              color: isHighlight ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: _labelWidth);
        tp.paint(canvas, Offset(4, y - tp.height / 2));
      }
    }

    // 피치 선
    if (history.isEmpty) return;
    final plotWidth = size.width - _labelWidth;
    final dx = plotWidth / (visibleFrames - 1);
    final start = history.length > visibleFrames ? history.length - visibleFrames : 0;
    final line = Paint()
      ..color = scheme.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Path? path;
    for (var i = start; i < history.length; i++) {
      final midi = history[i];
      final x = size.width - (history.length - 1 - i) * dx;
      if (midi == null) {
        if (path != null) canvas.drawPath(path, line);
        path = null;
        continue;
      }
      final y = yFor(midi);
      if (path == null) {
        path = Path()..moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    if (path != null) canvas.drawPath(path, line);

    final last = history.last;
    if (last != null) {
      canvas.drawCircle(Offset(size.width - 2, yFor(last)), 6, Paint()..color = scheme.primary);
    }
  }

  // history는 호출 측에서 제자리 갱신되므로 새 프레임마다 다시 그린다.
  @override
  bool shouldRepaint(_PitchGraphPainter old) => true;
}
