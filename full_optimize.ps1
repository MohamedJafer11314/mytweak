#Requires -RunAsAdministrator
<#
  FULL OPTIMIZE  -  all-in-one (merges: optimize, no_animations, bloat_fix, remove_apps, ultimate_optimize)

  - Makes a restore point + backs up services and power plan BEFORE touching anything.
  - Does NOT disable Windows Defender, Windows Update, firewall, Wi-Fi, audio or graphics.
  - Services go to Manual/Disabled (never deleted). Safe to run more than once.
  - Everything is logged to the backup folder on your Desktop.
#>

# ============================ SETTINGS (edit if you want) ============================
$OptimizationProfile     = 'Balanced'  # Safe / Balanced / Aggressive
$DisableSearchIndexer    = $false   # $true = stop Windows Search indexing (Start-menu search gets slower; fine if you use "Everything")
$DisableAnyDesk          = $false   # $true = AnyDesk service -> Manual (you can still start it by hand)
$RemoveStoreBloat        = $true    # Clipchamp, Solitaire, Teams, Bing apps, Phone Link, Copilot...
$DisableAnimations       = $true    # animations, transparency, visual effects
$DisableToastNotifs      = $false   # $true = turn OFF ALL pop-up notifications (was in no_animations.ps1)
$FastKillHungApps        = $false   # $true = AutoEndTasks: closes hung apps fast. UNSAVED WORK CAN BE LOST
$TunePowerOnAC           = $true    # CPU boost / cooling / no USB+PCIe sleep (plugged in only)
$LimitDefenderCpu        = $true    # Defender scans use less CPU (protection stays ON)
$DisableHibernation      = $false   # frees disk space (= size of RAM); keep $false if unsure
$DefenderExclusions      = $false   # exclude .minecraft/.lunarclient from scans (only if you trust your mods)
$CheckInstallUtil        = $true    # report on InstallUtil.exe if it is running
$PickProgramsToUninstall = $true    # at the END: a window opens, you choose programs to uninstall
# Startup entries to disable (wildcards matched against Run-key names). Add/remove as you like.
# Antivirus products (Avast, AVG...) are NOT in this list on purpose.
$KillStartup = @('*Driver*Booster*','*IObit*','*Discord*','*Spotify*','*Telegram*','*Steam*','*Teams*',
                 '*OneDrive*','*Skype*','*Adobe*','*Java*','*CCleaner*',
                 '*SupportAssist*','*MicrosoftEdgeAutoLaunch*','*Brave*')
# Services and apps that should be protected from aggressive cleanup.
$ProtectedServices = @('W32Time','Dhcp','Dnscache','MpsSvc','WinDefender','SecurityHealthService','wuauserv','UsoSvc','BITS')
$ProtectedApps = @('Microsoft.WindowsStore','Microsoft.WindowsCalculator','Microsoft.Windows.Photos','Microsoft.XboxApp')
# =====================================================================================

switch ($OptimizationProfile) {
    'Safe' {
        Write-Host "Optimization profile: Safe (lowest-risk)" -ForegroundColor Green
        $DisableSearchIndexer    = $false
        $RemoveStoreBloat        = $false
        $DisableAnimations       = $true
        $DisableToastNotifs      = $false
        $FastKillHungApps        = $false
        $TunePowerOnAC           = $true
        $LimitDefenderCpu        = $true
        $DisableHibernation      = $false
        $DefenderExclusions      = $false
        $CheckInstallUtil        = $true
        $PickProgramsToUninstall = $false
    }
    'Balanced' {
        Write-Host "Optimization profile: Balanced (recommended default)" -ForegroundColor Green
    }
    'Aggressive' {
        Write-Host "Optimization profile: Aggressive (more opinionated tuning)" -ForegroundColor Yellow
        $DisableSearchIndexer    = $true
        $RemoveStoreBloat        = $true
        $DisableAnimations       = $true
        $DisableToastNotifs      = $false
        $FastKillHungApps        = $false
        $TunePowerOnAC           = $true
        $LimitDefenderCpu        = $true
        $DisableHibernation      = $false
        $DefenderExclusions      = $false
        $CheckInstallUtil        = $true
        $PickProgramsToUninstall = $true
    }
    default {
        Write-Host "Unknown optimization profile '$OptimizationProfile'. Valid values: Safe, Balanced, Aggressive" -ForegroundColor Red
        return
    }
}

