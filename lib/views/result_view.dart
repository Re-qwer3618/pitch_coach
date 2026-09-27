import 'package:flutter/material.dart';

import '../models/match_result.dart';
import '../models/song.dart';

/// 곡 채점 결과: 일치율, 총평, 팁, 음표별 비교.
class ResultView extends StatelessWidget {
  const ResultView({super.key, required this.song, required this.result});

  final Song song;
  final MatchResult result;

  Color _scoreColor(ColorScheme scheme) {
    if (result.score >= 75) return Colors.green;
    if (result.score >= 50) return Colors.orange;
    return scheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _scoreColor(scheme);

    return Scaffold(
      appBar: AppBar(title: const Text('채점 결과')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: result.score),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => SizedBox(
                  width: 180,
                  height: 180,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: value / 100,
                        strokeWidth: 14,
                        strokeCap: StrokeCap.round,
                        color: color,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${value.round()}%',
                                style: theme.textTheme.displayMedium!.copyWith(fontWeight: FontWeight.w800, color: color)),
                            Text('일치율', style: theme.textTheme.labelLarge),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(result.headline, textAlign: TextAlign.center, style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (result.tips.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('피드백', style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      for (final tip in result.tips)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('•  '),
                              Expanded(child: Text(tip, style: theme.textTheme.bodyMedium)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text('음표별 비교', style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _Legend(),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.78,
              children: [for (final m in result.notes) _NoteResultTile(match: m)],
            ),
            const SizedBox(height: 8),
            Text(
              '인식된 음표 ${result.detectedNoteCount}개 · 목표 ${song.notes.length}개',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('홈으로'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('다시 부르기'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Color gradeColor(NoteGrade grade, ColorScheme scheme) => switch (grade) {
      NoteGrade.perfect => Colors.green,
      NoteGrade.good => Colors.lightGreen.shade700,
      NoteGrade.off => Colors.orange.shade800,
      NoteGrade.missed => scheme.outline,
    };

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const labels = {
      NoteGrade.perfect: '정확 (±30¢)',
      NoteGrade.good: '양호 (±60¢)',
      NoteGrade.off: '벗어남',
      NoteGrade.missed: '인식 안 됨',
    };
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final e in labels.entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: gradeColor(e.key, scheme), shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(e.value, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
      ],
    );
  }
}

class _NoteResultTile extends StatelessWidget {
  const _NoteResultTile({required this.match});

  final NoteMatch match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = gradeColor(match.grade, theme.colorScheme);
    final cents = match.centsError?.round();
    final sung = match.sungNote;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(match.lyric, style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold)),
          Text('${match.target.solfege} ${match.target.name}', style: theme.textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            sung == null ? '—' : '→ ${sung.name}',
            style: theme.textTheme.labelMedium!.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
          Text(
            cents == null ? '미인식' : '${cents > 0 ? '+' : ''}$cents¢',
            style: theme.textTheme.labelSmall!.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
