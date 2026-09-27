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

## 구조
```
lib/
  main.dart
  models/       note.dart, pitch_reading.dart, song.dart, match_result.dart
  services/     audio_capture_service.dart  마이크 PCM 스트림
                pitch_detector.dart         YIN F0 검출
                pitch_service.dart          윈도잉·스무딩 → PitchReading 스트림
                melody_matcher.dart         분할·정렬·채점·피드백
                permission_service.dart
  controllers/  live_pitch_controller.dart  화면용 실시간 상태
  views/        home_view, practice_view, song_view, result_view, widgets/
test/           pitch_detector_test, melody_matcher_test, widget_test
```

## 갤럭시에 설치하기
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
> 현재 릴리스 빌드는 Flutter 기본 설정대로 **debug 키로 서명**됩니다. 개인 설치용으로는 충분하지만,
> Play 스토어 배포 시에는 업로드 키를 만들어 `android/app/build.gradle.kts`의 `signingConfig`를 교체해야 합니다.

### iOS
`Info.plist`에 `NSMicrophoneUsageDescription`이 들어 있습니다. macOS에서 빌드할 때 `ios/Podfile`의
`post_install`에 permission_handler 마이크 매크로를 추가하세요:
```ruby
target.build_configurations.each do |config|
  config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)', 'PERMISSION_MICROPHONE=1']
end
```
