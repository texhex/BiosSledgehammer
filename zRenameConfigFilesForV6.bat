@echo off
echo This will rename existing configuration files to the new naming schema used 
echo by BIOS Sledgehammer v6 and upward. You only need to execute this file once.
echo.
echo If something goes wrong during the rename (e.g. file in use), just execute it again.
echo.

pause

@echo on
cd "%~dp0"

for /R %%G in (BIOS-Update-Settings.tx?) do REN "%%G" "BIOS-Update-BIOS-Settings.txt"

for /R %%G in (Shared-BIOS-Update-Settings.tx?) do REN "%%G" "Shared-BIOS-Update-BIOS-Settings.txt"



pause
