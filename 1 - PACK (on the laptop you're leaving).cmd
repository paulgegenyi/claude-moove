@echo off
REM =========================================================================
REM  CLAUDE MOOVE  -  carry ALL your Claude stuff to another laptop
REM
REM  On the laptop you're LEAVING:     double-click "1 - PACK ..."   (this one)
REM  On the laptop you're MOVING TO:   double-click "2 - UNPACK ..."
REM
REM  PACK makes a folder on your Desktop called "Claude Moove <date>".
REM  Copy that whole folder to a USB stick (or Google Drive), open it on the
REM  new laptop and double-click "2 - UNPACK". The window walks you through
REM  every step and checks everything for you.
REM
REM  Don't move or rename the "engine" folder next to this file.
REM =========================================================================
title Claude Moove
chcp 65001 >nul
if not exist "%~dp0engine\claude-moove.ps1" goto :inzip
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0engine\claude-moove.ps1" -Mode pack
if %errorlevel%==0 exit /b
if %errorlevel%==3 exit /b
echo.
echo   Claude Moove couldn't start. Take a photo of this window and show it to Claude.
pause
exit /b

:inzip
echo.
echo     ▐▛███▜▌    CLAUDE MOOVE
echo    ▝▜█████▛▘   You opened this from inside a zip file.
echo      ▘▘ ▝▝     Right-click the zip, choose "Extract All", open the extracted
echo                folder and double-click this button again.
echo.
pause
