@echo off
echo Setting up monthly phone data update...

:: Set the script path
set "SCRIPT_PATH=%~dp0update_phone_data.bat"
set "TASK_NAME=UpdatePhoneData"
set "DESCRIPTION=Monthly update of phone specifications data"

:: Create a scheduled task that runs on the 1st of every month at 2:00 AM
schtasks /create /tn "%TASK_NAME%" ^
         /tr "\"%SCRIPT_PATH%\"" ^
         /sc monthly /d 1 /st 02:00 ^
         /ru "SYSTEM" ^
         /rl HIGHEST ^
         /f

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Successfully scheduled monthly phone data update.
    echo The task will run on the 1st of every month at 2:00 AM.
) else (
    echo.
    echo ERROR: Failed to schedule the task.
    exit /b 1
)

echo.
echo You can verify the task in Windows Task Scheduler.
echo.
pause
