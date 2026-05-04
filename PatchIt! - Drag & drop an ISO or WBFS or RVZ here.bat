@echo off
title Generic Wii patcher/rebuilder v0.6b - Pandora's Tower Edition
:: This "patcher" makes use of:
:: WIT https://wit.wiimm.de
:: DolphinTool https://github.com/dolphin-emu/dolphin
:: xxd https://github.com/ckormanyos/xxd
:: Xdelta https://github.com/jmacd/xdelta-gpl

pushd %~dp0

set InputPath=%~p1
set InputName=%~n1
set InputExt=%~x1
set InputFullName=%~nx1
set InputFullPath=%~1

:: Drag-and-drop files only notice
if "%InputFullPath%"=="" (
	echo Usage: Drag-and-drop an ISO/WBFS/RVZ onto this batch file to start
	echo the patching process correctly. Close the window and try again. & pause & exit
	)
:: If input is an ISO/WBFS/RVZ -> proceed
if /i "%InputExt%"==".iso" (goto :PROCEED) else if /i "%InputExt%"==".wbfs" (goto :PROCEED) else if /i "%InputExt%"==".rvz" (goto :PROCEED)
:: In case nothing has triggered the goto lables...
goto :ERROR_INVALID_INPUT
:PROCEED

echo ######################################
echo #      Select the output format      #
echo ######################################
echo.
echo I: ISO
echo W: WBFS
echo.
choice /c IW /m "ISO or WBFS"
if errorlevel 2 (set OutputType=WBFS) else if errorlevel 1 (set OutputType=ISO)
echo Selected: %OutputType%

cd tools
echo. & echo Extracting %InputFullName%...
if /i "%InputExt%"==".iso" (wit extract "%InputFullPath%" Extracted --psel data) else if /i "%InputExt%"==".wbfs" (wit extract "%InputFullPath%" Extracted --psel data)
if /i "%InputExt%"==".rvz" (
	dolphintool extract -i "%InputFullPath%" -o . -g -q
	ren DATA Extracted
	)

echo. & echo Determining the game region...
for /f "delims=" %%A in ('xxd -s 0x03 -l 1 -u -ps Extracted\sys\boot.bin') do (set Region=%%A)
if "%Region%"=="45" (set GameRegion=NA) else if "%Region%"=="50" (set GameRegion=EU) else if "%Region%"=="4A" (set GameRegion=JP)
echo Determined: %GameRegion%

:: Filtering out the unsupported game versions
if "%GameRegion%"=="JP" (goto :ERROR_INVALID_REGION)

:: Game-specific: Data merging
echo. & echo Merging the patch data...
robocopy ..\data\UNDUB Extracted /is /e /nfl /ndl /njh /njs /nc /ns /np
robocopy ..\data\UNDUB_%GameRegion% Extracted /is /e /nfl /ndl /njh /njs /nc /ns /np

:: Game-specific: Xdelta patching	// No termination if unable to patch
echo. & echo Applying xdelta patches...
for %%A in (..\data\movie_xdelta\*.xdelta) do (
	ren Extracted\files\movie\%%~nA %%~nA.old
	xdelta3 -d -s Extracted\files\movie\%%~nA.old ..\data\movie_xdelta\%%~nxA Extracted\files\movie\%%~nA
	if exist Extracted\files\movie\%%~nA (echo %%~nA patched successfully. & del /q Extracted\files\movie\%%~nA.old)
	if not exist Extracted\files\movie\%%~nA (echo %%~nA patching failed. & ren Extracted\files\movie\%%~nA.old %%~nA)
	)

echo. & echo Bulding a patched %OutputType%...
if "%OutputType%"=="ISO" (wit copy Extracted "..\%InputName% patched.iso")
if "%OutputType%"=="WBFS" (wit copy Extracted "..\%InputName% patched.wbfs" --split)

echo. & echo Cleaning up...
rmdir /q /s Extracted
cd ..
echo. & echo All done!
pause
exit

:ERROR_INVALID_REGION
rmdir /q /s Extracted
echo. & echo Only the North American version of the game is compatible with
echo this patch. Supply a compatible ISO/WBFS/RVZ and try again. & pause & exit

:ERROR_INVALID_INPUT
echo Looks like you've used something other for an input than
echo an ISO/WBFS/RVZ file. Close this window and try again. & pause & exit
