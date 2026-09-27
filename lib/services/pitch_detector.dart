import 'dart:math' as math;
import 'dart:typed_data';

class PitchEstimate {
  const PitchEstimate({required this.frequency, required this.clarity});

  final double frequency;
  final double clarity;
}

/// YIN 알고리즘 기반 기본 주파수(F0) 검출기.
///
/// de Cheveigné & Kawahara (2002) "YIN, a fundamental frequency estimator
/// for speech and music". 머신러닝 없이 자기상관 계열 연산만 사용하므로
/// 모바일에서도 프레임당 1ms 안팎으로 동작한다.
class YinPitchDetector {
  YinPitchDetector({
    required this.sampleRate,
    this.bufferSize = 2048,
    this.threshold = 0.15,
    this.minFrequency = 70,
    this.maxFrequency = 1100,
  })  : assert(bufferSize.isEven),
        _yin = Float64List(bufferSize ~/ 2);

  final int sampleRate;
  final int bufferSize;

  /// CMNDF 절대 임계값. 낮을수록 엄격(무성음 판정 증가).
  final double threshold;
  final double minFrequency;
  final double maxFrequency;

  final Float64List _yin;

  /// [samples]의 앞 [bufferSize]개 샘플로 F0를 추정한다. 주기성이 없으면 null.
  PitchEstimate? detect(Float64List samples) {
    assert(samples.length >= bufferSize);
    final w = bufferSize ~/ 2;
    final tauMin = math.max(2, (sampleRate / maxFrequency).floor());
    final tauMax = math.min(w - 2, (sampleRate / minFrequency).ceil());

    // 1) 차분 함수 d(τ) = Σ (x[j] - x[j+τ])²
    for (var tau = 1; tau <= tauMax; tau++) {
      var sum = 0.0;
      for (var j = 0; j < w; j++) {
        final delta = samples[j] - samples[j + tau];
        sum += delta * delta;
      }
      _yin[tau] = sum;
    }

    // 2) 누적 평균 정규화 차분 함수(CMNDF)
    _yin[0] = 1;
    var runningSum = 0.0;
    for (var tau = 1; tau <= tauMax; tau++) {
      runningSum += _yin[tau];
      _yin[tau] = runningSum == 0 ? 1 : _yin[tau] * tau / runningSum;
    }

    // 3) 임계값 아래로 처음 내려가는 지점의 극소값 탐색
    var tauEstimate = -1;
    for (var tau = tauMin; tau <= tauMax; tau++) {
      if (_yin[tau] < threshold) {
        while (tau + 1 <= tauMax && _yin[tau + 1] < _yin[tau]) {
          tau++;
        }
        tauEstimate = tau;
        break;
      }
    }
    if (tauEstimate == -1) return null;

    // 4) 포물선 보간으로 서브샘플 정밀도 확보
    var betterTau = tauEstimate.toDouble();
    if (tauEstimate > 1 && tauEstimate < tauMax) {
      final s0 = _yin[tauEstimate - 1];
      final s1 = _yin[tauEstimate];
      final s2 = _yin[tauEstimate + 1];
      final denominator = s0 + s2 - 2 * s1;
      if (denominator.abs() > 1e-12) {
        betterTau = tauEstimate + (s0 - s2) / (2 * denominator);
      }
    }

    final frequency = sampleRate / betterTau;
    if (frequency < minFrequency || frequency > maxFrequency) return null;
    return PitchEstimate(
      frequency: frequency,
      clarity: (1 - _yin[tauEstimate]).clamp(0.0, 1.0),
    );
  }

  /// DC 성분을 제거하고 RMS를 반환한다.
  static double removeDcAndRms(Float64List samples) {
    var mean = 0.0;
    for (final s in samples) {
      mean += s;
    }
    mean /= samples.length;
    var sq = 0.0;
    for (var i = 0; i < samples.length; i++) {
      samples[i] -= mean;
      sq += samples[i] * samples[i];
    }
    return math.sqrt(sq / samples.length);
  }
}
