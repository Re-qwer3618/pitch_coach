# GitHub에서 빌드·서명하기

작업 PC가 바뀌어도 **서명 키는 GitHub Secrets에만** 두고, 푸시하면 GitHub Actions가 테스트 → 서명 → APK를 만듭니다.
폰에서는 Releases에서 APK를 받아 기존 앱 위에 덮어 설치합니다. PC에 Flutter나 Android SDK가 없어도 됩니다.

워크플로: [`.github/workflows/build-android.yml`](../.github/workflows/build-android.yml)

## 처음 한 번: 서명 키를 Secrets에 등록

**업로드 키(`upload-keystore.jks`)와 `android\key.properties`가 있는 PC**에서 실행합니다
(`tools\create_upload_key.ps1`로 키를 만든 PC, 기본 위치 `H:\dev\keys\`).

```
powershell -ExecutionPolicy Bypass -File tools\upload_signing_secrets.ps1
```

- GitHub CLI가 있고 로그인돼 있으면(`winget install GitHub.cli` → `gh auth login`) 4개를 바로 등록합니다.
- 없으면 키 값을 클립보드에 복사하고 등록 페이지를 열어 줍니다. 안내대로 4개를 붙여 넣으세요.

| Secret | 값 |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `.jks` 파일을 base64로 인코딩한 값 |
| `ANDROID_KEYSTORE_PASSWORD` | `key.properties`의 `storePassword` |
| `ANDROID_KEY_ALIAS` | `key.properties`의 `keyAlias` (기본 `upload`) |
| `ANDROID_KEY_PASSWORD` | `key.properties`의 `keyPassword` |

등록한 다음에는 키 파일이 없는 PC에서 작업해도 됩니다. **다만 키 파일과 비밀번호는 따로 백업해 두세요.**
GitHub Secrets는 값을 다시 볼 수 없어서, 키를 잃어버리면 Play 스토어 업데이트를 올릴 수 없습니다.

Secrets가 없으면 빌드는 일부러 실패합니다. debug 키로 서명된 APK는 폰의 기존 앱을 덮어쓰지 못하기 때문입니다.

## 폰에 설치

1. 푸시 후 약 10분 뒤 https://github.com/Re-qwer3618/pitch_coach/releases/latest 를 폰 브라우저로 엽니다.
2. Assets의 `pitch_coach-…-buildN.apk`를 눌러 받고 설치합니다(처음이면 '출처를 알 수 없는 앱' 허용).
3. 빌드 진행 상황과 실패 원인: https://github.com/Re-qwer3618/pitch_coach/actions

**"앱이 설치되지 않았습니다"가 뜨면** 폰의 앱이 다른 키(예: 예전 PC의 debug 키)로 서명된 것입니다.
기존 앱을 한 번 삭제하고 설치하세요. 이때 기기에 저장한 '내 노래'도 지워집니다. 그다음부터는 계속 덮어쓰기 업데이트가 됩니다.

## 참고

- 저장소가 공개라 **Releases의 APK는 누구나 받을 수 있습니다**. 서명 키는 Secrets에 있어 공개되지 않습니다.
- 문서만 바꾼 푸시(`*.md`, `docs/`, `store/`)는 빌드하지 않습니다. Actions 탭의 [Run workflow]로 직접 돌릴 수도 있습니다.
- Play 스토어에 올릴 `.aab`는 각 Actions 실행 페이지의 Artifacts(30일 보관)에 있습니다.
  스토어에 올릴 때마다 `pubspec.yaml`의 `version` `+` 뒤 숫자를 1씩 올리세요.
- Flutter 버전은 워크플로의 `flutter-version: 3.47.x`로 고정했습니다(README의 compileSdk 37 메모 참고).
