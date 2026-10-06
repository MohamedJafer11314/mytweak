#Requires -RunAsAdministrator
param(
    [string]$LaunchProfile = '',
    [ValidateSet('Optimize','Downloads','AdvancedTweaks')]
    [string]$LaunchMode = 'Optimize'
)
<#
  FULL OPTIMIZE  -  all-in-one (merges: optimize, no_animations, bloat_fix, remove_apps, ultimate_optimize)

  - Makes a restore point + backs up services and power plan BEFORE touching anything.
  - Does NOT disable Windows Defender, Windows Update, firewall, Wi-Fi, audio or graphics.
  - Services go to Manual/Disabled (never deleted). Safe to run more than once.
  - Everything is logged to the backup folder on your Desktop.
#>

# ============================ SETTINGS (edit if you want) ============================
$OptimizationProfile     = 'Balanced'  # Safe / Balanced / Aggressive
$EnableInteractiveChoose = $true       # If true, a window opens before running to let you choose a preset or custom tweaks.
$DisableSearchIndexer    = $false   # $true = stop Windows Search indexing (Start-menu search gets slower; fine if you use "Everything")
$DisableAnyDesk          = $false   # $true = AnyDesk service -> Manual (you can still start it by hand)
$RemoveStoreBloat        = $false   # Clipchamp, Solitaire, Teams, Bing apps, Phone Link, Copilot...
$DisableAnimations       = $true    # animations, transparency, visual effects
$DisableToastNotifs      = $false   # $true = turn OFF ALL pop-up notifications (was in no_animations.ps1)
$FastKillHungApps        = $false   # $true = AutoEndTasks: closes hung apps fast. UNSAVED WORK CAN BE LOST
$TunePowerOnAC           = $true    # CPU boost / cooling / no USB+PCIe sleep (plugged in only)
$LimitDefenderCpu        = $true    # Defender scans use less CPU (protection stays ON)
$DisableHibernation      = $false   # frees disk space (= size of RAM); keep $false if unsure
$DefenderExclusions      = $false   # exclude .minecraft/.lunarclient from scans (only if you trust your mods)
$CheckInstallUtil        = $true    # report on InstallUtil.exe if it is running
$PickProgramsToUninstall = $false   # at the END: a window opens, you choose programs to uninstall
$currentGpuScheduling = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode' -ErrorAction SilentlyContinue).HwSchMode
$currentPowerThrottling = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' -Name 'PowerThrottlingOff' -ErrorAction SilentlyContinue).PowerThrottlingOff
$EnableHardwareGpuScheduling = $currentGpuScheduling -eq 2 # requires a supported GPU and driver; restart required
$DisablePowerThrottling = $currentPowerThrottling -eq 1 # may increase heat and battery use
if($LaunchProfile -in @('Safe','Balanced','Aggressive')){
    $OptimizationProfile = $LaunchProfile
    $EnableInteractiveChoose = $false
}
if($LaunchMode -in @('Downloads','AdvancedTweaks')){ $EnableInteractiveChoose = $false }
# Startup entries to disable (wildcards matched against Run-key names). Add/remove as you like.
# Antivirus products (Avast, AVG...) are NOT in this list on purpose.
$KillStartup = @('*Driver*Booster*','*IObit*','*Discord*','*Spotify*','*Telegram*','*Steam*','*Teams*',
                 '*OneDrive*','*Skype*','*Adobe*','*Java*','*CCleaner*',
                 '*SupportAssist*','*MicrosoftEdgeAutoLaunch*','*Brave*')
# Services and apps that should be protected from aggressive cleanup.
$ProtectedServices = @('W32Time','Dhcp','Dnscache','MpsSvc','WinDefender','SecurityHealthService','wuauserv','UsoSvc','BITS')
$ProtectedApps = @('Microsoft.WindowsStore','Microsoft.WindowsCalculator','Microsoft.Windows.Photos','Microsoft.XboxApp')
# =====================================================================================

# Advanced tweak catalog for the interactive selection UI
$script:TweakCatalog = @(
    [pscustomobject]@{ Id='DisableSearchIndexer'; Title='Disable Search Indexer'; Category='Performance'; Risk='Low'; Description='Disables Windows Search indexing to reduce background activity. Useful if you use Everything or similar tools.'; Enabled=$false },
    [pscustomobject]@{ Id='DisableAnyDesk'; Title='Disable AnyDesk'; Category='Services'; Risk='Low'; Description='Sets AnyDesk service to Manual so it stays available but does not run in the background automatically.'; Enabled=$false },
    [pscustomobject]@{ Id='RemoveStoreBloat'; Title='Remove Store bloat'; Category='Apps'; Risk='Medium'; Description='Removes common preinstalled apps like Clipchamp, Teams, Solitaire, Weather, News, Phone Link, and Copilot-related clutter.'; Enabled=$false },
    [pscustomobject]@{ Id='DisableAnimations'; Title='Disable animations'; Category='Visuals'; Risk='Low'; Description='Disables transparency, animation, taskbar motion, and UI effects for a snappier feeling.'; Enabled=$true },
    [pscustomobject]@{ Id='DisableToastNotifs'; Title='Disable toast notifications'; Category='Privacy'; Risk='Low'; Description='Turns off all popup notifications from Windows to reduce distraction and interruptions.'; Enabled=$false },
    [pscustomobject]@{ Id='FastKillHungApps'; Title='Kill hung apps faster'; Category='Performance'; Risk='Medium'; Description='Changes timeout values so apps that stop responding are torn down faster. Unsaved work can be lost.'; Enabled=$false },
    [pscustomobject]@{ Id='TunePowerOnAC'; Title='Tune power plan for performance'; Category='Power'; Risk='Low'; Description='Applies AC power values for higher CPU boost, cooling priority, and less USB/PCIe sleep.'; Enabled=$true },
    [pscustomobject]@{ Id='LimitDefenderCpu'; Title='Limit Defender CPU usage'; Category='Security'; Risk='Low'; Description='Sets Defender scans to use less CPU while keeping protection enabled.'; Enabled=$true },
    [pscustomobject]@{ Id='EnableHardwareGpuScheduling'; Title='Enable GPU scheduling'; Category='Gaming'; Risk='Medium'; Description='Enables hardware-accelerated GPU scheduling when the GPU and driver support it; requires a restart.'; Enabled=$false },
    [pscustomobject]@{ Id='DisablePowerThrottling'; Title='Disable power throttling'; Category='Performance'; Risk='Medium'; Description='Reduces Windows background-app power limits; may increase heat and battery use.'; Enabled=$false },
    [pscustomobject]@{ Id='DisableHibernation'; Title='Disable hibernation'; Category='Storage'; Risk='Low'; Description='Turns off hibernation to free disk space equal to RAM size.'; Enabled=$false },
    [pscustomobject]@{ Id='DefenderExclusions'; Title='Game exclusions'; Category='Security'; Risk='Low'; Description='Adds exclusions for .minecraft and .lunarclient if you trust the mod directories.'; Enabled=$false },
    [pscustomobject]@{ Id='CheckInstallUtil'; Title='Check InstallUtil'; Category='Security'; Risk='Low'; Description='Creates a report for InstallUtil.exe to detect suspicious or abnormal execution.'; Enabled=$true },
    [pscustomobject]@{ Id='PickProgramsToUninstall'; Title='Pick programs to uninstall'; Category='Apps'; Risk='Medium'; Description='Shows a list of non-system apps so you can uninstall extras by selection.'; Enabled=$false },
    [pscustomobject]@{ Id='InstallBrowsers'; Title='Install browsers & tools'; Category='Apps'; Risk='Low'; Description='Offers Chrome, Brave, Firefox, 7-Zip, VLC, and other useful programs using winget.'; Enabled=$false },
    [pscustomobject]@{ Id='ManageStartupItems'; Title='Manage startup apps'; Category='Startup'; Risk='Low'; Description='Shows startup entries and lets you disable unnecessary background apps that launch at logon.'; Enabled=$false },
    [pscustomobject]@{ Id='ManageServices'; Title='Manage Windows services'; Category='Services'; Risk='Medium'; Description='Review common services and switch them to Manual or Disabled based on your needs.'; Enabled=$false },
    [pscustomobject]@{ Id='DisableWidgets'; Title='Disable Widgets / Chat'; Category='Privacy'; Risk='Low'; Description='Turns off quick-launch widgets and chat surfaces that add background noise.'; Enabled=$false },
    [pscustomobject]@{ Id='TuneStorage'; Title='Clean temp + cache'; Category='Storage'; Risk='Low'; Description='Removes temporary files, browser caches, and other junk that accumulates over time.'; Enabled=$true },
    [pscustomobject]@{ Id='ResetExplorer'; Title='Restart Explorer'; Category='System'; Risk='Low'; Description='Restarts Windows Explorer so visual and taskbar changes apply immediately.'; Enabled=$true },
    [pscustomobject]@{ Id='TrimVolume'; Title='Run SSD TRIM'; Category='System'; Risk='Low'; Description='Runs SSD trim and temp cleanup to improve responsiveness and remove temporary junk.'; Enabled=$true },
    [pscustomobject]@{ Id='FlushDNS'; Title='Flush DNS'; Category='Network'; Risk='Low'; Description='Clears cached DNS entries to resolve some connection or resolution problems.'; Enabled=$true }
)

