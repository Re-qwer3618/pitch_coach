# GitHub Actions 서명용 Secrets 등록 (업로드 키가 있는 PC에서 한 번만)
#
#   powershell -ExecutionPolicy Bypass -File tools\upload_signing_secrets.ps1
#
# android\key.properties (tools\create_upload_key.ps1이 만든 것)에서 키 파일 경로·별칭·비밀번호를 읽어
# 저장소 Secrets 4개를 등록한다. 비밀번호와 키 값은 화면에 출력하지 않는다 (내 PC에서만 실행할 것).
# - GitHub CLI(gh)가 있고 로그인돼 있으면 바로 등록한다.
# - 없으면 키 파일의 base64 값을 클립보드에 복사하고, 웹에서 등록하는 방법을 안내한다.
# 등록한 뒤에는 이 PC에 키가 없어도 GitHub가 같은 키로 서명한다 (docs\ci-build.md).
param(
    [string]$Repo = 'Re-qwer3618/pitch_coach'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$propsPath = Join-Path $root 'android\key.properties'

if (-not (Test-Path $propsPath)) {
    throw "android\key.properties 가 없어요.`n업로드 키를 만든 PC에서 실행하거나, 키가 아직 없다면 먼저 만드세요:`n  powershell -ExecutionPolicy Bypass -File tools\create_upload_key.ps1 -KeystorePath <키를 둘 경로>\upload-keystore.jks"
}

$props = @{}
foreach ($line in Get-Content $propsPath -Encoding UTF8) {
    if ($line -match '^\s*([^#!=][^=]*?)\s*=\s*(.*)$') { $props[$Matches[1]] = $Matches[2].Trim() }
}
foreach ($key in 'storeFile', 'storePassword', 'keyAlias', 'keyPassword') {
    if (-not $props[$key]) { throw "key.properties 에 $key 값이 없어요." }
}

# storeFile은 절대 경로이거나 android\app 기준 상대 경로 (Gradle file() 규칙)
$storeFile = $props['storeFile'] -replace '/', '\'
if (-not [IO.Path]::IsPathRooted($storeFile)) { $storeFile = Join-Path $root "android\app\$storeFile" }
if (-not (Test-Path $storeFile)) { throw "키 파일이 없어요: $storeFile" }
$keystoreBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($storeFile))

$secrets = [ordered]@{
    ANDROID_KEYSTORE_BASE64   = $keystoreBase64
    ANDROID_KEYSTORE_PASSWORD = $props['storePassword']
    ANDROID_KEY_ALIAS         = $props['keyAlias']
    ANDROID_KEY_PASSWORD      = $props['keyPassword']
}

Write-Host ''
Write-Host "키 파일: $storeFile" -ForegroundColor Cyan
Write-Host "저장소:  $Repo" -ForegroundColor Cyan

$gh = Get-Command gh -ErrorAction SilentlyContinue
$ghReady = $false
if ($gh) {
    # gh는 로그인 상태를 stderr로 알려서, PowerShell 5.1에서 직접 리디렉션하면 오류로 멈춘다 → cmd로 감싼다.
    cmd /c "gh auth status >nul 2>&1"
    $ghReady = $LASTEXITCODE -eq 0
}

if ($ghReady) {
    foreach ($name in $secrets.Keys) {
        # 파이프로 넘기면 PowerShell 5.1이 줄바꿈을 붙이고 인코딩을 바꿀 수 있어 --body로 정확히 넘긴다.
        & gh secret set $name --repo $Repo --body $secrets[$name]
        if ($LASTEXITCODE -ne 0) { throw "$name 등록 실패" }
        Write-Host "✔ $name" -ForegroundColor Green
    }
    Write-Host ''
    Write-Host '완료! 이제 푸시하면 GitHub가 이 키로 서명한 APK를 만들어요.' -ForegroundColor Green
    Write-Host "  빌드 결과: https://github.com/$Repo/actions"
    Write-Host "  폰에서 받기: https://github.com/$Repo/releases/latest"
    return
}

# gh가 없거나 로그인 전 → 웹에서 직접 등록
$keystoreBase64 | Set-Clipboard
$url = "https://github.com/$Repo/settings/secrets/actions/new"
Write-Host ''
if (-not $gh) {
    Write-Host 'GitHub CLI(gh)가 없어서 웹에서 등록하도록 안내할게요.' -ForegroundColor Yellow
    Write-Host '  (자동으로 하려면: winget install GitHub.cli → gh auth login → 이 스크립트 다시 실행)'
} else {
    Write-Host 'gh 로그인이 안 돼 있어요. (gh auth login 후 다시 실행하면 자동 등록)' -ForegroundColor Yellow
}
Write-Host ''
Write-Host "브라우저에서 [New repository secret]으로 4개를 하나씩 등록하세요: $url"
Write-Host ''
Write-Host '  1. ANDROID_KEYSTORE_BASE64   ← 지금 클립보드에 복사돼 있어요. 그대로 붙여 넣기'
Write-Host "  2. ANDROID_KEYSTORE_PASSWORD ← key.properties 의 storePassword 값"
Write-Host "  3. ANDROID_KEY_ALIAS         ← $($props['keyAlias'])"
Write-Host "  4. ANDROID_KEY_PASSWORD      ← key.properties 의 keyPassword 값"
Write-Host ''
Write-Host "key.properties 위치: $propsPath"
Write-Host '등록이 끝나면 클립보드를 비우세요 (아무 글자나 복사).' -ForegroundColor Yellow
Start-Process $url
