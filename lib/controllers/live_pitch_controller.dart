import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/pitch_reading.dart';
import '../services/permission_service.dart';
import '../services/pitch_service.dart';

/// 화면에서 쓰는 실시간 피치 상태: 그래프 히스토리, 마지막 유성음, 화면 중심 음높이.
class LivePitchController extends ChangeNotifier {
  LivePitchController({PitchService? service, this.maxHistory = 220, double initialCenter = 65})
      : _service = service ?? PitchService(),
        _center = initialCenter;

  final PitchService _service;
  final int maxHistory;

  final List<double?> history = [];

  /// start() 이후 받은 모든 측정값 (곡 채점용).
  final List<PitchReading> recording = [];

  StreamSubscription<PitchReading>? _subscription;
  PitchReading? _current;
  PitchReading? _lastVoiced;
  double _center;
  bool _running = false;
  bool _disposed = false;
  DateTime _suppressUntil = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isRunning => _running;
  PitchReading? get current => _current;

  /// 현재 유성음이거나, 없으면 직전 유성음.
  PitchReading? get lastVoiced => _lastVoiced;
  bool get isVoicedNow => _current?.isVoiced ?? false;
  double get centerMidi => _center;

  /// 마이크 권한을 확인하고 측정을 시작한다. 권한이 없으면 해당 상태를 반환한다.
  Future<MicPermission> start() async {
    final permission = await PermissionService.ensureMicrophone();
    if (permission != MicPermission.granted) return permission;

    history.clear();
    recording.clear();
    _current = null;
    _lastVoiced = null;
    _subscription ??= _service.readings.listen(_onReading);
    await _service.start();
    _running = true;
    _notify();
    return permission;
  }

  Future<void> stop() async {
    await _service.stop();
    _running = false;
    _current = null;
    _notify();
  }

  /// 피아노 소리가 스피커에서 나는 동안 마이크 입력을 무시한다.
  /// (스피커 소리를 사용자 목소리로 오인하지 않도록)
  void suppressInput(Duration duration) {
    final until = DateTime.now().add(duration);
    if (until.isAfter(_suppressUntil)) _suppressUntil = until;
  }

  bool get isSuppressed => DateTime.now().isBefore(_suppressUntil);

  void _onReading(PitchReading reading) {
    if (!_running) return;
    if (isSuppressed) {
      _current = null;
      history.add(null);
      if (history.length > maxHistory) history.removeAt(0);
      _notify();
      return;
    }
    _current = reading;
    recording.add(reading);
    history.add(reading.midi);
    if (history.length > maxHistory) history.removeAt(0);

    final midi = reading.midi;
    if (midi != null) {
      _lastVoiced = reading;
      // 부드럽게 따라가되, 화면 밖으로 나가면 바로 당겨온다.
      _center += (midi - _center) * 0.08;
      if ((midi - _center).abs() > 6) _center = midi;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}
