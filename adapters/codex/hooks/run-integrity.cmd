@echo off
setlocal EnableDelayedExpansion
REM Native Codex launcher. It contains no workflow policy.
if exist "%PLUGIN_ROOT%\bin\ff-integrity.exe" (
  "%PLUGIN_ROOT%\bin\ff-integrity.exe" host-preflight --host codex --mode observe
  exit /b !ERRORLEVEL!
)
REM Report degradation only for calls that could concern Feature Flow.
findstr /L /C:".feature-flow" /C:"ff-integrity" >nul 2>nul
if !ERRORLEVEL! equ 0 echo {"systemMessage":"Feature Flow integrity observe-only: FFI_CAPABILITY_DEGRADED"}
exit /b 0
