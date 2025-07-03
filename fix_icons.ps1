# Clean up existing icon files
$resDir = "android\app\src\main\res"
$mipmapDirs = @("mipmap-hdpi", "mipmap-mdpi", "mipmap-xhdpi", "mipmap-xxhdpi", "mipmap-xxxhdpi")

# Remove all existing launcher icons
foreach ($dir in $mipmapDirs) {
    $fullPath = "$resDir\$dir"
    if (Test-Path $fullPath) {
        Remove-Item "$fullPath\ic_launcher.png" -ErrorAction SilentlyContinue
        Remove-Item "$fullPath\ic_launcher_round.png" -ErrorAction SilentlyContinue
        Remove-Item "$fullPath\ic_launcher_foreground.png" -ErrorAction SilentlyContinue
    }
}

# Create a temporary directory for image processing
$tempDir = "temp_icons"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

# Copy the Premium.ico to the temp directory
Copy-Item -Path "assets\Premium.ico" -Destination "$tempDir\icon.ico" -Force

# Use ImageMagick to convert ICO to PNG
# If ImageMagick is not installed, we'll use a fallback approach
$iconFiles = @()

try {
    # Try using ImageMagick if available
    $magick = Get-Command magick -ErrorAction Stop
    
    # Create a 512x512 transparent PNG as a base
    magick convert -size 512x512 xc:none -alpha set "$tempDir\icon_base.png"
    
    # Convert ICO to PNG and resize to 70% of 512px (358x358) to ensure padding
    magick convert "$tempDir\icon.ico" -resize 358x358 -background none -gravity center -extent 358x358 "$tempDir\icon_resized.png"
    
    # Composite the resized icon onto the transparent base
    magick composite -gravity center "$tempDir\icon_resized.png" "$tempDir\icon_base.png" "$tempDir\launcher_icon.png"
    
    # Create foreground icon (same as launcher icon for now)
    Copy-Item -Path "$tempDir\launcher_icon.png" -Destination "$tempDir\launcher_foreground.png" -Force
    
    $iconFiles = @("launcher_icon.png", "launcher_foreground.png")
} catch {
    Write-Host "ImageMagick not found. Using fallback approach..."
    
    # Fallback: Use the original icon files if they exist
    if (Test-Path "assets\launcher_icon.png") {
        Copy-Item -Path "assets\launcher_icon.png" -Destination "$tempDir\launcher_icon.png" -Force
        $iconFiles += "launcher_icon.png"
    }
    if (Test-Path "assets\launcher_foreground.png") {
        Copy-Item -Path "assets\launcher_foreground.png" -Destination "$tempDir\launcher_foreground.png" -Force
        $iconFiles += "launcher_foreground.png"
    }
}

# Define target resolutions for different densities
$densityMap = @{
    "mipmap-mdpi" = 48
    "mipmap-hdpi" = 72
    "mipmap-xhdpi" = 96
    "mipmap-xxhdpi" = 144
    "mipmap-xxxhdpi" = 192
}

# Process each icon file
foreach ($iconFile in $iconFiles) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($iconFile)
    $isForeground = $baseName -like "*foreground*"
    
    foreach ($density in $densityMap.GetEnumerator()) {
        $targetDir = "$resDir\$($density.Key)"
        $size = $density.Value
        
        # Create target directory if it doesn't exist
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir | Out-Null
        }
        
        $outputFile = if ($isForeground) {
            "$targetDir\ic_launcher_foreground.png"
        } else {
            "$targetDir\ic_launcher.png"
        }
        
        # Try to resize with ImageMagick if available
        try {
            $magick = Get-Command magick -ErrorAction Stop
            magick convert "$tempDir\$iconFile" -resize ${size}x${size} "$outputFile"
        } catch {
            # If ImageMagick is not available, just copy the file
            Copy-Item -Path "$tempDir\$iconFile" -Destination $outputFile -Force
        }
        
        Write-Host "Created: $outputFile"
    }
}

# Create round launcher icons by copying the regular ones
foreach ($density in $densityMap.GetEnumerator()) {
    $targetDir = "$resDir\$($density.Key)"
    $sourceFile = "$targetDir\ic_launcher.png"
    $targetFile = "$targetDir\ic_launcher_round.png"
    
    if (Test-Path $sourceFile) {
        Copy-Item -Path $sourceFile -Destination $targetFile -Force
        Write-Host "Created: $targetFile"
    }
}

# Create adaptive icon XML
$adaptiveIconXml = @"
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"@

# Create mipmap-anydpi-v26 directory if it doesn't exist
$anydpiDir = "$resDir\mipmap-anydpi-v26"
if (-not (Test-Path $anydpiDir)) {
    New-Item -ItemType Directory -Path $anydpiDir | Out-Null
}

# Write the adaptive icon XML files
$adaptiveIconPath = "$anydpiDir\ic_launcher.xml"
$adaptiveIconRoundPath = "$anydpiDir\ic_launcher_round.xml"

Set-Content -Path $adaptiveIconPath -Value $adaptiveIconXml
Set-Content -Path $adaptiveIconRoundPath -Value $adaptiveIconXml

Write-Host "Launcher icons have been regenerated successfully!"
Write-Host "Please rebuild your app with 'flutter build apk --release'"

# Clean up temporary files
Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
