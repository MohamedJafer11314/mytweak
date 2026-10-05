# Full Optimize for Windows

One PowerShell script that trims Windows 10/11 bloat: unnecessary services, telemetry, ads and tips, startup junk, animations, and preinstalled apps. It creates a restore point and backups **before** changing anything.

> **Use at your own risk.** The script changes system settings. Read it first, and make sure you understand what it does. It is a single readable file: [`full_optimize.ps1`](full_optimize.ps1).

## Quick start

Open **PowerShell as Administrator** (right-click Start, then *Terminal (Admin)* or *Windows PowerShell (Admin)*) and run:

```powershell
irm https://raw.githubusercontent.com/USERNAME/REPO/main/full_optimize.ps1 | iex
```

The script asks for confirmation (`Y/N`) before it does anything. Restart your PC when it finishes.

### Prefer to read it first? (recommended)

```powershell
irm https://raw.githubusercontent.com/USERNAME/REPO/main/full_optimize.ps1 -OutFile full_optimize.ps1
notepad full_optimize.ps1      # review and edit the SETTINGS block at the top
Set-ExecutionPolicy -Scope Process Bypass
.\full_optimize.ps1
```

## What it does

| Area | Changes |
|---|---|
| Safety | Creates a System Restore point, exports service startup modes (`services_before.csv`) and your power plan (`power_before.pow`), and logs everything to a folder on your Desktop |
| Services | Sets telemetry/diagnostic services (DiagTrack, SysMain, RetailDemo, RemoteRegistry...) to Disabled and rarely used ones (Xbox, Maps, Fax, Insider...) to Manual. OEM updaters (Dell, Google, Adobe, Java, Brave) go to Manual |
| Privacy | Telemetry to minimum, advertising ID off, Start-menu suggestions/tips off, consumer features off, no P2P update uploads |
| Background | Background apps, Game DVR, Copilot, Windows AI data analysis, Edge startup boost and background mode: off. Game Mode stays on |
| Visuals | Animations, transparency, shadows, Aero Peek off; Widgets, Chat and Task View buttons hidden |
| Power (plugged in only) | Higher CPU boost, active cooling, no USB/PCIe/disk sleep. Battery settings untouched |
| Gaming | Higher scheduling priority for games |
| Defender | Stays **ON**. Only scan CPU usage is limited |
| Startup | Disables startup entries for Discord, Spotify, Steam, Telegram, OneDrive, Teams, Skype, Adobe, Java, CCleaner, IObit and similar (editable list). Antivirus is not touched |
| Tasks | Disables updater and telemetry scheduled tasks |
| Apps | Removes Store bloat (Clipchamp, Solitaire, Bing News/Weather, Teams, Phone Link, Copilot, etc.). Optional picker at the end lets you choose installed programs to uninstall |
| Cleanup | Temp files, DNS cache, SSD TRIM, .NET compile queue |

It does **not** disable Windows Defender, Windows Update, the firewall, networking, audio, or graphics.

## Settings

Open the script and edit the block at the top (before running, or after downloading it):

```powershell
$DisableSearchIndexer    = $false   # $true = stop Windows Search indexing
$DisableAnyDesk          = $false
$RemoveStoreBloat        = $true
$DisableAnimations       = $true
$DisableToastNotifs      = $false   # $true = turn off ALL pop-up notifications
$FastKillHungApps        = $false   # $true = hung apps close fast; unsaved work can be lost
$TunePowerOnAC           = $true
$LimitDefenderCpu        = $true
$DisableHibernation      = $false
$DefenderExclusions      = $false
$CheckInstallUtil        = $true
$PickProgramsToUninstall = $true    # opens a selection window at the end
```

## Undo

- **System Restore:** *Create a restore point* in the Start menu, then *System Restore*, and choose **"Before full_optimize"**.
- **Services:** the old startup modes are saved in `services_before.csv` in the backup folder (`optimize_backup_<date>` on your Desktop). Change them back in `services.msc`.
- **Power plan:** `powercfg /import power_before.pow` from the backup folder.
- **Removed Store apps:** reinstall from the Microsoft Store.

## Requirements

- Windows 10 version 2004 (build 19041) or newer, or Windows 11
- Windows PowerShell 5.1 (built in). The program picker needs `Out-GridView`, which is not available in some PowerShell 7 setups. The script skips it automatically in that case.
- Administrator rights

## Notes

- Some changes need a restart, and Explorer restarts at the end of the run (your taskbar flickers once).
- Windows updates can reset some settings. Run the script again if that happens; it is safe to run more than once.

## Disclaimer

Provided "as is", without warranty of any kind. You are responsible for what runs on your machine. Review the code before running it.

---

## بالعربي (ملخص)

سكربت PowerShell واحد بينضف ويحسّن ويندوز: بيوقف الخدمات والتتبع والإعلانات اللي ملهاش لازمة، وبيشيل برامج الـ startup والأنيميشن والتطبيقات الزايدة. قبل أي تغيير بيعمل نقطة استعادة (restore point) ونسخة احتياطية.

**التشغيل:** افتح PowerShell كـ **Administrator** واكتب:

```powershell
irm https://raw.githubusercontent.com/USERNAME/REPO/main/full_optimize.ps1 | iex
```

السكربت بيسألك Y/N قبل ما يبدأ. **Windows Defender وWindows Update والجدار الناري ما بيتلمسوش.** يُفضّل تقرأ الملف الأول (الطريقة التانية فوق) وتعدّل الإعدادات اللي في أوله على ذوقك. ولو حصلت مشكلة ارجع للـ restore point اسمها **Before full_optimize**.
