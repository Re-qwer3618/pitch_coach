import '../models/song.dart';

/// 앱에 기본으로 들어 있는 연습곡.
/// 표기법은 [Song.fromNotation] / Notation 참고 (가운데 도 옥타브 기준, `'`=한 옥타브 위).
final List<Song> builtInSongs = [
  // ── 기초 연습 ──
  Song.fromNotation(
    id: 'scale',
    title: '도레미 음계',
    category: '기초 연습',
    description: '한 음씩 차례로 올라갔다 내려와요. 모든 연습의 기본!',
    tempoBpm: 80,
    notation: "도 레 미 파 솔 라 시 도'-\n도' 시 라 솔 파 미 레 도-",
  ),
  Song.fromNotation(
    id: 'arpeggio',
    title: '도미솔 도약',
    category: '기초 연습',
    description: '음을 건너뛰어 부르는 연습이에요. 음 사이 간격을 느껴 보세요.',
    tempoBpm: 80,
    notation: "도 미 솔 미 도-\n도 미 솔 도' 솔 미 도-",
  ),

  // ── 동요 ──
  Song.fromNotation(
    id: 'airplane',
    title: '비행기',
    category: '동요',
    description: '도·레·미·솔 네 음만 나와요. 처음 시작하기 좋아요.',
    notation: '미 레 도 레 미 미 미-\n레 레 레- 미 솔 솔-\n미 레 도 레 미 미 미-\n레 레 미 레 도---',
    lyrics: '떴다떴다 비행기 날아라 날아라 높이높이 날아라 우리 비행기',
  ),
  Song.fromNotation(
    id: 'school_bell',
    title: '학교종',
    category: '동요',
    description: '솔솔라라 솔솔미 — 반복되는 음을 또박또박 불러요.',
    notation: '솔 솔 라 라 솔 솔 미-\n솔 솔 미 미 레--',
    lyrics: '학교종이 땡땡땡 어서 모이자',
  ),
  Song.fromNotation(
    id: 'little_star',
    title: '작은별',
    category: '동요',
    description: '도에서 솔로 크게 뛰어오르는 첫 소절이 포인트!',
    notation: '도 도 솔 솔 라 라 솔-\n파 파 미 미 레 레 도-\n솔 솔 파 파 미 미 레-\n솔 솔 파 파 미 미 레-\n'
        '도 도 솔 솔 라 라 솔-\n파 파 미 미 레 레 도-',
    lyrics: '반짝반짝 작은별 아름답게 비치네 동쪽하늘에서도 서쪽하늘에서도 반짝반짝 작은별 아름답게 비치네',
  ),

  // ── 명곡 (계이름으로 불러요) ──
  Song.fromNotation(
    id: 'ode_to_joy',
    title: '환희의 송가',
    category: '명곡',
    description: '베토벤 교향곡 9번. 계이름으로 불러 보세요. 대부분 한 칸씩 움직여요.',
    tempoBpm: 110,
    notation: '미 미 파 솔 솔 파 미 레\n도 도 레 미 미. 레_ 레-\n미 미 파 솔 솔 파 미 레\n도 도 레 미 레. 도_ 도-',
  ),
  Song.fromNotation(
    id: 'jingle_bells',
    title: '징글벨 (후렴)',
    category: '명곡',
    description: '같은 음 반복과 도약이 섞여 있어요. 계이름으로 신나게!',
    tempoBpm: 120,
    notation: '미 미 미- 미 미 미-\n미 솔 도 레 미---\n파 파 파. 파_ 파 미 미 미_ 미_\n미 레 레 미 레- 솔-\n'
        '미 미 미- 미 미 미-\n미 솔 도 레 미---\n파 파 파. 파_ 파 미 미 미_ 미_\n솔 솔 파 레 도---',
  ),
];

final Song schoolBellSong = builtInSongs.firstWhere((s) => s.id == 'school_bell');

const List<String> builtInCategories = ['기초 연습', '동요', '명곡'];
