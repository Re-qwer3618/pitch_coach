import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// 마이크 PCM 스트림을 -1.0~1.0 범위의 실수 샘플로 전달한다.
///
/// 파일 저장 없이 PCM16 raw 스트림만 사용하여 버퍼링 지연을 최소화한다.
class AudioCaptureService {
  static const int sampleRate = 44100;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _subscription;

  /// 청크 경계에서 잘린 16bit 샘플의 첫 바이트.
  int? _pendingByte;

  bool get isCapturing => _subscription != null;

  Future<void> start(void Function(Float64List samples) onSamples) async {
    await stop();
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: 1,
      // 피치 분석을 왜곡하는 음성 전처리는 끈다.
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
      // 앱의 피아노 소리가 재생돼도 녹음이 멈추지 않게 한다.
      audioInterruption: AudioInterruptionMode.none,
    ));
    _subscription = stream.listen((chunk) => onSamples(_decode(chunk)));
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _pendingByte = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
  }

  Float64List _decode(Uint8List chunk) {
    var bytes = chunk;
    if (_pendingByte != null) {
      bytes = Uint8List(chunk.length + 1);
      bytes[0] = _pendingByte!;
      bytes.setRange(1, bytes.length, chunk);
      _pendingByte = null;
    }
    if (bytes.length.isOdd) {
      _pendingByte = bytes[bytes.length - 1];
    }
    final count = bytes.length ~/ 2;
    final data = ByteData.sublistView(bytes);
    final samples = Float64List(count);
    for (var i = 0; i < count; i++) {
      samples[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }
}
