@echo off
setlocal EnableDelayedExpansion
REM Native Codex launcher. It contains no workflow policy.
if exist "%PLUGIN_ROOT%\bin\ff-integrity.exe" (
  "%PLUGIN_ROOT%\bin\ff-integrity.exe" host-preflight --host codex --mode observe
  exit /b !ERRORLEVEL!
)
echo {"systemMessage":"Feature Flow integrity observe-only: FFI_CAPABILITY_DEGRADED"}
exit /b 0
