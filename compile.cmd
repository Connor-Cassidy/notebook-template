@echo off
setlocal
cd /d "%~dp0"
set "COMPILE_LOG=%~dp0installation\compile.log"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0installation\compile.ps1" > "%COMPILE_LOG%" 2>&1
set "COMPILE_STATUS=%ERRORLEVEL%"
type "%COMPILE_LOG%"
if not "%COMPILE_STATUS%"=="0" (
  echo.
  echo Compilation failed. The complete output is saved in:
  echo %COMPILE_LOG%
  pause
  exit /b %COMPILE_STATUS%
)
echo.
echo Done: notes.html
echo Log: installation\compile.log
