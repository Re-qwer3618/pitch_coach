import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_coach/models/song.dart';
import 'package:pitch_coach/models/youtube_link.dart';

void main() {
  const id = 'dQw4w9WgXcQ';

  group('유튜브 링크 → 영상 ID', () {
    test('여러 가지 링크 형태', () {
      for (final link in [
        'https://www.youtube.com/watch?v=$id',
        'https://www.youtube.com/watch?v=$id&t=42s&list=PL123',
        'https://youtu.be/$id?si=abcdef',
        'youtu.be/$id',
        'https://m.youtube.com/watch?v=$id',
        'https://music.youtube.com/watch?v=$id&feature=share',
        'https://www.youtube.com/shorts/$id',
        'https://www.youtube.com/embed/$id',
        'https://www.youtube.com/live/$id?feature=shared',
        '  $id  ',
      ]) {
        expect(YoutubeLink.videoId(link), id, reason: link);
      }
    });

    test('유튜브 링크가 아니면 null', () {
      for (final link in [
        '',
        '노래 제목',
        'https://vimeo.com/123456789',
        'https://www.youtube.com/watch?v=short',
        'https://www.youtube.com/@channel',
        'https://notyoutube.com/watch?v=$id',
      ]) {
        expect(YoutubeLink.videoId(link), isNull, reason: link);
      }
    });

    test('열기/검색 주소', () {
      expect(YoutubeLink.watchUri(id).toString(), 'https://www.youtube.com/watch?v=$id');
      expect(YoutubeLink.searchUri('학교종 동요').queryParameters['search_query'], '학교종 동요');
    });
  });

  group('노래 저장', () {
    test('영상 ID가 JSON으로 저장되고 다시 읽힌다', () {
      final song = Song.fromNotation(id: 'c1', title: '학교종', notation: '솔 솔 라 라', isCustom: true, youtubeId: id);
      expect(song.toJson()['youtube'], id);
      expect(Song.fromJson(song.toJson()).youtubeId, id);
    });

    test('영상이 없으면 키를 쓰지 않고, 예전 저장 파일도 읽힌다', () {
      final song = Song.fromNotation(id: 'c1', title: '학교종', notation: '솔 솔 라 라', isCustom: true);
      expect(song.toJson().containsKey('youtube'), isFalse);
      expect(Song.fromJson({'id': 'old', 'title': '예전 노래', 'notation': '도 레 미'}).youtubeId, isNull);
    });
  });
}
