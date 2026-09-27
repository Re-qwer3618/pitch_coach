import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/note.dart';
import '../models/pitch_reading.dart';
import 'audio_capture_service.dart';
import 'pitch_detector.dart';

/// 마이크 스트림 → 슬라이딩 윈도우 → YIN → 스무딩 → [PitchReading] 스트림.
///
/// 2048샘플(46ms) 윈도우를 1024샘플(23ms)마다 분석하여 초당 약 43회 갱신한다.
class PitchService {
  PitchService({AudioCaptureService? capture, this.sampleRate = AudioCaptureService.sampleRate})
      : _capture = capture, // ignore: prefer_initializing_formals
        _detector = YinPitchDetector(sampleRate: sampleRate, bufferSize: bufferSize),
        _ring = Float64List(bufferSize),
        _frame = Float64List(bufferSize);

  static const int bufferSize = 2048;
  static const int hopSize = 1024;

  /// 이보다 작은 RMS는 무음으로 처리한다.
  static const double silenceRms = 0.008;

  final int sampleRate;
  AudioCaptureService? _capture;
  final YinPitchDetector _detector;
  final Float64List _ring;
  final Float64List _frame;
  final StreamController<PitchReading> _controller = StreamController.broadcast();

  int _writePos = 0;
  int _totalSamples = 0;
  int _sinceLastAnalysis = 0;
  final List<double> _recentMidis = [];

  Stream<PitchReading> get readings => _controller.stream;
  bool get isRunning => _capture?.isCapturing ?? false;

  Future<void> start() async {
    _reset();
    _capture ??= AudioCaptureService();
    await _capture!.start(processSamples);
  }

  Future<void> stop() async => _capture?.stop();

  Future<void> dispose() async {
    await _capture?.dispose();
    await _controller.close();
  }

  void _reset() {
    _writePos = 0;
    _totalSamples = 0;
    _sinceLastAnalysis = 0;
    _recentMidis.clear();
  }

  /// 새 샘플을 링버퍼에 넣고, hop 만큼 쌓이면 분석한다.
  /// 테스트에서는 합성 신호를 직접 넣어 전체 파이프라인을 검증한다.
  @visibleForTesting
  void processSamples(Float64List samples) {
    for (final s in samples) {
      _ring[_writePos] = s;
      _writePos = (_writePos + 1) % bufferSize;
      _totalSamples++;
      _sinceLastAnalysis++;
      if (_totalSamples >= bufferSize && _sinceLastAnalysis >= hopSize) {
        _sinceLastAnalysis = 0;
        _analyze();
      }
    }
  }

  void _analyze() {
    // 링버퍼를 시간순으로 펼친다.
    final tail = bufferSize - _writePos;
    _frame.setRange(0, tail, _ring, _writePos);
    _frame.setRange(tail, bufferSize, _ring, 0);

    final rms = YinPitchDetector.removeDcAndRms(_frame);
    final timeMs = (_totalSamples * 1000 / sampleRate).round();

    PitchEstimate? estimate;
    if (rms >= silenceRms) {
      estimate = _detector.detect(_frame);
    }

    double? frequency;
    if (estimate != null) {
      frequency = _smooth(Note.frequencyToMidi(estimate.frequency));
    } else {
      _recentMidis.clear();
    }

    if (!_controller.isClosed) {
      _controller.add(PitchReading(
        timeMs: timeMs,
        frequency: frequency,
        clarity: estimate?.clarity ?? 0,
        rms: rms,
      ));
    }
  }

  /// 최근 3프레임 중앙값으로 튀는 값(옥타브 오검출 등)을 억제한다.
  double _smooth(double midi) {
    _recentMidis.add(midi);
    if (_recentMidis.length > 3) _recentMidis.removeAt(0);
    final sorted = [..._recentMidis]..sort();
    return Note.midiToFrequency(sorted[sorted.length ~/ 2]);
  }
}
