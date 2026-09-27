import 'dart:math' as math;
import 'dart:typed_data';

import '../models/note.dart';

/// 음원 파일 없이 배음 합성으로 피아노 비슷한 소리를 만든다.
///
/// - 배음 10개 + 약간의 비조화성(현의 강성) → 피아노 특유의 밝은 음색
/// - 높은 배음일수록 빨리 감쇠, 낮은 음일수록 오래 울림
/// - 저배음은 두 줄(±0.7센트)로 겹쳐 합창 효과
///
/// 실수 MIDI를 받으므로 '솔보다 30센트 낮은 음'처럼 사용자가 부른 음도 재현할 수 있다.
class PianoSynth {
  const PianoSynth._();

  static const int sampleRate = 44100;
  static const List<double> _harmonicAmps = [1.0, 0.55, 0.32, 0.22, 0.14, 0.09, 0.06, 0.04, 0.03, 0.02];
  static const double _inharmonicity = 0.0004;

  static Float64List synthesize(double midi, {double seconds = 1.4, double peak = 0.8}) {
    final f0 = Note.midiToFrequency(midi);
    final n = (seconds * sampleRate).round();
    final out = Float64List(n);
    final nyquist = sampleRate / 2 * 0.9;
    // 저음은 오래, 고음은 짧게 울린다.
    final baseTau = 0.9 * math.pow(440 / f0, 0.3).clamp(0.6, 1.8);

    for (var k = 1; k <= _harmonicAmps.length; k++) {
      final fk = k * f0 * math.sqrt(1 + _inharmonicity * k * k);
      if (fk >= nyquist) break;
      final amp = _harmonicAmps[k - 1];
      final tau = baseTau / (1 + 0.6 * (k - 1));
      final detunes = k <= 3 ? const [-0.7, 0.7] : const [0.0];
      for (final cents in detunes) {
        final w = 2 * math.pi * fk * math.pow(2, cents / 1200) / sampleRate;
        final a = amp / detunes.length;
        final decay = math.exp(-1 / (tau * sampleRate));
        var env = a;
        for (var i = 0; i < n; i++) {
          out[i] += env * math.sin(w * i);
          env *= decay;
        }
      }
    }

    // 4ms 어택, 마지막 80ms 페이드아웃, 피크 정규화
    final attack = (0.004 * sampleRate).round();
    final release = (0.08 * sampleRate).round();
    var maxAbs = 0.0;
    for (var i = 0; i < n; i++) {
      if (i < attack) out[i] *= i / attack;
      if (i > n - release) out[i] *= (n - i) / release;
      maxAbs = math.max(maxAbs, out[i].abs());
    }
    if (maxAbs > 0) {
      final gain = peak / maxAbs;
      for (var i = 0; i < n; i++) {
        out[i] *= gain;
      }
    }
    return out;
  }

  /// 16bit mono PCM WAV 바이트.
  static Uint8List toWav(Float64List samples) {
    final dataBytes = samples.length * 2;
    final bytes = ByteData(44 + dataBytes);
    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        bytes.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataBytes, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little); // fmt chunk size
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // mono
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    bytes.setUint16(32, 2, Endian.little); // block align
    bytes.setUint16(34, 16, Endian.little); // bits per sample
    ascii(36, 'data');
    bytes.setUint32(40, dataBytes, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      bytes.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}