# ---- Admin check (#Requires is ignored when run via "irm | iex", so we check here) ----
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if(-not $isAdmin){
    Write-Host "Please open PowerShell as Administrator, then run the command again." -ForegroundColor Red
    return
}

# ---- Profile guard / safe defaults ----
$Profile = $Profile.Trim()
switch($Profile.ToLowerInvariant()){
    'safe' {
        $DisableSearchIndexer    = $false
        $DisableAnyDesk          = $false
        $RemoveStoreBloat        = $false
        $DisableAnimations       = $false
        $DisableToastNotifs      = $false
        $FastKillHungApps        = $false
        $TunePowerOnAC           = $false
        $LimitDefenderCpu        = $true
        $DisableHibernation      = $false
        $DefenderExclusions      = $false
        $CheckInstallUtil        = $true
        $PickProgramsToUninstall = $false
        $SkipCriticalServices    = $true
        Write-Host "Profile: SAFE (least aggressive, more conservative)" -ForegroundColor Green
    }
    'balanced' {
        $DisableSearchIndexer    = $false
        $DisableAnyDesk          = $false
        $RemoveStoreBloat        = $true
        $DisableAnimations       = $true
        $DisableToastNotifs      = $false
        $FastKillHungApps        = $false
        $TunePowerOnAC           = $true
        $LimitDefenderCpu        = $true
        $DisableHibernation      = $false
        $DefenderExclusions      = $false
        $CheckInstallUtil        = $true
        $PickProgramsToUninstall = $true
        $SkipCriticalServices    = $true
        Write-Host "Profile: BALANCED (recommended default)" -ForegroundColor Cyan
    }
    'gaming' {
        $DisableSearchIndexer    = $true
        $DisableAnyDesk          = $true
        $RemoveStoreBloat        = $true
        $DisableAnimations       = $true
        $DisableToastNotifs      = $false
        $FastKillHungApps        = $false
        $TunePowerOnAC           = $true
        $LimitDefenderCpu        = $true
        $DisableHibernation      = $false
        $DefenderExclusions      = $false
        $CheckInstallUtil        = $true
        $PickProgramsToUninstall = $true
        $SkipCriticalServices    = $false
        Write-Host "Profile: GAMING (more aggressive tuning)" -ForegroundColor Yellow
    }
    default {
        Write-Host "Unknown profile '$Profile'; using BALANCED defaults." -ForegroundColor Yellow
        $Profile = 'Balanced'
    }
}

# ---- Confirmation ----
Write-Host "FULL OPTIMIZE changes Windows services, registry settings, startup items and may remove apps." -ForegroundColor Yellow
Write-Host "A restore point and backups are created first. Review the SETTINGS at the top of the script before running." -ForegroundColor Yellow
if((Read-Host "Continue? (Y/N)") -notmatch '^[Yy]'){ Write-Host "Cancelled."; return }

$ErrorActionPreference = 'SilentlyContinue'
$stamp = Get-Date -Format 'yyyyMMdd_HHmm'
$bk = "$env:USERPROFILE\Desktop\optimize_backup_$stamp"
New-Item $bk -ItemType Directory -Force | Out-Null
Start-Transcript "$bk\log.txt" | Out-Null

# Save a simple summary of how this run was configured
@{
    Profile = $Profile
    DisableSearchIndexer = $DisableSearchIndexer
    DisableAnyDesk = $DisableAnyDesk
    RemoveStoreBloat = $RemoveStoreBloat
    DisableAnimations = $DisableAnimations
    TunePowerOnAC = $TunePowerOnAC
    LimitDefenderCpu = $LimitDefenderCpu
    PickProgramsToUninstall = $PickProgramsToUninstall
    Timestamp = (Get-Date).ToString('o')
} | Export-Clixml "$bk\config.xml"

