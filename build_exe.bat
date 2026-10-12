@echo off
echo ========================================================
echo   Building S60 Inventory Windows Standalone Executable (.exe)
echo ========================================================
python -m PyInstaller --clean --noconfirm desktop_app.spec
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================================
    echo   BUILD SUCCESSFUL!
    echo   Output: dist\S60_Inventory.exe
    copy /Y "dist\S60_Inventory.exe" "..\S60_Inventory.exe"
    copy /Y "s60_config.json" "dist\s60_config.json"
    copy /Y "s60_config.json" "..\s60_config.json"
    echo   Copied directly to Desktop: ..\S60_Inventory.exe
    echo   Config file created: ..\s60_config.json
    echo ========================================================
) else (
    echo.
    echo [ERROR] Build failed. Please check the logs above.
)
