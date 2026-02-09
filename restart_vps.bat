@echo off
setlocal EnableDelayedExpansion

REM ====================================================
REM VPS Restart Script
REM Reads configuration from .env file in the same directory
REM ====================================================

set ENV_FILE=%~dp0.env

if not exist "%ENV_FILE%" (
    echo Error: .env file not found at %ENV_FILE%
    echo Please create a .env file with VPS_HOST=your_ip
    pause
    exit /b 1
)

REM Load variables from .env file (ignoring comments)
for /f "usebackq tokens=1* delims==" %%A in (`type "%ENV_FILE%" ^| findstr /v "^#"`) do (
    set "key=%%A"
    set "value=%%B"
    if defined key (
        set "!key!=!value!"
    )
)

if "%VPS_HOST%"=="" (
    echo Error: VPS_HOST not set in .env file
    pause
    exit /b 1
)

if "%VPS_USER%"=="" set VPS_USER=root
if "%TARGET_DIR%"=="" set TARGET_DIR=/root/LilyIV

echo Connecting to %VPS_USER%@%VPS_HOST% to restart services in %TARGET_DIR%...

ssh %VPS_USER%@%VPS_HOST% "cd %TARGET_DIR% && echo Stopping services... && docker compose -f docker-compose.prod.yml down && echo. && echo Starting services... && docker compose -f docker-compose.prod.yml up -d && echo. && echo Current Status: && docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

echo.
echo Operation complete.
pause
