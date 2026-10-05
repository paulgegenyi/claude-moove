@echo off
REM =========================================================================
REM  CLAUDE MOOVE  -  carry ALL your Claude stuff to another laptop
REM
REM  On the laptop you're LEAVING:     double-click "1 - PACK ..."
REM  On the laptop you're MOVING TO:   double-click "2 - UNPACK ..."   (this one)
REM
REM  Use this inside the "Claude Moove <date>" folder that PACK made.
REM  The window walks you through every step and checks everything:
REM  installing Claude, signing in, closing Claude, merging your chats,
REM  Node.js and Git, and downloading your project folders from GitHub.
REM  Nothing already on this laptop gets lost.
REM
REM  Don't move or rename the "engine" folder next to this file.
REM =========================================================================
title Claude Moove
chcp 65001 >nul
if not exist "%~dp0engine\claude-moove.ps1" goto :inzip
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0engine\claude-moove.ps1" -Mode unpack
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
