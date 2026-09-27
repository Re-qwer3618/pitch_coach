import 'package:flutter/material.dart';

import '../controllers/live_pitch_controller.dart';
import '../models/song.dart';
import '../services/melody_matcher.dart';
import '../services/permission_service.dart';
import '../services/piano_service.dart';
import 'permission_prompt.dart';
import 'result_view.dart';
import 'widgets/note_display.dart';
import 'widgets/piano_keyboard.dart';
import 'widgets/pitch_graph.dart';

/// '학교종' 곡 연습: 피아노로 멜로디 듣기 → 녹음 → 종료 시 목표 멜로디와 비교해 채점.
class SongView extends StatefulWidget {
  const SongView({super.key, required this.song});

  final Song song;

  @override
  State<SongView> createState() => _SongViewState();
}

class _SongViewState extends State<SongView> {
  final _controller = LivePitchController(initialCenter: 65);
  final _matcher = const MelodyMatcher();
  final _piano = PianoService.instance;

  /// 지금까지 분리된 음표 개수 (진행 표시용).
  int _sungCount = 0;
  int _lastSegmentedAt = 0;

  /// 피아노로 재생 중인 음표 인덱스.
  int? _playingIndex;
  bool _melodyPlaying = false;
  int _pianoLow = 48; // C3

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateProgress);
    _piano.preload(widget.song.notes.map((n) => n.midi.toDouble()).toSet());
  }

  @override
  void dispose() {
    _piano.stopSequence();
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

  Future<void> _playMelody() async {
    if (_melodyPlaying) {
      await _piano.stopSequence();
      _endPlayback();
      return;
    }
    final song = widget.song;
    setState(() => _melodyPlaying = true);
    await _piano.playSequence(
      [for (var i = 0; i < song.notes.length; i++) (midi: song.notes[i].midi.toDouble(), duration: song.durationOf(i))],
      onStep: (i) {
        if (mounted) setState(() => _playingIndex = i);
      },
    );
    _endPlayback();
  }

  void _endPlayback() {
    if (!mounted) return;
    setState(() {
      _melodyPlaying = false;
      _playingIndex = null;
    });
  }

  Future<void> _playSingle(int index) async {
    if (_melodyPlaying || _controller.isRunning) return;
    setState(() => _playingIndex = index);
    await _piano.playNote(widget.song.notes[index].midi.toDouble());
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted && !_melodyPlaying) setState(() => _playingIndex = null);
  }

  Future<void> _start() async {
    if (_melodyPlaying) await _playMelody(); // 재생 중이면 멈춘다
    _sungCount = 0;
    _lastSegmentedAt = 0;
    final permission = await _controller.start();
    if (permission != MicPermission.granted) {
      if (mounted) await showPermissionDeniedDialog(context, permission);
      return;
    }
    // 시작음을 들려주고, 그동안은 스피커 소리가 녹음되지 않게 한다.
    _controller.suppressInput(const Duration(milliseconds: 1300));
    await _piano.playNote(widget.song.notes.first.midi.toDouble());
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
            final sungMidi = _controller.isVoicedNow ? _controller.lastVoiced?.midi : null;
            if (sungMidi != null) _pianoLow = PianoLayout.follow(_pianoLow, sungMidi);

            final highlightIndex = _playingIndex ?? currentIndex;
            final targetIndex = _playingIndex ?? (recording ? currentIndex : 0);

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                children: [
                  _SheetView(
                    song: song,
                    currentIndex: highlightIndex,
                    doneCount: recording ? _sungCount - 1 : 0,
                    onTap: recording ? null : _playSingle,
                  ),
                  const SizedBox(height: 8),
                  if (recording)
                    NoteDisplay(reading: _controller.lastVoiced, active: _controller.isVoicedNow, compact: true)
                  else
                    Card(
                      color: theme.colorScheme.secondaryContainer,
                      margin: EdgeInsets.zero,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('먼저 [멜로디 듣기]로 피아노 소리를 들어 보세요. 가사를 누르면 그 음만 들려줘요. '
                                  '녹음을 시작하면 첫 음(솔)이 울린 뒤 부르면 돼요.'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: PitchGraph(
                      history: _controller.history,
                      centerMidi: _controller.centerMidi,
                      visibleFrames: _controller.maxHistory,
                      highlightPitchClasses: song.pitchClasses,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PianoKeyboard(
                    lowMidi: _pianoLow,
                    height: 104,
                    sungMidi: sungMidi,
                    targetMidi: song.notes[targetIndex].midi,
                    pressedMidi: _playingIndex == null ? null : song.notes[_playingIndex!].midi,
                    onKeyTap: recording || _melodyPlaying ? null : (m) => _piano.playNote(m.toDouble()),
                  ),
                  const SizedBox(height: 10),
                  if (!recording) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _playMelody,
                            icon: Icon(_melodyPlaying ? Icons.stop_rounded : Icons.piano_rounded),
                            label: Text(_melodyPlaying ? '그만 듣기' : '멜로디 듣기'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _melodyPlaying ? null : () => _playSingle(0),
                            icon: const Icon(Icons.music_note_rounded),
                            label: const Text('첫 음 듣기'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 52,
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

/// 가사 + 계이름 악보. 진행 중인 음표를 강조하고, 누르면 그 음을 들려준다.
class _SheetView extends StatelessWidget {
  const _SheetView({required this.song, required this.currentIndex, required this.doneCount, this.onTap});

  final Song song;
  final int currentIndex;
  final int doneCount;
  final ValueChanged<int>? onTap;

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
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final i in phrase)
                  Flexible(
                    child: GestureDetector(
                      onTap: onTap == null ? null : () => onTap!(i),
                      child: _NoteChip(song: song, index: i, state: _stateOf(i)),
                    ),
                  ),
              ],
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
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 5),
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
