# 🎤 음치탈출 (pitch_coach)

마이크 입력을 실시간으로 분석해 음정을 시각화하고, 동요 '학교종' 멜로디 매칭으로 음치 탈출을 돕는 Flutter 앱(MVP).
ML 서버 없이 기기 안에서 경량 DSP(YIN 알고리즘)로만 동작합니다.

## 기능
| 모듈 | 구현 |
|---|---|
| ① 마이크 권한 · 스트림 | `permission_handler`로 앱 실행 시 권한 요청, `record`의 PCM16 44.1kHz raw 스트림(파일 저장 없음) |
| ② 피치 엔진 | 순수 Dart YIN (2048샘플 창 / 1024 hop ≈ 23ms 마다 갱신) + RMS 무음 게이트 + 3프레임 중앙값 스무딩 → 음이름·계이름·센트 |
| ③ 시각화 | 큰 음이름 표시, ±50센트 튜너 게이지(초록/주황/빨강), 흘러가는 피치 그래프 |
| 🎹 피아노 | 배음 합성으로 만든 피아노 음(음원 파일 없음, 센트 단위 재현). 건반 위 연속 커서로 현재 음 표시, 건반 탭 → 소리 + 목표 음 설정, 학교종 멜로디/첫 음 듣기, 결과 화면에서 정답 음 vs 내가 부른 음 비교 듣기. 재생 중에는 마이크 분석을 잠시 멈춰 스피커 소리 오인식을 막음 |
| ④ 학교종 매칭 | 음표 분할 → DP 정렬(빠뜨린/덧붙인 음 허용) → 옥타브 자동 보정 → 일치율(%)·음표별 비교·피드백 |

## 연습곡
기본 수록곡: 도레미 음계 · 도미솔 도약(기초 연습) / 비행기 · 학교종 · 작은별(동요) / 환희의 송가 · 징글벨 후렴(명곡, 계이름으로 부르기).

**내 노래 추가** — 노래 연습 → [노래 추가]에서 계이름 악보를 입력하거나 피아노 건반을 눌러 입력합니다. 기기에 저장되며 수정·삭제할 수 있습니다.

| 표기 | 뜻 |
|---|---|
| `도 레 미 파 솔 라 시` | 가운데 도 옥타브(C4~B4), 띄어쓰기 자유 |
| `도'` / `솔,` (또는 `높은도` / `낮은솔`) | 한 옥타브 위 / 아래 |
| `도#` `미b` | 반음 |
| `미-` `레--` `솔_` `미.` | 2박 / 3박 / 반 박 / 1.5박 (기본 1박) |
| 줄바꿈, `/` | 소절 나누기 |
| `G4` `C#5` | 영어 음이름 |

가사는 한 글자에 한 음씩 붙고, 비워 두면 계이름으로 부릅니다.

**MIDI 가져오기** — 노래 추가 화면의 [MIDI 가져오기]로 `.mid`/`.midi`/`.kar` 파일을 고르면 계이름 악보로 바꿔 채웁니다
(`lib/services/midi_importer.dart`, 순수 Dart 파서).
- 트랙·채널별로 멜로디 후보를 만들어 고르게 합니다. 드럼(10번 채널)은 빼고, 화음은 가장 높은 음만 남기며,
  트랙 이름이 멜로디/보컬이거나 화음이 적은 파트를 먼저 추천합니다.
- 박자는 반 박 단위로 맞춥니다. 계이름 악보에 쉼표가 없어서, 짧은 쉼은 앞 음에 붙이고 한 박 이상 쉬면 소절을 나눕니다.
- 가운데 음이 F4 근처가 되도록 옥타브를 옮깁니다(채점은 원래 옥타브 자동 보정).
- 가사(lyric/.kar 텍스트 이벤트)는 UTF-8이고 음절 수가 음표 수와 딱 맞을 때만 가져옵니다.

