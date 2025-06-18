@echo off
REM Silwela Flutter In-App Update Automated Release Script
REM 1. Build APK
REM 2. Update version.json
REM 3. Deploy to Firebase Hosting

set APK_PATH=build\app\outputs\flutter-apk\app-release.apk
set PUBLIC_DIR=public
set VERSION_JSON=%PUBLIC_DIR%\version.json
set APK_DEST=%PUBLIC_DIR%\app-release.apk

REM 1. Build APK
echo Building APK...
flutter build apk --release || goto :error

REM 2. Copy APK to public folder
echo Copying APK to public folder...
copy /Y %APK_PATH% %APK_DEST% || goto :error

REM 3. Update version.json (manual step: edit version number in version.json if needed)
echo Ensure version.json is updated with new version and APK URL.

REM 4. Deploy to Firebase Hosting
echo Deploying to Firebase Hosting...
firebase deploy --only hosting || goto :error

echo Deployment complete.

echo.
echo --- MANUAL TESTING STEPS ---
echo After a successful deployment, follow these steps on an Android device:
echo 1. Install an OLD version of the app (e.g., from a previous build).
echo 2. Run the app and navigate to the home screen.
echo 3. Verify that the "Update Available" dialog appears.
echo 4. Tap "Update" and confirm the new version downloads and installs correctly.
echo --------------------------

goto :eof

:error
echo ERROR during deployment. Check steps above.
exit /b 1