$TotalSteps = 14
function Step($n,$t){ Write-Host "`n[$n/$TotalSteps] $t" -ForegroundColor Cyan }
function Set-Reg($path,$name,$val,$type='DWord'){
    if(!(Test-Path $path)){ New-Item $path -Force | Out-Null }
    Set-ItemProperty -Path $path -Name $name -Value $val -Type $type -Force
}
function Set-Svc($pattern,$mode,$by='Name'){
    Get-Service | Where-Object { $_.$by -match $pattern } | ForEach-Object {
        if($ProtectedServices -contains $_.Name){
            Write-Host "   protected service skipped: $($_.DisplayName)" -ForegroundColor Yellow
            return
        }
        Write-Host "   service: $($_.DisplayName) -> $mode"
        Stop-Service $_.Name -Force
        Set-Service $_.Name -StartupType $mode
    }
}

# Windows version check
if([Environment]::OSVersion.Version.Build -lt 19041){
    Write-Host "This script needs Windows 10 (2004) or newer." -ForegroundColor Red
    Stop-Transcript | Out-Null; return
}

# ------------------------------------------------------------------ 1. Safety net
Step 1 "Safety net: restore point + backups"
Enable-ComputerRestore -Drive "$env:SystemDrive\"
# Windows normally allows only one restore point per 24h; lift that limit for this run
$srKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
Set-Reg $srKey 'SystemRestorePointCreationFrequency' 0
Checkpoint-Computer -Description "Before full_optimize" -RestorePointType MODIFY_SETTINGS
Remove-ItemProperty -Path $srKey -Name 'SystemRestorePointCreationFrequency'
Get-CimInstance Win32_Service | Select-Object Name,DisplayName,StartMode,State |
    Export-Csv "$bk\services_before.csv" -NoTypeInformation
$regBackupPaths = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search',
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection',
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
)
foreach($p in $regBackupPaths){
    if(Test-Path $p){
        $safeName = (($p -replace '[:\\/]','_') -replace '[^A-Za-z0-9_.-]','_') + '_before.reg'
        reg.exe export $p "$bk\$safeName" /y | Out-Null
    }
}
$active = ((powercfg /getactivescheme) -replace '.*:\s*([0-9a-fA-F-]{36}).*','$1').Trim()
powercfg /export "$bk\power_before.pow" $active | Out-Null
Write-Host "   backup folder: $bk"

# ------------------------------------------------------------------ 2. Services
Step 2 "Services (Manual/Disabled, never deleted)"
foreach($s in 'DiagTrack','dmwappushservice','RetailDemo','RemoteRegistry','SysMain'){
    Stop-Service $s -Force; Set-Service $s -StartupType Disabled
}
$manual = @('MapsBroker','Fax','WerSvc','XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc',
            'DSAService','DSAUpdateService','lfsvc','PhoneSvc','WMPNetworkSvc','icssvc','SharedAccess',
            'wisvc','SCardSvr','ScDeviceEnum','SEMgrSvc')
foreach($s in $manual){ Set-Service $s -StartupType Manual }
# OEM / updaters / analytics (Dell Optimizer and network drivers are NOT touched)
Set-Svc 'SupportAssist|DellClientManagement|DellDigitalDelivery|DellUpdate|DDVDataCollector|DDVRulesProcessor|DDVCollectorSvcApi|DellHardwareSupport' 'Manual'
Set-Svc 'Killer Analytics|Intel\(R\) Telemetry|Intel\(R\) System Usage|Intel\(R\) SUR QC' 'Disabled' 'DisplayName'
Set-Svc '^(gupdate|gupdatem|brave|bravem|AdobeUpdateService|AGSService|AdobeARMservice|JavaQuickStarterService)$' 'Manual'
if($DisableAnyDesk){ Set-Svc '^AnyDesk$' 'Manual' }
if($DisableSearchIndexer){ Set-Svc '^WSearch$' 'Disabled' }

# ------------------------------------------------------------------ 3. Telemetry, ads, tips
Step 3 "Telemetry, ads, suggestions"
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
foreach($n in 'SubscribedContent-338387Enabled','SubscribedContent-338388Enabled','SubscribedContent-338389Enabled',
              'SubscribedContent-353694Enabled','SubscribedContent-353696Enabled','SubscribedContent-310093Enabled',
              'SystemPaneSuggestionsEnabled','SilentInstalledAppsEnabled','SoftLandingEnabled','RotatingLockScreenEnabled'){
    Set-Reg $cdm $n 0
}
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableSoftLanding' 1
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSyncProviderNotifications' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0   # no P2P uploading
if($DisableToastNotifs){
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings' 'NOC_GLOBAL_SETTING_TOASTS_ENABLED' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications' 'ToastEnabled' 0
    Write-Host "   all toast notifications disabled"
}

