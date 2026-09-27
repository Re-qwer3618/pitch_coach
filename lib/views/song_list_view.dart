import 'package:flutter/material.dart';

import '../data/built_in_songs.dart';
import '../models/song.dart';
import '../services/song_repository.dart';
import 'song_editor_view.dart';
import 'song_view.dart';

/// 연습곡 목록: 기본 수록곡 + 내가 추가한 노래.
class SongListView extends StatefulWidget {
  const SongListView({super.key});

  @override
  State<SongListView> createState() => _SongListViewState();
}

class _SongListViewState extends State<SongListView> {
  final _repo = SongRepository.instance;

  @override
  void initState() {
    super.initState();
    _repo.load();
  }

  Future<void> _openEditor([Song? song]) async {
    await Navigator.push<Song>(context, MaterialPageRoute(builder: (_) => SongEditorView(song: song)));
  }

  Future<void> _confirmDelete(Song song) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('노래 삭제'),
        content: Text("'${song.title}'을(를) 삭제할까요?\n삭제하면 되돌릴 수 없어요."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true) await _repo.delete(song.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('노래 연습')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditor,
        icon: const Icon(Icons.add_rounded),
        label: const Text('노래 추가'),
      ),
      body: ListenableBuilder(
        listenable: _repo,
        builder: (context, _) {
          final custom = _repo.customSongs;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              for (final category in builtInCategories) ...[
                _SectionHeader(category),
                for (final song in builtInSongs.where((s) => s.category == category)) _SongTile(song: song),
              ],
              const _SectionHeader(Song.customCategory),
              if (custom.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('아직 추가한 노래가 없어요.', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text('부르고 싶은 노래의 계이름을 입력하거나 피아노로 찍어서 추가해 보세요 🎹',
                            textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _openEditor,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('노래 추가'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final song in custom)
                  _SongTile(
                    song: song,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) => value == 'edit' ? _openEditor(song) : _confirmDelete(song),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('수정')),
                        PopupMenuItem(value: 'delete', child: Text('삭제')),
                      ],
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Text(title,
          style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({required this.song, this.trailing});

  final Song song;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (badge, badgeColor) = switch (song.difficulty) {
      Difficulty.easy => ('쉬움', Colors.green),
      Difficulty.medium => ('보통', Colors.orange),
      Difficulty.hard => ('어려움', scheme.error),
    };
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(song.isCustom ? Icons.person_rounded : Icons.music_note_rounded, color: scheme.onPrimaryContainer),
        ),
        title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${song.rangeLabel} · ${song.notes.length}음'
            '${song.lyrics.isEmpty ? '' : '\n${song.lyrics.take(10).join()}${song.lyrics.length > 10 ? '…' : ''}'}'),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(badge, style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            ?trailing,
          ],
        ),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SongView(song: song))),
      ),
    );
  }
}
