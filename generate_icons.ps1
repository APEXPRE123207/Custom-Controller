Add-Type -AssemblyName System.Drawing

$srcPath = "W:\CODE\Controller\app_logo.jpg"
if (-not (Test-Path $srcPath)) {
    Write-Error "Source image $srcPath does not exist."
    exit 1
}

$srcImg = [System.Drawing.Bitmap]::FromFile($srcPath)
$origWidth = $srcImg.Width
$origHeight = $srcImg.Height
Write-Host "Source image size: ${origWidth}x${origHeight}"

# Square center crop
$dim = [Math]::Min($origWidth, $origHeight)
$cropX = ($origWidth - $dim) / 2
$cropY = ($origHeight - $dim) / 2
$cropRect = [System.Drawing.Rectangle]::new($cropX, $cropY, $dim, $dim)

# Function to create full square launcher icons for home screen
function Create-Square-Icon {
    param (
        [int]$size,
        [string]$destPath
    )

    $destBmp = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($destBmp)
    
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    # Fill solid dark background
    $g.Clear([System.Drawing.Color]::FromArgb(255, 12, 14, 20))

    $destRect = [System.Drawing.Rectangle]::new(0, 0, $size, $size)
    $g.DrawImage($srcImg, $destRect, $cropRect, [System.Drawing.GraphicsUnit]::Pixel)

    $g.Dispose()

    $dir = Split-Path -Parent $destPath
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $destBmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $destBmp.Dispose()
    Write-Host "Created Square Launcher Icon: $destPath ($size x $size)"
}

# Function to create elegant non-bursting Splash Screen icon (58% centered with black margins)
function Create-Splash-Icon {
    param (
        [int]$canvasSize,
        [double]$scaleRatio,
        [string]$destPath
    )

    $destBmp = [System.Drawing.Bitmap]::new($canvasSize, $canvasSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($destBmp)
    
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    # Deep black background matching the app theme
    $g.Clear([System.Drawing.Color]::FromArgb(255, 12, 14, 20))

    # Scale controller to ~58% of canvas so it is not oversized or bursting
    $targetDim = [int]($canvasSize * $scaleRatio)
    $targetX = [int](($canvasSize - $targetDim) / 2)
    $targetY = [int](($canvasSize - $targetDim) / 2)
    $destRect = [System.Drawing.Rectangle]::new($targetX, $targetY, $targetDim, $targetDim)

    $g.DrawImage($srcImg, $destRect, $cropRect, [System.Drawing.GraphicsUnit]::Pixel)

    $g.Dispose()

    $dir = Split-Path -Parent $destPath
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $destBmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $destBmp.Dispose()
    Write-Host "Created Splash Icon: $destPath ($canvasSize x $canvasSize, content: $targetDim px)"
}

# Function to create circular in-app logo
function Create-Circular-Icon {
    param (
        [int]$size,
        [string]$destPath
    )

    $destBmp = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($destBmp)
    
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $path.AddEllipse(1, 1, $size - 2, $size - 2)
    $g.SetClip($path)

    $destRect = [System.Drawing.Rectangle]::new(0, 0, $size, $size)
    $g.DrawImage($srcImg, $destRect, $cropRect, [System.Drawing.GraphicsUnit]::Pixel)

    $g.ResetClip()

    $pen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(180, 0, 195, 227), 2)
    $g.DrawEllipse($pen, 1, 1, $size - 2, $size - 2)
    $pen.Dispose()

    $g.Dispose()
    $path.Dispose()

    $dir = Split-Path -Parent $destPath
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $destBmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $destBmp.Dispose()
    Write-Host "Created Circular In-App Logo: $destPath ($size x $size)"
}

$sizes = @{
    "android_app\android\app\src\main\res\mipmap-mdpi" = 48
    "android_app\android\app\src\main\res\mipmap-hdpi" = 72
    "android_app\android\app\src\main\res\mipmap-xhdpi" = 96
    "android_app\android\app\src\main\res\mipmap-xxhdpi" = 144
    "android_app\android\app\src\main\res\mipmap-xxxhdpi" = 192
}

# 1. Launcher icons
foreach ($entry in $sizes.GetEnumerator()) {
    $folder = $entry.Key
    $px = $entry.Value
    Create-Square-Icon -size $px -destPath "$folder\ic_launcher.png"
    Create-Square-Icon -size $px -destPath "$folder\ic_launcher_round.png"
}

# 2. Splash Screen Icons (not big, 58% center ratio on dark background)
Create-Splash-Icon -canvasSize 288 -scaleRatio 0.58 -destPath "android_app\android\app\src\main\res\drawable-xxxhdpi\splash_icon.png"
Create-Splash-Icon -canvasSize 216 -scaleRatio 0.58 -destPath "android_app\android\app\src\main\res\drawable-xxhdpi\splash_icon.png"
Create-Splash-Icon -canvasSize 144 -scaleRatio 0.58 -destPath "android_app\android\app\src\main\res\drawable-xhdpi\splash_icon.png"
Create-Splash-Icon -canvasSize 108 -scaleRatio 0.58 -destPath "android_app\android\app\src\main\res\drawable-hdpi\splash_icon.png"
Create-Splash-Icon -canvasSize 72  -scaleRatio 0.58 -destPath "android_app\android\app\src\main\res\drawable-mdpi\splash_icon.png"
Create-Splash-Icon -canvasSize 288 -scaleRatio 0.58 -destPath "android_app\android\app\src\main\res\drawable\splash_icon.png"

# 3. Circular in-app logo
Create-Circular-Icon -size 512 -destPath "android_app\assets\icon\app_logo_circle.png"

$srcImg.Dispose()
Write-Host "All icons generated: Non-bursting Splash + Square launcher + Circular in-app logo!"