$script:SoftwareCatalog = @(
    [pscustomobject]@{ Id='GoogleChrome'; Name='Google Chrome'; Category='متصفح'; PackageId='Google.Chrome'; Source='winget'; Description='متصفح Google بميزة التوافق مع معظم المواقع والخدمات.' },
    [pscustomobject]@{ Id='Brave'; Name='Brave Browser'; Category='متصفح'; PackageId='Brave.Brave'; Source='winget'; Description='متصفح يركز على الخصوصية وحجب الإعلانات.' },
    [pscustomobject]@{ Id='Firefox'; Name='Mozilla Firefox'; Category='متصفح'; PackageId='Mozilla.Firefox'; Source='winget'; Description='متصفح مفتوح المصدر بإعدادات خصوصية مرنة.' },
    [pscustomobject]@{ Id='7Zip'; Name='7-Zip'; Category='أدوات'; PackageId='7zip.7zip'; Source='winget'; Description='أداة مجانية لضغط واستخراج ZIP و7z وصيغ أخرى.' },
    [pscustomobject]@{ Id='VLC'; Name='VLC Media Player'; Category='أدوات'; PackageId='VideoLAN.VLC'; Source='winget'; Description='مشغل وسائط مجاني لملفات الفيديو والصوت.' },
    [pscustomobject]@{ Id='NotepadPlusPlus'; Name='Notepad++'; Category='أدوات'; PackageId='Notepad++.Notepad++'; Source='winget'; Description='محرر نصوص وبرمجة خفيف مع تلوين الصياغة.' },
    [pscustomobject]@{ Id='WinRAR'; Name='WinRAR'; Category='أدوات'; PackageId='RARLab.WinRAR'; Source='winget'; Description='أداة لإدارة الملفات المضغوطة.' },
    [pscustomobject]@{ Id='MicrosoftPowerToys'; Name='Microsoft PowerToys'; Category='أدوات'; PackageId='Microsoft.PowerToys'; Source='winget'; Description='أدوات إضافية لـ Windows مثل FancyZones وإعادة تسمية الملفات.' }
)

$script:DriverCatalog = @(
    [pscustomobject]@{ Id='NvidiaApp'; Name='NVIDIA App'; Category='NVIDIA'; PackageId='XP8CLZL93F5Z4P'; Source='msstore'; Description='تطبيق NVIDIA الرسمي للتعريفات وإعدادات الألعاب. يتطلب بطاقة NVIDIA.' },
    [pscustomobject]@{ Id='LenovoSystemUpdate'; Name='Lenovo System Update'; Category='Lenovo'; PackageId='Lenovo.SystemUpdate'; Source='winget'; Description='أداة Lenovo الرسمية لاكتشاف تعريفات وبرامج BIOS المناسبة لأجهزة Lenovo.' },
    [pscustomobject]@{ Id='HPSupportAssistant'; Name='HP Support Assistant'; Category='HP'; PackageId='HP.SupportAssistant'; Source='winget'; Description='أداة HP الرسمية لاكتشاف تعريفات الجهاز وتحديثها.' },
    [pscustomobject]@{ Id='IntelDriverSupport'; Name='Intel Driver & Support Assistant'; Category='Intel'; DownloadUrl='https://www.intel.com/content/www/us/en/support/detect.html'; Description='يفتح صفحة Intel الرسمية لفحص تعريفات Intel وتنزيل أداة الدعم.' },
    [pscustomobject]@{ Id='AmdDrivers'; Name='AMD Drivers'; Category='AMD'; DownloadUrl='https://www.amd.com/en/support/download/drivers.html'; Description='يفتح صفحة AMD الرسمية لاختيار تعريف بطاقة Radeon أو معالج Ryzen حسب طراز الجهاز.' },
    [pscustomobject]@{ Id='DellDrivers'; Name='Dell Drivers & Downloads'; Category='Dell'; DownloadUrl='https://www.dell.com/support/home'; Description='يفتح دعم Dell الرسمي؛ أدخل Service Tag لاختيار تعريفات جهازك.' },
    [pscustomobject]@{ Id='AsusDrivers'; Name='ASUS Drivers & Support'; Category='ASUS'; DownloadUrl='https://www.asus.com/support/download-center/'; Description='يفتح مركز ASUS الرسمي للبحث عن تعريفات طراز جهازك.' },
    [pscustomobject]@{ Id='MsiDrivers'; Name='MSI Drivers & Downloads'; Category='MSI'; DownloadUrl='https://www.msi.com/support/download'; Description='يفتح صفحة MSI الرسمية لاختيار طراز اللوحة أو الجهاز وتعريفاته.' },
    [pscustomobject]@{ Id='AcerDrivers'; Name='Acer Drivers & Manuals'; Category='Acer'; DownloadUrl='https://www.acer.com/us-en/support/drivers-and-manuals'; Description='يفتح دعم Acer الرسمي للبحث عن التعريفات حسب طراز الجهاز أو الرقم التسلسلي.' }
)
$script:DownloadCatalog = @($script:SoftwareCatalog) + @($script:DriverCatalog)

