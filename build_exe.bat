@echo off
title Building SwiCon Desktop App (.exe)
cd /d "%~dp0"

set PYTHON=D:\MiniConda\envs\swicon\python.exe

echo ============================================
echo   SwiCon Desktop App - EXE Builder
echo ============================================
echo.

:: Check Python exists
if not exist "%PYTHON%" (
    echo [ERROR] Python not found at %PYTHON%
    echo Please update the PYTHON path in this script.
    pause
    exit /b 1
)

set "PATH=D:\MiniConda\envs\swicon;D:\MiniConda\envs\swicon\Scripts;D:\MiniConda\envs\swicon\Library\bin;%PATH%"

echo [1/3] Installing PyInstaller...
"%PYTHON%" -m pip install pyinstaller --quiet

echo [2/3] Building standalone EXE...
if exist "dist\SwiCon.exe" del /f /q "dist\SwiCon.exe"

"%PYTHON%" -m PyInstaller ^
    --onefile ^
    --windowed ^
    --name "SwiCon" ^
    --paths "D:\MiniConda\envs\swicon\Library\bin" ^
    --add-binary "D:\MiniConda\envs\swicon\Library\bin\*.dll;." ^
    --add-data "D:\MiniConda\envs\swicon\Library\lib\tcl8.6;tcl" ^
    --add-data "D:\MiniConda\envs\swicon\Library\lib\tk8.6;tk" ^
    --add-data "D:\MiniConda\envs\swicon\Lib\site-packages\vgamepad\win\vigem;vgamepad\win\vigem" ^
    --hidden-import vgamepad ^
    --hidden-import vgamepad.win ^
    --hidden-import vgamepad.win.vigem_commons ^
    --hidden-import vgamepad.win.vigem_client ^
    --hidden-import pydirectinput ^
    --collect-all vgamepad ^
    --distpath ".\dist" ^
    --workpath ".\build_temp" ^
    --clean ^
    --noconfirm ^
    "windows_receiver\desktop_app.py"

echo.
if exist "dist\SwiCon.exe" (
    echo ============================================
    echo   BUILD SUCCESSFUL!
    echo   Output: dist\SwiCon.exe
    echo ============================================
    echo.
    echo You can now distribute dist\SwiCon.exe
    echo Note: SwiCon will automatically detect if ViGEmBus
    echo       is missing and download/install it with one click!
) else (
    echo [ERROR] Build failed. Check output above.
)

echo.
pause