# ------------------------------------------------------------------ 4. Background apps, Game DVR, Copilot, Edge
Step 4 "Background apps, Game Bar, Copilot, Edge background"
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1
Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'ShowStartupPanel' 0
Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'UseNexusForGameBarEnabled' 0
Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1      # Game Mode stays ON
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' 0

# ------------------------------------------------------------------ 5. Animations and visuals
Step 5 "Animations and visual effects"
if($DisableAnimations){
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 2
    Set-Reg 'HKCU:\Control Panel\Desktop' 'UserPreferencesMask' ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) 'Binary'
    Set-Reg 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '0' 'String'
    Set-Reg 'HKCU:\Control Panel\Desktop' 'DragFullWindows' '0' 'String'
    Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String'
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-Reg $adv 'TaskbarAnimations' 0
    Set-Reg $adv 'ListviewAlphaSelect' 0
    Set-Reg $adv 'ListviewShadow' 0
    Set-Reg $adv 'TaskbarDa' 0          # Widgets button
    Set-Reg $adv 'TaskbarMn' 0          # Chat/Teams button
    Set-Reg $adv 'ShowTaskViewButton' 0
    Set-Reg $adv 'LaunchTo' 1           # Explorer opens "This PC"
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\DWM' 'EnableAeroPeek' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\DWM' 'AlwaysHibernateThumbnails' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' 0
} else { Write-Host "   skipped (DisableAnimations = false)" }
if($FastKillHungApps){
    Set-Reg 'HKCU:\Control Panel\Desktop' 'AutoEndTasks' '1' 'String'
    Set-Reg 'HKCU:\Control Panel\Desktop' 'HungAppTimeout' '1000' 'String'
    Set-Reg 'HKCU:\Control Panel\Desktop' 'WaitToKillAppTimeout' '2000' 'String'
}

# ------------------------------------------------------------------ 6. CPU and power (AC only)
Step 6 "CPU and power tuning (AC only, battery untouched)"
if($TunePowerOnAC){
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 20  | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFBOOSTMODE 2     | Out-Null   # aggressive boost
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PERFEPP 25          | Out-Null   # favor performance
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR SYSCOOLPOL 1        | Out-Null   # active cooling first
    powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null  # USB suspend off
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0             | Out-Null
    powercfg /setacvalueindex SCHEME_CURRENT SUB_DISK DISKIDLE 0               | Out-Null
    powercfg /setactive SCHEME_CURRENT | Out-Null
    Write-Host "   AC power profile tuned"
}
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0   # real shutdowns
if($DisableHibernation){ powercfg /hibernate off | Out-Null }

# ------------------------------------------------------------------ 7. Game and multimedia priority
Step 7 "Game / multimedia scheduling"
$prof = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
Set-Reg $prof 'SystemResponsiveness' 10
Set-Reg "$prof\Tasks\Games" 'GPU Priority' 8
Set-Reg "$prof\Tasks\Games" 'Priority' 6
Set-Reg "$prof\Tasks\Games" 'Scheduling Category' 'High' 'String'
Set-Reg "$prof\Tasks\Games" 'SFIO Priority' 'High' 'String'

# ------------------------------------------------------------------ 8. Defender
Step 8 "Windows Defender: lower CPU load (protection stays ON)"
if($LimitDefenderCpu){
    Set-MpPreference -ScanAvgCPULoadFactor 20
    Set-MpPreference -EnableLowCpuPriority $true
    Write-Host "   scans limited to ~20% CPU, low priority"
}
if($DefenderExclusions){
    Add-MpPreference -ExclusionPath "$env:USERPROFILE\.minecraft","$env:USERPROFILE\.lunarclient"
    Write-Host "   exclusions added for .minecraft and .lunarclient"
}

