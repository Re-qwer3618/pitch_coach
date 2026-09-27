import 'package:flutter/material.dart';

import '../controllers/live_pitch_controller.dart';
import '../models/song.dart';
import '../services/melody_matcher.dart';
import '../services/permission_service.dart';
import 'permission_prompt.dart';
import 'result_view.dart';
import 'widgets/note_display.dart';
import 'widgets/pitch_graph.dart';

/// '학교종' 곡 연습: 녹음 → 종료 시 목표 멜로디와 비교해 채점.
class SongView extends StatefulWidget {
  const SongView({super.key, required this.song});

  final Song song;

  @override
  State<SongView> createState() => _SongViewState();
}

class _SongViewState extends State<SongView> {
  final _controller = LivePitchController(initialCenter: 65);
  final _matcher = const MelodyMatcher();

  /// 지금까지 분리된 음표 개수 (진행 표시용).
  int _sungCount = 0;
  int _lastSegmentedAt = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateProgress);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateProgress);
    _controller.dispose();
    super.dispose();
  }

  void _updateProgress() {
    final length = _controller.recording.length;
    // 8프레임(≈0.2초)마다 한 번씩만 다시 분할한다.
    if (length - _lastSegmentedAt < 8) return;
    _lastSegmentedAt = length;
    _sungCount = _matcher.segment(_controller.recording).length;
  }

  Future<void> _start() async {
    _sungCount = 0;
    _lastSegmentedAt = 0;
    final permission = await _controller.start();
    if (permission != MicPermission.granted && mounted) {
      await showPermissionDeniedDialog(context, permission);
    }
  }

  Future<void> _finish() async {
    await _controller.stop();
    final result = _matcher.evaluate(widget.song, List.of(_controller.recording));
    if (!mounted) return;
    final retry = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ResultView(song: widget.song, result: result)),
    );
    if (!mounted) return;
    setState(() => _sungCount = 0);
    if (retry == true) {
      await _start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final song = widget.song;
    return Scaffold(
      appBar: AppBar(title: Text("'${song.title}' 부르기")),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final recording = _controller.isRunning;
            final currentIndex = recording ? (_sungCount - 1).clamp(0, song.notes.length - 1) : -1;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  _SheetView(song: song, currentIndex: currentIndex, doneCount: recording ? _sungCount - 1 : 0),
                  const SizedBox(height: 12),
                  if (!recording)
                    Card(
                      color: theme.colorScheme.secondaryContainer,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('첫 음은 솔(G4 · 392Hz)이에요. 녹음을 시작하고 가사대로 또박또박 불러 주세요. '
                                  '다 부르면 [녹음 종료]를 누르세요.'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    NoteDisplay(reading: _controller.lastVoiced, active: _controller.isVoicedNow, compact: true),
                  const SizedBox(height: 12),
                  Expanded(
                    child: PitchGraph(
                      history: _controller.history,
                      centerMidi: _controller.centerMidi,
                      visibleFrames: _controller.maxHistory,
                      highlightPitchClasses: song.pitchClasses,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: recording
                        ? FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                            onPressed: _finish,
                            icon: const Icon(Icons.stop_rounded),
                            label: const Text('녹음 종료 & 채점'),
                          )
                        : FilledButton.icon(
                            onPressed: _start,
                            icon: const Icon(Icons.fiber_manual_record_rounded),
                            label: const Text('녹음 시작'),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 가사 + 계이름 악보. 진행 중인 음표를 강조한다.
class _SheetView extends StatelessWidget {
  const _SheetView({required this.song, required this.currentIndex, required this.doneCount});

  final Song song;
  final int currentIndex;
  final int doneCount;

  @override
  Widget build(BuildContext context) {
    final phrases = <List<int>>[];
    var start = 0;
    for (final b in [...song.phraseBreaks, song.notes.length]) {
      phrases.add([for (var i = start; i < b; i++) i]);
      start = b;
    }
    return Column(
      children: [
        for (final phrase in phrases)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [for (final i in phrase) Flexible(child: _NoteChip(song: song, index: i, state: _stateOf(i)))],
            ),
          ),
      ],
    );
  }

  _ChipState _stateOf(int i) {
    if (i == currentIndex) return _ChipState.current;
    if (i < doneCount) return _ChipState.done;
    return _ChipState.upcoming;
  }
}

enum _ChipState { upcoming, current, done }

class _NoteChip extends StatelessWidget {
  const _NoteChip({required this.song, required this.index, required this.state});

  final Song song;
  final int index;
  final _ChipState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final note = song.notes[index];
    final (bg, fg) = switch (state) {
      _ChipState.current => (scheme.primary, scheme.onPrimary),
      _ChipState.done => (scheme.primaryContainer, scheme.onPrimaryContainer),
      _ChipState.upcoming => (scheme.surfaceContainerHighest, scheme.onSurface),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 6),
      constraints: const BoxConstraints(maxWidth: 52),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(song.lyrics[index], style: theme.textTheme.titleMedium!.copyWith(color: fg, fontWeight: FontWeight.bold)),
          Text(note.solfege, style: theme.textTheme.labelMedium!.copyWith(color: fg)),
          Text(note.name, style: theme.textTheme.labelSmall!.copyWith(color: fg.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}
