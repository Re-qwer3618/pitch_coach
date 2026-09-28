import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/notation.dart';
import '../models/note.dart';
import '../models/song.dart';
import '../models/youtube_link.dart';
import '../services/midi_importer.dart';
import '../services/piano_service.dart';
import '../services/song_repository.dart';
import '../services/youtube_launcher.dart';
import 'widgets/piano_keyboard.dart';

/// 내 노래 추가/수정. 계이름 악보를 직접 입력하거나, 피아노 건반을 눌러 입력하거나,
/// MIDI 파일에서 가져온다. 원곡 유튜브 링크를 붙여 둘 수 있다.
class SongEditorView extends StatefulWidget {
  const SongEditorView({super.key, this.song});

  /// 수정할 노래 (null이면 새 노래).
  final Song? song;

  @override
  State<SongEditorView> createState() => _SongEditorViewState();
}

class _SongEditorViewState extends State<SongEditorView> {
  final _piano = PianoService.instance;
  late final _title = TextEditingController(text: widget.song?.title ?? '');
  late final _notation = TextEditingController(text: widget.song?.notation ?? '');
  late final _lyrics = TextEditingController(text: widget.song?.lyricsText ?? '');
  late final _youtube = TextEditingController(
    text: widget.song?.youtubeId == null ? '' : YoutubeLink.watchUri(widget.song!.youtubeId!).toString(),
  );
  late double _tempo = widget.song?.tempoBpm ?? 100;

  Song? _preview;
  String? _error;
  int _pianoLow = 48;
  int? _pressed;
  Timer? _pressedTimer;
  bool _playing = false;
  int? _playingIndex;

  bool get _isEditing => widget.song != null;

  @override
  void initState() {
    super.initState();
    _notation.addListener(_reparse);
    _lyrics.addListener(_reparse);
    _title.addListener(() => setState(() {}));
    _youtube.addListener(() => setState(() {}));
    _reparse();
  }

  @override
  void dispose() {
    _pressedTimer?.cancel();
    _piano.stopSequence();
    _title.dispose();
    _notation.dispose();
    _lyrics.dispose();
    _youtube.dispose();
    super.dispose();
  }

  void _reparse() {
    setState(() {
      if (_notation.text.trim().isEmpty) {
        _preview = null;
        _error = null;
        return;
      }
      try {
        _preview = _build(widget.song?.id ?? 'preview');
        _error = null;
      } on FormatException catch (e) {
        _preview = null;
        _error = e.message;
      }
    });
  }

  Song _build(String id) => Song.fromNotation(
        id: id,
        title: _title.text.trim(),
        notation: _notation.text,
        lyrics: _lyrics.text,
        tempoBpm: _tempo,
        isCustom: true,
        youtubeId: YoutubeLink.videoId(_youtube.text),
      );

  /// 링크를 적었는데 유튜브 링크가 아니면 true.
  bool get _youtubeInvalid => _youtube.text.trim().isNotEmpty && YoutubeLink.videoId(_youtube.text) == null;

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  // ───── MIDI 가져오기 ─────

