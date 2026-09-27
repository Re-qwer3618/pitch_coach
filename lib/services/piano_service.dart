import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'piano_synth.dart';

/// 재생할 음 하나: 실수 MIDI + 다음 음까지의 간격.
typedef PianoStep = ({double midi, Duration duration});

/// 합성 피아노 음을 재생한다. 앱 전체에서 [instance] 하나를 공유한다.
///
/// 합성한 WAV는 임시 폴더에 1센트 단위로 캐시하고, 여러 음이 겹칠 수 있도록
/// 저지연 플레이어 풀을 돌려 가며 사용한다.
class PianoService {
  PianoService._();

  static final PianoService instance = PianoService._();

  /// 한 음의 길이(합성 길이와 동일). 마이크 억제 시간 계산에 쓴다.
  static const Duration toneLength = Duration(milliseconds: 1400);
  static const int _poolSize = 6;

  /// 녹음 중에도 재생되고, 재생이 녹음을 멈추지 않도록 한다.
  static final AudioContext _context = AudioContext(
    android: const AudioContextAndroid(
      usageType: AndroidUsageType.media,
      contentType: AndroidContentType.music,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playAndRecord,
      options: const {AVAudioSessionOptions.defaultToSpeaker, AVAudioSessionOptions.mixWithOthers},
    ),
  );

  final List<AudioPlayer> _players = [];
  final Map<int, String> _files = {};
  Directory? _cacheDir;
  int _next = 0;
  int _sequenceId = 0;

  Future<void> _ensurePlayers() async {
    if (_players.isNotEmpty) return;
    for (var i = 0; i < _poolSize; i++) {
      final player = AudioPlayer();
      await player.setAudioContext(_context);
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);
      _players.add(player);
    }
  }

  Future<String> _fileFor(double midi) async {
    final key = (midi * 100).round();
    final cached = _files[key];
    if (cached != null) return cached;
    _cacheDir ??= await getTemporaryDirectory();
    final file = File('${_cacheDir!.path}/piano_$key.wav');
    if (!await file.exists()) {
      // 합성은 수 ms 수준이지만 UI 스레드를 막지 않도록 isolate에서 한다.
      final wav = await compute(_render, key / 100);
      await file.writeAsBytes(wav, flush: true);
    }
    return _files[key] = file.path;
  }

  static Uint8List _render(double midi) => PianoSynth.toWav(PianoSynth.synthesize(midi));

  /// 자주 쓰는 음을 미리 합성해 둔다 (첫 재생 지연 방지).
  Future<void> preload(Iterable<double> midis) async {
    for (final m in midis) {
      await _fileFor(m);
    }
  }

  Future<void> playNote(double midi) async {
    try {
      await _ensurePlayers();
      final path = await _fileFor(midi);
      final player = _players[_next];
      _next = (_next + 1) % _players.length;
      await player.stop();
      await player.play(DeviceFileSource(path));
    } catch (e) {
      debugPrint('피아노 재생 실패: $e');
    }
  }

  /// 음을 차례로 재생한다. [onStep]은 각 음이 시작될 때 인덱스와 함께 호출된다.
  /// 끝까지 재생하면 true, [stopSequence]로 중단되면 false.
  Future<bool> playSequence(List<PianoStep> steps, {void Function(int index)? onStep}) async {
    final id = ++_sequenceId;
    await preload(steps.map((s) => s.midi));
    for (var i = 0; i < steps.length; i++) {
      if (id != _sequenceId) return false;
      onStep?.call(i);
      unawaited(playNote(steps[i].midi));
      await Future<void>.delayed(steps[i].duration);
    }
    return id == _sequenceId;
  }

  Future<void> stopSequence() async {
    _sequenceId++;
    for (final p in _players) {
      await p.stop();
    }
  }
}
