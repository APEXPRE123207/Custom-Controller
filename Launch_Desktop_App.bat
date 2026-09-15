@echo off
title SwiCon - Nintendo Switch Pro Controller Receiver
cd /d "%~dp0"

:: 1. Check for standalone EXE first
if exist "dist\SwiCon.exe" goto :run_exe

:: 2. Check for swicon conda environment
if exist "D:\MiniConda\envs\swicon\pythonw.exe" goto :run_conda

:: 3. Check for pythonw in PATH
where pythonw >nul 2>&1
if %ERRORLEVEL% EQU 0 goto :run_pythonw

:: 4. Check for python in PATH
where python >nul 2>&1
if %ERRORLEVEL% EQU 0 goto :run_python

echo [ERROR] Neither dist\SwiCon.exe nor Python was found!
echo Please run build_exe.bat or install Python.
pause
exit /b 1

:run_exe
echo Starting SwiCon Standalone App...
start "" /d "%~dp0" "%~dp0dist\SwiCon.exe"
exit /b 0

:run_conda
echo Starting SwiCon via swicon environment...
start "" /d "%~dp0" "D:\MiniConda\envs\swicon\pythonw.exe" "%~dp0windows_receiver\desktop_app.py"
exit /b 0

:run_pythonw
echo Starting SwiCon via pythonw...
start "" /d "%~dp0" pythonw "%~dp0windows_receiver\desktop_app.py"
exit /b 0

:run_python
echo Starting SwiCon via python...
start "" /d "%~dp0" python "%~dp0windows_receiver\desktop_app.py"
exit /b 0
