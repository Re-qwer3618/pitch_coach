import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/notation.dart';
import '../models/note.dart';

/// MIDI 파일의 한 파트(트랙·채널)를 단선율로 줄여 계이름 악보로 바꾼 것.
class MidiMelody {
  const MidiMelody({
    required this.name,
    required this.notation,
    required this.lyrics,
    required this.noteCount,
    required this.lowest,
    required this.highest,
    required this.octaveShift,
  });

  /// 트랙 이름 (없으면 '트랙 n'), 한 트랙에 채널이 여럿이면 채널 번호도 붙는다.
  final String name;
  final String notation;

  /// 음표마다 한 음절씩 맞아떨어질 때만 채운다. 아니면 ''.
  final String lyrics;
  final int noteCount;

  /// 옮긴 뒤의 가장 낮은/높은 MIDI 번호.
  final int lowest;
  final int highest;

  /// 부르기 편한 음역으로 옮긴 옥타브 수 (음수 = 아래로).
  final int octaveShift;

  String get rangeLabel => '${Note(lowest).name}–${Note(highest).name}';
}

class MidiImport {
  const MidiImport({required this.tempoBpm, required this.melodies});

  /// 첫 템포 (없으면 MIDI 기본값 120).
  final double tempoBpm;

  /// 멜로디일 가능성이 높은 순서.
  final List<MidiMelody> melodies;
}

/// 표준 MIDI 파일(.mid/.midi/.kar)을 읽어 멜로디 후보를 계이름 악보로 만든다.
///
/// - 드럼(10번 채널)은 뺀다.
/// - 화음은 가장 높은 음만 남기고(skyline), 겹치는 음은 다음 음이 시작할 때 끊는다.
/// - 박자는 반 박 단위로 맞춘다. 한 박 이상 쉬면 소절을 나누고, 짧은 쉼은 앞 음에 붙인다
///   (계이름 악보에는 쉼표가 없다).
class MidiImporter {
  const MidiImporter._();

  static final RegExp _melodyName = RegExp(r'melod|vocal|voice|lead|sing|멜로디|보컬|노래|주선율', caseSensitive: false);

  /// 형식이 틀리면 [FormatException] (메시지는 사용자에게 그대로 보여줄 수 있다).
  static MidiImport parse(Uint8List bytes) {
    final r = _Reader(bytes);
    if (bytes.length < 14 || r.ascii(4) != 'MThd') throw const FormatException('MIDI 파일이 아니에요');
    final headerEnd = r.u32() + r.pos;
    r.u16(); // format: 0/1/2 모두 트랙을 똑같이 훑는다
    final trackCount = r.u16();
    final division = r.u16();
    if (division & 0x8000 != 0) throw const FormatException('SMPTE 시간 단위 MIDI는 아직 지원하지 않아요');
    if (division == 0 || headerEnd > bytes.length) throw _Reader.corrupt;
    r.pos = headerEnd;

    final tempos = <(int, int)>[]; // (tick, 4분음표당 마이크로초)
    final lyrics = <_Text>[];
    final texts = <_Text>[];
    final tracks = <_Track>[];
    while (tracks.length < trackCount && r.end - r.pos >= 8) {
      final id = r.ascii(4);
      final length = r.u32();
      final end = math.min(r.pos + length, bytes.length); // 잘린 파일은 있는 데까지만
      if (id == 'MTrk') tracks.add(_parseTrack(_Reader(bytes, r.pos, end), tempos, lyrics, texts));
      r.pos = end;
    }
    if (tracks.isEmpty) throw _Reader.corrupt;

    tempos.sort((a, b) => a.$1 - b.$1);
    final microsPerBeat = tempos.isEmpty || tempos.first.$2 == 0 ? 500000 : tempos.first.$2;
    // 가사 이벤트가 없으면 .kar 방식의 텍스트 이벤트를 쓴다 ('@'로 시작하는 건 머리말).
    final words = lyrics.isNotEmpty ? lyrics : texts.where((t) => !t.text.startsWith('@')).toList();
    final readableWords = words.any((w) => w.text.contains('�')) ? <_Text>[] : (words..sort((a, b) => a.tick - b.tick));

    final chordTolerance = math.max(1, division ~/ 16);
    final scored = <(double, MidiMelody)>[];
    for (var t = 0; t < tracks.length; t++) {
      final track = tracks[t];
      final channels = track.notes.map((n) => n.channel).where((c) => c != 9).toSet().toList()..sort();
      for (final channel in channels) {
        final raw = track.notes.where((n) => n.channel == channel).toList();
        final (line, chordNotes) = _skyline(raw, chordTolerance);
        if (line.length < 4) continue;
        final name = [
          (track.name?.trim().isNotEmpty ?? false) ? track.name!.trim() : '트랙 ${t + 1}',
          if (channels.length > 1) '채널 ${channel + 1}',
        ].join(' · ');
        final melody = _toMelody(name, line, division, readableWords, chordTolerance);

        final average = line.fold<int>(0, (sum, n) => sum + n.pitch) / line.length;
        var score = line.length * (1 - chordNotes / (chordNotes + line.length));
        if (average < 52) score *= 0.3; // 베이스 파트
        if (_melodyName.hasMatch(name)) score += 10000;
        scored.add((score, melody));
      }
    }
    if (scored.isEmpty) throw const FormatException('멜로디로 쓸 만한 음표를 찾지 못했어요');
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return MidiImport(
      tempoBpm: 60000000 / microsPerBeat,
      melodies: [for (final s in scored) s.$2],
    );
  }