$script:AdvancedSettingCatalog = @(
    [pscustomobject]@{ Id='DisableSearchIndexer'; Name='تقليل فهرسة البحث'; Description='يقلل نشاط الفهرسة؛ قد يصبح بحث Start أبطأ.' },
    [pscustomobject]@{ Id='DisableAnyDesk'; Name='إيقاف تشغيل AnyDesk تلقائيًا'; Description='يضبط الخدمة على Manual؛ يبقى تشغيلها اليدوي ممكنًا.' },
    [pscustomobject]@{ Id='DisableAnimations'; Name='إيقاف المؤثرات'; Description='يوقف الرسوم والشفافية وبعض مؤثرات Windows.' },
    [pscustomobject]@{ Id='TunePowerOnAC'; Name='تعزيز الأداء عند توصيل الشاحن'; Description='يضبط طاقة المعالج وUSB وPCIe عند التوصيل بالكهرباء فقط.' },
    [pscustomobject]@{ Id='LimitDefenderCpu'; Name='تقليل حمل فحص Defender'; Description='يحد حمل الفحص فقط؛ لا يوقف الحماية الفورية.' },
    [pscustomobject]@{ Id='EnableHardwareGpuScheduling'; Name='تفعيل جدولة GPU العتادية'; Description='قد يحسن استجابة الألعاب على عتاد مدعوم؛ يحتاج تعريفًا مناسبًا وإعادة تشغيل.' },
    [pscustomobject]@{ Id='DisablePowerThrottling'; Name='إلغاء تقييد طاقة التطبيقات'; Description='قد يحسن أداء تطبيقات الخلفية، لكنه قد يزيد حرارة الجهاز واستهلاك البطارية.' },
    [pscustomobject]@{ Id='FastKillHungApps'; Name='إغلاق التطبيقات العالقة أسرع'; Description='قد يؤدي إلى فقدان عمل غير محفوظ.' },
    [pscustomobject]@{ Id='DisableHibernation'; Name='تعطيل الإسبات'; Description='يوفر مساحة تقارب حجم RAM، لكنه يعطل الإسبات.' },
    [pscustomobject]@{ Id='DisableToastNotifs'; Name='إيقاف الإشعارات المنبثقة'; Description='يوقف كل الإشعارات المنبثقة، بما فيها التنبيهات المهمة.' },
    [pscustomobject]@{ Id='RemoveStoreBloat'; Name='إزالة تطبيقات المتجر المحددة'; Description='يتطلب تأكيد REMOVE إضافيًا؛ لا تشملها الاستعادة.' },
    [pscustomobject]@{ Id='PickProgramsToUninstall'; Name='اختيار برامج لإزالتها'; Description='يفتح قائمة منفصلة للإزالة؛ راجع أسماء البرامج قبل التأكيد.' },
    [pscustomobject]@{ Id='DefenderExclusions'; Name='استثناء مجلدات Minecraft'; Description='يقلل فحص هذه المجلدات؛ استخدمه فقط عند الوثوق بمحتواها.' },
    [pscustomobject]@{ Id='CheckInstallUtil'; Name='إنشاء تقرير InstallUtil'; Description='ينشئ تقريرًا فقط؛ لا يوقف الأداة ولا يحذفها.' }
)

$script:CustomTweakSelections = @()

function Get-SelectedTweakNames {
    param([string[]]$names)
    foreach($n in $names){
        $t = $script:TweakCatalog | Where-Object { $_.Id -eq $n }
        if($t){ $script:CustomTweakSelections += $n }
    }
}

function ApplyTweakSelection {
    param([string[]]$selectedIds)
    foreach($id in $selectedIds){
        switch ($id) {
            'DisableSearchIndexer' { $script:DisableSearchIndexer = $true }
            'DisableAnyDesk'       { $script:DisableAnyDesk = $true }
            'RemoveStoreBloat'     { $script:RemoveStoreBloat = $true }
            'DisableAnimations'    { $script:DisableAnimations = $true }
            'DisableToastNotifs'   { $script:DisableToastNotifs = $true }
            'FastKillHungApps'     { $script:FastKillHungApps = $true }
            'TunePowerOnAC'        { $script:TunePowerOnAC = $true }
            'LimitDefenderCpu'     { $script:LimitDefenderCpu = $true }
            'EnableHardwareGpuScheduling' { $script:EnableHardwareGpuScheduling = $true }
            'DisablePowerThrottling' { $script:DisablePowerThrottling = $true }
            'EnableHardwareGpuScheduling' { $script:EnableHardwareGpuScheduling = $true }
            'DisablePowerThrottling' { $script:DisablePowerThrottling = $true }
            'DisableHibernation'   { $script:DisableHibernation = $true }
            'DefenderExclusions'   { $script:DefenderExclusions = $true }
            'CheckInstallUtil'     { $script:CheckInstallUtil = $true }
            'PickProgramsToUninstall' { $script:PickProgramsToUninstall = $true }
            'InstallBrowsers'      { Show-SoftwareInstallerDialog }
            'ManageStartupItems'   { Show-StartupManagerDialog }
            'ManageServices'       { Show-ServiceManagerDialog }
            'DisableWidgets'       { Write-Host '   Widgets/Chat cleanup selected.' -ForegroundColor Cyan }
            'TuneStorage'          { Write-Host '   Temp cache cleanup selected.' -ForegroundColor Cyan }
            'ResetExplorer'        { }
            'TrimVolume'           { }
            'FlushDNS'             { }
        }
    }
}

