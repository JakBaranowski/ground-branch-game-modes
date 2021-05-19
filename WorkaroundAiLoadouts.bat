:: Creates empty .kit files in the _BadGuys dir mirroring the files in original BadGuys
:: allowing for them to be used in the mission editor.

@echo off
setlocal

set sourceDir=GroundBranch\Content\GroundBranch\AI\Loadouts\BadGuys
set targetDir=GroundBranch\Content\GroundBranch\AI\Loadouts\_BadGuys

if not exist %targetDir% (
    md %targetDir%
)

:: Create file in _BadGuys dir for every file in BadGuys dir
for /F %%f in ('dir /b /a-d %sourceDir%') do (
    if not exist "%targetDir%\%%f" (
        type nul > %targetDir%\%%f
        echo Created: %targetDir%\%%f
    )
)

:: Remove every file from _BadGuys dir that don't have counterpart in BadGuys dir
for /F %%f in ('dir /b /a-d %targetDir%') do (
    if not exist "%sourceDir%\%%f" (
        del %targetDir%\%%f
        echo Removed: %targetDir%\%%f
    )
)

endlocal