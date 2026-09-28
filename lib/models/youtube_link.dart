/// 유튜브 링크 ↔ 영상 ID. 영상은 앱 안에서 재생하지 않고 유튜브 앱/브라우저로 연다
/// (앱이 인터넷 권한 없이 동작하도록).
class YoutubeLink {
  const YoutubeLink._();

  static final RegExp _id = RegExp(r'^[A-Za-z0-9_-]{11}$');

  /// 공유 링크, 주소창 링크, 쇼츠, 유튜브 뮤직 링크, 영상 ID 자체에서 영상 ID를 뽑는다.
  /// 유튜브 링크가 아니면 null.
  static String? videoId(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    if (_id.hasMatch(text)) return text;

    final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
    if (uri == null) return null;
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^(www|m|music)\.'), '');
    String? candidate;
    if (host == 'youtu.be') {
      candidate = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    } else if (host == 'youtube.com' || host == 'youtube-nocookie.com') {
      final segments = uri.pathSegments;
      if (segments.isNotEmpty && segments.first == 'watch') {
        candidate = uri.queryParameters['v'];
      } else if (segments.length >= 2 && const {'shorts', 'embed', 'live', 'v'}.contains(segments.first)) {
        candidate = segments[1];
      }
    }
    return candidate != null && _id.hasMatch(candidate) ? candidate : null;
  }

  static Uri watchUri(String videoId) => Uri.https('www.youtube.com', '/watch', {'v': videoId});

  static Uri searchUri(String query) => Uri.https('www.youtube.com', '/results', {'search_query': query});
}