function Show-SoftwareInstallerDialog {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'مركز البرامج والتعريفات'
    $form.Size = New-Object System.Drawing.Size(920, 620)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 22)
    $form.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $form.RightToLeft = [System.Windows.Forms.RightToLeft]::Yes
    $form.RightToLeftLayout = $true
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'اختر التطبيقات أو أدوات دعم التعريفات'
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $title.Location = New-Object System.Drawing.Point(20, 20)
    $title.Size = New-Object System.Drawing.Size(850, 32)
    $form.Controls.Add($title)

    $checkedList = New-Object System.Windows.Forms.CheckedListBox
    $checkedList.Location = New-Object System.Drawing.Point(20, 60)
    $checkedList.Size = New-Object System.Drawing.Size(430, 450)
    $checkedList.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $checkedList.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 40)
    $checkedList.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    foreach($app in $script:DownloadCatalog){
        $checkedList.Items.Add("$($app.Category) | $($app.Name)") | Out-Null
    }
    $form.Controls.Add($checkedList)

    $desc = New-Object System.Windows.Forms.Label
    $desc.Location = New-Object System.Drawing.Point(470, 60)
    $desc.Size = New-Object System.Drawing.Size(430, 450)
    $desc.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $desc.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 36)
    $desc.BorderStyle = 'FixedSingle'
    $desc.Padding = New-Object System.Windows.Forms.Padding(12)
    $desc.Text = 'حدد العناصر المطلوبة. تُثبّت البرامج عبر winget، وتفتح روابط الشركات صفحات الدعم الرسمية لاختيار الطراز الصحيح.'
    $form.Controls.Add($desc)

    $checkedList.Add_SelectedIndexChanged({
        $idx = $checkedList.SelectedIndex
        if($idx -ge 0){
            $desc.Text = $script:DownloadCatalog[$idx].Description
        }
    })

    $installBtn = New-Object System.Windows.Forms.Button
    $installBtn.Text = 'تنفيذ المحدد'
    $installBtn.Location = New-Object System.Drawing.Point(470, 530)
    $installBtn.Size = New-Object System.Drawing.Size(180, 38)
    $installBtn.BackColor = [System.Drawing.Color]::FromArgb(0, 140, 92)
    $installBtn.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $installBtn.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($installBtn)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'إغلاق'
    $cancel.Location = New-Object System.Drawing.Point(670, 530)
    $cancel.Size = New-Object System.Drawing.Size(120, 38)
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $cancel.BackColor = [System.Drawing.Color]::FromArgb(90, 90, 100)
    $cancel.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $form.Controls.Add($cancel)

    $form.AcceptButton = $installBtn
    $form.CancelButton = $cancel

    $result = $form.ShowDialog()
    if($result -ne [System.Windows.Forms.DialogResult]::OK){ return }

    $selected = @()
    for($i = 0; $i -lt $checkedList.Items.Count; $i++){
        if($checkedList.GetItemChecked($i)){
            $selected += $script:DownloadCatalog[$i]
        }
    }

    if(-not $selected){
        Write-Host 'لم تحدد أي عنصر.' -ForegroundColor Yellow
        return
    }

    $needsWinget = @($selected | Where-Object { $_.PackageId }).Count -gt 0
    $wingetAvailable = [bool](Get-Command winget -ErrorAction SilentlyContinue)
    if($needsWinget -and -not $wingetAvailable){
        Write-Host 'winget غير متوفر؛ ستظل روابط الدعم الرسمية المحددة قابلة للفتح.' -ForegroundColor Yellow
    }

    foreach($app in $selected){
        if($app.PackageId){
            if(-not $wingetAvailable){ continue }
            $arguments = @('install','--id',$app.PackageId,'--exact','--accept-source-agreements','--accept-package-agreements')
            if($app.Source -eq 'msstore'){ $arguments += @('--source','msstore') }
            Write-Host "تثبيت $($app.Name)..." -ForegroundColor Cyan
            & winget @arguments
            if($LASTEXITCODE -ne 0){ Write-Host "فشل تثبيت $($app.Name) (رمز $LASTEXITCODE)." -ForegroundColor Red }
        } elseif($app.DownloadUrl){
            try {
                Start-Process -FilePath $app.DownloadUrl -ErrorAction Stop
            } catch {
                Write-Host "تعذر فتح صفحة $($app.Name): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

function Show-AdvancedSettingsDialog {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'إعدادات وتحسينات متقدمة'
    $form.Size = New-Object System.Drawing.Size(880, 620)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 22)
    $form.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'عدّل الخيارات التي تريدها ثم راجع خطة التنفيذ'
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
    $title.Location = New-Object System.Drawing.Point(20, 18)
    $title.Size = New-Object System.Drawing.Size(820, 34)
    $form.Controls.Add($title)

    $checkedList = New-Object System.Windows.Forms.CheckedListBox
    $checkedList.Location = New-Object System.Drawing.Point(20, 64)
    $checkedList.Size = New-Object System.Drawing.Size(410, 440)
    $checkedList.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $checkedList.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 40)
    $checkedList.ForeColor = [System.Drawing.Color]::FromArgb(250, 250, 250)
    foreach($option in $script:AdvancedSettingCatalog){
        $index = $checkedList.Items.Add($option.Name)
        $current = Get-Variable -Name $option.Id -Scope Script -ValueOnly -ErrorAction SilentlyContinue
        if($null -ne $current){ $checkedList.SetItemChecked($index, [bool]$current) }
    }
    $form.Controls.Add($checkedList)

    $description = New-Object System.Windows.Forms.Label
    $description.Location = New-Object System.Drawing.Point(450, 64)
    $description.Size = New-Object System.Drawing.Size(390, 440)
    $description.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $description.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 36)
    $description.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $description.BorderStyle = 'FixedSingle'
    $description.Padding = New-Object System.Windows.Forms.Padding(12)
    $description.Text = 'حدد خيارًا من القائمة لقراءة أثره قبل تطبيقه.'
    $form.Controls.Add($description)

    $checkedList.Add_SelectedIndexChanged({
        $index = $checkedList.SelectedIndex
        if($index -ge 0){ $description.Text = $script:AdvancedSettingCatalog[$index].Description }
    })

    $apply = New-Object System.Windows.Forms.Button
    $apply.Text = 'اعتماد الاختيارات'
    $apply.Location = New-Object System.Drawing.Point(600, 530)
    $apply.Size = New-Object System.Drawing.Size(150, 40)
    $apply.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $apply.BackColor = [System.Drawing.Color]::FromArgb(0, 140, 92)
    $apply.ForeColor = [System.Drawing.Color]::White
    $form.Controls.Add($apply)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'إلغاء'
    $cancel.Location = New-Object System.Drawing.Point(760, 530)
    $cancel.Size = New-Object System.Drawing.Size(80, 40)
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancel)
    $form.AcceptButton = $apply
    $form.CancelButton = $cancel

    if($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){ return $false }
    for($i = 0; $i -lt $script:AdvancedSettingCatalog.Count; $i++){
        $option = $script:AdvancedSettingCatalog[$i]
        Set-Variable -Name $option.Id -Scope Script -Value ([bool]$checkedList.GetItemChecked($i))
    }
    return $true
}

function Get-StartupEntries {
    $entries = @()
    $paths = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
    )

    foreach($p in $paths){
        if(Test-Path $p){
            $props = Get-ItemProperty $p -ErrorAction SilentlyContinue
            if($null -ne $props){
                foreach($name in $props.PSObject.Properties.Name){
                    if($name -notmatch 'PSPath|PSParentPath|PSChildName|PSProvider|^_'){ 
                        $entries += [pscustomobject]@{ Name=$name; Value=$props.$name; Path=$p; Source='Registry' }
                    }
                }
            }
        }
    }

    return $entries | Sort-Object Name -Unique
}

function Show-StartupManagerDialog {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $entries = Get-StartupEntries
    if(-not $entries -or $entries.Count -eq 0){
        [System.Windows.Forms.MessageBox]::Show('No startup entries were found.', 'Startup Manager', 'OK', 'Information') | Out-Null
        return
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Startup Manager'
    $form.Size = New-Object System.Drawing.Size(780, 560)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 22)
    $form.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)

    $listBox = New-Object System.Windows.Forms.CheckedListBox
    $listBox.Location = New-Object System.Drawing.Point(20, 60)
    $listBox.Size = New-Object System.Drawing.Size(720, 360)
    $listBox.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $listBox.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 40)
    $listBox.ForeColor = [System.Drawing.Color]::FromArgb(250, 250, 250)
    foreach($item in $entries){
        $listBox.Items.Add("$($item.Name) :: $($item.Value)") | Out-Null
    }
    $form.Controls.Add($listBox)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'Select startup items to disable'
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $title.Location = New-Object System.Drawing.Point(20, 20)
    $title.Size = New-Object System.Drawing.Size(400, 30)
    $form.Controls.Add($title)

    $apply = New-Object System.Windows.Forms.Button
    $apply.Text = 'Disable selected'
    $apply.Location = New-Object System.Drawing.Point(490, 450)
    $apply.Size = New-Object System.Drawing.Size(160, 38)
    $apply.BackColor = [System.Drawing.Color]::FromArgb(0, 140, 92)
    $apply.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $apply.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($apply)

    $close = New-Object System.Windows.Forms.Button
    $close.Text = 'Close'
    $close.Location = New-Object System.Drawing.Point(660, 450)
    $close.Size = New-Object System.Drawing.Size(80, 38)
    $close.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $close.BackColor = [System.Drawing.Color]::FromArgb(90, 90, 100)
    $close.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $form.Controls.Add($close)

    $form.AcceptButton = $apply
    $form.CancelButton = $close

    $result = $form.ShowDialog()
    if($result -ne [System.Windows.Forms.DialogResult]::OK){ return }

    foreach($idx in $listBox.CheckedIndices){
        $name = $entries[$idx].Name
        $path = $entries[$idx].Path
        if(Test-Path $path){
            try {
                Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
                Write-Host "   Disabled startup entry: $name" -ForegroundColor Green
            } catch {
                Write-Host "   Could not disable startup entry: $name" -ForegroundColor Yellow
            }
        }
    }
}

