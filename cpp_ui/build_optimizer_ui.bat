@echo off
setlocal
where cl >nul 2>nul
if errorlevel 1 (
    echo MSVC compiler not found. Open a Developer Command Prompt for Visual Studio and run this script again.
    echo Example: "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
    exit /b 1
)

cd /d "%~dp0"
cl /nologo /EHsc /utf-8 /DUNICODE /D_UNICODE /std:c++17 /FeOptimizerUI.exe OptimizerUI.cpp user32.lib gdi32.lib shell32.lib comctl32.lib
if errorlevel 1 (
    echo Build failed.
    exit /b 1
)

echo Build successful: OptimizerUI.exe
exit /b 0
