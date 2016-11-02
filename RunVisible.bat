@echo off

REM This can be run from MDT/SCCM like this (given you stored it in \Scripts\BiosSledgehammer):
REM ---
REM cmd.exe /c "%SCRIPTROOT%\BiosSledgehammer\RunVisible.bat"
REM ---

REM We need to make sure to start the 64-bit PowerShell on a 64-bit machine.
REM To avoid WoW we will need to use C:\Windows\sysnative
IF "%PROGRAMFILES(X86)%"=="" GOTO X86
GOTO X64

:X86
SET PS_EXE=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
GOTO RUN

:X64
SET PS_EXE=C:\Windows\sysnative\WindowsPowerShell\v1.0\powershell.exe
GOTO RUN


:RUN
start "BiosSledgehammer" /wait %PS_EXE% -ExecutionPolicy Bypass -File "%~dp0BiosSledgehammer.ps1" -WaitAtEnd

