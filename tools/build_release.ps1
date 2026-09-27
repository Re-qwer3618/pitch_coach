# Play 스토어 제출용 AAB 빌드
#
#   powershell -ExecutionPolicy Bypass -File tools\build_release.ps1
#
# 1) 업로드 키 확인  2) 테스트  3) flutter build appbundle  4) 서명 확인
# 결과: build\app\outputs\bundle\release\app-release.aab
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
if (Test-Path 'H:\dev\env.ps1') { . 'H:\dev\env.ps1' }

if (-not (Test-Path 'android\key.properties')) {
    throw "업로드 키가 없어요. 먼저 실행하세요: powershell -ExecutionPolicy Bypass -File tools\create_upload_key.ps1"
}

$version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()
Write-Host "버전: $version  (스토어에 올릴 때마다 + 뒤 숫자(versionCode)를 1씩 올려야 해요)" -ForegroundColor Cyan

Write-Host '▶ 테스트 실행' -ForegroundColor Cyan
flutter test
if ($LASTEXITCODE -ne 0) { throw '테스트 실패 — 빌드를 중단합니다.' }

Write-Host '▶ AAB 빌드' -ForegroundColor Cyan
flutter build appbundle --release
if ($LASTEXITCODE -ne 0) { throw '빌드 실패' }

$aab = Join-Path $root 'build\app\outputs\bundle\release\app-release.aab'
$cert = & keytool -J-Duser.language=en -printcert -jarfile $aab 2>&1 | Out-String
if ($cert -match 'CN=Android Debug') { throw 'debug 키로 서명됐어요. android\key.properties 를 확인하세요.' }
$owner = ($cert -split "`n" | Where-Object { $_ -match 'CN=' } | Select-Object -First 1)
if (-not $owner) { $owner = '(인증서 정보를 읽지 못했어요)' }

Write-Host ''
Write-Host "✔ 완성: $aab ($([math]::Round((Get-Item $aab).Length / 1MB, 1)) MB)" -ForegroundColor Green
Write-Host "  서명: $($owner.Trim())"
Write-Host '  Play Console > 테스트 및 출시 > (내부/비공개 테스트 또는 프로덕션) > 새 버전 만들기 에 업로드하세요.'
