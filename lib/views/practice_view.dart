import 'package:flutter/material.dart';

import '../controllers/live_pitch_controller.dart';
import '../services/permission_service.dart';
import 'permission_prompt.dart';
import 'widgets/note_display.dart';
import 'widgets/pitch_graph.dart';
import 'widgets/tuner_gauge.dart';

/// 기본 연습 모드: 실시간 음정 표시 + 튜너 게이지 + 피치 흐름 그래프.
class PracticeView extends StatefulWidget {
  const PracticeView({super.key});

  @override
  State<PracticeView> createState() => _PracticeViewState();
}

class _PracticeViewState extends State<PracticeView> {
  final _controller = LivePitchController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _toggle());
  }

  @override
  void dispose() {
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
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  NoteDisplay(reading: shown, active: _controller.isVoicedNow),
                  const SizedBox(height: 16),
                  TunerGauge(cents: _controller.isVoicedNow ? shown?.cents : null),
                  const SizedBox(height: 8),
                  Text(
                    _controller.isVoicedNow && (shown?.cents?.abs() ?? 99) <= 10
                        ? '정확해요! 이 음을 유지해 보세요 👍'
                        : '바늘을 가운데 초록 구간에 맞춰 보세요',
                    style: theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: PitchGraph(
                      history: _controller.history,
                      centerMidi: _controller.centerMidi,
                      visibleFrames: _controller.maxHistory,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
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