# ------------------------------------------------------------------ 9. Startup entries
Step 9 "Startup entries"
$off  = [byte[]](3,0,0,0,0,0,0,0,0,0,0,0)
$locs = @(
  @{Run='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Appr='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'},
  @{Run='HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'; Appr='HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'}
)
foreach($l in $locs){
    (Get-ItemProperty $l.Run).PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object {
        foreach($pat in $KillStartup){
            if($_.Name -like $pat){ Set-Reg $l.Appr $_.Name $off 'Binary'; Write-Host "   startup disabled: $($_.Name)" }
        }
    }
}

# ------------------------------------------------------------------ 10. Scheduled tasks
Step 10 "Scheduled tasks (only ones that exist)"
Get-ScheduledTask | Where-Object {
    $_.TaskName -match 'GoogleUpdate|Adobe.*Update|Java ?Update|SupportAssist|DellUpdate|CCleaner|Driver ?Booster|IObit|Compatibility Appraiser|ProgramDataUpdater|Consolidator|UsbCeip|DmClient'
} | ForEach-Object { Write-Host "   task: $($_.TaskName)"; Disable-ScheduledTask -InputObject $_ | Out-Null }

# ------------------------------------------------------------------ 11. Store bloat
Step 11 "Windows bloatware apps"
if($RemoveStoreBloat){
    $bloat = 'Clipchamp.Clipchamp','Microsoft.BingNews','Microsoft.BingWeather','Microsoft.GetHelp','Microsoft.Getstarted',
             'Microsoft.MicrosoftSolitaireCollection','Microsoft.MicrosoftOfficeHub','Microsoft.PowerAutomateDesktop',
             'Microsoft.WindowsFeedbackHub','Microsoft.MixedReality.Portal','Microsoft.Microsoft3DViewer','Microsoft.SkypeApp',
             'MicrosoftTeams','MSTeams','Microsoft.Todos','Microsoft.549981C3F5F10','Microsoft.Windows.DevHome',
             'Microsoft.People','Microsoft.YourPhone','Microsoft.Copilot','Microsoft.Windows.Ai.Copilot.Provider'
    foreach($b in $bloat){
        if($ProtectedApps -contains $b){
            Write-Host "   protected app skipped: $b" -ForegroundColor Yellow
            continue
        }
        $f = Get-AppxPackage -AllUsers -Name $b
        if($f){ Write-Host "   removing: $b"; $f | Remove-AppxPackage -AllUsers }
        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $b } | Remove-AppxProvisionedPackage -Online | Out-Null
    }
} else { Write-Host "   skipped (RemoveStoreBloat = false)" }

# ------------------------------------------------------------------ 12. Disk health + cleanup
Step 12 "SSD TRIM, temp cleanup, .NET queue, DNS"
fsutil behavior set DisableDeleteNotify 0 | Out-Null
Optimize-Volume -DriveLetter C -ReTrim | Out-Null
Get-ChildItem $env:TEMP,"$env:windir\Temp" -Force -Recurse | Remove-Item -Force -Recurse
$ngen = "$env:windir\Microsoft.NET\Framework64\v4.0.30319\ngen.exe"
if(Test-Path $ngen){ & $ngen executeQueuedItems | Out-Null }
ipconfig /flushdns | Out-Null

# ------------------------------------------------------------------ 13. InstallUtil.exe check
Step 13 "Checking InstallUtil.exe"
if($CheckInstallUtil){
    $report = "$bk\InstallUtil_report.txt"
    $lines = @("InstallUtil check - $(Get-Date)", "")
    $procs = Get-CimInstance Win32_Process -Filter "Name='InstallUtil.exe'"
    if(-not $procs){
        $lines += "InstallUtil.exe is NOT running right now (good)."
    } else {
        foreach($p in $procs){
            $parent = Get-CimInstance Win32_Process -Filter "ProcessId=$($p.ParentProcessId)"
            $sig  = Get-AuthenticodeSignature $p.ExecutablePath
            $hash = (Get-FileHash $p.ExecutablePath -Algorithm SHA256).Hash
            $lines += "PID:            $($p.ProcessId)"
            $lines += "Path:           $($p.ExecutablePath)"
            $lines += "Command line:   $($p.CommandLine)"
            $lines += "Started by:     $($parent.Name) (PID $($p.ParentProcessId)) $($parent.ExecutablePath)"
            $lines += "Signature:      $($sig.Status) - $($sig.SignerCertificate.Subject)"
            $lines += "SHA256:         $hash"
            $lines += ""
        }
    }
    $lines | Out-File $report -Encoding utf8
    Write-Host "   report saved: $report" -ForegroundColor Yellow
} else { Write-Host "   skipped" }