function Show-ServiceManagerDialog {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $services = @(
        'SysMain','DiagTrack','dmwappushservice','Fax','WSearch','WMPNetworkSvc','MapsBroker',
        'XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc','RetailDemo','PhoneSvc','RemoteRegistry',
        'WerSvc','Fax','Windows Mobile Hotspot Service'
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Service Tuner'
    $form.Size = New-Object System.Drawing.Size(750, 560)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 22)
    $form.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'Select services to tune'
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $title.Location = New-Object System.Drawing.Point(20, 20)
    $title.Size = New-Object System.Drawing.Size(360, 30)
    $form.Controls.Add($title)

    $list = New-Object System.Windows.Forms.CheckedListBox
    $list.Location = New-Object System.Drawing.Point(20, 60)
    $list.Size = New-Object System.Drawing.Size(700, 360)
    $list.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $list.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 40)
    $list.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    foreach($name in $services){
        $list.Items.Add($name) | Out-Null
    }
    $form.Controls.Add($list)

    $apply = New-Object System.Windows.Forms.Button
    $apply.Text = 'Apply changes'
    $apply.Location = New-Object System.Drawing.Point(470, 450)
    $apply.Size = New-Object System.Drawing.Size(150, 38)
    $apply.BackColor = [System.Drawing.Color]::FromArgb(0, 140, 92)
    $apply.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $apply.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($apply)

    $close = New-Object System.Windows.Forms.Button
    $close.Text = 'Close'
    $close.Location = New-Object System.Drawing.Point(630, 450)
    $close.Size = New-Object System.Drawing.Size(90, 38)
    $close.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $close.BackColor = [System.Drawing.Color]::FromArgb(90, 90, 100)
    $close.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $form.Controls.Add($close)

    $form.AcceptButton = $apply
    $form.CancelButton = $close

    $result = $form.ShowDialog()
    if($result -ne [System.Windows.Forms.DialogResult]::OK){ return }

    foreach($idx in $list.CheckedIndices){
        $svcName = $services[$idx]
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if($null -ne $svc){
            try {
                Stop-Service $svcName -Force -ErrorAction SilentlyContinue
                Set-Service $svcName -StartupType Manual -ErrorAction SilentlyContinue
                Write-Host "   Service set to Manual: $svcName" -ForegroundColor Green
            } catch {
                Write-Host "   Could not change service: $svcName" -ForegroundColor Yellow
            }
        }
    }
}

function Show-AdvancedChooser {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Advanced Windows Optimizer'
    $form.Size = New-Object System.Drawing.Size(1100, 700)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 22)
    $form.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'Choose the tweaks you want to apply'
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
    $title.Location = New-Object System.Drawing.Point(20, 18)
    $title.Size = New-Object System.Drawing.Size(500, 34)
    $form.Controls.Add($title)

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(20, 70)
    $listBox.Size = New-Object System.Drawing.Size(360, 430)
    $listBox.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $listBox.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 40)
    $listBox.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    foreach($item in $script:TweakCatalog){
        $listBox.Items.Add($item.Title) | Out-Null
    }
    $form.Controls.Add($listBox)

    $info = New-Object System.Windows.Forms.GroupBox
    $info.Text = 'What this tweak does'
    $info.Location = New-Object System.Drawing.Point(410, 70)
    $info.Size = New-Object System.Drawing.Size(660, 300)
    $info.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 32)
    $info.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $form.Controls.Add($info)

    $infoText = New-Object System.Windows.Forms.Label
    $infoText.Location = New-Object System.Drawing.Point(15, 25)
    $infoText.Size = New-Object System.Drawing.Size(620, 260)
    $infoText.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $infoText.AutoSize = $false
    $infoText.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 32)
    $infoText.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $infoText.Text = 'Select an item from the list to see the full description and risk level.'
    $info.Controls.Add($infoText)

    $checkAll = New-Object System.Windows.Forms.Button
    $checkAll.Text = 'Select all'
    $checkAll.Location = New-Object System.Drawing.Point(20, 520)
    $checkAll.Size = New-Object System.Drawing.Size(120, 38)
    $checkAll.BackColor = [System.Drawing.Color]::FromArgb(70, 90, 130)
    $checkAll.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $form.Controls.Add($checkAll)

    $clearAll = New-Object System.Windows.Forms.Button
    $clearAll.Text = 'Clear all'
    $clearAll.Location = New-Object System.Drawing.Point(150, 520)
    $clearAll.Size = New-Object System.Drawing.Size(120, 38)
    $clearAll.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 75)
    $clearAll.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $form.Controls.Add($clearAll)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Apply'
    $ok.Location = New-Object System.Drawing.Point(900, 520)
    $ok.Size = New-Object System.Drawing.Size(120, 38)
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $ok.BackColor = [System.Drawing.Color]::FromArgb(0, 160, 100)
    $ok.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $form.Controls.Add($ok)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Location = New-Object System.Drawing.Point(1028, 520)
    $cancel.Size = New-Object System.Drawing.Size(120, 38)
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $cancel.BackColor = [System.Drawing.Color]::FromArgb(80, 80, 90)
    $cancel.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $form.Controls.Add($cancel)

    $listBox.Add_SelectedIndexChanged({
        $idx = $listBox.SelectedIndex
        if($idx -ge 0){
            $item = $script:TweakCatalog[$idx]
            $infoText.Text = "Title: $($item.Title)`nCategory: $($item.Category)`nRisk: $($item.Risk)`n`nDescription:`n$item.Description"
        }
    })

    $checkAll.Add_Click({
        for($i = 0; $i -lt $listBox.Items.Count; $i++){
            $listBox.SetSelected($i, $true)
        }
    })

    $clearAll.Add_Click({
        $listBox.ClearSelected()
        $infoText.Text = 'Select an item from the list to see the full description and risk level.'
    })

    $form.AcceptButton = $ok
    $form.CancelButton = $cancel

    $result = $form.ShowDialog()
    if($result -ne [System.Windows.Forms.DialogResult]::OK){
        return @()
    }

    $selected = @()
    foreach($idx in $listBox.SelectedIndices){
        $selected += $script:TweakCatalog[$idx].Id
    }
    return $selected
}

