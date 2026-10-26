@echo off
setlocal

chcp 65001 >nul

set "SCRIPT=%~dp0ChromeAvatarRepair.ps1"

echo.
echo ================================================
echo   Chrome Profile Avatar Repair
echo ================================================
echo.

if not exist "%SCRIPT%" (
    echo ERROR:
    echo ChromeAvatarRepair.ps1 が見つかりません。
    echo.
    echo BATファイルとPS1ファイルを
    echo 同じフォルダに置いてください。
    echo.
    pause
    exit /b 1
)

powershell.exe ^
  -NoProfile ^
  -ExecutionPolicy Bypass ^
  -File "%SCRIPT%"

set "RC=%ERRORLEVEL%"

echo.

if "%RC%"=="0" (
    echo ================================================
    echo   処理が完了しました。
    echo ================================================
) else if "%RC%"=="2" (
    echo ================================================
    echo   処理をキャンセルしました。
    echo ================================================
) else (
    echo ================================================
    echo   エラーが発生しました。
    echo   ErrorLevel=%RC%
    echo ================================================
)

echo.
pause

exit /b %RC%
