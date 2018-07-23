@echo.
@echo THE PROGRAM REQUIRED ADMINISTRATOR PRIVILEGES!
@echo.

"%~dp0BiosConfigUtility64.exe" /get:"%temp%\Settings.txt"

@echo.
@echo Data export to %temp%\Settings.txt
@echo.

start "launch" "%temp%\Settings.txt"

pause