function Show-PresetChooser {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $presetList = @(
        [pscustomobject]@{ Name='Safe'; Description='Minimal changes - best for stability and daily use' },
        [pscustomobject]@{ Name='Balanced'; Description='Recommended default - good balance of speed and stability' },
        [pscustomobject]@{ Name='Aggressive'; Description='More performance tweaks and more system changes' },
        [pscustomobject]@{ Name='Custom'; Description='Select custom tweaks manually' }
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Optimization presets'
    $form.Size = New-Object System.Drawing.Size(640, 420)
    $form.StartPosition = 'CenterScreen'
    $form.BackColor = [System.Drawing.Color]::FromArgb(18, 18, 22)
    $form.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'Choose a preset:'
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
    $title.Location = New-Object System.Drawing.Point(20, 20)
    $title.Size = New-Object System.Drawing.Size(300, 32)
    $form.Controls.Add($title)

    $list = New-Object System.Windows.Forms.ListBox
    $list.Location = New-Object System.Drawing.Point(20, 60)
    $list.Size = New-Object System.Drawing.Size(250, 220)
    $list.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    foreach($p in $presetList){
        $list.Items.Add($p.Name) | Out-Null
    }
    $list.SelectedIndex = 1
    $form.Controls.Add($list)

    $desc = New-Object System.Windows.Forms.Label
    $desc.Location = New-Object System.Drawing.Point(290, 60)
    $desc.Size = New-Object System.Drawing.Size(300, 220)
    $desc.Text = $presetList[1].Description
    $desc.BorderStyle = 'FixedSingle'
    $desc.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 36)
    $desc.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $desc.Padding = New-Object System.Windows.Forms.Padding(12)
    $form.Controls.Add($desc)

    $list.Add_SelectedIndexChanged({
        $idx = $list.SelectedIndex
        if($idx -ge 0){ $desc.Text = $presetList[$idx].Description }
    })

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'OK'
    $ok.Location = New-Object System.Drawing.Point(400, 300)
    $ok.Size = New-Object System.Drawing.Size(100, 38)
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($ok)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Location = New-Object System.Drawing.Point(510, 300)
    $cancel.Size = New-Object System.Drawing.Size(100, 38)
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancel)

    $form.AcceptButton = $ok
    $form.CancelButton = $cancel

    $result = $form.ShowDialog()
    if($result -ne [System.Windows.Forms.DialogResult]::OK){
        return $null
    }
    return $presetList[$list.SelectedIndex].Name
}

function Show-AdvancedOptimizerDialog {
    $preset = Show-PresetChooser
    if($null -eq $preset){
        return
    }

    Set-OptimizationPreset -Name $preset

    if($preset -eq 'Custom'){
        $selected = Show-AdvancedChooser
        if($selected.Count -gt 0){
            ApplyTweakSelection -selectedIds $selected
        }
    }
}

function Set-OptimizationPreset {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    switch ($Name) {
        'Safe' {
            $script:OptimizationProfile = 'Safe'
            $script:DisableSearchIndexer = $false
            $script:DisableAnyDesk = $false
            $script:RemoveStoreBloat = $false
            $script:DisableAnimations = $false
            $script:DisableToastNotifs = $false
            $script:FastKillHungApps = $false
            $script:TunePowerOnAC = $false
            $script:LimitDefenderCpu = $true
            $script:EnableHardwareGpuScheduling = $false
            $script:DisablePowerThrottling = $false
            $script:DisableHibernation = $false
            $script:DefenderExclusions = $false
            $script:CheckInstallUtil = $true
            $script:PickProgramsToUninstall = $false
        }
        'Balanced' {
            $script:OptimizationProfile = 'Balanced'
            $script:DisableSearchIndexer = $false
            $script:DisableAnyDesk = $false
            $script:RemoveStoreBloat = $false
            $script:DisableAnimations = $true
            $script:DisableToastNotifs = $false
            $script:FastKillHungApps = $false
            $script:TunePowerOnAC = $true
            $script:LimitDefenderCpu = $true
            $script:EnableHardwareGpuScheduling = $false
            $script:DisablePowerThrottling = $false
            $script:DisableHibernation = $false
            $script:DefenderExclusions = $false
            $script:CheckInstallUtil = $true
            $script:PickProgramsToUninstall = $false
        }
        'Aggressive' {
            $script:OptimizationProfile = 'Aggressive'
            $script:DisableSearchIndexer = $true
            $script:DisableAnyDesk = $true
            $script:RemoveStoreBloat = $true
            $script:DisableAnimations = $true
            $script:DisableToastNotifs = $false
            $script:FastKillHungApps = $false
            $script:TunePowerOnAC = $true
            $script:LimitDefenderCpu = $true
            $script:EnableHardwareGpuScheduling = $false
            $script:DisablePowerThrottling = $false
            $script:DisableHibernation = $false
            $script:DefenderExclusions = $false
            $script:CheckInstallUtil = $true
            $script:PickProgramsToUninstall = $true
        }
        'Custom' {
            Write-Host 'Using current custom settings from the top of the file.' -ForegroundColor Cyan
        }
        default {
            Write-Host "Unknown preset '$Name'; keeping the current values." -ForegroundColor Yellow
        }
    }
}

function Show-OptimizationChooser {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $presets = @(
        [pscustomobject]@{ Name='Safe'; Description='Low-risk profile for daily use' },
        [pscustomobject]@{ Name='Balanced'; Description='Recommended default with a good balance of speed and stability' },
        [pscustomobject]@{ Name='Aggressive'; Description='More performance tweaks and more aggressive cleanup' },
        [pscustomobject]@{ Name='Custom'; Description='Use the settings already written at the top of the script' }
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Optimization Selector'
    $form.Size = New-Object System.Drawing.Size(700, 480)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 28)
    $form.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'Choose your optimization profile:'
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
    $title.Location = New-Object System.Drawing.Point(20, 20)
    $title.Size = New-Object System.Drawing.Size(380, 30)
    $title.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $form.Controls.Add($title)

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(20, 60)
    $listBox.Size = New-Object System.Drawing.Size(300, 220)
    $listBox.BackColor = [System.Drawing.Color]::FromArgb(34, 34, 38)
    $listBox.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $listBox.BorderStyle = 'FixedSingle'
    $listBox.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    foreach($item in $presets){
        $listBox.Items.Add($item.Name) | Out-Null
    }
    $listBox.SelectedIndex = 1
    $form.Controls.Add($listBox)

    $desc = New-Object System.Windows.Forms.Label
    $desc.Location = New-Object System.Drawing.Point(340, 60)
    $desc.Size = New-Object System.Drawing.Size(320, 200)
    $desc.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 46)
    $desc.BorderStyle = 'FixedSingle'
    $desc.Padding = New-Object System.Windows.Forms.Padding(12)
    $desc.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $desc.ForeColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
    $desc.Text = $presets[1].Description
    $form.Controls.Add($desc)

    $listBox.Add_SelectedIndexChanged({
        $sel = $presets | Where-Object { $_.Name -eq $listBox.SelectedItem }
        if($sel){
            $desc.Text = $sel.Description
        }
    })

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'OK'
    $ok.Location = New-Object System.Drawing.Point(420, 290)
    $ok.Size = New-Object System.Drawing.Size(110, 40)
    $ok.BackColor = [System.Drawing.Color]::FromArgb(0, 153, 102)
    $ok.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($ok)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Location = New-Object System.Drawing.Point(540, 290)
    $cancel.Size = New-Object System.Drawing.Size(110, 40)
    $cancel.BackColor = [System.Drawing.Color]::FromArgb(75, 75, 80)
    $cancel.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancel)

    $form.AcceptButton = $ok
    $form.CancelButton = $cancel

    $result = $form.ShowDialog()
    if($result -eq [System.Windows.Forms.DialogResult]::OK){
        return $listBox.SelectedItem
    }

    return $null
}

