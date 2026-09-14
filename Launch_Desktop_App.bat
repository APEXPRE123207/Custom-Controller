@echo off
title Nintendo Switch Pro Controller - Desktop App
cd /d "%~dp0"
echo Starting Nintendo Switch Controller Desktop Receiver GUI...
start "" pythonw windows_receiver\desktop_app.py
if %ERRORLEVEL% NEQ 0 (
    echo pythonw not found in PATH, launching with python...
    python windows_receiver\desktop_app.py
)
