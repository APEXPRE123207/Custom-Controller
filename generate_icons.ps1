Add-Type -AssemblyName System.Drawing

$srcPath = "W:\CODE\Controller\app_logo.png"
if (-not (Test-Path $srcPath)) {
    Write-Error "Source image $srcPath does not exist."
    exit 1
}

$srcImg = [System.Drawing.Bitmap]::FromFile($srcPath)
$origWidth = $srcImg.Width
$origHeight = $srcImg.Height
Write-Host "Source image size: ${origWidth}x${origHeight}"

# We will take a square center crop
$dim = [Math]::Min($origWidth, $origHeight)
$cropX = ($origWidth - $dim) / 2
$cropY = ($origHeight - $dim) / 2
$cropRect = [System.Drawing.Rectangle]::new($cropX, $cropY, $dim, $dim)

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

    # Circular clipping path
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $path.AddEllipse(1, 1, $size - 2, $size - 2)
    $g.SetClip($path)

    # Draw scaled image inside circle
    $destRect = [System.Drawing.Rectangle]::new(0, 0, $size, $size)
    $g.DrawImage($srcImg, $destRect, $cropRect, [System.Drawing.GraphicsUnit]::Pixel)

    $g.ResetClip()

    # Draw subtle circular accent border (Neon Cyan / Gold aesthetic)
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
    Write-Host "Created: $destPath ($size x $size)"
}

$sizes = @{
    "android_app\android\app\src\main\res\mipmap-mdpi" = 48
    "android_app\android\app\src\main\res\mipmap-hdpi" = 72
    "android_app\android\app\src\main\res\mipmap-xhdpi" = 96
    "android_app\android\app\src\main\res\mipmap-xxhdpi" = 144
    "android_app\android\app\src\main\res\mipmap-xxxhdpi" = 192
}

foreach ($entry in $sizes.GetEnumerator()) {
    $folder = $entry.Key
    $px = $entry.Value
    Create-Circular-Icon -size $px -destPath "$folder\ic_launcher.png"
    Create-Circular-Icon -size $px -destPath "$folder\ic_launcher_round.png"
}

# Also create high-res asset for in-app display (512x512)
Create-Circular-Icon -size 512 -destPath "android_app\assets\icon\app_logo_circle.png"

$srcImg.Dispose()
Write-Host "All circular icons generated successfully!"
