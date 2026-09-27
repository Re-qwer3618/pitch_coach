# 앱 아이콘 / Play 스토어 그래픽 생성 (Windows System.Drawing 사용, 외부 도구 불필요)
#   assets/icon/icon.png          1024x1024  런처 아이콘 원본 (배경 포함)
#   assets/icon/foreground.png    1024x1024  적응형 아이콘 전경 (투명 배경)
#   store/icon-512.png            512x512    Play 스토어 앱 아이콘
#   store/feature-graphic.png     1024x500   Play 스토어 그래픽 이미지
# 사용: powershell -ExecutionPolicy Bypass -File tools/generate_store_assets.ps1
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Force "$root\assets\icon", "$root\store" | Out-Null

$indigo = [System.Drawing.Color]::FromArgb(255, 63, 81, 181)
$purple = [System.Drawing.Color]::FromArgb(255, 103, 58, 183)
$amber = [System.Drawing.Color]::FromArgb(255, 255, 193, 7)
$white = [System.Drawing.Color]::White

function New-Canvas([int]$w, [int]$h) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    return @($bmp, $g)
}

function Fill-Gradient($g, [int]$w, [int]$h) {
    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $indigo, $purple, 45.0
    $g.FillRectangle($brush, $rect)
    $brush.Dispose()
}

# 1024 좌표계 기준 마이크 + 음파. (cx, cy) 중심, scale 배율.
function Draw-Mic($g, [float]$cx, [float]$cy, [float]$scale) {
    $state = $g.Save()
    $g.TranslateTransform($cx, $cy)
    $g.ScaleTransform($scale, $scale)
    $g.TranslateTransform(-512, -512)

    $round = [System.Drawing.Drawing2D.LineCap]::Round

    # 음파 (좌우)
    $wave = New-Object System.Drawing.Pen $amber, 34
    $wave.StartCap = $round; $wave.EndCap = $round
    foreach ($r in 300, 380) {
        $g.DrawArc($wave, 512 - $r, 440 - $r, 2 * $r, 2 * $r, -32, 64)
        $g.DrawArc($wave, 512 - $r, 440 - $r, 2 * $r, 2 * $r, 148, 64)
    }

    # 마이크 캡슐
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $x = 412; $y = 230; $w = 200; $h = 380; $d = 200
    $path.AddArc($x, $y, $d, $d, 180, 180)
    $path.AddLine($x + $w, $y + $d / 2, $x + $w, $y + $h - $d / 2)
    $path.AddArc($x, $y + $h - $d, $d, $d, 0, 180)
    $path.CloseFigure()
    $g.FillPath((New-Object System.Drawing.SolidBrush $white), $path)

    # 캡슐 격자 무늬
    $grill = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(90, 63, 81, 181)), 14
    $grill.StartCap = $round; $grill.EndCap = $round
    foreach ($ly in 340, 400, 460) { $g.DrawLine($grill, 462, $ly, 562, $ly) }

    # 받침대
    $pen = New-Object System.Drawing.Pen $white, 40
    $pen.StartCap = $round; $pen.EndCap = $round
    $g.DrawArc($pen, 322, 300, 380, 380, 0, 180)
    $g.DrawLine($pen, 512, 680, 512, 780)
    $g.DrawLine($pen, 402, 790, 622, 790)

    $g.Restore($state)
}

function Save-Png($bmp, [string]$path) {
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "생성: $path"
}

# 1) 런처 아이콘 원본 (배경 포함, 전체 채움 — 런처가 모양을 자른다)
$bmp, $g = New-Canvas 1024 1024
Fill-Gradient $g 1024 1024
Draw-Mic $g 512 512 0.78
Save-Png $bmp "$root\assets\icon\icon.png"

# 2) Play 스토어 아이콘 512x512
$small, $g2 = New-Canvas 512 512
$g2.DrawImage($bmp, 0, 0, 512, 512)
Save-Png $small "$root\store\icon-512.png"
$g2.Dispose(); $small.Dispose(); $g.Dispose(); $bmp.Dispose()

# 3) 적응형 아이콘 전경 (안전 영역 66% 안에 들어가도록 축소)
$bmp, $g = New-Canvas 1024 1024
$g.Clear([System.Drawing.Color]::Transparent)
Draw-Mic $g 512 512 0.55
Save-Png $bmp "$root\assets\icon\foreground.png"
$g.Dispose(); $bmp.Dispose()

# 4) 그래픽 이미지 1024x500
$bmp, $g = New-Canvas 1024 500
Fill-Gradient $g 1024 500
Draw-Mic $g 250 250 0.46

# 오른쪽 아래 피아노 건반 장식
$keyW = 34; $keyH = 90; $kx0 = 470; $ky0 = 350
for ($i = 0; $i -lt 14; $i++) {
    $g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(230, 255, 255, 255))), $kx0 + $i * $keyW, $ky0, $keyW - 3, $keyH)
}
foreach ($i in 0, 1, 3, 4, 5, 7, 8, 10, 11, 12) {
    $g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 40, 40, 70))), $kx0 + ($i + 1) * $keyW - 11, $ky0, 20, 55)
}

$titleFont = New-Object System.Drawing.Font 'Malgun Gothic', 72, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$subFont = New-Object System.Drawing.Font 'Malgun Gothic', 30, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$g.DrawString('음치탈출', $titleFont, (New-Object System.Drawing.SolidBrush $white), 470, 110)
$g.DrawString('내 목소리 음정을 실시간으로', $subFont, (New-Object System.Drawing.SolidBrush $white), 474, 215)
$g.DrawString('피아노로 듣고 따라 부르기', $subFont, (New-Object System.Drawing.SolidBrush $amber), 474, 262)
Save-Png $bmp "$root\store\feature-graphic.png"
$g.Dispose(); $bmp.Dispose()