**원곡 영상** — 노래에 유튜브 링크를 붙여 두면 연습 화면의 [원곡] 버튼이 유튜브 앱(없으면 브라우저)에서 엽니다.
앱 안에서 재생하지 않으므로 인터넷 권한 없이 동작합니다. 음원을 내려받거나 분석하지 않습니다(유튜브 약관).

## 구조
```
lib/
  main.dart
  models/       note.dart, pitch_reading.dart, song.dart, notation.dart, match_result.dart, youtube_link.dart
  services/     audio_capture_service.dart  마이크 PCM 스트림
                pitch_detector.dart         YIN F0 검출
                pitch_service.dart          윈도잉·스무딩 → PitchReading 스트림
                melody_matcher.dart         분할·정렬·채점·피드백
                permission_service.dart
                midi_importer.dart          MIDI 파일 → 멜로디 후보 → 계이름 악보
                youtube_launcher.dart       원곡 영상을 유튜브 앱으로 열기
  controllers/  live_pitch_controller.dart  화면용 실시간 상태
  views/        home_view, practice_view, song_view, result_view, widgets/
test/           pitch_detector_test, melody_matcher_test, song_test, midi_importer_test, youtube_link_test, widget_test
```

## 갤럭시에 설치하기
**가장 쉬운 방법: GitHub에서 받기.** 푸시하면 GitHub Actions가 서명된 APK를 만들어 [Releases](https://github.com/Re-qwer3618/pitch_coach/releases/latest)에 올립니다.
폰에서 열어 APK를 받아 설치하면 됩니다(처음 설정: [docs/ci-build.md](docs/ci-build.md)). PC에서 직접 빌드했다면 아래 순서를 따르세요.

1. `build/app/outputs/flutter-apk/app-release.apk` 파일을 폰으로 옮깁니다 (USB, 카카오톡 나에게 보내기, 구글 드라이브 등).
2. 폰의 **내 파일** 앱에서 APK를 누릅니다.
3. "출처를 알 수 없는 앱" 경고가 나오면 **설정 → 이 출처 허용**을 켜고 설치합니다.
4. Play 프로텍트 경고가 나오면 **무시하고 설치**를 누릅니다 (개인 서명 APK라 뜨는 정상 경고).
5. 첫 실행 시 마이크 권한을 **허용**합니다.

USB 디버깅이 켜진 폰을 연결했다면 PC에서 바로 설치할 수도 있습니다:
```
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## 직접 빌드하기
```
flutter pub get
flutter test
flutter build apk --release
```
> **빌드 환경 메모**
> - Windows에서는 프로젝트를 짧은 경로(예: `H:\dev\pitch_coach`)에 두세요. 경로가 260자를 넘으면 에셋 쓰기 단계에서 빌드가 실패합니다.
> - `permission_handler`는 `12.0.1`로 고정되어 있습니다. 13.x(android 14.x)는 compileSdk 37을 요구하는데,
>   Flutter 3.47의 AGP 9.1이 `android-37.0`으로 배포된 SDK Platform 37을 인식하지 못해 빌드가 깨집니다.
>
> `android/key.properties`(업로드 키)가 있으면 릴리스 빌드가 그 키로 서명되고, 없으면 debug 키로 서명됩니다(개인 설치용).

## Google Play 스토어 출시
[docs/play-store-guide.md](docs/play-store-guide.md)에 전체 절차가 있습니다.
```
powershell -ExecutionPolicy Bypass -File tools\create_upload_key.ps1   # 업로드 키 생성 (처음 한 번)
powershell -ExecutionPolicy Bypass -File tools\build_release.ps1       # 서명된 AAB 빌드
```
개인정보처리방침: [docs/privacy-policy.md](docs/privacy-policy.md) · 스토어 그래픽: `store/`

### iOS
`Info.plist`에 `NSMicrophoneUsageDescription`이 들어 있습니다. macOS에서 빌드할 때 `ios/Podfile`의
`post_install`에 permission_handler 마이크 매크로를 추가하세요:
```ruby
target.build_configurations.each do |config|
  config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)', 'PERMISSION_MICROPHONE=1']
end
```
