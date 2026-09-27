import 'package:flutter/material.dart';

import '../../models/pitch_reading.dart';
import 'tuner_gauge.dart';

/// 현재 음이름 · 계이름 · Hz · 센트를 크게 보여준다.
class NoteDisplay extends StatelessWidget {
  const NoteDisplay({super.key, required this.reading, required this.active, this.compact = false});

  /// 표시할 측정값(마지막 유성음). null이면 대기 상태.
  final PitchReading? reading;

  /// false면 흐리게 표시(소리가 끊긴 직후).
  final bool active;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = reading;
    final note = r?.note;
    final cents = r?.cents;
    final color = cents == null ? scheme.onSurfaceVariant : TunerGauge.colorFor(cents, scheme);

    final noteStyle = (compact ? theme.textTheme.displaySmall : theme.textTheme.displayLarge)!
        .copyWith(fontWeight: FontWeight.w800, color: note == null ? scheme.outline : color);

    return AnimatedOpacity(
      opacity: active || r == null ? 1 : 0.45,
      duration: const Duration(milliseconds: 200),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(note?.name ?? '—', style: noteStyle),
              if (note != null) ...[
                const SizedBox(width: 12),
                Text(note.solfege, style: (compact ? theme.textTheme.titleLarge : theme.textTheme.headlineMedium)!.copyWith(color: color)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            r?.frequency == null
                ? '소리를 내 보세요'
                : '${r!.frequency!.toStringAsFixed(1)} Hz   ·   ${cents! >= 0 ? '+' : ''}${cents.round()}¢',
            style: theme.textTheme.titleMedium!.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
