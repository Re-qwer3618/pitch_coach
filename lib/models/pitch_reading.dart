import 'note.dart';

/// 분석 프레임 하나(약 23ms)의 피치 측정 결과.
class PitchReading {
  const PitchReading({
    required this.timeMs,
    required this.frequency,
    required this.clarity,
    required this.rms,
  });

  /// 측정 시작 시점부터의 경과 시간(ms).
  final int timeMs;

  /// 기본 주파수(F0). 무음·무성음이면 null.
  final double? frequency;

  /// YIN 신뢰도(0~1). 1에 가까울수록 주기성이 뚜렷하다.
  final double clarity;

  /// 프레임 음량(RMS, 0~1).
  final double rms;

  bool get isVoiced => frequency != null;

  /// 실수 MIDI 값 (예: 67.12 → G4에서 +12센트).
  double? get midi => frequency == null ? null : Note.frequencyToMidi(frequency!);

  /// 가장 가까운 음.
  Note? get note => midi == null ? null : Note(midi!.round());

  /// 가장 가까운 음 대비 센트 오차(-50~+50).
  double? get cents => midi == null ? null : (midi! - midi!.round()) * 100;
}
