@echo off
echo ========================================================
echo   Building S60 Inventory Android Release APK
echo ========================================================
echo.

cd /d "%~dp0mobile"

where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Flutter SDK is not detected in your PATH.
    echo.
    echo To build the native Android APK on your machine:
    echo 1. Download Flutter SDK from: https://docs.flutter.dev/get-started/install/windows/mobile
    echo 2. Extract Flutter (e.g. to C:\src\flutter) and add C:\src\flutter\bin to your Windows PATH.
    echo 3. Install Android Studio (with Android SDK and Java JDK 17).
    echo 4. Run this script again!
    echo.
    pause
    exit /b 1
)

echo [1/3] Fetching Flutter dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo [ERROR] Failed to fetch flutter packages.
    pause
    exit /b 1
)

echo.
echo [2/3] Building release APK...
call flutter build apk --release --split-per-abi=false
if %errorlevel% neq 0 (
    echo [ERROR] APK build failed. Please verify Android SDK is installed.
    pause
    exit /b 1
)

echo.
echo ========================================================
echo   SUCCESS! Your installable APK has been created at:
echo   %~dp0mobile\build\app\outputs\flutter-apk\app-release.apk
echo ========================================================
echo.
explorer "%~dp0mobile\build\app\outputs\flutter-apk"
pause
