import 'package:flutter/material.dart';

import '../data/built_in_songs.dart';
import '../services/permission_service.dart';
import 'practice_view.dart';
import 'song_list_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with WidgetsBindingObserver {
  MicPermission? _permission;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 앱 실행 시 마이크 권한 요청
    _requestPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 설정 앱에서 권한을 바꾸고 돌아오면 다시 확인한다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PermissionService.status().then((p) {
        if (mounted) setState(() => _permission = p);
      });
    }
  }

  Future<void> _requestPermission() async {
    final p = await PermissionService.ensureMicrophone();
    if (mounted) setState(() => _permission = p);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final needsPermission = _permission == MicPermission.denied || _permission == MicPermission.permanentlyDenied;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          children: [
            Text('🎤 음치탈출', style: theme.textTheme.displaySmall!.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('내 목소리의 음정을 실시간으로 보고\n정확한 음으로 노래해 봐요.',
                style: theme.textTheme.titleMedium!.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            if (needsPermission) ...[
              Card(
                color: scheme.errorContainer,
                child: ListTile(
                  leading: Icon(Icons.mic_off_rounded, color: scheme.onErrorContainer),
                  title: Text('마이크 권한이 필요해요', style: TextStyle(color: scheme.onErrorContainer)),
                  subtitle: Text(
                    _permission == MicPermission.permanentlyDenied ? '설정에서 마이크를 허용해 주세요' : '눌러서 권한을 허용해 주세요',
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                  onTap: _permission == MicPermission.permanentlyDenied
                      ? PermissionService.openSettings
                      : _requestPermission,
                ),
              ),
              const SizedBox(height: 12),
            ],
            _ModeCard(
              icon: Icons.graphic_eq_rounded,
              color: scheme.primary,
              title: '기본 연습 모드',
              description: '지금 내는 음을 피아노 건반 위에 보여줘요.\n건반을 눌러 소리를 듣고 따라 불러 보세요 🎹',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PracticeView())),
            ),
            const SizedBox(height: 12),
            _ModeCard(
              icon: Icons.library_music_rounded,
              color: scheme.tertiary,
              title: '노래 연습',
              description: '음계·동요·명곡 ${builtInSongs.length}곡 + 내가 추가한 노래\n피아노로 듣고 부르면 일치율 점수와 피드백을 알려줘요.',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SongListView())),
            ),
            const SizedBox(height: 24),
            Text('Tip. 조용한 곳에서 휴대폰을 입에서 20~30cm 떨어뜨리고 불러 주세요.',
                style: theme.textTheme.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(description, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
