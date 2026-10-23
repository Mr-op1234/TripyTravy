@echo off
cd /d "%~dp0apps\agent_desktop\build\windows\x64\runner\Release"
start "" "agent_desktop.exe"
exit /b 0