# ------------------------------------------------------------------ 14. Pick programs to uninstall (interactive)
Step 14 "Choose programs to uninstall (optional)"
if($PickProgramsToUninstall -and (Get-Command Out-GridView -ErrorAction SilentlyContinue)){
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    # Hidden on purpose (drivers, runtimes, system components)
    $hide = 'Microsoft|Windows|\.NET|Visual C\+\+|Redistributable|WebView2|Intel|Realtek|Killer|NVIDIA|AMD|Goodix|Texas Instruments|Thunderbolt|Update for|Security Update|Hotfix|Samsung Mobile|Easy Anti-Cheat'
    $id = 0
    $apps = foreach($p in $paths){
        Get-ItemProperty $p | Where-Object {
            $_.DisplayName -and -not $_.SystemComponent -and -not $_.ParentKeyName -and
            (($_.DisplayName -notmatch $hide) -or ($_.DisplayName -match 'Driver & Support Assistant'))
        } | ForEach-Object {
            $script:id++
            [pscustomobject]@{
                Id        = $script:id
                Name      = $_.DisplayName
                Publisher = $_.Publisher
                SizeMB    = if($_.EstimatedSize){ [math]::Round($_.EstimatedSize / 1024, 0) } else { $null }
                Installed = $_.InstallDate
                Uninstall = $_.UninstallString
                Quiet     = $_.QuietUninstallString
            }
        }
    }
    $apps = $apps | Sort-Object Name -Unique
    if(-not $apps){
        Write-Host "   no programs found." -ForegroundColor Yellow
    } else {
        Write-Host "   A window will open. Ctrl+click to select several, then press OK. Cancel = uninstall nothing." -ForegroundColor Yellow
        $picked = $apps | Select-Object Id,Name,Publisher,SizeMB,Installed |
            Out-GridView -Title "Select programs to UNINSTALL (Ctrl+click for multiple)" -PassThru
        if(-not $picked){
            Write-Host "   nothing selected." -ForegroundColor Green
        } else {
            Write-Host "`n   You selected:" -ForegroundColor Cyan
            $picked | ForEach-Object { Write-Host "      - $($_.Name)" }
            $answer = Read-Host "`n   Uninstall these now? (Y/N)"
            if($answer -match '^[Yy]'){
                foreach($sel in $picked){
                    $app = $apps | Where-Object { $_.Id -eq $sel.Id }
                    $cmd = if($app.Quiet){ $app.Quiet } else { $app.Uninstall }
                    if(-not $cmd){ Write-Host "   no uninstaller for: $($app.Name)" -ForegroundColor Yellow; continue }
                    Write-Host "   uninstalling: $($app.Name)"
                    if($cmd -match 'msiexec'){
                        $cmd = $cmd -replace '(?i)/I(?=\s*\{)','/X'
                        if($cmd -notmatch '/q'){ $cmd += ' /qn /norestart' }
                    }
                    Start-Process -FilePath cmd.exe -ArgumentList "/c $cmd" -Wait
                }
            } else { Write-Host "   cancelled." -ForegroundColor Yellow }
        }
    }
} elseif($PickProgramsToUninstall){
    Write-Host "   Out-GridView is not available in this PowerShell - skipped. Run in Windows PowerShell 5.1 to use it." -ForegroundColor Yellow
} else { Write-Host "   skipped" }

# ------------------------------------------------------------------ Finish
Stop-Process -Name explorer -Force   # restart the shell so visual changes apply

Write-Host "`n=========================================" -ForegroundColor Green
Write-Host " DONE. Please RESTART your PC now." -ForegroundColor Green
Write-Host " Backups + log: $bk" -ForegroundColor Yellow
Write-Host " Undo: System Restore point 'Before full_optimize'" -ForegroundColor Yellow
Write-Host "       services_before.csv = old service startup modes, power_before.pow = old power plan" -ForegroundColor Yellow
Write-Host " Also uninstall Driver Booster manually if it is still installed (Settings > Apps)." -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Green
Stop-Transcript | Out-Null
