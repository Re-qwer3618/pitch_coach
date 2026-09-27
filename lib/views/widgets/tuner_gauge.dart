import 'package:flutter/material.dart';

/// -50 ~ +50센트 범위를 보여주는 수평 튜너 게이지.
class TunerGauge extends StatelessWidget {
  const TunerGauge({super.key, required this.cents, this.height = 56});

  /// null이면 바늘을 숨긴다.
  final double? cents;
  final double height;

  static Color colorFor(double cents, ColorScheme scheme) {
    final c = cents.abs();
    if (c <= 10) return Colors.green;
    if (c <= 25) return Colors.orange;
    return scheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: (cents ?? 0).clamp(-50.0, 50.0)),
        duration: const Duration(milliseconds: 90),
        builder: (context, value, _) => CustomPaint(
          size: Size.infinite,
          painter: _GaugePainter(
            cents: cents == null ? null : value,
            scheme: scheme,
            textStyle: Theme.of(context).textTheme.labelSmall!,
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.cents, required this.scheme, required this.textStyle});

  final double? cents;
  final ColorScheme scheme;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const labelHeight = 16.0;
    final barTop = 8.0;
    final barHeight = size.height - labelHeight - barTop;
    double xFor(double c) => size.width * (c + 50) / 100;

    // 구간 배경: 빨강 | 주황 | 초록 | 주황 | 빨강
    final zones = <(double, double, Color)>[
      (-50, -25, scheme.error.withValues(alpha: 0.18)),
      (-25, -10, Colors.orange.withValues(alpha: 0.22)),
      (-10, 10, Colors.green.withValues(alpha: 0.28)),
      (10, 25, Colors.orange.withValues(alpha: 0.22)),
      (25, 50, scheme.error.withValues(alpha: 0.18)),
    ];
    final clip = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, barTop, size.width, barHeight),
      const Radius.circular(10),
    );
    canvas.save();
    canvas.clipRRect(clip);
    for (final (from, to, color) in zones) {
      canvas.drawRect(Rect.fromLTRB(xFor(from), barTop, xFor(to), barTop + barHeight), Paint()..color = color);
    }
    canvas.restore();

    // 눈금
    final tick = Paint()
      ..color = scheme.onSurfaceVariant.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (var c = -50; c <= 50; c += 10) {
      final x = xFor(c.toDouble());
      final len = c == 0 ? barHeight : barHeight * 0.35;
      canvas.drawLine(Offset(x, barTop + barHeight - len), Offset(x, barTop + barHeight), tick);
    }
    for (final c in [-50, -25, 0, 25, 50]) {
      final tp = TextPainter(
        text: TextSpan(text: c > 0 ? '+$c' : '$c', style: textStyle.copyWith(color: scheme.onSurfaceVariant)),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (xFor(c.toDouble()) - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(x, size.height - labelHeight + 2));
    }

    // 바늘
    if (cents != null) {
      final x = xFor(cents!);
      final color = TunerGauge.colorFor(cents!, scheme);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, barTop + barHeight),
        Paint()
          ..color = color
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(Offset(x, 4), 6, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.cents != cents || old.scheme != scheme;
}
