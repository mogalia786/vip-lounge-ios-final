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

# Copy the logo to the temp directory
$sourceLogo = "assets\New_cc_logo.png"
$logoPath = "$tempDir\logo.png"

if (-not (Test-Path $sourceLogo)) {
    Write-Host "Error: $sourceLogo not found!"
    exit 1
}

Copy-Item -Path $sourceLogo -Destination $logoPath -Force

# Define target resolutions for different densities
$densityMap = @{
    "mipmap-mdpi" = 48
    "mipmap-hdpi" = 72
    "mipmap-xhdpi" = 96
    "mipmap-xxhdpi" = 144
    "mipmap-xxxhdpi" = 192
}

# Process the logo for each density
foreach ($density in $densityMap.GetEnumerator()) {
    $targetDir = "$resDir\$($density.Key)"
    $size = $density.Value
    
    # Create target directory if it doesn't exist
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir | Out-Null
    }
    
    # Copy the logo with the correct size
    $outputFile = "$targetDir\ic_launcher.png"
    
    # Try to resize with ImageMagick if available
    try {
        $magick = Get-Command magick -ErrorAction Stop
        magick convert "$logoPath" -resize ${size}x${size} -background none -gravity center -extent ${size}x${size} "$outputFile"
    } catch {
        # If ImageMagick is not available, just copy the file
        Copy-Item -Path $logoPath -Destination $outputFile -Force
    }
    
    # Create round launcher icon (copy of regular icon for now)
    $roundOutput = "$targetDir\ic_launcher_round.png"
    Copy-Item -Path $outputFile -Destination $roundOutput -Force
    
    # Create foreground icon (same as launcher icon for now)
    $foregroundOutput = "$targetDir\ic_launcher_foreground.png"
    Copy-Item -Path $outputFile -Destination $foregroundOutput -Force
    
    Write-Host "Created: $outputFile"
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

Write-Host "Launcher icons have been updated with New_cc_logo.png!"
Write-Host "Please rebuild your app with 'flutter build apk --release'"

# Clean up temporary files
Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
