@echo off
echo Starting phone data update...

:: Set Python executable path (update this to your Python path if needed)
set PYTHON=python

:: Navigate to the script directory
cd /d %~dp0

:: Run the Python script
%PYTHON% update_phone_data.py

:: Check for errors
if %ERRORLEVEL% EQU 0 (
    echo Phone data update completed successfully.
) else (
    echo ERROR: Phone data update failed with error code %ERRORLEVEL%
    pause
    exit /b %ERRORLEVEL%
)

:: Add a pause to see the output before the window closes
pause
