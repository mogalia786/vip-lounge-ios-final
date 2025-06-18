# Silwela Flutter In-App Update: Build & Release Instructions

This document outlines the steps required to build a new release of the VIP Lounge application and deploy it for the in-app update mechanism.

## Pre-Deployment Steps (Manual)

Before running the automated deployment script, you must perform these two manual steps:

### 1. Update App Version in `pubspec.yaml`

Navigate to the `pubspec.yaml` file in the project root. Locate the `version` line and increment the version number according to your changes (e.g., from `1.1.0` to `1.1.1` for a patch, or `1.2.0` for a minor update).

**Example:**
```yaml
# before
version: 1.1.0+4

# after
version: 1.1.1+5
```
*Note: Remember to also increment the build number (the number after the `+`).*

### 2. Update Version in `public/version.json`

Navigate to the `public/version.json` file. Update the `version` field to **exactly match** the new version number you set in `pubspec.yaml` (without the `+buildNumber`).

**Example:**
```json
// before
{
  "version": "1.1.0",
  "apk_url": "https://vip-lounge-f3730.web.app/app-release.apk"
}

// after
{
  "version": "1.1.1",
  "apk_url": "https://vip-lounge-f3730.web.app/app-release.apk"
}
```

## Deployment Step (Automated)

### 3. Run the Deployment Script

Once the version numbers are updated and synchronized, open your terminal in the project's root directory and run the deployment script:

```bash
.\deploy_release.bat
```

This script will automatically:
1.  Build the release APK.
2.  Copy the new APK into the `public` folder.
3.  Deploy the `public` folder (containing the new APK and `version.json`) to Firebase Hosting.

After the script finishes, the new version will be live and available for users to download via the in-app update prompt.