function Show-CustomTweakChooser {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $tweaks = @(
        [pscustomobject]@{ Name='DisableSearchIndexer'; Label='Disable Search Indexer'; Description='Turns off Windows Search indexing' },
        [pscustomobject]@{ Name='DisableAnyDesk'; Label='Disable AnyDesk'; Description='Sets AnyDesk service to Manual' },
        [pscustomobject]@{ Name='RemoveStoreBloat'; Label='Remove Store bloat'; Description='Removes unnecessary Store apps' },
        [pscustomobject]@{ Name='DisableAnimations'; Label='Disable animations'; Description='Speeds up the UI and removes motion' },
        [pscustomobject]@{ Name='DisableToastNotifs'; Label='Disable popups'; Description='Turns off toast notifications' },
        [pscustomobject]@{ Name='FastKillHungApps'; Label='Kill hung apps faster'; Description='Can close apps without warning' },
        [pscustomobject]@{ Name='TunePowerOnAC'; Label='Tune power for performance'; Description='Better performance while plugged in' },
        [pscustomobject]@{ Name='LimitDefenderCpu'; Label='Reduce Defender CPU'; Description='Keeps security on while limiting scan load' },
        [pscustomobject]@{ Name='EnableHardwareGpuScheduling'; Label='Enable GPU scheduling'; Description='Needs supported graphics hardware and a restart' },
        [pscustomobject]@{ Name='DisablePowerThrottling'; Label='Disable power throttling'; Description='May increase heat and battery use' },
        [pscustomobject]@{ Name='DisableHibernation'; Label='Turn off hibernation'; Description='Frees disk space' },
        [pscustomobject]@{ Name='DefenderExclusions'; Label='Add game exclusions'; Description='Adds .minecraft/.lunarclient exclusions' },
        [pscustomobject]@{ Name='CheckInstallUtil'; Label='Check InstallUtil'; Description='Writes a report for InstallUtil.exe' },
        [pscustomobject]@{ Name='PickProgramsToUninstall'; Label='Pick uninstall list'; Description='Lets you choose extra apps to remove' }
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Custom tweaks'
    $form.Size = New-Object System.Drawing.Size(760, 520)
    $form.StartPosition = 'CenterScreen'
    $form.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 28)
    $form.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'Choose the tweaks you want:'
    $title.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
    $title.Location = New-Object System.Drawing.Point(20, 20)
    $title.Size = New-Object System.Drawing.Size(420, 30)
    $form.Controls.Add($title)

    $checkedList = New-Object System.Windows.Forms.CheckedListBox
    $checkedList.Location = New-Object System.Drawing.Point(20, 60)
    $checkedList.Size = New-Object System.Drawing.Size(380, 320)
    $checkedList.BackColor = [System.Drawing.Color]::FromArgb(34, 34, 38)
    $checkedList.ForeColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $checkedList.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    foreach($item in $tweaks){
        $checkedList.Items.Add($item.Label) | Out-Null
    }
    $form.Controls.Add($checkedList)

    $desc = New-Object System.Windows.Forms.Label
    $desc.Location = New-Object System.Drawing.Point(420, 60)
    $desc.Size = New-Object System.Drawing.Size(300, 320)
    $desc.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 46)
    $desc.BorderStyle = 'FixedSingle'
    $desc.Font = New-Object System.Drawing.Font('Segoe UI', 11)
    $desc.ForeColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
    $desc.Padding = New-Object System.Windows.Forms.Padding(12)
    $desc.Text = 'Select something from the left list. Each item explains what it does.'
    $form.Controls.Add($desc)

    $checkedList.Add_SelectedIndexChanged({
        $idx = $checkedList.SelectedIndex
        if($idx -ge 0){
            $desc.Text = $tweaks[$idx].Description
        }
    })

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Apply'
    $ok.Location = New-Object System.Drawing.Point(470, 410)
    $ok.Size = New-Object System.Drawing.Size(130, 40)
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $ok.BackColor = [System.Drawing.Color]::FromArgb(0, 153, 102)
    $ok.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $form.Controls.Add($ok)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Location = New-Object System.Drawing.Point(610, 410)
    $cancel.Size = New-Object System.Drawing.Size(110, 40)
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $cancel.BackColor = [System.Drawing.Color]::FromArgb(75, 75, 80)
    $cancel.ForeColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
    $form.Controls.Add($cancel)

    $form.AcceptButton = $ok
    $form.CancelButton = $cancel

    $result = $form.ShowDialog()
    if($result -ne [System.Windows.Forms.DialogResult]::OK){
        return
    }

    $selected = @()
    for($i = 0; $i -lt $checkedList.Items.Count; $i++){
        if($checkedList.GetItemChecked($i)){
            $selected += $tweaks[$i].Name
        }
    }

    foreach($name in $selected){
        switch($name){
            'DisableSearchIndexer' { $script:DisableSearchIndexer = $true }
            'DisableAnyDesk' { $script:DisableAnyDesk = $true }
            'RemoveStoreBloat' { $script:RemoveStoreBloat = $true }
            'DisableAnimations' { $script:DisableAnimations = $true }
            'DisableToastNotifs' { $script:DisableToastNotifs = $true }
            'FastKillHungApps' { $script:FastKillHungApps = $true }
            'TunePowerOnAC' { $script:TunePowerOnAC = $true }
            'LimitDefenderCpu' { $script:LimitDefenderCpu = $true }
            'EnableHardwareGpuScheduling' { $script:EnableHardwareGpuScheduling = $true }
            'DisablePowerThrottling' { $script:DisablePowerThrottling = $true }
            'DisableHibernation' { $script:DisableHibernation = $true }
            'DefenderExclusions' { $script:DefenderExclusions = $true }
            'CheckInstallUtil' { $script:CheckInstallUtil = $true }
            'PickProgramsToUninstall' { $script:PickProgramsToUninstall = $true }
        }
    }
}

if($LaunchMode -eq 'Downloads'){
    Show-SoftwareInstallerDialog
    return
}

