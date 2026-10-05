# Optimizer UI (C++ Win32)

This folder contains a lightweight Windows desktop frontend that launches the PowerShell optimizer script with a clean dark-mode style.

## What it does

- Shows a dark themed optimizer window
- Lets the user choose a profile: Safe / Balanced / Aggressive / Custom
- Runs the optimizer as Administrator using PowerShell
- Keeps the logic in the original PowerShell script while improving the UI feel

## Files

- `OptimizerUI.cpp` — Win32 desktop application
- `build_optimizer_ui.bat` — build script for MSVC

## Build

1. Open a Developer Command Prompt for Visual Studio.
2. Run:

```bat
build_optimizer_ui.bat
```

3. The resulting executable is `OptimizerUI.exe`.

## Important note

The script still requires the main optimizer file to be present beside the app, or you can adjust the path in the code.

```powershell
full_optimize.ps1
```
