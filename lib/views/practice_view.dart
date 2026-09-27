import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/live_pitch_controller.dart';
import '../models/note.dart';
import '../services/permission_service.dart';
import '../services/piano_service.dart';
import 'permission_prompt.dart';
import 'widgets/note_display.dart';
import 'widgets/piano_keyboard.dart';
import 'widgets/pitch_graph.dart';
import 'widgets/tuner_gauge.dart';

/// 기본 연습 모드: 실시간 음정 + 튜너 게이지 + 피치 그래프 + 피아노.
///
/// 피아노 건반을 누르면 그 음이 울리고 목표 음이 된다. 목표 음을 따라 불러 보며
/// 음높이 감각을 익힌다.
class PracticeView extends StatefulWidget {
  const PracticeView({super.key});

  @override
  State<PracticeView> createState() => _PracticeViewState();
}

class _PracticeViewState extends State<PracticeView> {
  final _controller = LivePitchController();
  final _piano = PianoService.instance;

  int _pianoLow = 48; // C3
  int? _target;
  int? _pressed;
  Timer? _pressedTimer;

  @override
  void initState() {
    super.initState();
    _piano.preload([for (var m = 48; m <= 72; m++) m.toDouble()]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _toggle());
  }

  @override
  void dispose() {
    _pressedTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_controller.isRunning) {
      await _controller.stop();
      return;
    }
    final permission = await _controller.start();
    if (permission != MicPermission.granted && mounted) {
      await showPermissionDeniedDialog(context, permission);
    }
  }

  void _playKey(int midi, {bool setTarget = true}) {
    // 피아노 소리를 내 목소리로 오인하지 않도록 잠시 마이크 분석을 멈춘다.
    _controller.suppressInput(const Duration(milliseconds: 1200));
    _piano.playNote(midi.toDouble());
    _pressedTimer?.cancel();
    setState(() {
      _pressed = midi;
      if (setTarget) _target = midi;
    });
    _pressedTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _pressed = null);
    });
  }

  String _guidance(double? midi) {
    final target = _target;
    if (target == null) {
      if (midi != null && ((midi - midi.round()) * 100).abs() <= 10) return '정확해요! 이 음을 유지해 보세요 👍';
      return '건반을 누르면 소리가 나고, 그 음이 목표 음이 돼요 🎹';
    }
    final name = '${Note(target).solfege}(${Note(target).name})';
    if (midi == null) return _controller.isSuppressed ? '잘 듣고… 🎧' : '$name 음을 따라 불러 보세요';
    final diff = midi - target;
    final cents = diff * 100;
    if (cents.abs() <= 25) return '목표 음 성공! 🎯 그대로 유지해요';
    // 한 옥타브 차이는 같은 음이름 — 남성/여성 음역 차이일 수 있다.
    final octaveDiff = diff - 12 * (diff / 12).round();
    if ((diff / 12).round() != 0 && (octaveDiff * 100).abs() <= 25) {
      return '음이름은 맞아요! (${diff > 0 ? '한 옥타브 위' : '한 옥타브 아래'}) 👌';
    }
    final up = diff < 0;
    final arrow = up ? '↑ 더 높게' : '↓ 더 낮게';
    if (diff.abs() < 1) return '조금만 $arrow';
    return '${diff.abs().round()}반음 $arrow';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('기본 연습 모드')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final shown = _controller.lastVoiced;
            final voiced = _controller.isVoicedNow;
            final sungMidi = voiced ? shown?.midi : null;
            if (sungMidi != null) _pianoLow = PianoLayout.follow(_pianoLow, sungMidi);

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  NoteDisplay(reading: shown, active: voiced, compact: true),
                  const SizedBox(height: 8),
                  TunerGauge(cents: voiced ? shown?.cents : null, height: 48),
                  const SizedBox(height: 6),
                  Text(
                    _guidance(sungMidi),
                    style: theme.textTheme.titleSmall!.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: PitchGraph(
                      history: _controller.history,
                      centerMidi: _controller.centerMidi,
                      visibleFrames: _controller.maxHistory,
                      highlightPitchClasses: _target == null ? const {} : {_target! % 12},
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PianoHeader(
                    low: _pianoLow,
                    target: _target,
                    onShift: (delta) => setState(() => _pianoLow = (_pianoLow + delta).clamp(24, 84)),
                    onReplay: _target == null ? null : () => _playKey(_target!),
                    onClear: _target == null ? null : () => setState(() => _target = null),
                  ),
                  PianoKeyboard(
                    lowMidi: _pianoLow,
                    sungMidi: sungMidi,
                    targetMidi: _target,
                    pressedMidi: _pressed,
                    onKeyTap: _playKey,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _toggle,
                      icon: Icon(_controller.isRunning ? Icons.stop_rounded : Icons.mic_rounded),
                      label: Text(_controller.isRunning ? '멈추기' : '듣기 시작'),
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

/// 건반 위: 옥타브 이동, 목표 음, 다시 듣기/해제.
class _PianoHeader extends StatelessWidget {
  const _PianoHeader({
    required this.low,
    required this.target,
    required this.onShift,
    required this.onReplay,
    required this.onClear,
  });

  final int low;
  final int? target;
  final ValueChanged<int> onShift;
  final VoidCallback? onReplay;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = target;
    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: '한 옥타브 아래',
          onPressed: () => onShift(-12),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text('${Note(low).name}–${Note(low + 24).name}', style: theme.textTheme.labelMedium),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: '한 옥타브 위',
          onPressed: () => onShift(12),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        const Spacer(),
        if (t != null) ...[
          Text('🎯 ${Note(t).solfege} ${Note(t).name}',
              style: theme.textTheme.labelLarge!.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '다시 듣기',
            onPressed: onReplay,
            icon: const Icon(Icons.volume_up_rounded),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: '목표 해제',
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ],
    );
  }
}
