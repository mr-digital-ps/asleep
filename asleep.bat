@echo off
setlocal
cd /d "%~dp0"

if exist ".venv\Scripts\python.exe" (
    start "" /b ".venv\Scripts\python.exe" web.py
    exit /b 0
)

where uv >nul 2>nul
if %errorlevel% equ 0 (
    start "" /b uv run web.py
    exit /b 0
)

where python >nul 2>nul
if %errorlevel% equ 0 (
    start "" /b python web.py
    exit /b 0
)

echo [ERROR] Neither uv nor python was found in PATH.
pause
exit /b 1

