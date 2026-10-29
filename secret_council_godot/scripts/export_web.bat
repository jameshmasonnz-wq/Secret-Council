@echo off
setlocal
set "ROOT=%~dp0.."
if "%GODOT_BIN%"=="" set "GODOT_BIN=godot"
if "%WEB_OUT_DIR%"=="" set "WEB_OUT_DIR=%ROOT%\build\web"

if not exist "%WEB_OUT_DIR%" mkdir "%WEB_OUT_DIR%"
"%GODOT_BIN%" --headless --path "%ROOT%" --editor --quit
if errorlevel 1 exit /b %errorlevel%
"%GODOT_BIN%" --headless --path "%ROOT%" --export-release "Web" "%WEB_OUT_DIR%\index.html"
if errorlevel 1 exit /b %errorlevel%

if not exist "%WEB_OUT_DIR%\index.html" (
  echo ERROR: Web export did not create index.html.
  exit /b 2
)
echo Web export created at "%WEB_OUT_DIR%"
echo Publish the entire directory, not just index.html.
