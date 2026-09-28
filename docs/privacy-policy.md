# 개인정보처리방침 — 음치탈출

시행일: 2026년 9월 29일

'음치탈출'(이하 "앱")은 사용자의 개인정보를 수집하지 않습니다. 이 문서는 앱이 어떤 데이터를 어떻게 다루는지 설명합니다.

## 1. 마이크 사용
- 앱은 **노래하는 목소리의 음정(주파수)을 실시간으로 분석**하기 위해 마이크 권한을 요청합니다.
- 마이크 소리는 **기기 안에서만** 음정 계산에 사용되며, **녹음 파일로 저장하지 않고, 외부 서버로 전송하지 않습니다.**
- 분석 결과(음정 흐름, 점수)는 화면에 표시하는 동안에만 메모리에 머물며, 화면을 벗어나면 사라집니다.
- 마이크 권한은 기기 설정에서 언제든지 끌 수 있습니다. 끄면 음정 분석 기능만 동작하지 않습니다.

## 2. 기기에 저장되는 데이터
- 사용자가 직접 추가한 노래(제목, 계이름 악보, 가사, 빠르기, 원곡 유튜브 영상 주소)는 **앱 전용 저장 공간에만** 저장됩니다.
- MIDI 파일을 가져올 때는 사용자가 파일 선택 창에서 **직접 고른 파일 하나만** 읽어 악보로 바꾸며, 파일 자체는 저장하거나 전송하지 않습니다. 저장소 전체 접근 권한은 요청하지 않습니다.
- 원곡 영상 버튼을 누르면 유튜브 앱 또는 브라우저가 열립니다. 이후의 영상 재생은 앱 밖(유튜브)에서 이루어지며 유튜브의 개인정보처리방침이 적용됩니다.
- 피아노 소리 재생을 위해 만든 임시 소리 파일은 앱의 임시 폴더에 저장되며, 시스템이 필요 시 자동으로 지웁니다.
- 이 데이터는 외부로 전송되지 않으며, 앱을 삭제하면 함께 삭제됩니다.

## 3. 수집·공유하지 않는 정보
- 이름, 이메일, 전화번호, 위치, 연락처, 기기 식별자 등 어떠한 개인정보도 수집하지 않습니다.
- 광고, 분석(애널리틱스), 로그인 기능이 없으며, 제3자에게 데이터를 제공하지 않습니다.
- 앱은 인터넷 권한을 사용하지 않습니다.

## 4. 아동의 개인정보
앱은 개인정보를 수집하지 않으므로 아동의 개인정보도 수집하지 않습니다.

## 5. 방침 변경
이 방침이 바뀌면 이 페이지에 변경 내용과 시행일을 게시합니다.

## 6. 문의
https://github.com/Re-qwer3618/pitch_coach/issues

---

# Privacy Policy — 음치탈출 (Pitch Coach)

Effective date: September 29, 2026

This app does **not collect any personal data**.

- **Microphone:** used only to analyze the pitch of your singing voice in real time. Audio is processed **on the device only**; it is **never recorded to a file or sent to any server**.
- **On-device data:** songs you add (title, notation, lyrics, tempo, reference YouTube video link) are stored only in the app's private storage and are deleted when the app is uninstalled. Temporary piano sound files are kept in the app's cache.
- **MIDI import:** only the single file you pick in the system file picker is read and converted on the device; the file itself is not kept or sent anywhere. No broad storage permission is requested.
- **Reference videos:** the "original" button opens the YouTube app or your browser. Playback happens outside this app, under YouTube's privacy policy.
- **No collection or sharing:** no account, no ads, no analytics, no third-party SDKs that collect data, and no internet permission.
- **Children:** the app collects no personal information from anyone, including children.
- **Contact:** https://github.com/Re-qwer3618/pitch_coach/issues
