# Play 스토어 업로드 키 만들기 (처음 한 번만)
#
#   powershell -ExecutionPolicy Bypass -File tools\create_upload_key.ps1
#
# - 키 파일은 저장소 밖(기본: H:\dev\keys\upload-keystore.jks)에 만든다.
# - android\key.properties 에 경로/비밀번호를 기록한다 (.gitignore 되어 있어 GitHub에 올라가지 않음).
# - 키 파일과 비밀번호를 잃어버리면 업데이트를 올릴 수 없으니 반드시 따로 백업할 것!
param(
    [string]$KeystorePath = 'H:\dev\keys\upload-keystore.jks',
    [string]$Alias = 'upload'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$propsPath = Join-Path $root 'android\key.properties'

# 이 프로젝트용 JDK(keytool) 경로 설정
if (Test-Path 'H:\dev\env.ps1') { . 'H:\dev\env.ps1' }
if (-not (Get-Command keytool -ErrorAction SilentlyContinue)) {
    throw 'keytool을 찾을 수 없어요. JDK 17을 설치하거나 H:\dev\env.ps1 을 확인해 주세요.'
}

if (Test-Path $KeystorePath) {
    throw "이미 키 파일이 있어요: $KeystorePath`n기존 키를 계속 써야 합니다. 새로 만들려면 다른 경로를 -KeystorePath 로 지정하세요."
}

function Read-Plain([string]$prompt) {
    $secure = Read-Host -AsSecureString $prompt
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

Write-Host ''
Write-Host '=== Play 스토어 업로드 키 만들기 ===' -ForegroundColor Cyan
$name = Read-Host '개발자 이름 또는 닉네임 (인증서에 기록됨, 영문 권장)'
if ([string]::IsNullOrWhiteSpace($name)) { $name = 'Developer' }

do {
    $pw = Read-Plain '키 비밀번호 (6자 이상)'
    $pw2 = Read-Plain '키 비밀번호 확인'
    if ($pw.Length -lt 6) { Write-Host '6자 이상이어야 해요.' -ForegroundColor Yellow; continue }
    if ($pw -ne $pw2) { Write-Host '두 비밀번호가 달라요.' -ForegroundColor Yellow }
} while ($pw.Length -lt 6 -or $pw -ne $pw2)

New-Item -ItemType Directory -Force (Split-Path $KeystorePath) | Out-Null
# 인증서 이름(X.500)에서 특별한 뜻이 있는 문자(\ , = + " < > ; #)는 keytool이 거부하므로 공백으로 바꾼다.
$cn = ($name -replace '[\\,=+"<>;#]', ' ').Trim()
if ([string]::IsNullOrWhiteSpace($cn)) { $cn = 'Developer' }
$dname = "CN=$cn, C=KR"

& keytool -genkeypair -v -keystore $KeystorePath -storetype PKCS12 -keyalg RSA -keysize 2048 `
    -validity 10000 -alias $Alias -storepass $pw -keypass $pw -dname $dname
if ($LASTEXITCODE -ne 0) { throw 'keytool 실패' }

# .properties 는 역슬래시를 이스케이프로 해석하므로 / 로 기록
$storeFile = $KeystorePath -replace '\\', '/'
$props = "storePassword=$pw`nkeyPassword=$pw`nkeyAlias=$Alias`nstoreFile=$storeFile`n"
[IO.File]::WriteAllText($propsPath, $props, (New-Object Text.UTF8Encoding $false))
$pw = $null; $pw2 = $null

Write-Host ''
Write-Host "✔ 키 생성: $KeystorePath" -ForegroundColor Green
Write-Host "✔ 설정 기록: $propsPath (GitHub에 올라가지 않음)" -ForegroundColor Green
Write-Host ''
Write-Host '⚠ 꼭 백업하세요: 키 파일(.jks) + 비밀번호. 잃어버리면 앱 업데이트가 불가능합니다.' -ForegroundColor Yellow
Write-Host '   (Play App Signing을 쓰면 업로드 키 분실 시 Google에 재설정 요청은 가능)' -ForegroundColor Yellow
Write-Host ''
Write-Host '다음 단계: powershell -ExecutionPolicy Bypass -File tools\build_release.ps1'
