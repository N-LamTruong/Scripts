@echo off
setlocal enabledelayedexpansion

set "LOG_DIR=C:\ProgramData\TEMP"
set "LOG_FILE=%LOG_DIR%\%DATE:~0,2%-%DATE:~3,2%-%DATE:~6,4%.txt"
set "CURRENT_DATE=%DATE:~0,2%-%DATE:~3,2%-%DATE:~6,4%"

REM Kiểm tra và nén file log của ngày hôm qua
set /A "PREVIOUS_DAY=%DATE:~0,2%-1"
if %PREVIOUS_DAY% LSS 10 set PREVIOUS_DAY=0%PREVIOUS_DAY%
set "PREVIOUS_DATE=%PREVIOUS_DAY%-%DATE:~3,2%-%DATE:~6,4%"
set "PREVIOUS_LOG=%LOG_DIR%\%PREVIOUS_DATE%.txt"
if exist "%PREVIOUS_LOG%" (
  echo Compressing previous log file...
  "C:\Program Files\WinRAR\Rar.exe" a -ep -r "%LOG_DIR%\%PREVIOUS_DATE%.rar" "%PREVIOUS_LOG%" > nul
  if %errorlevel%==0 (
    echo Compression successful. Deleting previous log file...
    del "%PREVIOUS_LOG%"
  ) else (
    echo Compression failed.
  )
)

echo. >> %LOG_FILE%
echo Time: %TIME:~0,5% %DATE:~0,2%/%DATE:~3,2%/%DATE:~6,4% >> %LOG_FILE%
for /f "delims=" %%i in ('curl -s "https://api.ipify.org/?format=text"') do set "IP=%%i"
echo IP Public: !IP! >> %LOG_FILE%
nslookup connect.vadar.vn > nul
if "%errorlevel%"=="0" (
  echo nslookup -OK- >> %LOG_FILE%
  telnet connect.vadar.vn 15141 > nul 2>&1
  if "%errorlevel%"=="0" (
    echo telnet 15141 -OK- >> %LOG_FILE%
    tracert -d -w 1000 connect.vadar.vn >> %LOG_FILE%
  ) else (
    echo telnet 15141 -NOT OK- >> %LOG_FILE%
  )
) else (
  echo nslookup -NOT OK- >> %LOG_FILE%
)