  static _Track _parseTrack(_Reader r, List<(int, int)> tempos, List<_Text> lyrics, List<_Text> texts) {
    var tick = 0;
    int? running;
    String? name;
    final notes = <_RawNote>[];
    final open = <int, List<int>>{}; // (채널 << 7 | 음) → 시작 tick들
    events:
    while (!r.atEnd) {
      tick += r.varLen();
      var status = r.u8();
      if (status < 0x80) {
        // running status: 앞 이벤트의 상태 바이트를 그대로 쓰고, 방금 읽은 건 데이터다.
        if (running == null) throw _Reader.corrupt;
        status = running;
        r.pos--;
      }
      if (status == 0xFF) {
        running = null;
        final type = r.u8();
        final data = r.take(r.varLen());
        switch (type) {
          case 0x2F:
            break events;
          case 0x51 when data.length == 3:
            tempos.add((tick, data[0] << 16 | data[1] << 8 | data[2]));
          case 0x03:
            name ??= _decode(data);
          case 0x05:
            lyrics.add(_Text(tick, _decode(data)));
          case 0x01:
            texts.add(_Text(tick, _decode(data)));
        }
      } else if (status == 0xF0 || status == 0xF7) {
        running = null;
        r.take(r.varLen());
      } else if (status > 0xF0) {
        throw _Reader.corrupt; // 파일에는 나오지 않는 실시간 메시지
      } else {
        running = status;
        final kind = status & 0xF0;
        final channel = status & 0x0F;
        final pitch = r.u8();
        final velocity = kind == 0xC0 || kind == 0xD0 ? 0 : r.u8();
        final key = channel << 7 | pitch;
        if (kind == 0x90 && velocity > 0) {
          open.putIfAbsent(key, () => []).add(tick);
        } else if (kind == 0x80 || kind == 0x90) {
          final starts = open[key];
          if (starts != null && starts.isNotEmpty) notes.add(_RawNote(channel, pitch, starts.removeAt(0), tick));
        }
      }
    }
    // 끝나지 않은 음은 트랙 끝에서 끊는다.
    open.forEach((key, starts) {
      for (final start in starts) {
        notes.add(_RawNote(key >> 7, key & 0x7F, start, tick));
      }
    });
    return _Track(name, notes);
  }

  static String _decode(List<int> data) => utf8.decode(data, allowMalformed: true);

  /// 화음(거의 동시에 시작하는 음)은 가장 높은 음만, 겹치는 음은 다음 음 시작에서 끊는다.
  /// 반환: (단선율, 버린 화음 음 개수).
  static (List<_RawNote>, int) _skyline(List<_RawNote> notes, int tolerance) {
    final sorted = [...notes]..sort((a, b) => a.start != b.start ? a.start - b.start : b.pitch - a.pitch);
    final line = <_RawNote>[];
    var dropped = 0;
    for (final n in sorted) {
      if (line.isNotEmpty) {
        final last = line.last;
        if (n.start - last.start <= tolerance) {
          dropped++;
          if (n.pitch > last.pitch) line[line.length - 1] = _RawNote(n.channel, n.pitch, n.start, n.end);
          continue;
        }
        if (n.start < last.end) last.end = n.start;
      }
      line.add(_RawNote(n.channel, n.pitch, n.start, n.end));
    }
    return (line, dropped);
  }