  Future<void> _importMidi() async {
    final PlatformFile? file;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mid', 'midi', 'kar'],
        withData: true,
      );
      file = picked?.files.single;
    } catch (_) {
      if (mounted) _snack('파일을 열지 못했어요');
      return;
    }
    if (file == null || !mounted) return; // 고르지 않고 닫음
    final bytes = file.bytes;
    if (bytes == null) {
      _snack('파일을 읽지 못했어요');
      return;
    }

    final MidiImport imported;
    try {
      imported = MidiImporter.parse(bytes);
    } on FormatException catch (e) {
      _snack(e.message);
      return;
    }
    final melody = await _chooseMelody(imported.melodies);
    if (melody == null || !mounted) return;

    await _piano.stopSequence();
    if (_title.text.trim().isEmpty) {
      _title.text = file.name.replaceFirst(RegExp(r'\.(mid|midi|kar)$', caseSensitive: false), '').replaceAll('_', ' ');
    }
    // 빠르기 슬라이더(50~160, 5단위)에 맞춘다.
    _tempo = ((imported.tempoBpm / 5).round() * 5).clamp(50, 160).toDouble();
    if (melody.lyrics.isNotEmpty) _lyrics.text = melody.lyrics;
    _setNotation(melody.notation);
    final shifted = melody.octaveShift == 0
        ? ''
        : ' (부르기 편하게 ${melody.octaveShift.abs()}옥타브 ${melody.octaveShift > 0 ? '올렸어요' : '내렸어요'})';
    _snack('${melody.noteCount}개 음을 가져왔어요$shifted');
  }

  /// 멜로디 후보를 보여주고 하나를 고르게 한다. 첫 번째가 추천.
  Future<MidiMelody?> _chooseMelody(List<MidiMelody> melodies) {
    final replacing = _notation.text.trim().isNotEmpty;
    return showDialog<MidiMelody>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('어느 파트를 가져올까요?'),
        children: [
          if (replacing)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('지금 입력된 악보는 바뀌어요.', style: Theme.of(context).textTheme.bodySmall),
            ),
          for (var i = 0; i < melodies.length; i++)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Icon(i == 0 ? Icons.star_rounded : Icons.music_note_rounded),
              title: Text(melodies[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${i == 0 ? '추천 · ' : ''}${melodies[i].noteCount}음 · ${melodies[i].rangeLabel}'
                  '${melodies[i].lyrics.isEmpty ? '' : ' · 가사 있음'}'),
              onTap: () => Navigator.pop(context, melodies[i]),
            ),
        ],
      ),
    );
  }

  // ───── 유튜브 ─────

  void _searchYoutube() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _snack('노래 제목을 먼저 입력해 주세요');
      return;
    }
    openYoutube(context, YoutubeLink.searchUri(title));
  }

  // ───── 피아노 입력 ─────

  void _setNotation(String text) {
    _notation.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }

  void _appendKey(int midi) {
    _piano.playNote(midi.toDouble());
    final text = _notation.text;
    final needsSpace = text.isNotEmpty && !text.endsWith(' ') && !text.endsWith('\n');
    _setNotation('$text${needsSpace ? ' ' : ''}${Notation.tokenFor(midi)}');
    _pressedTimer?.cancel();
    setState(() => _pressed = midi);
    _pressedTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _pressed = null);
    });
  }

  void _appendRaw(String s) {
    final text = _notation.text.trimRight();
    if (text.isEmpty) return;
    _setNotation(text + s);
  }

  /// 마지막 음표 하나(꾸밈 기호 포함)를 지운다.
  void _removeLast() {
    var text = _notation.text.trimRight();
    var cut = -1;
    for (var i = text.length - 1; i >= 0; i--) {
      if ('도레미파솔라시CDEFGAB'.contains(text[i])) {
        cut = i;
        break;
      }
    }
    if (cut < 0) {
      text = '';
    } else {
      while (cut >= 2 && (text.startsWith('높은', cut - 2) || text.startsWith('낮은', cut - 2))) {
        cut -= 2;
      }
      text = text.substring(0, cut).trimRight();
    }
    _setNotation(text.isEmpty ? '' : '$text ');
  }

  // ───── 미리 듣기 / 저장 ─────

  Future<void> _togglePlay() async {
    final song = _preview;
    if (song == null) return;
    if (_playing) {
      await _piano.stopSequence();
      return;
    }
    setState(() => _playing = true);
    await _piano.playSequence(
      [for (var i = 0; i < song.notes.length; i++) (midi: song.notes[i].midi.toDouble(), duration: song.durationOf(i))],
      onStep: (i) {
        if (mounted) setState(() => _playingIndex = i);
      },
    );
    if (mounted) {
      setState(() {
        _playing = false;
        _playingIndex = null;
      });
    }
  }

  String? get _saveProblem {
    if (_title.text.trim().isEmpty) return '노래 제목을 입력해 주세요';
    if (_preview == null) return _error ?? '음표를 입력해 주세요';
    if (_preview!.notes.length < 2) return '음표를 2개 이상 입력해 주세요';
    if (_youtubeInvalid) return '유튜브 링크를 확인해 주세요';
    return null;
  }

  Future<void> _save() async {
    final problem = _saveProblem;
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    final song = _build(widget.song?.id ?? SongRepository.newId());
    await SongRepository.instance.save(song);
    if (mounted) Navigator.pop(context, song);
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계이름 입력 방법'),
        content: const SingleChildScrollView(
          child: Text(
            '• 계이름: 도 레 미 파 솔 라 시\n'
            '   (가운데 도 옥타브 기준, 띄어쓰기는 자유)\n\n'
            "• 높은 음: 도'  (한 옥타브 위, 도''는 두 옥타브)\n"
            '   또는 높은도\n'
            '• 낮은 음: 솔,  (한 옥타브 아래)\n'
            '   또는 낮은솔\n\n'
            '• 반음: 도#  미b\n\n'
            '• 길이: 기본 1박\n'
            '   미-  = 2박,  레-- = 3박\n'
            '   솔_  = 반 박,  미.  = 1.5박\n\n'
            '• 줄바꿈 또는 / : 소절 나누기\n\n'
            '• 영어 음이름도 돼요: G4 A4 C5\n\n'
            '예) 학교종\n'
            '솔 솔 라 라 솔 솔 미-\n'
            '솔 솔 미 미 레--',
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = _preview;
    final syllableCount = Notation.syllables(_lyrics.text).length;
    final noteCount = preview?.notes.length ?? 0;
    final lyricsMismatch = syllableCount > 0 && syllableCount != noteCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '노래 수정' : '노래 추가'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: const Text('저장'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: '노래 제목', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('계이름 악보', style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold)),
              IconButton(onPressed: _showHelp, icon: const Icon(Icons.help_outline_rounded), tooltip: '입력 방법'),
              const Spacer(),
              TextButton.icon(
                onPressed: _importMidi,
                icon: const Icon(Icons.file_open_rounded),
                label: const Text('MIDI 가져오기'),
              ),
            ],
          ),
          TextField(
            controller: _notation,
            minLines: 3,
            maxLines: 8,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: '예) 솔 솔 라 라 솔 솔 미-\n솔 솔 미 미 레--',
              errorText: _error,
              errorMaxLines: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text('🎹 건반을 누르면 소리가 나고 악보에 음이 추가돼요', style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _pianoLow = (_pianoLow - 12).clamp(36, 72)),
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: '한 옥타브 아래',
              ),
              Text('${Note(_pianoLow).name}–${Note(_pianoLow + 24).name}', style: theme.textTheme.labelMedium),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _pianoLow = (_pianoLow + 12).clamp(36, 72)),
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: '한 옥타브 위',
              ),
              const Spacer(),
              _ToolButton(label: '⌫', tooltip: '마지막 음 지우기', onPressed: _removeLast),
              _ToolButton(label: '−', tooltip: '마지막 음 길게 (+1박)', onPressed: () => _appendRaw('-')),
              _ToolButton(label: '↵', tooltip: '다음 소절', onPressed: () => _appendRaw('\n')),
            ],
          ),
          PianoKeyboard(
            lowMidi: _pianoLow,
            height: 110,
            pressedMidi: _pressed ?? (_playingIndex == null ? null : preview?.notes[_playingIndex!].midi),
            onKeyTap: _appendKey,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _lyrics,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: '가사 (선택)',
              hintText: '예) 학교종이 땡땡땡 어서 모이자',
              helperText: '한 글자에 한 음씩 붙어요. 비워 두면 계이름으로 불러요.',
              border: const OutlineInputBorder(),
              counterText: syllableCount == 0 ? null : '가사 $syllableCount글자 / 음표 $noteCount개',
              counterStyle: TextStyle(color: lyricsMismatch ? scheme.error : null),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _youtube,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: '원곡 영상 (선택)',
              hintText: '유튜브 링크를 붙여 넣으세요',
              helperText: '연습 화면의 [원곡] 버튼으로 유튜브에서 열려요',
              errorText: _youtubeInvalid ? '유튜브 링크가 아니에요' : null,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: _searchYoutube,
                icon: const Icon(Icons.search_rounded),
                tooltip: '유튜브에서 제목으로 찾기',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('빠르기: ${_tempo.round()} BPM', style: theme.textTheme.titleSmall),
          Slider(
            value: _tempo,
            min: 50,
            max: 160,
            divisions: 22,
            label: '${_tempo.round()}',
            onChanged: (v) {
              _tempo = v;
              _reparse();
            },
          ),
          const SizedBox(height: 8),
          if (preview != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('미리 보기', style: theme.textTheme.titleSmall!.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${preview.notes.length}음 · ${preview.rangeLabel} · ${preview.difficulty.label}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _togglePlay,
                          icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
                          label: Text(_playing ? '정지' : '듣기'),
                        ),
                      ],
                    ),
                    if (lyricsMismatch)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          syllableCount < noteCount
                              ? '가사가 ${noteCount - syllableCount}글자 모자라요 (남는 음은 계이름으로 표시돼요)'
                              : '가사가 ${syllableCount - noteCount}글자 남아요 (남는 가사는 쓰이지 않아요)',
                          style: theme.textTheme.bodySmall!.copyWith(color: scheme.error),
                        ),
                      ),
                    const SizedBox(height: 8),
                    for (final phrase in preview.phrases)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final i in phrase)
                              _PreviewChip(
                                lyric: preview.lyrics[i],
                                note: preview.notes[i],
                                beats: preview.beats[i],
                                active: i == _playingIndex,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.label, required this.tooltip, required this.onPressed});

  final String label;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Tooltip(
        message: tooltip,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(44, 36), padding: EdgeInsets.zero),
          onPressed: onPressed,
          child: Text(label, style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.lyric, required this.note, required this.beats, required this.active});

  final String lyric;
  final Note note;
  final double beats;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = active ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = active ? scheme.onPrimary : scheme.onSurface;
    final beatLabel = beats == beats.roundToDouble() ? beats.round().toString() : beats.toString();
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Text(lyric, style: theme.textTheme.titleSmall!.copyWith(color: fg, fontWeight: FontWeight.bold)),
          Text(note.name, style: theme.textTheme.labelSmall!.copyWith(color: fg)),
          Text('$beatLabel박', style: theme.textTheme.labelSmall!.copyWith(color: fg.withValues(alpha: 0.7), fontSize: 9)),
        ],
      ),
    );
  }
}
