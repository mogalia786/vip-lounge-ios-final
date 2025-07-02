# Update Launcher Icons Script

# Source and destination paths
$sourceImage = "assets/New_cc_logo.png"
$resFolders = @(
    "mipmap-hdpi/ic_launcher.png",
    "mipmap-mdpi/ic_launcher.png",
    "mipmap-xhdpi/ic_launcher.png",
    "mipmap-xxhdpi/ic_launcher.png",
    "mipmap-xxxhdpi/ic_launcher.png",
    "mipmap-hdpi/ic_launcher_round.png",
    "mipmap-mdpi/ic_launcher_round.png",
    "mipmap-xhdpi/ic_launcher_round.png",
    "mipmap-xxhdpi/ic_launcher_round.png",
    "mipmap-xxxhdpi/ic_launcher_round.png"
)

# Create a temporary directory for image processing
$tempDir = "temp_icons"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

# Create different icon sizes and copy to respective folders
foreach ($folder in $resFolders) {
    $destination = "android/app/src/main/res/$folder"
    
    # Create directory if it doesn't exist
    $dir = [System.IO.Path]::GetDirectoryName($destination)
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    
    # Copy the source image to the destination
    Copy-Item -Path $sourceImage -Destination $destination -Force
    Write-Host "Updated: $destination"
}

Write-Host "Icon update complete!"
Write-Host "Please rebuild your app to see the changes."