  static MidiMelody _toMelody(String name, List<_RawNote> notes, int division, List<_Text> words, int tolerance) {
    // 반 박(8분음표) 단위로 맞춘다.
    int q(int tick) => (tick * 2 / division).round();

    // 가운데가 F4 근처에 오도록 옥타브를 옮긴다 (부르기 편하고 악보에 ' , 가 덜 붙는다).
    final sortedPitches = notes.map((n) => n.pitch).toList()..sort();
    final shift = ((66 - sortedPitches[sortedPitches.length ~/ 2]) / 12).round();
    int fit(int midi) {
      var m = midi + 12 * shift;
      while (m < 36) {
        m += 12;
      }
      while (m > 96) {
        m -= 12;
      }
      return m;
    }

    final out = StringBuffer();
    var lowest = 127;
    var highest = 0;
    var phraseLength = 0;
    var separator = '';
    for (var i = 0; i < notes.length; i++) {
      final start = q(notes[i].start);
      final soundEnd = math.max(q(notes[i].end), start + 1);
      final nextStart = i + 1 < notes.length ? q(notes[i + 1].start) : null;
      int halves;
      var phraseEnds = false;
      if (nextStart == null) {
        halves = soundEnd - start;
      } else if (nextStart - soundEnd >= 2) {
        halves = soundEnd - start; // 한 박 이상 쉼 → 소절 끝
        phraseEnds = true;
      } else {
        halves = nextStart - start; // 짧은 쉼은 앞 음에 붙인다
      }

      final midi = fit(notes[i].pitch);
      lowest = math.min(lowest, midi);
      highest = math.max(highest, midi);
      out
        ..write(separator)
        ..write(Notation.tokenFor(midi))
        ..write(_beatSuffix(math.max(halves, 1)));

      phraseLength++;
      // 쉼이 없는 긴 소절은 12음이 넘으면 다음 마디(4/4 가정) 첫 음에서 나눈다.
      if (phraseEnds || (phraseLength >= 12 && nextStart != null && nextStart % 8 == 0)) {
        separator = '\n';
        phraseLength = 0;
      } else {
        separator = ' ';
      }
    }

    return MidiMelody(
      name: name,
      notation: out.toString(),
      lyrics: _lyricsFor(notes, words, tolerance),
      noteCount: notes.length,
      lowest: lowest,
      highest: highest,
      octaveShift: shift,
    );
  }

  /// 반 박 개수 → 악보 길이 기호. 1: `_`, 2: 없음, 3: `.`, 4: `-`, 5: `.-`, 6: `--` …
  static String _beatSuffix(int halves) {
    if (halves == 1) return '_';
    if (halves.isEven) return '-' * (halves ~/ 2 - 1);
    return '.${'-' * ((halves - 3) ~/ 2)}';
  }

  /// 음표마다 그 음이 울리는 동안 나온 가사를 붙인다. 음절 수가 음표 수와 딱 맞을 때만 쓴다.
  static String _lyricsFor(List<_RawNote> notes, List<_Text> words, int tolerance) {
    if (words.isEmpty) return '';
    final parts = <String>[];
    var w = 0;
    for (var i = 0; i < notes.length; i++) {
      final from = notes[i].start - tolerance;
      final to = i + 1 < notes.length ? notes[i + 1].start - tolerance : null;
      while (w < words.length && words[w].tick < from) {
        w++;
      }
      final part = StringBuffer();
      while (w < words.length && (to == null || words[w].tick < to)) {
        part.write(words[w].text);
        w++;
      }
      // .kar의 줄바꿈 표시(/ \)와 공백을 걷어낸다.
      parts.add(part.toString().replaceAll(RegExp(r'[/\\\r\n]'), '').trim());
    }
    final text = parts.join(' ');
    return Notation.syllables(text).length == notes.length ? text : '';
  }
}

class _RawNote {
  _RawNote(this.channel, this.pitch, this.start, this.end);

  final int channel;
  final int pitch;
  final int start;
  int end;
}

class _Track {
  const _Track(this.name, this.notes);

  final String? name;
  final List<_RawNote> notes;
}

class _Text {
  const _Text(this.tick, this.text);

  final int tick;
  final String text;
}

class _Reader {
  _Reader(this.bytes, [this.pos = 0, int? end]) : end = end ?? bytes.length;

  static const corrupt = FormatException('MIDI 파일이 손상됐거나 읽을 수 없는 형식이에요');

  final Uint8List bytes;
  final int end;
  int pos;

  bool get atEnd => pos >= end;

  int u8() {
    if (pos >= end) throw corrupt;
    return bytes[pos++];
  }

  int u16() => u8() << 8 | u8();

  int u32() => u16() << 16 | u16();

  /// 가변 길이 수 (7비트씩, 최대 4바이트).
  int varLen() {
    var value = 0;
    for (var i = 0; i < 4; i++) {
      final b = u8();
      value = value << 7 | (b & 0x7F);
      if (b & 0x80 == 0) return value;
    }
    throw corrupt;
  }

  Uint8List take(int n) {
    if (pos + n > end) throw corrupt;
    final out = Uint8List.sublistView(bytes, pos, pos + n);
    pos += n;
    return out;
  }

  String ascii(int n) => String.fromCharCodes(take(n));
}
