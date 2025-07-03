# Update Launcher Icons Script

# Source and destination paths
$sourceImage = "assets/Premium.ico"
$resFolders = @(
    "mipmap-hdpi/ic_launcher.png",
    "mipmap-mdpi/ic_launcher.png",
    "mipmap-xhdpi/ic_launcher.png",
    "mipmap-xxhdpi/ic_launcher.png",
    "mipmap-xxxhdpi/ic_launcher.png",
    "mipmap-hdpi/ic_launcher_foreground.png",
    "mipmap-mdpi/ic_launcher_foreground.png",
    "mipmap-xhdpi/ic_launcher_foreground.png",
    "mipmap-xxhdpi/ic_launcher_foreground.png",
    "mipmap-xxxhdpi/ic_launcher_foreground.png",
    "mipmap-hdpi/ic_launcher_round.png",
    "mipmap-mdpi/ic_launcher_round.png",
    "mipmap-xhdpi/ic_launcher_round.png",
    "mipmap-xxhdpi/ic_launcher_round.png",
    "mipmap-xxxhdpi/ic_launcher_round.png"
)

# Android resource directory
$androidResDir = "android/app/src/main/res"

# Create a temporary directory for image processing
$tempDir = "temp_icons"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

# Create different icon sizes and copy to respective folders
foreach ($folder in $resFolders) {
    $destination = "$androidResDir/$folder"
    
    # Create directory if it doesn't exist
    $dir = [System.IO.Path]::GetDirectoryName($destination)
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    
    # Copy the source image to the destination
    Copy-Item -Path $sourceImage -Destination $destination -Force
    Write-Host "Updated: $destination"
}

# Update the adaptive icon XML
$adaptiveIconXml = @"
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"@

$adaptiveIconPath = "$androidResDir/mipmap-anydpi-v26/ic_launcher.xml"
$adaptiveIconRoundPath = "$androidResDir/mipmap-anydpi-v26/ic_launcher_round.xml"

# Create mipmap-anydpi-v26 directory if it doesn't exist
$anydpiDir = "$androidResDir/mipmap-anydpi-v26"
if (!(Test-Path $anydpiDir)) {
    New-Item -ItemType Directory -Force -Path $anydpiDir | Out-Null
}

# Write the adaptive icon XML files
Set-Content -Path $adaptiveIconPath -Value $adaptiveIconXml
Set-Content -Path $adaptiveIconRoundPath -Value $adaptiveIconXml

Write-Host "Icon update complete!"
Write-Host "Please clean and rebuild your app to see the changes."