switch ($OptimizationProfile) {
    'Safe' {
        Write-Host "Optimization profile: Safe (lowest-risk)" -ForegroundColor Green
        $DisableSearchIndexer    = $false
        $RemoveStoreBloat        = $false
        $DisableAnimations       = $false
        $DisableToastNotifs      = $false
        $FastKillHungApps        = $false
        $TunePowerOnAC           = $false
        $LimitDefenderCpu        = $true
        $EnableHardwareGpuScheduling = $false
        $DisablePowerThrottling  = $false
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
        $EnableHardwareGpuScheduling = $false
        $DisablePowerThrottling  = $false
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

if($LaunchMode -eq 'AdvancedTweaks'){
    if(-not (Show-AdvancedSettingsDialog)){ return }
}

if($EnableInteractiveChoose){
    Write-Host "Opening optimization selector..." -ForegroundColor Cyan
    $selectedPreset = Show-OptimizationChooser
    if($selectedPreset){
        Set-OptimizationPreset -Name $selectedPreset
    }

    $answer = Read-Host "هل تريد اختيار تعديلات إضافية يدوياً؟ (Y/N)"
    if($answer -match '^[Yy]'){
        Show-CustomTweakChooser
    }
}

# ---- Admin check (#Requires is ignored when run via "irm | iex", so we check here) ----
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if(-not $isAdmin){
    Write-Host "Please open PowerShell as Administrator, then run the command again." -ForegroundColor Red
    return
}

# ---- Profile guard / safe defaults ----
$Profile = [string]$OptimizationProfile
$Profile = $Profile.Trim()
if($Profile -notin @('Safe','Balanced','Aggressive')){
    Write-Host "Unknown profile '$Profile'; using Balanced defaults." -ForegroundColor Yellow
    $Profile = 'Balanced'
}

# ---- Preview and confirmation ----
$plannedChanges = @(
    'Disable services: DiagTrack, dmwappushservice, RetailDemo, RemoteRegistry, and SysMain; set selected optional services to Manual.',
    'Change privacy, visual, gaming, and other registry settings.',
    'Disable matching startup entries: ' + ($KillStartup -join ', '),
    'Disable matching updater/telemetry scheduled tasks (Google, Adobe, Java, Dell, IObit, and selected Windows telemetry tasks).',
    'Disable Windows Search indexing: ' + $(if($DisableSearchIndexer){'yes'}else{'no'}),
    'Set AnyDesk service to Manual: ' + $(if($DisableAnyDesk){'yes'}else{'no'}),
    'Disable visual effects: ' + $(if($DisableAnimations){'yes'}else{'no'}),
    'Disable all toast notifications: ' + $(if($DisableToastNotifs){'yes'}else{'no'}),
    'Close hung apps faster (unsaved work may be lost): ' + $(if($FastKillHungApps){'yes'}else{'no'}),
    'Tune AC power settings: ' + $(if($TunePowerOnAC){'yes'}else{'no'}),
    'Limit Defender scan CPU: ' + $(if($LimitDefenderCpu){'yes'}else{'no'}),
    'Exclude Minecraft folders from Defender: ' + $(if($DefenderExclusions){'yes'}else{'no'}),
    'Enable hardware GPU scheduling: ' + $(if($EnableHardwareGpuScheduling){'yes (restart required)'}else{'no'}),
    'Disable Windows power throttling: ' + $(if($DisablePowerThrottling){'yes (may increase heat/battery use)'}else{'no'}),
    'Disable hibernation: ' + $(if($DisableHibernation){'yes'}else{'no'}),
    'Remove bundled Store apps: ' + $(if($RemoveStoreBloat){'yes'}else{'no'}),
    'Show optional installed-program removal picker: ' + $(if($PickProgramsToUninstall){'yes'}else{'no'}),
    'Clean temporary files, run SSD TRIM, and flush DNS.'
)
Write-Host "`nFULL OPTIMIZE - planned changes ($Profile profile)" -ForegroundColor Cyan
$plannedChanges | ForEach-Object { Write-Host "  - $_" }
Write-Host "`nA restore point and backups are attempted before system changes. Some changes (such as removed apps and startup/task changes) need manual reversal." -ForegroundColor Yellow
if((Read-Host "Continue with this plan? (Y/N)") -notmatch '^[Yy]'){ Write-Host "Cancelled."; return }
if($RemoveStoreBloat -and (Read-Host "Store apps will be removed for all users. Type REMOVE to confirm") -cne 'REMOVE'){
    $RemoveStoreBloat = $false
    Write-Host "Store app removal skipped; continuing with the other selected changes." -ForegroundColor Yellow
}

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
    EnableHardwareGpuScheduling = $EnableHardwareGpuScheduling
    DisablePowerThrottling = $DisablePowerThrottling
    OriginalGpuSchedulingPresent = ($null -ne $currentGpuScheduling)
    OriginalGpuScheduling = $currentGpuScheduling
    OriginalPowerThrottlingPresent = ($null -ne $currentPowerThrottling)
    OriginalPowerThrottling = $currentPowerThrottling
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
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize',
    'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers',
    'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling'
)
foreach($p in $regBackupPaths){
    if(Test-Path $p){
        $safeName = (($p -replace '[:\\/]','_') -replace '[^A-Za-z0-9_.-]','_') + '_before.reg'
        reg.exe export $p "$bk\$safeName" /y | Out-Null
    }
}
$active = ((powercfg /getactivescheme) -replace '.*:\s*([0-9a-fA-F-]{36}).*','$1').Trim()
powercfg /export "$bk\power_before.pow" $active | Out-Null
$restoreScript = @'
# Best-effort restore of the snapshots saved by this run.
# Run this file from an elevated Windows PowerShell session.
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$csv = Join-Path $root 'services_before.csv'
if(Test-Path $csv){
    Import-Csv $csv | ForEach-Object {
        $mode = switch($_.StartMode){ 'Auto' {'Automatic'} 'Manual' {'Manual'} 'Disabled' {'Disabled'} default {$null} }
        if($mode){ try { Set-Service -Name $_.Name -StartupType $mode -ErrorAction Stop } catch { Write-Warning "Could not restore service $($_.Name): $_" } }
    }
}
Get-ChildItem -LiteralPath $root -Filter '*_before.reg' | ForEach-Object { & reg.exe import $_.FullName }
$configPath = Join-Path $root 'config.xml'
if(Test-Path $configPath){
    $config = Import-Clixml $configPath
    $graphicsKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
    $throttlingKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling'
    if($config.PSObject.Properties['OriginalGpuSchedulingPresent']){
        if($config.OriginalGpuSchedulingPresent){
            if(-not (Test-Path $graphicsKey)){ New-Item $graphicsKey -Force | Out-Null }
            Set-ItemProperty -Path $graphicsKey -Name 'HwSchMode' -Value $config.OriginalGpuScheduling -Type DWord -Force
        } else {
            Remove-ItemProperty -Path $graphicsKey -Name 'HwSchMode' -ErrorAction SilentlyContinue
        }
    }
    if($config.PSObject.Properties['OriginalPowerThrottlingPresent']){
        if($config.OriginalPowerThrottlingPresent){
            if(-not (Test-Path $throttlingKey)){ New-Item $throttlingKey -Force | Out-Null }
            Set-ItemProperty -Path $throttlingKey -Name 'PowerThrottlingOff' -Value $config.OriginalPowerThrottling -Type DWord -Force
        } else {
            Remove-ItemProperty -Path $throttlingKey -Name 'PowerThrottlingOff' -ErrorAction SilentlyContinue
        }
    }
}
$power = Join-Path $root 'power_before.pow'
if(Test-Path $power){
    $importOutput = & powercfg.exe /import $power
    $guid = ($importOutput | Out-String) -replace '.*GUID:\s*([0-9a-fA-F-]{36}).*','$1'
    if($guid -match '^[0-9a-fA-F-]{36}$'){ & powercfg.exe /setactive $guid }
}
Write-Host 'Restore attempt finished. Restart Windows and review any warnings above.' -ForegroundColor Yellow
'@
Set-Content -LiteralPath "$bk\restore_settings.ps1" -Value $restoreScript -Encoding UTF8
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
$graphicsKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
$throttlingKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling'
if($EnableHardwareGpuScheduling){
    Set-Reg $graphicsKey 'HwSchMode' 2
    Write-Host '   hardware GPU scheduling enabled; restart Windows to apply'
} else {
    Remove-ItemProperty -Path $graphicsKey -Name 'HwSchMode' -ErrorAction SilentlyContinue
}
if($DisablePowerThrottling){
    Set-Reg $throttlingKey 'PowerThrottlingOff' 1
    Write-Host '   Windows power throttling disabled; heat and battery use may increase'
} else {
    Remove-ItemProperty -Path $throttlingKey -Name 'PowerThrottlingOff' -ErrorAction SilentlyContinue
}

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
