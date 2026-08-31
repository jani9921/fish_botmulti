<#
================================================================================
 AI-FishBot Monitor v2.8 - PID vezerles es AH eladasi tanacsado
================================================================================
 A v2 stabilizalt, hibajavitott valtozata. Ugyanaz a 17 reteg, valtozatlan
 architekturaval:

   1  Configuration        7  Loot            13 Notification
   2  Logging              8  Price           14 Session/Report
   3  Audio                9  Revenue         15 Monitor
   4  PID selector        10  Target          16 GUI
   5  Client State        11  Metrics         17 Entry Point
   6  Input (Queue!)      12  Anomaly

 A legfontosabb valtozas a 6. retegben van: a korabbi szetszort
 Focus-Client+SendKeys hivasok helyett MINDEN billentyu-kuldes egy kozponti
 Input Queue-n megy at (Queue-Input -> Process-InputQueue -> Invoke-InputAction
 -> Complete-Input). A reszleteket lasd a fajl vegen levo CHANGELOG-ban.

 SZALKEZELES: tovabbra is EGY szalon fut minden (ket Timer, kulon
 intervallummal) - ez maradt a v2-bol, szandekosan nem lett hattterszalas.
================================================================================
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

# ==============================================================================
# 1) CONFIGURATION
# ==============================================================================

$Config = @{

    General = @{
        Retail                            = $true
        AutoStop                          = $false
        AutoStopMinutes                   = 3000
        AutoLogout                        = $false
        UseWindowFocus                    = $true
        FishingRetries                    = 15
        UseWeakAura                       = $false
        CastKey                           = "F6"
        BobberKey                         = "F7"
        LogoutKey                         = "F8"
        LootWaitSeconds                   = 2.0
        NoBiteStreakLimit                 = 10
        NoCatchWarningMinutes             = 15
        FishRateDropThresholdPct          = 50
        MaxClients                        = 8
        ProcessCheckIntervalSeconds       = 3
        FocusSettleMilliseconds           = 35
    }

    Client = @{
        BuffsEnabled = @(1)
        Buffs = @{
            1 = @{ Keybind = "F9";  CastTimeSeconds = 1; DurationMinutes = 5 }
            2 = @{ Keybind = "F10"; CastTimeSeconds = 5; DurationMinutes = 30 }
        }
        UsePi       = $false
        PicoComPort = "COM6"
        KeybindConfigPath = Join-Path $script:scriptDir "client-keybinds.json"
        ShowKeybindEditorEveryStart = $true
    }

    Audio = @{
        Sensitivity = 1
        PollIntervalMs = 100
    }

    Recovery = @{
        Enabled                    = $true
        NetworkPollSeconds         = 2
        NetworkLearnTimeoutSeconds = 30
        DisconnectConfirmSeconds   = 12
        StableConnectionSeconds    = 5
        MaxAttempts                = 3
        BackoffSeconds             = @(15, 30, 60)
        AllowPasswordTyping        = $false
        FallbackToNoBiteOnly       = $false
        ServerPorts                 = @()      # ures = automatikus tanulas
        IgnoreRemotePorts           = @(80, 443)

        # Minden lepes utan a program a halozati kapcsolat visszaallasat figyeli.
        # Ha mar visszajott, a hatralevo lepeseket nem hajtja vegre.
        ActionPlan = @(
            @{ Name = "Reconnect"; Type = "Key";      Key = "ENTER"; WaitForConnectionSeconds = 8  }
            @{ Name = "Password";  Type = "Password";                WaitForConnectionSeconds = 12 }
            @{ Name = "Confirm";   Type = "Key";      Key = "ENTER"; WaitForConnectionSeconds = 15 }
        )
    }

    Loot = @{
        Enabled            = $true
        ReloadEveryCatches = 10
        MaxUnsyncedMinutes  = 3
        CatchJournalEnabled = $true
        RequiredAddonVersion = "1.3"
        HighlightFishName  = "Wyrmfish"
        ReloadSettleSeconds = 4   # /reload utan ennyit var, mielott a SavedVariables fajlt olvasna
        ReloadSpacingSeconds = 8  # 8 kliensnel ne egyszerre reloadoljanak
        BindTimeoutSeconds   = 15 # PID -> SavedVariables automatikus parositas timeout
        BindMaxRetries       = 3
    }

    Price = @{
        GameVersion            = "retail"
        Region                 = "eu"
        Realm                  = "Ragnaros"
        Faction                = "Horde" # Alliance/Horde; a BBB importoldalon modositott kontextus felulirhatja
        Item                   = "Wyrmfish"
        ImportPollSeconds      = 5
        FallbackPrice          = 62
        BlizzardEnabled        = $true
        ConnectedRealmId       = $null # null = a Realm slug alapjan automatikusan feloldja
        BlizzardRefreshMinutes = 60
        BlizzardRetryMinutes   = 5
        BlizzardTimeoutSeconds = 180
        BlizzardPriceMetric    = "MinimumBuyout"
        BlizzardCachePath      = Join-Path $script:scriptDir "blizzard-ah-price-cache.json"
        BlizzardCredentialPath = Join-Path $script:scriptDir "blizzard-api-credentials.json"
        PriceHistoryPath       = Join-Path $script:scriptDir "blizzard-ah-price-history.csv"
        PriceHistoryMaxDays    = 120
        SellMinimumSamples     = 12
        SellMinimumDistinctDays = 3
        SellNowPercentile      = 0.75
        SellExpectedRisePct    = 5
        BootyBayBrokerUrl      = "https://bootybaybroker.com/inventory-price-check"
        InventoryExportPath    = Join-Path $script:scriptDir "bootybaybroker-catches.json"
        PriceImportPath        = Join-Path $script:scriptDir "bootybaybroker-price-import.csv"
        # Kezi/sandbox arak. Ezek elsobbseget elveznek az importalt arakkal
        # szemben, igy a BootyBayBrokeren nem letezo custom item is arazhato.
        AdditionalItemPrices = @{
            # "Masik hal neve" = 12.5
        }
    }

    Revenue = @{
        GoldPerEuro = 1000000 / 40
        EurToHuf    = 400
    }

    Target = @{
        TargetHuf = 100000
    }

    Gui = @{
        MonitorIntervalMs     = 100
        RefreshIntervalMs     = 1000
        ReportIntervalSeconds = 60    # CSV allapotkep percenkent; a fogasi journal azonnali
        AlertHistoryLimit     = 200
        AlertDisplayCount     = 20
    }

    Notification = @{
        Enabled         = $false
        DiscordWebhook  = $env:AIFISHBOT_DISCORD_WEBHOOK
        OnStart         = $true
        OnStop          = $true
        ThrottleMinutes = 10
        TimeoutSeconds  = 5
    }

    Logging = @{
        Directory = Join-Path $script:scriptDir "logs"
        Debug     = $false
        ErrorThrottleSeconds = 30
    }
}

$wowPassword = $env:AIFISHBOT_WOW_PASSWORD
if (-not $wowPassword) { $wowPassword = "" }

# Blizzard API credentialek: kornyezeti valtozobol vagy a GUI altal mentett,
# Windows felhasznalohoz kotott DPAPI titkositott fajlbol.
$script:BlizzardClientId = ""
$script:BlizzardClientSecret = ""

function ConvertFrom-ProtectedString {
    param([string]$Encrypted)
    if ([string]::IsNullOrWhiteSpace($Encrypted)) { return "" }
    try {
        $secure = ConvertTo-SecureString $Encrypted -ErrorAction Stop
        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
    } catch { return "" }
}

function Import-BlizzardCredentials {
    $envId = [string]$env:AIFISHBOT_BLIZZARD_CLIENT_ID
    $envSecret = [string]$env:AIFISHBOT_BLIZZARD_CLIENT_SECRET
    if (-not [string]::IsNullOrWhiteSpace($envId) -and -not [string]::IsNullOrWhiteSpace($envSecret)) {
        $script:BlizzardClientId = $envId.Trim()
        $script:BlizzardClientSecret = $envSecret
        return $true
    }
    $path = $Config.Price.BlizzardCredentialPath
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    try {
        $saved = Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $script:BlizzardClientId = ConvertFrom-ProtectedString -Encrypted ([string]$saved.ClientId)
        $script:BlizzardClientSecret = ConvertFrom-ProtectedString -Encrypted ([string]$saved.ClientSecret)
        return (-not [string]::IsNullOrWhiteSpace($script:BlizzardClientId) -and -not [string]::IsNullOrWhiteSpace($script:BlizzardClientSecret))
    } catch {
        Write-LogException -Context "Blizzard credential betoltese" -ErrorRecord $_
        return $false
    }
}

function Save-BlizzardCredentials {
    param([string]$ClientId, [string]$ClientSecret)
    $ClientId = $ClientId.Trim()
    if ([string]::IsNullOrWhiteSpace($ClientId) -or [string]::IsNullOrWhiteSpace($ClientSecret)) {
        throw "A Client ID es a Client Secret is kotelezo."
    }
    $idEncrypted = ConvertFrom-SecureString (ConvertTo-SecureString $ClientId -AsPlainText -Force)
    $secretEncrypted = ConvertFrom-SecureString (ConvertTo-SecureString $ClientSecret -AsPlainText -Force)
    [PSCustomObject]@{
        Version = 1
        ClientId = $idEncrypted
        ClientSecret = $secretEncrypted
        Updated = Get-Date
    } | ConvertTo-Json | Out-File -LiteralPath $Config.Price.BlizzardCredentialPath -Force -Encoding UTF8
    $script:BlizzardClientId = $ClientId
    $script:BlizzardClientSecret = $ClientSecret
}

# ==============================================================================
# 2) LOGGING ENGINE
# ==============================================================================

try {
    if (-not (Test-Path $Config.Logging.Directory)) {
        New-Item -ItemType Directory -Path $Config.Logging.Directory -Force | Out-Null
    }
} catch {
    $Config.Logging.Directory = $script:scriptDir
}
$script:LogFilePath = Join-Path $Config.Logging.Directory ("session_{0}.log" -f (Get-Date -Format "yyyy-MM-dd"))
$script:SessionId = Get-Date -Format "yyyy-MM-dd_HHmmss"
$script:CatchCsvPath = Join-Path $Config.Logging.Directory ("catches_{0}.csv" -f $script:SessionId)
$script:LastExceptionLog = @{}

function Write-Log {
    param(
        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG")]
        [string]$Level,
        [string]$Message
    )
    if ($Level -eq "DEBUG" -and -not $Config.Logging.Debug) { return }
    $line = "{0:yyyy-MM-dd HH:mm:ss} [{1}] [{2}] {3}" -f (Get-Date), $script:SessionId, $Level, $Message
    try { Add-Content -Path $script:LogFilePath -Value $line -ErrorAction SilentlyContinue } catch { }
}

function Write-LogException {
    param([string]$Context, $ErrorRecord)
    $typeName = $ErrorRecord.Exception.GetType().Name
    $message = $ErrorRecord.Exception.Message
    $key = "$Context|$typeName|$message"
    $now = Get-Date
    if ($script:LastExceptionLog.ContainsKey($key)) {
        $elapsed = ($now - $script:LastExceptionLog[$key]).TotalSeconds
        if ($elapsed -lt $Config.Logging.ErrorThrottleSeconds) { return }
    }
    $script:LastExceptionLog[$key] = $now
    Write-Log -Level ERROR -Message ("{0} | {1}: {2}" -f $Context, $typeName, $message)
}

# Azonnali, addon-fuggetlen esemenynaplo. Ez azt jelenti, hogy a bot a bobbert
# sikeresen megnyomta; a pontos targynev/mennyiseg a kovetkezo loot sync utan
# erkezik a WoW SavedVariables fajljabol.
function Write-CatchJournal {
    param($Client, [datetime]$Now)
    if (-not $Config.Loot.CatchJournalEnabled) { return }

    try {
        $knownLootTotal = 0
        if ($Client.FishCounts -and $Client.FishCounts.Count -gt 0) {
            $sum = ($Client.FishCounts.Values | Measure-Object -Sum).Sum
            if ($null -ne $sum) { $knownLootTotal = [int]$sum }
        }
        $row = [PSCustomObject]@{
            Timestamp       = $Now.ToString("yyyy-MM-dd HH:mm:ss.fff")
            Client          = $Client.PID
            Event           = "BobberClick"
            SessionHooks    = $Client.HookCount
            SyncedLootItems = $knownLootTotal
            PendingHooks    = [Math]::Max($Client.HookCount - $Client.LastLootSyncHookCount, 0)
            LootSyncState   = $Client.LootReloadState
        }
        if (Test-Path -LiteralPath $script:CatchCsvPath) {
            $row | Export-Csv -LiteralPath $script:CatchCsvPath -NoTypeInformation -Append -Encoding UTF8
        } else {
            $row | Export-Csv -LiteralPath $script:CatchCsvPath -NoTypeInformation -Encoding UTF8
        }
    } catch {
        Write-LogException -Context "[$($Client.PID)] Catch journal" -ErrorRecord $_
    }
}

# ==============================================================================
# 3) AUDIO ENGINE (NAudio / WASAPI)
# ==============================================================================

function Ensure-NAudio {
    $scriptDir = $script:scriptDir
    $packages = @("NAudio.Core", "NAudio.Wasapi")

    foreach ($pkg in $packages) {
        $dllPath = Join-Path $scriptDir "$pkg.dll"
        if (Test-Path $dllPath) { continue }

        Write-Log -Level INFO -Message "NAudio komponens letoltese: $pkg"
        try {
            $tmpZip = Join-Path $env:TEMP "$pkg.zip"
            $tmpDir = Join-Path $env:TEMP "$($pkg)_extract"
            if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue }
            Invoke-WebRequest -Uri "https://www.nuget.org/api/v2/package/$pkg/2.2.1" -OutFile $tmpZip -UseBasicParsing -TimeoutSec 30
            Expand-Archive -Path $tmpZip -DestinationPath $tmpDir -Force

            $dll = Get-ChildItem -Path $tmpDir -Recurse -Filter "$pkg.dll" -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match "net472" } | Select-Object -First 1
            if (-not $dll) {
                $dll = Get-ChildItem -Path $tmpDir -Recurse -Filter "$pkg.dll" -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -match "netstandard2\.0" } | Select-Object -First 1
            }
            if (-not $dll) {
                $dll = Get-ChildItem -Path $tmpDir -Recurse -Filter "$pkg.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
            }
            if (-not $dll) { throw "Nem talalhato $pkg.dll a letoltott csomagban." }
            Copy-Item $dll.FullName -Destination $dllPath -Force
        } catch {
            Write-LogException -Context "NAudio letoltes ($pkg)" -ErrorRecord $_
            [System.Windows.Forms.MessageBox]::Show(
                "NAudio letoltese sikertelen ($pkg): $($_.Exception.Message)`n`nToltsd le kezzel: https://www.nuget.org/packages/$pkg",
                "AI-FishBot Monitor v2.8", "OK", "Error") | Out-Null
            Exit 1
        }
    }

    try {
        Add-Type -Path (Join-Path $scriptDir "NAudio.Core.dll")
        Add-Type -Path (Join-Path $scriptDir "NAudio.Wasapi.dll")
    } catch {
        Write-LogException -Context "NAudio betoltes (Add-Type)" -ErrorRecord $_
        [System.Windows.Forms.MessageBox]::Show(
            "NAudio betoltese sikertelen: $($_.Exception.Message)`n`nToroljd a script melletti NAudio.Core.dll / NAudio.Wasapi.dll fajlokat es probald ujra.",
            "AI-FishBot Monitor v2.8", "OK", "Error") | Out-Null
        Exit 1
    }

    # Fust-teszt: probaljuk tenylegesen hasznalni, hogy korai, ertheto hibat kapjunk
    # ahelyett hogy csak az elso valodi poll-nal derulne ki.
    try {
        $testEnum = New-Object NAudio.CoreAudioApi.MMDeviceEnumerator
        $null = $testEnum.GetDefaultAudioEndpoint([NAudio.CoreAudioApi.DataFlow]::Render, [NAudio.CoreAudioApi.Role]::Multimedia)
    } catch {
        Write-LogException -Context "NAudio fust-teszt" -ErrorRecord $_
        [System.Windows.Forms.MessageBox]::Show(
            "NAudio betoltodott, de nem hasznalhato: $($_.Exception.Message)`n`nLehet, hogy nincs aktiv lejatszo audio eszkoz.",
            "AI-FishBot Monitor v2.8", "OK", "Warning") | Out-Null
    }
}

$script:AudioDevice = $null

function Get-AudioDeviceCached {
    if (-not $script:AudioDevice) {
        $enumerator = New-Object NAudio.CoreAudioApi.MMDeviceEnumerator
        $script:AudioDevice = $enumerator.GetDefaultAudioEndpoint(
            [NAudio.CoreAudioApi.DataFlow]::Render,
            [NAudio.CoreAudioApi.Role]::Multimedia
        )
    }
    return $script:AudioDevice
}

# SOHA nem dobhat kifele kivetelt - a monitor ciklus stabilitasa ettol fugg.
function Get-ClientAudioPeaks {
    param([uint32[]]$Pids)

    $peakResult = @{}
    if (-not $Pids -or $Pids.Count -eq 0) { return $peakResult }
    $wantedPids = @{}
    foreach ($pidValue in $Pids) { $wantedPids[[uint32]$pidValue] = $true }

    try {
        $device = Get-AudioDeviceCached
        $sessions = $device.AudioSessionManager.Sessions
        for ($i = 0; $i -lt $sessions.Count; $i++) {
            try {
                $session = $sessions[$i]
                $sessionPid = [uint32]$session.GetProcessID
                if (-not $wantedPids.ContainsKey($sessionPid)) { continue }
                $peakPct = [Math]::Round($session.AudioMeterInformation.MasterPeakValue * 100, 2)
                if (-not $peakResult.ContainsKey($sessionPid) -or $peakResult[$sessionPid] -lt $peakPct) {
                    $peakResult[$sessionPid] = $peakPct
                }
            } catch {
                # egy session hibaja ne allitsa meg a tobbi feldolgozasat
                continue
            }
        }
    } catch {
        # az alapertelmezett eszkoz valtozhatott - dobjuk el a cache-t, kovetkezo hivas ujra probalja
        $script:AudioDevice = $null
        Write-Log -Level DEBUG -Message "Audio device cache torolve: $($_.Exception.Message)"
    }
    return $peakResult
}

# ==============================================================================
# 4) PID SELECTOR GUI
# ==============================================================================

function Show-ClientSelectorDialog {
    $wowProcesses = @(
        Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -eq "Wow" } |
        Sort-Object Id
    )

    if ($wowProcesses.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Nem talalhato futo Wow process.", "AI-FishBot Monitor v2.8", "OK", "Warning") | Out-Null
        return @()
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "AI-FishBot Monitor v2.8 - WoW PID valasztas"
    $form.Size = New-Object System.Drawing.Size(560, 500)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Valaszd ki a monitorozni kivant WoW klienseket:"
    $titleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $titleLabel.Size = New-Object System.Drawing.Size(500, 30)
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($titleLabel)

    $list = New-Object System.Windows.Forms.CheckedListBox
    $list.Location = New-Object System.Drawing.Point(20, 60)
    $list.Size = New-Object System.Drawing.Size(500, 320)
    $list.CheckOnClick = $true
    $list.Font = New-Object System.Drawing.Font("Segoe UI", 10)

    foreach ($process in $wowProcesses) {
        $windowTitle = ""
        try { $windowTitle = $process.MainWindowTitle } catch { $windowTitle = "" }
        if ([string]::IsNullOrWhiteSpace($windowTitle)) { $windowTitle = "World of Warcraft" }
        [void]$list.Items.Add(("PID {0} | {1}" -f $process.Id, $windowTitle))
    }
    $form.Controls.Add($list)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.Location = New-Object System.Drawing.Point(330, 400)
    $okButton.Size = New-Object System.Drawing.Size(90, 35)
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Megse"
    $cancelButton.Location = New-Object System.Drawing.Point(430, 400)
    $cancelButton.Size = New-Object System.Drawing.Size(90, 35)
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($cancelButton)

    $form.AcceptButton = $okButton
    $form.CancelButton = $cancelButton

    $result = $form.ShowDialog()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) { return @() }

    $selected = @()
    foreach ($idx in $list.CheckedIndices) {
        $selected += [uint32]$wowProcesses[$idx].Id
    }
    return @($selected | Select-Object -Unique)
}

function New-DefaultKeybindMap {
    $buffKeys = @{}
    foreach ($idx in $Config.Client.Buffs.Keys) {
        $buffKeys[[string]$idx] = [string]$Config.Client.Buffs[$idx].Keybind
    }
    return @{
        Cast   = [string]$Config.General.CastKey
        Bobber = [string]$Config.General.BobberKey
        Logout = [string]$Config.General.LogoutKey
        Buffs  = $buffKeys
    }
}

function Copy-KeybindMap {
    param($Source)
    $result = New-DefaultKeybindMap
    if (-not $Source) { return $result }

    if ($Source.Cast)   { $result.Cast = [string]$Source.Cast }
    if ($Source.Bobber) { $result.Bobber = [string]$Source.Bobber }
    if ($Source.Logout) { $result.Logout = [string]$Source.Logout }
    if ($Source.Buffs) {
        foreach ($idx in $Config.Client.Buffs.Keys) {
            $property = $Source.Buffs.PSObject.Properties[[string]$idx]
            if ($property -and $property.Value) { $result.Buffs[[string]$idx] = [string]$property.Value }
        }
        if ($Source.Buffs -is [hashtable]) {
            foreach ($idx in $Source.Buffs.Keys) { $result.Buffs[[string]$idx] = [string]$Source.Buffs[$idx] }
        }
    }
    return $result
}

function Import-KeybindSlots {
    $path = $Config.Client.KeybindConfigPath
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    try {
        $saved = Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        return @($saved.Slots)
    } catch {
        Write-LogException -Context "Keybind profil betoltese" -ErrorRecord $_
        return @()
    }
}

function Save-KeybindSlots {
    param([object[]]$Slots)
    try {
        [PSCustomObject]@{
            Version = 1
            Updated = Get-Date
            Slots   = @($Slots)
        } | ConvertTo-Json -Depth 8 | Out-File -LiteralPath $Config.Client.KeybindConfigPath -Force -Encoding UTF8
    } catch {
        Write-LogException -Context "Keybind profil mentese" -ErrorRecord $_
    }
}

function Test-KeySpec {
    param([string]$KeySpec)
    if ([string]::IsNullOrWhiteSpace($KeySpec)) { return $false }
    $normalized = $KeySpec.Trim().ToUpperInvariant() -replace '\s+', ''
    return $normalized -match '^(?:(?:CTRL|SHIFT|ALT)\+)*(?:F(?:[1-9]|1[0-9]|2[0-4])|[A-Z0-9]|SPACE|ENTER|ESC|TAB|HOME|END|PGUP|PGDN|UP|DOWN|LEFT|RIGHT|INSERT|DELETE|BACKSPACE)$'
}

function ConvertTo-SendKeysSequence {
    param([string]$KeySpec)
    if (-not (Test-KeySpec -KeySpec $KeySpec)) { throw "Ervenytelen billentyu: $KeySpec" }
    $parts = @($KeySpec.Trim().ToUpperInvariant() -replace '\s+', '' -split '\+')
    $base = $parts[-1]
    $prefix = ""
    for ($i = 0; $i -lt ($parts.Count - 1); $i++) {
        switch ($parts[$i]) {
            "CTRL"  { $prefix += "^" }
            "SHIFT" { $prefix += "+" }
            "ALT"   { $prefix += "%" }
        }
    }
    $sendName = switch ($base) {
        "BACKSPACE" { "BS" }
        "DELETE"    { "DEL" }
        default      { $base }
    }
    $body = if ($sendName.Length -eq 1) { $sendName } else { "{$sendName}" }
    return "$prefix$body"
}

function Show-ClientKeybindDialog {
    param([uint32[]]$Pids)

    $savedSlots = Import-KeybindSlots
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "AI-FishBot v2.8 - kliensenkenti billentyuk"
    $form.Size = New-Object System.Drawing.Size(980, 540)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $help = New-Object System.Windows.Forms.Label
    $help.Text = "Minden sor egy WoW kliens. Elfogadott pelda: F6, 1, CTRL+F6, SHIFT+1. A beallitasokat slotonkent megjegyzi."
    $help.Location = New-Object System.Drawing.Point(15, 15)
    $help.Size = New-Object System.Drawing.Size(930, 35)
    $form.Controls.Add($help)

    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(15, 55)
    $grid.Size = New-Object System.Drawing.Size(935, 370)
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.RowHeadersVisible = $false
    $grid.AutoSizeColumnsMode = "Fill"
    [void]$grid.Columns.Add("Slot", "Slot")
    [void]$grid.Columns.Add("PID", "PID")
    [void]$grid.Columns.Add("Window", "Ablak")
    [void]$grid.Columns.Add("Cast", "Dobas")
    [void]$grid.Columns.Add("Bobber", "Kapás")
    [void]$grid.Columns.Add("Logout", "Kilépés")
    foreach ($idx in ($Config.Client.Buffs.Keys | Sort-Object)) {
        [void]$grid.Columns.Add("Buff$idx", "Buff $idx")
    }
    $grid.Columns["Slot"].ReadOnly = $true
    $grid.Columns["PID"].ReadOnly = $true
    $grid.Columns["Window"].ReadOnly = $true

    for ($slot = 0; $slot -lt $Pids.Count; $slot++) {
        $pidValue = [uint32]$Pids[$slot]
        $source = if ($slot -lt $savedSlots.Count) { $savedSlots[$slot] } else { $null }
        $keys = Copy-KeybindMap -Source $source
        $windowTitle = "World of Warcraft"
        try {
            $candidateTitle = (Get-Process -Id $pidValue -ErrorAction Stop).MainWindowTitle
            if (-not [string]::IsNullOrWhiteSpace($candidateTitle)) { $windowTitle = $candidateTitle }
        } catch { }

        $values = New-Object System.Collections.Generic.List[object]
        [void]$values.Add($slot + 1)
        [void]$values.Add($pidValue)
        [void]$values.Add($windowTitle)
        [void]$values.Add($keys.Cast)
        [void]$values.Add($keys.Bobber)
        [void]$values.Add($keys.Logout)
        foreach ($idx in ($Config.Client.Buffs.Keys | Sort-Object)) { [void]$values.Add($keys.Buffs[[string]$idx]) }
        [void]$grid.Rows.Add($values.ToArray())
    }
    $form.Controls.Add($grid)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "Mentes es inditas"
    $okButton.Location = New-Object System.Drawing.Point(730, 445)
    $okButton.Size = New-Object System.Drawing.Size(135, 35)
    $form.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Megse"
    $cancelButton.Location = New-Object System.Drawing.Point(875, 445)
    $cancelButton.Size = New-Object System.Drawing.Size(75, 35)
    $cancelButton.Add_Click({ $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel; $form.Close() })
    $form.Controls.Add($cancelButton)

    $resultHolder = @{ ByPid = @{}; Slots = @() }
    $okButton.Add_Click({
        $byPid = @{}
        $slotsToSave = @()
        foreach ($row in $grid.Rows) {
            $pidValue = [uint32]$row.Cells["PID"].Value
            $keys = @{
                Cast   = [string]$row.Cells["Cast"].Value
                Bobber = [string]$row.Cells["Bobber"].Value
                Logout = [string]$row.Cells["Logout"].Value
                Buffs  = @{}
            }
            $specs = @($keys.Cast, $keys.Bobber, $keys.Logout)
            foreach ($idx in ($Config.Client.Buffs.Keys | Sort-Object)) {
                $value = [string]$row.Cells["Buff$idx"].Value
                $keys.Buffs[[string]$idx] = $value
                $specs += $value
            }
            $invalid = @($specs | Where-Object { -not (Test-KeySpec -KeySpec $_) })
            if ($invalid.Count -gt 0) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Ervenytelen billentyu a(z) $pidValue PID soraban: $($invalid -join ', ')",
                    "AI-FishBot v2.8", "OK", "Warning") | Out-Null
                return
            }
            $byPid[$pidValue] = Copy-KeybindMap -Source $keys
            $slotsToSave += [PSCustomObject]@{
                Cast = $keys.Cast; Bobber = $keys.Bobber; Logout = $keys.Logout
                Buffs = $keys.Buffs
            }
        }
        $resultHolder.ByPid = $byPid
        $resultHolder.Slots = $slotsToSave
        Save-KeybindSlots -Slots $slotsToSave
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })

    $dialogResult = $form.ShowDialog()
    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
    return [PSCustomObject]$resultHolder
}

# ==============================================================================
# 5) CLIENT STATE
# ==============================================================================

function New-ClientState {
    param([uint32]$WowPid, [hashtable]$Keybinds)

    $installDir = $null
    $exePath = $null
    try {
        $proc = Get-Process -Id $WowPid -ErrorAction Stop
        if ($proc.Path) {
            $exePath = $proc.Path
            $installDir = Split-Path $proc.Path -Parent
        }
    } catch { }

    $buffStates = @{}
    foreach ($idx in $Config.Client.BuffsEnabled) {
        $buffStates[$idx] = @{ Phase = "NeedPress"; NextActionTime = (Get-Date) }
    }
    $initialLootState = if ($Config.Loot.Enabled) { "NeedBind" } else { "Disabled" }
    $resolvedKeybinds = Copy-KeybindMap -Source $Keybinds

    return @{
        PID                     = $WowPid
        InstallDir              = $installDir
        ExePath                 = $exePath
        Keybinds                = $resolvedKeybinds

        Phase                   = "NeedCast"
        NextActionTime          = Get-Date
        CastDeadline            = Get-Date
        RangeCount              = 0
        RestartTotal            = 0

        HookCount               = 0
        FishCounts              = @{}
        FishItemIds             = @{}
        LastActivity            = Get-Date

        LastLootSyncHookCount   = 0
        LastSavedVarUpdate      = $null
        FirstUnsyncedCatchAt    = $null
        LastLootItemTotal       = 0
        LootAddonVersion        = "-"
        LootLastMessage         = "Addon parositasra var"
        IsSyncing               = $false
        LootReloadState         = $initialLootState
        LootReloadNextCheck     = Get-Date
        LootBindSnapshot        = @{}
        LootBindStarted         = $null
        LootBindRetries         = 0
        SavedVariablesPath      = $null

        Buffs                   = $buffStates

        NoBiteStreak            = 0
        NeedsManualHelp         = $false
        IsRecovering            = $false
        RecoveryState           = "Learning"
        RecoveryStepIndex       = 0
        RecoveryAttempt         = 0
        RecoveryDeadline        = $null
        RecoveryBackoffUntil    = $null
        RecoveryReason          = ""
        NetworkBaseline         = @{}
        NetworkTelemetryAvailable = $null
        NetworkConnected        = $null
        NetworkLearnStarted     = Get-Date
        NetworkLostSince        = $null
        NetworkStableSince      = $null
        LastNetworkSeen         = $null

        ActiveTimeSeconds       = 0.0
        PausedTimeSeconds       = 0.0
        ReloadTimeSeconds       = 0.0

        ControlState            = "RUNNING"
        ControlStateChangedAt   = Get-Date

        Status                  = "OK"
        StatusReason            = ""
        LastProcessCheck        = Get-Date
        ProcessAlive            = $true
    }
}

$script:Clients = @{}
$script:SelectedClientPid = $null

function Test-ClientAutomationEnabled {
    param($Client)
    if (-not $Client) { return $false }
    # Regi fixture-ekkel es kezzel letrehozott kliensallapotokkal kompatibilis.
    if (-not $Client.ContainsKey("ControlState")) { return $true }
    return [string]$Client.ControlState -eq "RUNNING"
}

function Clear-ClientInputQueue {
    param([uint32]$TargetPid)

    foreach ($item in @($script:InputQueue | Where-Object { [uint32]$_.PID -eq $TargetPid })) {
        [void]$script:PendingInputKeys.Remove("$($item.PID)|$($item.Type)")
        [void]$script:InputQueue.Remove($item)
    }
}

function Reset-ClientAutomationState {
    param($Client, [datetime]$Now)

    Clear-ClientInputQueue -TargetPid $Client.PID
    if ($script:RecoveryOwnerPid -eq $Client.PID) { $script:RecoveryOwnerPid = $null }
    $Client.IsRecovering = $false
    $Client.NeedsManualHelp = $false
    $Client.RecoveryAttempt = 0
    $Client.RecoveryStepIndex = 0
    $Client.RecoveryDeadline = $null
    $Client.RecoveryBackoffUntil = $null
    $Client.RecoveryReason = ""
    $Client.RecoveryState = if ($Client.NetworkBaseline.Count -gt 0) { "Monitoring" } else { "Learning" }
    $Client.IsSyncing = $false
    if ($Config.Loot.Enabled) {
        $Client.LootReloadState = if ($Client.SavedVariablesPath) { "Idle" } else { "NeedBind" }
        $Client.LootReloadNextCheck = $Now
    }
    $Client.Phase = "NeedCast"
    $Client.NextActionTime = $Now
    $Client.CastDeadline = $Now
    $Client.RangeCount = 0
    foreach ($buff in $Client.Buffs.Values) {
        $buff.Phase = "NeedPress"
        $buff.NextActionTime = $Now
    }
}

function Set-ClientControlState {
    param([uint32]$TargetPid, [ValidateSet("RUNNING", "PAUSED", "STOPPED")][string]$State)

    $client = $script:Clients[$TargetPid]
    if (-not $client) { return $false }
    $now = Get-Date
    $oldState = if ($client.ContainsKey("ControlState")) { [string]$client.ControlState } else { "RUNNING" }

    if ($State -eq "RUNNING" -and -not (Test-ClientProcess -Client $client -Force)) {
        Write-Log -Level WARNING -Message "[$TargetPid] START nem lehetseges: a WoW folyamat nem fut."
        return $false
    }
    if ($oldState -eq $State) { return $true }

    # PAUSE/STOP: azonnal toroljuk a klienshez tartozo meg nem kuldott inputokat.
    # START: tiszta, kiszamithato allapotbol induljon ujra, ne egy lejart bite/cast deadline-bol.
    Clear-ClientInputQueue -TargetPid $TargetPid
    if ($script:RecoveryOwnerPid -eq $TargetPid) { $script:RecoveryOwnerPid = $null }

    if ($State -eq "RUNNING") {
        Reset-ClientAutomationState -Client $client -Now $now
    } else {
        $client.IsRecovering = $false
        $client.IsSyncing = $false
        $client.NeedsManualHelp = $false
        $client.RecoveryDeadline = $null
        $client.RecoveryBackoffUntil = $null
    }

    $client.ControlState = $State
    $client.ControlStateChangedAt = $now
    $client.Status = switch ($State) {
        "PAUSED"  { "PAUSED" }
        "STOPPED" { "STOPPED" }
        default   { "OK" }
    }
    $client.StatusReason = switch ($State) {
        "PAUSED"  { "Felhasznalo altal szuneteltetve" }
        "STOPPED" { "Felhasznalo altal leallitva" }
        default   { "" }
    }
    Write-Log -Level INFO -Message "[$TargetPid] Kliensvezerles: $oldState -> $State"
    return $true
}

# ==============================================================================
# 6) INPUT ENGINE (kozponti Input Queue)
# ==============================================================================

$script:WShell = $null
if ($Config.General.UseWindowFocus) {
    try { $script:WShell = New-Object -ComObject wscript.shell }
    catch { Write-LogException -Context "WScript.Shell letrehozas" -ErrorRecord $_ }
}

$script:InputQueue       = New-Object System.Collections.Generic.List[object]
$script:PendingInputKeys = @{}     # "$TargetPid|$Type" -> $true, amig fuggoben van
$script:InputBusy        = $false
$script:MaxInputRetries  = 3

$script:InputPriority = @{
    Recovery = 0
    Bobber   = 1
    Cast     = 2
    Buff     = 3
    Maintenance = 4   # Reload, ChatCommand, Logout
}

# Kozponti process-ellenorzo - mindenhol ezt hasznaljuk, ne szort Get-Process hivasokat.
function Test-ClientProcess {
    param($Client, [switch]$Force)
    if (-not $Client) { return $false }
    $now = Get-Date
    if (-not $Force -and $Client.LastProcessCheck -and
        (($now - $Client.LastProcessCheck).TotalSeconds -lt $Config.General.ProcessCheckIntervalSeconds)) {
        return [bool]$Client.ProcessAlive
    }
    try {
        $proc = Get-Process -Id $Client.PID -ErrorAction Stop
        $Client.ProcessAlive = -not $proc.HasExited
    } catch {
        $Client.ProcessAlive = $false
    }
    $Client.LastProcessCheck = $now
    return [bool]$Client.ProcessAlive
}

function Focus-Client {
    param([uint32]$TargetPid)
    if (-not $Config.General.UseWindowFocus) { return $true }
    if (-not $script:WShell) { return $false }
    try {
        $activated = $script:WShell.AppActivate([int]$TargetPid)
        if (-not $activated) { return $false }
        Start-Sleep -Milliseconds $Config.General.FocusSettleMilliseconds
        return $true
    } catch {
        return $false
    }
}

function Get-EscapedSendKeys {
    param([string]$Text)
    $special = '+^%~(){}[]'
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $Text.ToCharArray()) {
        if ($special.IndexOf($ch) -ge 0) { [void]$sb.Append('{').Append($ch).Append('}') }
        else { [void]$sb.Append($ch) }
    }
    return $sb.ToString()
}

function Send-RawKey {
    param([string]$Key)
    if ($Config.Client.UsePi) {
        if ($script:PicoPort -and $script:PicoPort.IsOpen) {
            try { $script:PicoPort.WriteLine($Key) } catch { Write-LogException -Context "Pi WriteLine" -ErrorRecord $_ }
        }
    } else {
        $sequence = ConvertTo-SendKeysSequence -KeySpec $Key
        [System.Windows.Forms.SendKeys]::SendWait($sequence)
    }
}

# --- Bekerules a queue-ba: dedup-al, halott klienst elutasit ---
function Queue-Input {
    param(
        [uint32]$TargetPid,
        [string]$Type,
        [hashtable]$Payload = @{},
        [int]$Priority = 4
    )

    $client = $script:Clients[$TargetPid]
    if (-not $client) { return $false }
    if (-not (Test-ClientAutomationEnabled -Client $client)) { return $false }
    if (-not (Test-ClientProcess -Client $client)) { return $false }

    $dedupKey = "$TargetPid|$Type"
    if ($script:PendingInputKeys.ContainsKey($dedupKey)) { return $false }

    $item = @{
        PID       = $TargetPid
        Type      = $Type
        Payload   = $Payload
        Priority  = $Priority
        CreatedAt = Get-Date
        RetryCount = 0
        NextAttemptAt = Get-Date
    }
    $script:InputQueue.Add($item) | Out-Null
    $script:PendingInputKeys[$dedupKey] = $true

    $logPayload = if ($Type -like "Recovery*") { "[REDACTED]" } else { ($Payload.Keys -join ",") }
    Write-Log -Level DEBUG -Message "[$TargetPid] Queue-Input: $Type (prio=$Priority, payload=$logPayload)"
    return $true
}

# --- Tenyleges vegrehajtas (fokusz + billentyu) - CSAK ezen a helyen tortenik SendKeys ---
function Invoke-InputAction {
    param($Client, $Item)

    if (-not (Focus-Client -TargetPid $Client.PID)) { return $false }

    switch ($Item.Type) {
        "Cast"   { Send-RawKey -Key $Client.Keybinds.Cast;   return $true }
        "Bobber" { Send-RawKey -Key $Client.Keybinds.Bobber; return $true }
        "Buff"   { Send-RawKey -Key $Item.Payload.Keybind;     return $true }
        "Logout" { Send-RawKey -Key $Client.Keybinds.Logout; return $true }

        "ChatCommand" {
            if ($Config.Client.UsePi) { return $false }
            [System.Windows.Forms.SendKeys]::SendWait("{ENTER}$($Item.Payload.Command){ENTER}")
            return $true
        }
        "Reload" {
            if ($Config.Client.UsePi) { return $false }
            [System.Windows.Forms.SendKeys]::SendWait("{ENTER}/reload{ENTER}")
            return $true
        }
        "BindLoot" {
            if ($Config.Client.UsePi) { return $false }
            [System.Windows.Forms.SendKeys]::SendWait("{ENTER}/aifishloot reset{ENTER}")
            Start-Sleep -Milliseconds 150
            [System.Windows.Forms.SendKeys]::SendWait("{ENTER}/reload{ENTER}")
            return $true
        }
        "RecoveryAction" {
            if ($Client.NetworkConnected -eq $true) {
                $Item.Payload.Skipped = $true
                return $true
            }
            switch ($Item.Payload.ActionType) {
                "Key" {
                    Send-RawKey -Key $Item.Payload.Key
                    return $true
                }
                "Password" {
                    if ($Config.Client.UsePi -or -not $Config.Recovery.AllowPasswordTyping -or
                        [string]::IsNullOrEmpty($wowPassword)) { return $false }
                    [System.Windows.Forms.SendKeys]::SendWait("^a")
                    [System.Windows.Forms.SendKeys]::SendWait("{DEL}")
                    $escaped = Get-EscapedSendKeys -Text $wowPassword
                    [System.Windows.Forms.SendKeys]::SendWait("$escaped{ENTER}")
                    return $true
                }
                default { return $false }
            }
        }
        default {
            Write-Log -Level WARNING -Message "Ismeretlen input tipus: $($Item.Type)"
            return $false
        }
    }
}

# --- Queue elem lezarasa: allapotgep-atmenetek innen indulnak ---
function Complete-Input {
    param($Item, [bool]$Success)

    $dedupKey = "$($Item.PID)|$($Item.Type)"
    $script:PendingInputKeys.Remove($dedupKey)
    [void]$script:InputQueue.Remove($Item)

    $client = $script:Clients[$Item.PID]
    if (-not $client) { return }
    $now = Get-Date

    if (-not $Success) {
        Write-Log -Level WARNING -Message "[$($Item.PID)] Input sikertelen: $($Item.Type) (retry=$($Item.RetryCount))"
        if ($Item.Type -eq "RecoveryAction") {
            $client.RecoveryStepIndex++
            $client.RecoveryState = "AwaitingAction"
            $client.RecoveryReason = "Recovery input sikertelen: $($Item.Payload.Name)"
        }
        elseif ($Item.Type -eq "Reload") {
            $client.LootReloadState = "Failed"
        }
        elseif ($Item.Type -eq "BindLoot") {
            $client.LootBindRetries++
            $client.LootReloadState = if ($client.LootBindRetries -ge $Config.Loot.BindMaxRetries) { "BindFailed" } else { "NeedBind" }
            $client.LootReloadNextCheck = $now.AddSeconds(3)
            $client.IsSyncing = $false
            if ($script:LootBindingPid -eq $client.PID) { $script:LootBindingPid = $null }
        }
        return
    }

    switch ($Item.Type) {
        "Cast" {
            $client.Phase = "AwaitingBite"
            $settleSeconds = 2
            $castingTime = if ($Config.General.Retail) { 22 } else { 30 }
            $client.NextActionTime = $now.AddSeconds($settleSeconds)
            $client.CastDeadline   = $now.AddSeconds($settleSeconds + $castingTime)
        }
        "Bobber" {
            $client.LastActivity = $now
            $client.HookCount++
            $client.NoBiteStreak = 0
            if (-not $client.FirstUnsyncedCatchAt) { $client.FirstUnsyncedCatchAt = $now }
            Write-CatchJournal -Client $client -Now $now
            $client.Phase = "PostCatch"
            $lootWaitMs = [int]($Config.General.LootWaitSeconds * 1000)
            $client.NextActionTime = $now.AddMilliseconds($lootWaitMs + (Get-Random -Minimum 0 -Maximum 400))
        }
        "Buff" {
            $idx = $Item.Payload.Index
            $buffCfg = $Config.Client.Buffs[$idx]
            if ($buffCfg -and $client.Buffs.ContainsKey($idx)) {
                $client.Buffs[$idx].Phase = "Casting"
                $client.Buffs[$idx].NextActionTime = $now.AddSeconds([Math]::Max($buffCfg.CastTimeSeconds, 0) + 1)
            }
        }
        "Reload" {
            $client.LootReloadState = "SyncLoot"
            $client.LootReloadNextCheck = $now.AddSeconds($Config.Loot.ReloadSettleSeconds)
        }
        "BindLoot" {
            $client.LootBindSnapshot = $Item.Payload.Snapshot
            $client.LootBindStarted = $now
            $client.LootReloadState = "Binding"
            $client.LootReloadNextCheck = $now.AddSeconds($Config.Loot.ReloadSettleSeconds)
        }
        "RecoveryAction" {
            if ($Item.Payload.Skipped) {
                $client.RecoveryState = "Stabilizing"
                if (-not $client.NetworkStableSince) { $client.NetworkStableSince = $now }
                return
            }
            $client.RecoveryState = "WaitingForConnection"
            $waitSeconds = [Math]::Max([double]$Item.Payload.WaitSeconds, 1.0)
            $client.RecoveryDeadline = $now.AddSeconds($waitSeconds)
            Write-Log -Level INFO -Message "[$($client.PID)] Recovery lepes elkuldve: $($Item.Payload.Name), kapcsolatfigyeles ${waitSeconds}s"
        }
    }
}

# --- Egy tick alatt LEGFELJEBB EGY elemet dolgoz fel, hogy a GUI ne akadjon meg ---
function Process-InputQueue {
    if ($script:InputBusy) { return }
    if ($script:InputQueue.Count -eq 0) { return }

    $script:InputBusy = $true
    try {
        # @() kotelezo: egyetlen queue elemnel a pipeline skalart adna vissza,
        # es a $sorted[0] hashtable-kulcskereses lenne (null). Ez okozta a
        # naploban a folyamatos "array index evaluated to null" hibat.
        $now = Get-Date
        $sorted = @(
            $script:InputQueue |
                Where-Object { -not $_.NextAttemptAt -or $_.NextAttemptAt -le $now } |
                Sort-Object Priority, CreatedAt
        )
        if ($sorted.Count -eq 0) { return }
        $item = $sorted[0]

        $client = $script:Clients[$item.PID]
        if (-not $client -or -not (Test-ClientProcess -Client $client)) {
            Complete-Input -Item $item -Success $false
            return
        }
        if (-not (Test-ClientAutomationEnabled -Client $client)) {
            $dedupKey = "$($item.PID)|$($item.Type)"
            [void]$script:PendingInputKeys.Remove($dedupKey)
            [void]$script:InputQueue.Remove($item)
            return
        }
        if ($client.NeedsManualHelp) {
            $dedupKey = "$($item.PID)|$($item.Type)"
            [void]$script:PendingInputKeys.Remove($dedupKey)
            [void]$script:InputQueue.Remove($item)
            return
        }

        $ok = $false
        try {
            $ok = Invoke-InputAction -Client $client -Item $item
        } catch {
            Write-LogException -Context "[$($item.PID)] Invoke-InputAction ($($item.Type))" -ErrorRecord $_
            $ok = $false
        }

        if (-not $ok) {
            $item.RetryCount++
            if ($item.RetryCount -ge $script:MaxInputRetries) {
                Complete-Input -Item $item -Success $false
            } else {
                $item.NextAttemptAt = (Get-Date).AddMilliseconds(250)
            }
            # kulonben a queue-ban marad, kovetkezo tick ujraprobalja (nincs while/retry-loop)
        } else {
            Complete-Input -Item $item -Success $true
        }
    } finally {
        $script:InputBusy = $false
    }
}

# ==============================================================================
# ADAPTIVE CONNECTION / RECOVERY ENGINE
# ==============================================================================

$script:FastTcpReaderAvailable = $false
try {
    if (-not ("AIFishBot.TcpTableReader" -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Net;
using System.Runtime.InteropServices;

namespace AIFishBot {
    public sealed class TcpConnectionRow {
        public int ProcessId { get; set; }
        public string RemoteAddress { get; set; }
        public int RemotePort { get; set; }
    }

    public static class TcpTableReader {
        private const int AF_INET = 2;
        private const int ERROR_INSUFFICIENT_BUFFER = 122;
        private const int TCP_TABLE_OWNER_PID_ALL = 5;
        private const uint MIB_TCP_STATE_ESTAB = 5;

        [StructLayout(LayoutKind.Sequential)]
        private struct MIB_TCPROW_OWNER_PID {
            public uint state;
            public uint localAddr;
            public uint localPort;
            public uint remoteAddr;
            public uint remotePort;
            public uint owningPid;
        }

        [DllImport("iphlpapi.dll", SetLastError = true)]
        private static extern uint GetExtendedTcpTable(
            IntPtr tcpTable, ref int size, bool order, int ipVersion,
            int tableClass, uint reserved = 0);

        public static TcpConnectionRow[] GetEstablishedIPv4() {
            int size = 0;
            uint first = GetExtendedTcpTable(IntPtr.Zero, ref size, false, AF_INET, TCP_TABLE_OWNER_PID_ALL, 0);
            if (first == 0 && size <= 0) return new TcpConnectionRow[0];
            if (first != ERROR_INSUFFICIENT_BUFFER || size <= 0) {
                throw new InvalidOperationException("GetExtendedTcpTable meretezes sikertelen. Kod: " + first);
            }

            IntPtr buffer = Marshal.AllocHGlobal(size);
            try {
                uint result = GetExtendedTcpTable(buffer, ref size, false, AF_INET, TCP_TABLE_OWNER_PID_ALL, 0);
                if (result != 0) {
                    throw new InvalidOperationException("GetExtendedTcpTable olvasas sikertelen. Kod: " + result);
                }
                int count = Marshal.ReadInt32(buffer);
                int rowSize = Marshal.SizeOf(typeof(MIB_TCPROW_OWNER_PID));
                IntPtr rowPtr = IntPtr.Add(buffer, sizeof(uint));
                var rows = new List<TcpConnectionRow>(count);
                for (int i = 0; i < count; i++) {
                    var native = (MIB_TCPROW_OWNER_PID)Marshal.PtrToStructure(rowPtr, typeof(MIB_TCPROW_OWNER_PID));
                    rowPtr = IntPtr.Add(rowPtr, rowSize);
                    if (native.state != MIB_TCP_STATE_ESTAB || native.remoteAddr == 0) continue;
                    byte[] addressBytes = BitConverter.GetBytes(native.remoteAddr);
                    byte[] portBytes = BitConverter.GetBytes(native.remotePort);
                    rows.Add(new TcpConnectionRow {
                        ProcessId = unchecked((int)native.owningPid),
                        RemoteAddress = new IPAddress(addressBytes).ToString(),
                        RemotePort = (portBytes[0] << 8) + portBytes[1]
                    });
                }
                return rows.ToArray();
            } finally {
                Marshal.FreeHGlobal(buffer);
            }
        }
    }
}
"@
    }
    $script:FastTcpReaderAvailable = $true
} catch {
    Write-LogException -Context "Gyors TCP tabla olvaso betoltese" -ErrorRecord $_
}

$script:RecoveryOwnerPid = $null
$script:NextNetworkPoll = Get-Date
$script:NetworkTelemetryErrorLogged = $false

function Get-WowNetworkSnapshot {
    param([uint32[]]$Pids)

    $byPid = @{}
    $wanted = @{}
    foreach ($pidValue in $Pids) {
        $uPid = [uint32]$pidValue
        $wanted[$uPid] = $true
        $byPid[$uPid] = @()
    }

    try {
        if ($script:FastTcpReaderAvailable) {
            $connections = @([AIFishBot.TcpTableReader]::GetEstablishedIPv4() | ForEach-Object {
                [PSCustomObject]@{
                    OwningProcess = $_.ProcessId
                    RemoteAddress = $_.RemoteAddress
                    RemotePort    = $_.RemotePort
                }
            })
        } elseif (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
            # Lassabb tartalek ut: csak akkor hasznaljuk, ha a gyors WinAPI olvaso
            # ezen a gepen nem toltheto be.
            $connections = @(Get-NetTCPConnection -State Established -ErrorAction Stop)
        } else {
            return [PSCustomObject]@{
                Available = $false
                ByPid     = $byPid
                Error     = "Sem a gyors TCP olvaso, sem a Get-NetTCPConnection nem erheto el"
            }
        }

        foreach ($connection in $connections) {
            $pidValue = [uint32]$connection.OwningProcess
            if (-not $wanted.ContainsKey($pidValue)) { continue }

            $remoteAddress = [string]$connection.RemoteAddress
            $remotePort = [int]$connection.RemotePort
            if ([string]::IsNullOrWhiteSpace($remoteAddress) -or
                $remoteAddress -in @("127.0.0.1", "::1", "0.0.0.0", "::")) { continue }
            if ($Config.Recovery.ServerPorts.Count -gt 0) {
                if ($Config.Recovery.ServerPorts -notcontains $remotePort) { continue }
            } elseif ($Config.Recovery.IgnoreRemotePorts -contains $remotePort) {
                continue
            }

            $endpoint = [PSCustomObject]@{
                Address = $remoteAddress
                Port    = $remotePort
                Key     = "$remoteAddress|$remotePort"
            }
            $byPid[$pidValue] = @($byPid[$pidValue]) + $endpoint
        }
        return [PSCustomObject]@{ Available = $true; ByPid = $byPid; Error = $null }
    } catch {
        return [PSCustomObject]@{ Available = $false; ByPid = $byPid; Error = $_.Exception.Message }
    }
}

function Update-NetworkTelemetry {
    param([uint32[]]$Pids, [datetime]$Now)

    if (-not $Config.Recovery.Enabled -or $Now -lt $script:NextNetworkPoll) { return }
    $script:NextNetworkPoll = $Now.AddSeconds($Config.Recovery.NetworkPollSeconds)
    $snapshot = Get-WowNetworkSnapshot -Pids $Pids

    if (-not $snapshot.Available) {
        foreach ($pidValue in $Pids) {
            $client = $script:Clients[[uint32]$pidValue]
            if (-not $client) { continue }
            $client.NetworkTelemetryAvailable = $false
            if ($client.IsRecovering) {
                # Friss kapcsolat-visszacsatolas nelkul egyetlen tovabbi
                # recovery billentyut sem szabad vakon elkuldeni.
                Clear-ClientPendingInputs -TargetPid $client.PID -IncludeRecovery
                $client.RecoveryState = "TelemetryPaused"
                $client.RecoveryDeadline = $null
                $client.RecoveryBackoffUntil = $null
                $client.RecoveryReason = "Recovery szunetel: nincs halozati telemetria"
                if ($script:RecoveryOwnerPid -eq $client.PID) { $script:RecoveryOwnerPid = $null }
            }
        }
        if (-not $script:NetworkTelemetryErrorLogged) {
            Write-Log -Level WARNING -Message "Automatikus reconnect letiltva: halozati telemetria nem erheto el ($($snapshot.Error))"
            $script:NetworkTelemetryErrorLogged = $true
        }
        return
    }

    $script:NetworkTelemetryErrorLogged = $false
    foreach ($pidValue in $Pids) {
        $client = $script:Clients[[uint32]$pidValue]
        if (-not $client) { continue }
        $client.NetworkTelemetryAvailable = $true
        $endpoints = @($snapshot.ByPid[[uint32]$pidValue])

        if ($client.NetworkBaseline.Count -eq 0) {
            if ($endpoints.Count -gt 0) {
                foreach ($endpoint in $endpoints) {
                    $client.NetworkBaseline["E:$($endpoint.Key)"] = $true
                    $client.NetworkBaseline["P:$($endpoint.Port)"] = $true
                }
                $client.NetworkConnected = $true
                $client.LastNetworkSeen = $Now
                $client.NetworkStableSince = $Now
                if ($client.RecoveryState -eq "Learning") { $client.RecoveryState = "Monitoring" }
                Write-Log -Level INFO -Message "[$($client.PID)] Szerverkapcsolat megtanulva: $($endpoints.Key -join ', ')"
            }
            continue
        }

        $matched = $false
        foreach ($endpoint in $endpoints) {
            if ($client.NetworkBaseline.ContainsKey("E:$($endpoint.Key)") -or
                $client.NetworkBaseline.ContainsKey("P:$($endpoint.Port)")) {
                $matched = $true
                # Sikeres ujracsatlakozas utan az uj cimet is tanuljuk meg.
                $client.NetworkBaseline["E:$($endpoint.Key)"] = $true
                break
            }
        }

        $wasConnected = $client.NetworkConnected
        $client.NetworkConnected = $matched
        if ($matched) {
            $client.LastNetworkSeen = $Now
            $client.NetworkLostSince = $null
            if ($wasConnected -ne $true -or -not $client.NetworkStableSince) { $client.NetworkStableSince = $Now }
        } else {
            $client.NetworkStableSince = $null
            if (-not $client.NetworkLostSince) { $client.NetworkLostSince = $Now }
        }
    }
}

function Clear-ClientPendingInputs {
    param([uint32]$TargetPid, [switch]$IncludeRecovery)
    foreach ($item in @($script:InputQueue | Where-Object {
        $_.PID -eq $TargetPid -and ($IncludeRecovery -or $_.Type -notlike "Recovery*")
    })) {
        $dedupKey = "$($item.PID)|$($item.Type)"
        [void]$script:PendingInputKeys.Remove($dedupKey)
        [void]$script:InputQueue.Remove($item)
    }
}

function Complete-ClientRecovery {
    param($Client, [datetime]$Now)
    $Client.IsRecovering = $false
    $Client.NeedsManualHelp = $false
    $Client.RecoveryState = "Monitoring"
    $Client.RecoveryStepIndex = 0
    $Client.RecoveryAttempt = 0
    $Client.RecoveryDeadline = $null
    $Client.RecoveryBackoffUntil = $null
    $Client.RecoveryReason = ""
    $Client.NoBiteStreak = 0
    $Client.Phase = "NeedCast"
    $Client.NextActionTime = $Now.AddSeconds(1)
    $Client.CastDeadline = $Now
    $Client.LastActivity = $Now
    foreach ($buffState in $Client.Buffs.Values) {
        $buffState.Phase = "NeedPress"
        $buffState.NextActionTime = $Now.AddSeconds(2)
    }
    if ($script:RecoveryOwnerPid -eq $Client.PID) { $script:RecoveryOwnerPid = $null }
    Write-Log -Level INFO -Message "[$($Client.PID)] Kapcsolat stabil - horgaszat ujraindul"
}

function Set-ClientRecoveryManual {
    param($Client, [string]$Reason)
    Clear-ClientPendingInputs -TargetPid $Client.PID -IncludeRecovery
    $Client.NeedsManualHelp = $true
    $Client.IsRecovering = $false
    $Client.RecoveryState = "Manual"
    $Client.RecoveryReason = $Reason
    $Client.StatusReason = $Reason
    if ($script:RecoveryOwnerPid -eq $Client.PID) { $script:RecoveryOwnerPid = $null }
    Write-Log -Level ERROR -Message "[$($Client.PID)] $Reason"
}

function Move-ClientRecoveryToBackoffOrManual {
    param($Client, [datetime]$Now)
    if ($Client.RecoveryAttempt -ge $Config.Recovery.MaxAttempts) {
        Set-ClientRecoveryManual -Client $Client -Reason "Reconnect sikertelen ($($Client.RecoveryAttempt)x), kezi beavatkozas kell"
        return
    }
    $backoffs = @($Config.Recovery.BackoffSeconds)
    $index = [Math]::Min([Math]::Max($Client.RecoveryAttempt - 1, 0), $backoffs.Count - 1)
    $seconds = if ($backoffs.Count -gt 0) { [double]$backoffs[$index] } else { 15.0 }
    $Client.RecoveryState = "Backoff"
    $Client.RecoveryBackoffUntil = $Now.AddSeconds($seconds)
    $Client.RecoveryStepIndex = 0
    if ($script:RecoveryOwnerPid -eq $Client.PID) { $script:RecoveryOwnerPid = $null }
    Write-Log -Level WARNING -Message "[$($Client.PID)] Reconnect kor sikertelen, ujraproba ${seconds}s mulva"
}

function Queue-NextRecoveryAction {
    param($Client, [datetime]$Now)
    $plan = @($Config.Recovery.ActionPlan)

    while ($Client.RecoveryStepIndex -lt $plan.Count) {
        $step = $plan[$Client.RecoveryStepIndex]
        $type = [string]$step.Type
        if ($type -eq "Password" -and
            (-not $Config.Recovery.AllowPasswordTyping -or [string]::IsNullOrEmpty($wowPassword) -or $Config.Client.UsePi)) {
            Write-Log -Level INFO -Message "[$($Client.PID)] Recovery lepes kihagyva: $($step.Name) (jelszobeiras nincs engedelyezve)"
            $Client.RecoveryStepIndex++
            continue
        }
        if ($type -eq "Key" -and -not (Test-KeySpec -KeySpec ([string]$step.Key))) {
            Write-Log -Level WARNING -Message "[$($Client.PID)] Recovery lepes ervenytelen billentyuvel kihagyva: $($step.Name)"
            $Client.RecoveryStepIndex++
            continue
        }

        $payload = @{
            StepIndex = $Client.RecoveryStepIndex
            Name = [string]$step.Name
            ActionType = $type
            Key = [string]$step.Key
            WaitSeconds = [double]$step.WaitForConnectionSeconds
        }
        $queued = Queue-Input -TargetPid $Client.PID -Type "RecoveryAction" -Priority $script:InputPriority.Recovery -Payload $payload
        if ($queued) { $Client.RecoveryState = "ActionPending" }
        return
    }

    Move-ClientRecoveryToBackoffOrManual -Client $Client -Now $Now
}

function Update-ClientRecoveryState {
    param($Client, [datetime]$Now)
    if (-not $Config.Recovery.Enabled -or -not $Client.ProcessAlive) { return }

    $hasBaseline = $Client.NetworkBaseline.Count -gt 0
    $confirmedNetworkLoss = $Client.NetworkTelemetryAvailable -eq $true -and $hasBaseline -and
        $Client.NetworkConnected -eq $false -and $Client.NetworkLostSince -and
        (($Now - $Client.NetworkLostSince).TotalSeconds -ge $Config.Recovery.DisconnectConfirmSeconds)
    $fallbackLoss = $Config.Recovery.FallbackToNoBiteOnly -and -not $hasBaseline -and
        $Client.NoBiteStreak -ge $Config.General.NoBiteStreakLimit

    switch ($Client.RecoveryState) {
        "Learning" {
            # Baseline nelkul nincs jelszobeiras. A no-bite csak akkor lehet
            # fallback trigger, ha ezt a felhasznalo kulon engedelyezte.
            if ($fallbackLoss) {
                $Client.RecoveryState = "WaitingSlot"
                $Client.IsRecovering = $true
                $Client.RecoveryReason = "No-bite fallback"
                Clear-ClientPendingInputs -TargetPid $Client.PID
            }
        }
        "Monitoring" {
            if ($confirmedNetworkLoss -or $fallbackLoss) {
                $Client.IsRecovering = $true
                $Client.RecoveryState = "WaitingSlot"
                $Client.RecoveryReason = if ($confirmedNetworkLoss) { "Tartos szerverkapcsolat-vesztes" } else { "No-bite fallback" }
                Clear-ClientPendingInputs -TargetPid $Client.PID
                Write-Log -Level WARNING -Message "[$($Client.PID)] Disconnect megerositve: $($Client.RecoveryReason)"
            }
        }
        "WaitingSlot" {
            if ($Client.NetworkConnected -eq $true) {
                $Client.RecoveryState = "Stabilizing"
                if (-not $Client.NetworkStableSince) { $Client.NetworkStableSince = $Now }
                return
            }
            if (-not $script:RecoveryOwnerPid) {
                $script:RecoveryOwnerPid = $Client.PID
                $Client.RecoveryAttempt++
                $Client.RecoveryStepIndex = 0
                $Client.RecoveryState = "AwaitingAction"
                Write-Log -Level WARNING -Message "[$($Client.PID)] Reconnect probalkozas #$($Client.RecoveryAttempt)"
            }
        }
        "AwaitingAction" {
            if ($Client.NetworkConnected -eq $true) {
                $Client.RecoveryState = "Stabilizing"
                return
            }
            Queue-NextRecoveryAction -Client $Client -Now $Now
        }
        "ActionPending" { }
        "WaitingForConnection" {
            if ($Client.NetworkConnected -eq $true) {
                $Client.RecoveryState = "Stabilizing"
                if (-not $Client.NetworkStableSince) { $Client.NetworkStableSince = $Now }
            } elseif ($Client.RecoveryDeadline -and $Now -ge $Client.RecoveryDeadline) {
                $Client.RecoveryStepIndex++
                $Client.RecoveryState = "AwaitingAction"
            }
        }
        "Stabilizing" {
            if ($Client.NetworkConnected -ne $true) {
                $Client.NetworkStableSince = $null
                $Client.RecoveryState = "WaitingSlot"
                if ($script:RecoveryOwnerPid -eq $Client.PID) { $script:RecoveryOwnerPid = $null }
            } elseif ($Client.NetworkStableSince -and
                (($Now - $Client.NetworkStableSince).TotalSeconds -ge $Config.Recovery.StableConnectionSeconds)) {
                Complete-ClientRecovery -Client $Client -Now $Now
            }
        }
        "Backoff" {
            if ($Client.NetworkConnected -eq $true) {
                $Client.RecoveryState = "Stabilizing"
                if (-not $Client.NetworkStableSince) { $Client.NetworkStableSince = $Now }
            } elseif ($Client.RecoveryBackoffUntil -and $Now -ge $Client.RecoveryBackoffUntil) {
                $Client.RecoveryState = "WaitingSlot"
            }
        }
        "TelemetryPaused" {
            if ($Client.NetworkTelemetryAvailable -eq $true) {
                if ($Client.NetworkConnected -eq $true) {
                    $Client.RecoveryState = "Stabilizing"
                    if (-not $Client.NetworkStableSince) { $Client.NetworkStableSince = $Now }
                } elseif ($hasBaseline) {
                    $Client.RecoveryState = "WaitingSlot"
                }
            }
        }
        "Manual" { }
        default { $Client.RecoveryState = if ($hasBaseline) { "Monitoring" } else { "Learning" } }
    }
}

# --- Buff allapotgep: NeedPress -> (queue-ol) -> Casting -> Active -> NeedPress ---
function Update-ClientBuffs {
    param($Client, [datetime]$Now)

    foreach ($idx in $Config.Client.BuffsEnabled) {
        $buffCfg = $Config.Client.Buffs[$idx]
        $buffKey = $Client.Keybinds.Buffs[[string]$idx]
        if (-not $buffCfg -or -not $buffKey) { continue }
        if (-not $Client.Buffs.ContainsKey($idx)) {
            $Client.Buffs[$idx] = @{ Phase = "NeedPress"; NextActionTime = $Now }
        }
        $buffState = $Client.Buffs[$idx]
        if ($Now -lt $buffState.NextActionTime) { continue }

        switch ($buffState.Phase) {
            "NeedPress" {
                Queue-Input -TargetPid $Client.PID -Type "Buff" -Priority $script:InputPriority.Buff -Payload @{ Index = $idx; Keybind = $buffKey } | Out-Null
                # a Phase valtast a Complete-Input vegzi siker eseten; itt csak elkeruljuk
                # az azonnali ujra-ellenorzest a kovetkezo tick-ig.
            }
            "Casting" {
                # a Complete-Input mar beallitotta a NextActionTime-ot, itt csak varunk
            }
            "Active" {
                $buffState.Phase = "NeedPress"
                $buffState.NextActionTime = $Now
            }
        }
    }
}

# ==============================================================================
# 7) LOOT TRACKER (AIFishLootTracker addon SavedVariables)
# ==============================================================================

$script:LootBindingPid = $null
$script:NextLootReloadAllowed = Get-Date

function Get-SavedVarFiles {
    param([string]$InstallDir)
    if (-not $InstallDir) { return @() }
    $pattern = Join-Path $InstallDir "WTF\Account\*\SavedVariables\AIFishLootTracker.lua"
    try { return @(Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue) }
    catch { return @() }
}

function Get-SavedVarSnapshot {
    param([string]$InstallDir)
    $snapshot = @{}
    foreach ($file in (Get-SavedVarFiles -InstallDir $InstallDir)) {
        $snapshot[$file.FullName.ToLowerInvariant()] = $file.LastWriteTimeUtc.Ticks
    }
    return $snapshot
}

function Find-ChangedSavedVarFile {
    param([string]$InstallDir, [hashtable]$Before, [uint32]$ForPid)
    if (-not $Before) { $Before = @{} }
    $assigned = @{}
    foreach ($other in $script:Clients.Values) {
        if ($other.PID -ne $ForPid -and $other.SavedVariablesPath) {
            $assigned[$other.SavedVariablesPath.ToLowerInvariant()] = $true
        }
    }

    $changed = @(
        Get-SavedVarFiles -InstallDir $InstallDir |
            Where-Object {
                $pathKey = $_.FullName.ToLowerInvariant()
                (-not $assigned.ContainsKey($pathKey)) -and
                ((-not $Before.ContainsKey($pathKey)) -or $_.LastWriteTimeUtc.Ticks -gt [int64]$Before[$pathKey])
            } |
            Sort-Object LastWriteTimeUtc -Descending
    )
    if ($changed.Count -eq 0) { return $null }
    return $changed[0]
}

# A klienshez mar automatikusan hozzarendelt SavedVariables fajlt olvassa.
# Az ures AIFishLootDB is ervenyes (friss reset utan ez a normalis allapot).
function Update-LootLog {
    param($Client)

    if (-not $Client.SavedVariablesPath) {
        Write-Log -Level DEBUG -Message "[$($Client.PID)] Loot fajl meg nincs a klienshez parositva"
        return $false
    }
    $svFile = Get-Item -LiteralPath $Client.SavedVariablesPath -ErrorAction SilentlyContinue
    if (-not $svFile -or $svFile.Length -eq 0) { return $false }

    try {
        $content = Get-Content -LiteralPath $svFile.FullName -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($content)) { return $false }

        $blockMatch = [regex]::Match(
            $content,
            'AIFishLootDB\s*=\s*\{(.*?)\r?\n\}',
            [System.Text.RegularExpressions.RegexOptions]::Singleline
        )
        if (-not $blockMatch.Success) {
            # A WoW ures tablat egy sorban is kiirhatja: AIFishLootDB = {}
            if ($content -match 'AIFishLootDB\s*=\s*\{\s*\}') {
                $searchText = ""
            } else {
                Write-Log -Level WARNING -Message "[$($Client.PID)] SavedVariables tartalma nem ertelmezheto - regi adat megtartva"
                return $false
            }
        } else {
            $searchText = $blockMatch.Groups[1].Value
        }

        $newCounts = @{}
        $matches = [regex]::Matches($searchText, '\["(.+?)"\]\s*=\s*(\d+)')
        foreach ($m in $matches) {
            $newCounts[$m.Groups[1].Value] = [int]$m.Groups[2].Value
        }

        $newItemIds = @{}
        $itemIdBlock = [regex]::Match(
            $content,
            '\["itemIds"\]\s*=\s*\{(.*?)\r?\n\s*\},',
            [System.Text.RegularExpressions.RegexOptions]::Singleline
        )
        if ($itemIdBlock.Success) {
            $itemIdMatches = [regex]::Matches($itemIdBlock.Groups[1].Value, '\["(.+?)"\]\s*=\s*(\d+)')
            foreach ($m in $itemIdMatches) {
                $newItemIds[$m.Groups[1].Value] = [int]$m.Groups[2].Value
            }
        }

        $versionMatch = [regex]::Match($content, '\["version"\]\s*=\s*"([^"]+)"')
        $Client.LootAddonVersion = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { "legacy/unknown" }
        $versionMismatch = $Client.LootAddonVersion -ne $Config.Loot.RequiredAddonVersion

        $itemTotal = 0
        if ($newCounts.Count -gt 0) {
            $sum = ($newCounts.Values | Measure-Object -Sum).Sum
            if ($null -ne $sum) { $itemTotal = [int]$sum }
        }
        $Client.FishCounts = $newCounts
        $Client.FishItemIds = $newItemIds
        $Client.LastSavedVarUpdate = Get-Date
        $Client.LastLootItemTotal = $itemTotal
        if ($versionMismatch) {
            $Client.LootLastMessage = "Regi addon: $($Client.LootAddonVersion), kell: $($Config.Loot.RequiredAddonVersion)"
            Write-Log -Level WARNING -Message "[$($Client.PID)] $($Client.LootLastMessage). Csereld le az AIFishLootTracker mappat is."
        } elseif ($Client.HookCount -gt 0 -and $itemTotal -eq 0) {
            $Client.LootLastMessage = "Addon adat ures ($($Client.HookCount) bobber-click utan)"
            Write-Log -Level WARNING -Message "[$($Client.PID)] Loot sync sikerult, de az addon adatbazisa ures. Ellenorizd: /aifishloot status"
        } else {
            $Client.LootLastMessage = "$itemTotal item / $($newCounts.Count) fajta / $($newItemIds.Count) ID"
            Write-Log -Level INFO -Message "[$($Client.PID)] Loot sync ok: $itemTotal item, $($newCounts.Count) fajta, $($newItemIds.Count) item ID"
        }
        try { Update-BootyBayBrokerArtifacts -Now (Get-Date) } catch { Write-LogException -Context "BootyBayBroker export" -ErrorRecord $_ }
        return $true
    } catch {
        Write-LogException -Context "[$($Client.PID)] Update-LootLog" -ErrorRecord $_
        return $false
    }
}

# Nem blokkolo, 8 kliensre sorositott allapotgep. Indulaskor kliensenkent egy
# reset+reload alapjan automatikusan felismeri, melyik account SavedVariables
# fajlja tartozik az adott PID-hez. Kesobb a reloadok kozott globalis szunetet tart.
function Update-LootReloadState {
    param($Client, [datetime]$Now)

    if (-not $Config.Loot.Enabled -or $Client.NeedsManualHelp) { return }

    switch ($Client.LootReloadState) {
        "NeedBind" {
            # Indulaskor minden kliens var a sajat fajlparositasara, igy a
            # reset elott kifogott halak nem vesznek el a session statisztikabol.
            $Client.IsSyncing = $true
            if ($script:LootBindingPid -or $Now -lt $Client.LootReloadNextCheck) { return }
            $snapshot = Get-SavedVarSnapshot -InstallDir $Client.InstallDir
            $Client.IsSyncing = $true
            $queued = Queue-Input -TargetPid $Client.PID -Type "BindLoot" -Priority $script:InputPriority.Recovery -Payload @{ Snapshot = $snapshot }
            if ($queued) {
                $script:LootBindingPid = $Client.PID
                $Client.LootReloadState = "BindRequested"
                Write-Log -Level INFO -Message "[$($Client.PID)] Loot fajl automatikus parositasa indul"
            } else {
                $Client.LootReloadNextCheck = $Now.AddSeconds(2)
            }
        }
        "BindRequested" { }
        "Binding" {
            if ($Now -lt $Client.LootReloadNextCheck) { return }
            $changed = Find-ChangedSavedVarFile -InstallDir $Client.InstallDir -Before $Client.LootBindSnapshot -ForPid $Client.PID
            if ($changed) {
                $Client.SavedVariablesPath = $changed.FullName
                [void](Update-LootLog -Client $Client)
                $Client.LastLootSyncHookCount = $Client.HookCount
                $Client.FirstUnsyncedCatchAt = $null
                $Client.LootBindRetries = 0
                $Client.IsSyncing = $false
                $Client.LootReloadState = "Idle"
                $script:LootBindingPid = $null
                $script:NextLootReloadAllowed = $Now.AddSeconds($Config.Loot.ReloadSpacingSeconds)
                Write-Log -Level INFO -Message "[$($Client.PID)] Loot fajl parositva: $($changed.FullName)"
                return
            }

            if ($Client.LootBindStarted -and (($Now - $Client.LootBindStarted).TotalSeconds -ge $Config.Loot.BindTimeoutSeconds)) {
                $Client.LootBindRetries++
                $Client.IsSyncing = $false
                $script:LootBindingPid = $null
                if ($Client.LootBindRetries -ge $Config.Loot.BindMaxRetries) {
                    $Client.LootReloadState = "BindFailed"
                    $Client.LootLastMessage = "Addon/SavedVariables parositas sikertelen"
                    $Client.Status = "WARNING"
                    $Client.StatusReason = "Loot fajl parositas sikertelen"
                    Write-Log -Level WARNING -Message "[$($Client.PID)] Loot fajl parositas $($Client.LootBindRetries)x sikertelen"
                } else {
                    $Client.IsSyncing = $true
                    $Client.LootReloadState = "NeedBind"
                    $Client.LootReloadNextCheck = $Now.AddSeconds(3)
                }
            } else {
                $Client.LootReloadNextCheck = $Now.AddSeconds(1)
            }
        }
        "Idle" {
            if (-not $Client.SavedVariablesPath) {
                $Client.LootReloadState = "NeedBind"
                return
            }
            if ($script:LootBindingPid -or $Now -lt $script:NextLootReloadAllowed -or
                $Now -lt $Client.LootReloadNextCheck) { return }

            $pendingHooks = [Math]::Max($Client.HookCount - $Client.LastLootSyncHookCount, 0)
            $countDue = $pendingHooks -ge $Config.Loot.ReloadEveryCatches
            $timeDue = $pendingHooks -gt 0 -and $Client.FirstUnsyncedCatchAt -and
                (($Now - $Client.FirstUnsyncedCatchAt).TotalMinutes -ge $Config.Loot.MaxUnsyncedMinutes)
            if ($countDue -or $timeDue) {
                $Client.IsSyncing = $true
                $queued = Queue-Input -TargetPid $Client.PID -Type "Reload" -Priority $script:InputPriority.Maintenance
                if ($queued) {
                    $Client.LootReloadState = "Requested"
                    $script:NextLootReloadAllowed = $Now.AddSeconds($Config.Loot.ReloadSpacingSeconds)
                    $reason = if ($countDue) { "$pendingHooks uj fogasi esemeny" } else { "$([Math]::Round(($Now - $Client.FirstUnsyncedCatchAt).TotalMinutes, 1)) perc elmaradas" }
                    Write-Log -Level INFO -Message "[$($Client.PID)] Loot sync inditasa: $reason"
                } else {
                    $Client.IsSyncing = $false
                }
            }
        }
        "Requested" { }
        "SyncLoot" {
            if ($Now -ge $Client.LootReloadNextCheck) {
                $ok = Update-LootLog -Client $Client
                $Client.IsSyncing = $false
                $Client.LootReloadState = "Idle"
                if ($ok) {
                    $Client.LastLootSyncHookCount = $Client.HookCount
                    $Client.FirstUnsyncedCatchAt = $null
                    $Client.LootReloadNextCheck = $Now
                } else {
                    $Client.LootLastMessage = "Loot fajl olvasasa sikertelen - ujraproba 60s"
                    $Client.LootReloadNextCheck = $Now.AddSeconds(60)
                    Write-Log -Level WARNING -Message "[$($Client.PID)] Loot sync nem olvashato; a fogasok fuggoben maradnak, ujraproba 60s mulva"
                }
            }
        }
        "Failed" {
            $Client.IsSyncing = $false
            $Client.LootReloadState = "Idle"
            $Client.LootReloadNextCheck = $Now.AddSeconds(3)
        }
        "BindFailed" { }
        default { $Client.LootReloadState = "NeedBind" }
    }
}

# ==============================================================================
# 8) PRICE ENGINE
# ==============================================================================

$script:PriceCache = @{
    Price       = $Config.Price.FallbackPrice
    LastUpdated = $null
    Source      = "FALLBACK / nincs BBB arimport"
    Online      = $false
    PricedItems = 0
    MissingItems = 0
}
$script:ItemPricesByName = @{}
$script:ItemPricesById = @{}
$script:LastPriceImportWriteUtc = $null
$script:LastPriceImportPoll = $null
$script:BlizzardPricesById = @{}
$script:BlizzardPriceJob = $null
$script:BlizzardPriceState = @{
    Status              = "WAITING"
    LastUpdated         = $null
    LastAttempt         = $null
    NextAttempt         = [datetime]::MinValue
    LastTargetSignature = ""
    LastError           = ""
    ConnectedRealmId    = $null
    RequestedItems      = 0
    FoundItems          = 0
}
$script:PriceHistoryById = @{}
$script:LastPriceHistoryPrune = $null
$script:HungarianDayNames = @("Vasarnap", "Hetfo", "Kedd", "Szerda", "Csutortok", "Pentek", "Szombat")

function Get-HungarianDayName {
    param([int]$DayNumber)
    if ($DayNumber -lt 0 -or $DayNumber -gt 6) { return "-" }
    return $script:HungarianDayNames[$DayNumber]
}

function Get-PricePercentile {
    param([double[]]$Values, [double]$Percentile)
    $sorted = @($Values | Where-Object { $_ -gt 0 } | Sort-Object)
    if ($sorted.Count -eq 0) { return 0.0 }
    $pct = [Math]::Max(0.0, [Math]::Min(1.0, $Percentile))
    $index = [int][Math]::Floor(($sorted.Count - 1) * $pct)
    return [double]$sorted[$index]
}

function Convert-PriceHistoryEntryToRow {
    param($Entry)
    return [PSCustomObject][ordered]@{
        Timestamp = ([datetime]$Entry.Timestamp).ToString("o")
        ItemId = [int]$Entry.ItemId
        PriceGold = [double]$Entry.PriceGold
        MinBuyoutGold = [double]$Entry.MinBuyoutGold
        WeightedAverageGold = [double]$Entry.WeightedAverageGold
        AvailableQuantity = [int64]$Entry.AvailableQuantity
        Listings = [int]$Entry.Listings
        AuctionSource = [string]$Entry.AuctionSource
        ConnectedRealmId = [int]$Entry.ConnectedRealmId
        Region = [string]$Entry.Region
        Realm = [string]$Entry.Realm
    }
}

function Import-PriceHistory {
    $script:PriceHistoryById = @{}
    if (-not (Test-Path -LiteralPath $Config.Price.PriceHistoryPath)) { return }
    $cutoff = (Get-Date).AddDays(-[double]$Config.Price.PriceHistoryMaxDays)
    $loaded = 0
    try {
        foreach ($row in @(Import-Csv -LiteralPath $Config.Price.PriceHistoryPath -ErrorAction Stop)) {
            try {
                if ($row.Region -and [string]$row.Region -ne $Config.Price.Region) { continue }
                if ($row.Realm -and [string]$row.Realm -ne $Config.Price.Realm) { continue }
                $timestamp = [datetime]::Parse([string]$row.Timestamp, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind)
                $itemId = [int]$row.ItemId
                $price = ConvertTo-PositivePriceNumber $row.PriceGold
                if ($timestamp -lt $cutoff -or $itemId -le 0 -or $null -eq $price) { continue }
                $minBuyout = ConvertTo-PositivePriceNumber $row.MinBuyoutGold
                if ($null -eq $minBuyout) { $minBuyout = $price }
                $weighted = ConvertTo-PositivePriceNumber $row.WeightedAverageGold
                if ($null -eq $weighted) { $weighted = $price }
                $entry = [PSCustomObject]@{
                    Timestamp = $timestamp; ItemId = $itemId; PriceGold = [double]$price
                    MinBuyoutGold = [double]$minBuyout
                    WeightedAverageGold = [double]$weighted
                    AvailableQuantity = [int64]$row.AvailableQuantity
                    Listings = [int]$row.Listings
                    AuctionSource = [string]$row.AuctionSource
                    ConnectedRealmId = [int]$row.ConnectedRealmId
                    Region = [string]$Config.Price.Region; Realm = [string]$Config.Price.Realm
                }
                $key = [string]$itemId
                if ($script:PriceHistoryById.ContainsKey($key)) {
                    $script:PriceHistoryById[$key] = @($script:PriceHistoryById[$key]) + $entry
                } else {
                    $script:PriceHistoryById[$key] = @($entry)
                }
                $loaded++
            } catch { }
        }
        Write-Log -Level INFO -Message "AH arhistorika betoltve: $loaded minta, $($script:PriceHistoryById.Count) item ID"
    } catch {
        Write-LogException -Context "AH arhistorika import" -ErrorRecord $_
    }
}

function Export-PriceHistory {
    try {
        $rows = foreach ($key in ($script:PriceHistoryById.Keys | Sort-Object { [int]$_ })) {
            foreach ($entry in @($script:PriceHistoryById[$key] | Sort-Object Timestamp)) {
                Convert-PriceHistoryEntryToRow -Entry $entry
            }
        }
        if (@($rows).Count -gt 0) {
            $rows | Export-Csv -LiteralPath $Config.Price.PriceHistoryPath -NoTypeInformation -Encoding UTF8
        }
    } catch {
        Write-LogException -Context "AH arhistorika export" -ErrorRecord $_
    }
}

function Prune-PriceHistory {
    param([datetime]$Now)
    if ($script:LastPriceHistoryPrune -and (($Now - $script:LastPriceHistoryPrune).TotalHours -lt 24)) { return }
    $script:LastPriceHistoryPrune = $Now
    $cutoff = $Now.AddDays(-[double]$Config.Price.PriceHistoryMaxDays)
    foreach ($key in @($script:PriceHistoryById.Keys)) {
        $kept = @($script:PriceHistoryById[$key] | Where-Object { $_.Timestamp -ge $cutoff })
        if ($kept.Count -gt 0) { $script:PriceHistoryById[$key] = $kept }
        else { [void]$script:PriceHistoryById.Remove($key) }
    }
    Export-PriceHistory
}

function Add-BlizzardPriceHistorySnapshot {
    param([datetime]$Timestamp, [hashtable]$FreshPrices, [int]$ConnectedRealmId)
    if (-not $FreshPrices -or $FreshPrices.Count -eq 0) { return }

    $rows = @()
    foreach ($key in ($FreshPrices.Keys | Sort-Object { [int]$_ })) {
        $price = $FreshPrices[$key]
        if (-not (Test-ValidPrice $price.PriceGold)) { continue }
        $entry = [PSCustomObject]@{
            Timestamp = $Timestamp; ItemId = [int]$price.ItemId; PriceGold = [double]$price.PriceGold
            MinBuyoutGold = [double]$price.MinBuyoutGold
            WeightedAverageGold = [double]$price.WeightedAverageGold
            AvailableQuantity = [int64]$price.AvailableQuantity
            Listings = [int]$price.Listings
            AuctionSource = [string]$price.AuctionSource
            ConnectedRealmId = $ConnectedRealmId
            Region = [string]$Config.Price.Region; Realm = [string]$Config.Price.Realm
        }
        $historyKey = [string]$entry.ItemId
        if ($script:PriceHistoryById.ContainsKey($historyKey)) {
            $script:PriceHistoryById[$historyKey] = @($script:PriceHistoryById[$historyKey]) + $entry
        } else {
            $script:PriceHistoryById[$historyKey] = @($entry)
        }
        $rows += Convert-PriceHistoryEntryToRow -Entry $entry
    }
    if ($rows.Count -gt 0) {
        if (Test-Path -LiteralPath $Config.Price.PriceHistoryPath) {
            $rows | Export-Csv -LiteralPath $Config.Price.PriceHistoryPath -NoTypeInformation -Append -Encoding UTF8
        } else {
            $rows | Export-Csv -LiteralPath $Config.Price.PriceHistoryPath -NoTypeInformation -Encoding UTF8
        }
    }
    Prune-PriceHistory -Now $Timestamp
}

function Get-ItemPriceAnalysis {
    param([int]$ItemId, [double]$CurrentPrice, [datetime]$Now = (Get-Date))

    $history = if ($ItemId -gt 0) { @($script:PriceHistoryById[[string]$ItemId] | Sort-Object Timestamp) } else { @() }
    $prices = [double[]]@($history | ForEach-Object { [double]$_.PriceGold } | Where-Object { $_ -gt 0 })
    $sampleCount = $prices.Count
    $distinctDays = @($history | ForEach-Object { $_.Timestamp.ToString("yyyy-MM-dd") } | Select-Object -Unique).Count
    $minPrice = if ($sampleCount -gt 0) { [double]($prices | Measure-Object -Minimum).Minimum } else { 0.0 }
    $maxPrice = if ($sampleCount -gt 0) { [double]($prices | Measure-Object -Maximum).Maximum } else { 0.0 }
    $averagePrice = if ($sampleCount -gt 0) { [double]($prices | Measure-Object -Average).Average } else { 0.0 }
    $sellThreshold = Get-PricePercentile -Values $prices -Percentile $Config.Price.SellNowPercentile

    # Napi medianokbol szamolunk heti mintat, hogy egy hosszu futasi nap ne
    # kapjon aranytalanul nagy sulyt a rovidebb mintavetelezesu napokhoz kepest.
    $daily = @()
    foreach ($group in @($history | Group-Object { $_.Timestamp.ToString("yyyy-MM-dd") })) {
        $dayPrices = [double[]]@($group.Group | ForEach-Object { [double]$_.PriceGold } | Sort-Object)
        if ($dayPrices.Count -eq 0) { continue }
        $middle = [int][Math]::Floor(($dayPrices.Count - 1) / 2)
        $median = if ($dayPrices.Count % 2 -eq 0) { ([double]$dayPrices[$middle] + [double]$dayPrices[$middle + 1]) / 2.0 } else { [double]$dayPrices[$middle] }
        $daily += [PSCustomObject]@{ DayNumber = [int]$group.Group[0].Timestamp.DayOfWeek; Median = $median }
    }
    $weekdayStats = @()
    for ($day = 0; $day -le 6; $day++) {
        $dayValues = @($daily | Where-Object { $_.DayNumber -eq $day } | ForEach-Object { [double]$_.Median })
        if ($dayValues.Count -gt 0) {
            $weekdayStats += [PSCustomObject]@{
                DayNumber = $day; DayName = Get-HungarianDayName $day
                Average = [double]($dayValues | Measure-Object -Average).Average
                Days = $dayValues.Count
            }
        }
    }
    $bestDay = $weekdayStats | Sort-Object @{ Expression = "Average"; Descending = $true }, @{ Expression = "Days"; Descending = $true } | Select-Object -First 1
    $daysUntilBest = if ($bestDay) { ([int]$bestDay.DayNumber - [int]$Now.DayOfWeek + 7) % 7 } else { $null }
    $changePct = if ($averagePrice -gt 0 -and $CurrentPrice -gt 0) { (($CurrentPrice / $averagePrice) - 1.0) * 100.0 } else { 0.0 }
    $confidence = if ($distinctDays -ge 14) { "JO" } elseif ($distinctDays -ge 7) { "KOZEPES" } elseif ($distinctDays -ge $Config.Price.SellMinimumDistinctDays) { "ELOZETES" } else { "KEVES ADAT" }

    $signalCode = "COLLECT"
    $signalText = "ADATGYUJTES"
    if ($CurrentPrice -le 0) {
        $signalCode = "NO_PRICE"; $signalText = "NINCS AKTUALIS AR"
    } elseif ($sampleCount -ge $Config.Price.SellMinimumSamples -and $distinctDays -ge $Config.Price.SellMinimumDistinctDays) {
        $riseFactor = 1.0 + ([double]$Config.Price.SellExpectedRisePct / 100.0)
        if ($bestDay -and $daysUntilBest -in @(1, 2) -and [double]$bestDay.Average -ge ($CurrentPrice * $riseFactor)) {
            $signalCode = "HOLD"; $signalText = "TARTSD MEG $daysUntilBest NAPOT"
        } elseif (($sellThreshold -gt 0 -and $CurrentPrice -ge $sellThreshold -and $CurrentPrice -ge $averagePrice) -or
            ($bestDay -and $daysUntilBest -eq 0 -and $CurrentPrice -ge $averagePrice)) {
            $signalCode = "SELL_NOW"; $signalText = "MEHETSZ AZ AH-BA - ELADAS MOST"
        } elseif ($averagePrice -gt 0 -and $CurrentPrice -lt ($averagePrice * 0.95)) {
            $signalCode = "WAIT"; $signalText = "VARJ - ATLAG ALATTI AR"
        } else {
            $signalCode = "SELL_OK"; $signalText = "ELADHATO, DE NEM CSUCSAR"
        }
    }

    return [PSCustomObject]@{
        ItemId = $ItemId; CurrentPrice = $CurrentPrice; SampleCount = $sampleCount; DistinctDays = $distinctDays
        MinPrice = $minPrice; MaxPrice = $maxPrice; AveragePrice = $averagePrice; SellThreshold = $sellThreshold
        BestDayName = if ($bestDay) { $bestDay.DayName } else { "-" }
        BestDayAverage = if ($bestDay) { [double]$bestDay.Average } else { 0.0 }
        DaysUntilBest = $daysUntilBest; ChangeFromAveragePct = $changePct
        SignalCode = $signalCode; SignalText = $signalText; Confidence = $confidence
        WeekdayStats = @($weekdayStats)
    }
}

# Ugyanez a tiszta aggregalo scriptblock fut a fixture-tesztekben es a kulon
# PowerShell-jobban. A buyout egy teljes stack ara, a unit_price eleve darabar.
$script:AuctionAggregationScript = {
    param($Auctions, [int[]]$ItemIds, [hashtable]$Stats, [string]$Source)

    if (-not $Stats) { $Stats = @{} }
    $targets = @{}
    foreach ($id in $ItemIds) { if ([int]$id -gt 0) { $targets[[string][int]$id] = $true } }

    foreach ($auction in @($Auctions)) {
        if (-not $auction -or -not $auction.item) { continue }
        $itemId = [int]$auction.item.id
        $key = [string]$itemId
        if (-not $targets.ContainsKey($key)) { continue }

        $quantity = [int64]$auction.quantity
        if ($quantity -lt 1) { $quantity = 1 }
        $unitCopper = 0.0
        $unitProperty = $auction.PSObject.Properties["unit_price"]
        $buyoutProperty = $auction.PSObject.Properties["buyout"]
        if ($unitProperty -and [double]$unitProperty.Value -gt 0) {
            $unitCopper = [double]$unitProperty.Value
        } elseif ($buyoutProperty -and [double]$buyoutProperty.Value -gt 0) {
            $unitCopper = [double]$buyoutProperty.Value / [double]$quantity
        }
        if ($unitCopper -le 0) { continue }

        if (-not $Stats.ContainsKey($key)) {
            $Stats[$key] = @{
                ItemId = $itemId; MinCopper = $unitCopper; WeightedCopper = 0.0
                Quantity = [int64]0; Listings = 0; Sources = @{}
            }
        }
        $stat = $Stats[$key]
        if ($unitCopper -lt [double]$stat.MinCopper) { $stat.MinCopper = $unitCopper }
        $stat.WeightedCopper = [double]$stat.WeightedCopper + ($unitCopper * [double]$quantity)
        $stat.Quantity = [int64]$stat.Quantity + $quantity
        $stat.Listings = [int]$stat.Listings + 1
        $stat.Sources[$Source] = $true
    }
    return $Stats
}

function Test-ValidPrice {
    param($Value)
    if ($null -eq $Value) { return $false }
    try {
        $d = [double]$Value
        if ([double]::IsNaN($d) -or [double]::IsInfinity($d)) { return $false }
        if ($d -le 0) { return $false }
        return $true
    } catch { return $false }
}

function ConvertTo-PositivePriceNumber {
    param($Value)
    if ($null -eq $Value) { return $null }
    $text = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }

    # Szandekosan nincs AllowThousands: a magyar 12,5 arat nem szabad 125-nek
    # ertelmezni invariant ezreselvalasztokent.
    $styles = [System.Globalization.NumberStyles]::Float
    foreach ($culture in @([System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.CultureInfo]::CurrentCulture)) {
        $parsed = 0.0
        if ([double]::TryParse($text, $styles, $culture, [ref]$parsed) -and (Test-ValidPrice $parsed)) {
            return [double]$parsed
        }
    }
    if ($text.Contains(",") -and -not $text.Contains(".")) {
        $parsed = 0.0
        $normalized = $text.Replace(",", ".")
        if ([double]::TryParse($normalized, $styles, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed) -and (Test-ValidPrice $parsed)) {
            return [double]$parsed
        }
    }
    return $null
}

function Get-RowValue {
    param($Row, [string[]]$Names)
    foreach ($name in $Names) {
        $property = $Row.PSObject.Properties[$name]
        if ($property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return $property.Value
        }
    }
    return $null
}

function Get-ImportedUnitPriceGold {
    param($Row)

    $goldValue = Get-RowValue -Row $Row -Names @("UnitPriceGold", "PriceGold", "Gold")
    $gold = ConvertTo-PositivePriceNumber $goldValue
    if ($null -ne $gold) { return [double]$gold }

    # A BootyBayBroker nyers mezoi rezben (copper) vannak; 10 000 copper = 1 gold.
    $copperValue = Get-RowValue -Row $Row -Names @(
        "UnitPriceCopper", "effective_price", "market_value", "unit_price", "buyout"
    )
    $copper = ConvertTo-PositivePriceNumber $copperValue
    if ($null -ne $copper) { return [double]$copper / 10000.0 }
    return $null
}

function Get-ItemUnitPrice {
    param([string]$ItemName, [int]$ItemId = 0)

    if ($Config.Price.AdditionalItemPrices.ContainsKey($ItemName)) {
        $manual = ConvertTo-PositivePriceNumber $Config.Price.AdditionalItemPrices[$ItemName]
        if ($null -ne $manual) {
            return [PSCustomObject]@{ PriceGold = [double]$manual; Source = "MANUAL" }
        }
    }

    if ($ItemId -gt 0 -and $script:BlizzardPricesById.ContainsKey([string]$ItemId)) {
        return $script:BlizzardPricesById[[string]$ItemId]
    }
    if ($ItemId -gt 0 -and $script:ItemPricesById.ContainsKey([string]$ItemId)) {
        return $script:ItemPricesById[[string]$ItemId]
    }
    if ($ItemName -and $script:ItemPricesByName.ContainsKey($ItemName)) {
        return $script:ItemPricesByName[$ItemName]
    }
    if ($ItemName -eq $Config.Loot.HighlightFishName -and (Test-ValidPrice $Config.Price.FallbackPrice)) {
        return [PSCustomObject]@{ PriceGold = [double]$Config.Price.FallbackPrice; Source = "FALLBACK" }
    }
    return [PSCustomObject]@{ PriceGold = 0.0; Source = "UNPRICED" }
}

function Import-BootyBayBrokerPrices {
    param([datetime]$Now, [switch]$Force)

    if (-not $Force -and $script:LastPriceImportPoll -and
        (($Now - $script:LastPriceImportPoll).TotalSeconds -lt $Config.Price.ImportPollSeconds)) { return }
    $script:LastPriceImportPoll = $Now

    $priceFile = Get-Item -LiteralPath $Config.Price.PriceImportPath -ErrorAction SilentlyContinue
    if (-not $priceFile) {
        Update-PriceCacheSummary -Now $Now
        return
    }
    if (-not $Force -and $script:LastPriceImportWriteUtc -and
        $priceFile.LastWriteTimeUtc -eq $script:LastPriceImportWriteUtc) { return }

    try {
        $newByName = @{}
        $newById = @{}
        $rows = @(Import-Csv -LiteralPath $priceFile.FullName -ErrorAction Stop)
        $loaded = 0
        foreach ($row in $rows) {
            $itemName = [string](Get-RowValue -Row $row -Names @("ItemName", "name", "Name"))
            $itemIdRaw = Get-RowValue -Row $row -Names @("ItemId", "itemId", "blizzard_id", "BlizzardId")
            $itemId = 0
            if ($itemIdRaw) { [void][int]::TryParse([string]$itemIdRaw, [ref]$itemId) }
            $priceGold = Get-ImportedUnitPriceGold -Row $row
            if ($null -eq $priceGold) { continue }
            $source = [string](Get-RowValue -Row $row -Names @("Source", "source"))
            if ([string]::IsNullOrWhiteSpace($source)) { $source = "BOOTYBAYBROKER_IMPORT" }
            $entry = [PSCustomObject]@{
                PriceGold = [double]$priceGold
                Source    = $source
                ItemName  = $itemName
                ItemId    = $itemId
            }
            if ($itemName) { $newByName[$itemName] = $entry }
            if ($itemId -gt 0) { $newById[[string]$itemId] = $entry }
            $loaded++
        }

        $script:ItemPricesByName = $newByName
        $script:ItemPricesById = $newById
        $script:LastPriceImportWriteUtc = $priceFile.LastWriteTimeUtc
        Update-PriceCacheSummary -Now $Now -FallbackUpdated $priceFile.LastWriteTime
        Write-Log -Level INFO -Message "Arlista betoltve: $loaded arazott tetel ($($priceFile.FullName))"
    } catch {
        Write-LogException -Context "BootyBayBroker arimport" -ErrorRecord $_
        Update-PriceCacheSummary -Now $Now
    }
}

function Update-PriceCacheSummary {
    param([datetime]$Now, $FallbackUpdated = $null)

    $highlight = Get-ItemUnitPrice -ItemName $Config.Loot.HighlightFishName
    $script:PriceCache.Price = if ($highlight.PriceGold -gt 0) { [double]$highlight.PriceGold } else { [double]$Config.Price.FallbackPrice }

    $blizzardCount = $script:BlizzardPricesById.Count
    $bbbCount = $script:ItemPricesById.Count + $script:ItemPricesByName.Count
    $status = [string]$script:BlizzardPriceState.Status
    $parts = @()
    switch ($status) {
        "ONLINE"         { $parts += "BLIZZARD AH $($script:BlizzardPriceState.FoundItems)/$($script:BlizzardPriceState.RequestedItems) ID" }
        "ONLINE_PARTIAL" { $parts += "BLIZZARD RESZLEGES $($script:BlizzardPriceState.FoundItems)/$($script:BlizzardPriceState.RequestedItems) ID" }
        "CACHED"         { $parts += "BLIZZARD CACHE $blizzardCount ID" }
        "RUNNING"        { $parts += $(if ($blizzardCount -gt 0) { "BLIZZARD LEKERES FUT (cache $blizzardCount ID)" } else { "BLIZZARD LEKERES FUT" }) }
        "WAITING_CREDENTIALS" { $parts += $(if ($blizzardCount -gt 0) { "BLIZZARD KULCS HIANYZIK (cache $blizzardCount ID)" } else { "BLIZZARD KULCS HIANYZIK" }) }
        "WAITING_FOR_ITEM_IDS" { $parts += "BLIZZARD ITEM ID-RE VAR" }
        "ERROR"          {
            $errorPreview = ([string]$script:BlizzardPriceState.LastError -replace "[\r\n]+", " ").Trim()
            if ($errorPreview.Length -gt 70) { $errorPreview = $errorPreview.Substring(0, 70) + "..." }
            $cacheSuffix = if ($blizzardCount -gt 0) { " (cache $blizzardCount ID)" } else { "" }
            $parts += $(if ($errorPreview) { "BLIZZARD HIBA$cacheSuffix`: $errorPreview" } else { "BLIZZARD HIBA$cacheSuffix" })
        }
        "DISABLED"       { $parts += "BLIZZARD KIKAPCSOLVA" }
        default            { $parts += "BLIZZARD VARAKOZIK" }
    }
    if ($bbbCount -gt 0) { $parts += "BBB/CSV fallback" }
    if ($Config.Price.AdditionalItemPrices.Count -gt 0) { $parts += "manualis ar" }
    $script:PriceCache.Source = $parts -join " | "
    $script:PriceCache.Online = $status -in @("ONLINE", "ONLINE_PARTIAL", "CACHED") -and $blizzardCount -gt 0

    if ($script:BlizzardPriceState.LastUpdated) {
        $script:PriceCache.LastUpdated = $script:BlizzardPriceState.LastUpdated
    } elseif ($FallbackUpdated) {
        $script:PriceCache.LastUpdated = $FallbackUpdated
    }
}

function Get-BlizzardTargetItemIds {
    $seen = @{}
    foreach ($client in $script:Clients.Values) {
        foreach ($id in $client.FishItemIds.Values) {
            $numericId = [int]$id
            if ($numericId -gt 0) { $seen[[string]$numericId] = $numericId }
        }
    }
    return @($seen.Values | Sort-Object)
}

function Import-BlizzardPriceCache {
    if (-not (Test-Path -LiteralPath $Config.Price.BlizzardCachePath)) { return }
    try {
        $cache = Get-Content -LiteralPath $Config.Price.BlizzardCachePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ([string]$cache.Region -ne $Config.Price.Region -or [string]$cache.Realm -ne $Config.Price.Realm) { return }

        $loaded = @{}
        foreach ($row in @($cache.Prices)) {
            $itemId = [int]$row.ItemId
            $priceGold = ConvertTo-PositivePriceNumber $row.PriceGold
            if ($itemId -le 0 -or $null -eq $priceGold) { continue }
            $loaded[[string]$itemId] = [PSCustomObject]@{
                PriceGold = [double]$priceGold
                Source = "BLIZZARD_CACHE_$([string]$row.AuctionSource)"
                ItemId = $itemId
                MinBuyoutGold = [double]$row.MinBuyoutGold
                WeightedAverageGold = [double]$row.WeightedAverageGold
                AvailableQuantity = [int64]$row.AvailableQuantity
                Listings = [int]$row.Listings
            }
        }
        $script:BlizzardPricesById = $loaded
        $script:BlizzardPriceState.Status = if ($loaded.Count -gt 0) { "CACHED" } else { "WAITING" }
        $script:BlizzardPriceState.LastUpdated = if ($cache.RetrievedAt) { [datetime]$cache.RetrievedAt } else { (Get-Item -LiteralPath $Config.Price.BlizzardCachePath).LastWriteTime }
        $script:BlizzardPriceState.ConnectedRealmId = $cache.ConnectedRealmId
        $script:BlizzardPriceState.FoundItems = $loaded.Count
        Update-PriceCacheSummary -Now (Get-Date)
        Write-Log -Level INFO -Message "Blizzard AH cache betoltve: $($loaded.Count) item ID"
    } catch {
        Write-LogException -Context "Blizzard AH cache import" -ErrorRecord $_
    }
}

function Export-BlizzardPriceCache {
    try {
        $rows = foreach ($key in ($script:BlizzardPricesById.Keys | Sort-Object { [int]$_ })) {
            $entry = $script:BlizzardPricesById[$key]
            [PSCustomObject][ordered]@{
                ItemId = [int]$entry.ItemId
                PriceGold = [double]$entry.PriceGold
                AuctionSource = [string]$entry.AuctionSource
                MinBuyoutGold = [double]$entry.MinBuyoutGold
                WeightedAverageGold = [double]$entry.WeightedAverageGold
                AvailableQuantity = [int64]$entry.AvailableQuantity
                Listings = [int]$entry.Listings
            }
        }
        $cache = [PSCustomObject][ordered]@{
            Version = 1
            Region = $Config.Price.Region
            Realm = $Config.Price.Realm
            ConnectedRealmId = $script:BlizzardPriceState.ConnectedRealmId
            PriceMetric = $Config.Price.BlizzardPriceMetric
            RetrievedAt = $script:BlizzardPriceState.LastUpdated
            Prices = @($rows)
        }
        $json = $cache | ConvertTo-Json -Depth 7
        [System.IO.File]::WriteAllText($Config.Price.BlizzardCachePath, $json, (New-Object System.Text.UTF8Encoding($false)))
    } catch {
        Write-LogException -Context "Blizzard AH cache export" -ErrorRecord $_
    }
}

function Start-BlizzardAuctionPriceJob {
    param([datetime]$Now, [int[]]$ItemIds, [string]$TargetSignature)

    if ($script:BlizzardPriceJob) { return }
    $clientId = [string]$script:BlizzardClientId
    $clientSecret = [string]$script:BlizzardClientSecret
    if ([string]::IsNullOrWhiteSpace($clientId) -or [string]::IsNullOrWhiteSpace($clientSecret)) {
        $script:BlizzardPriceState.Status = "WAITING_CREDENTIALS"
        $script:BlizzardPriceState.NextAttempt = $Now.AddMinutes(1)
        Update-PriceCacheSummary -Now $Now
        return
    }

    $region = $Config.Price.Region.ToLowerInvariant()
    $realm = $Config.Price.Realm
    $connectedRealmId = if ($Config.Price.ConnectedRealmId) { [int]$Config.Price.ConnectedRealmId } else { 0 }
    $timeoutSeconds = [int]$Config.Price.BlizzardTimeoutSeconds
    $priceMetric = [string]$Config.Price.BlizzardPriceMetric
    $aggregatorText = $script:AuctionAggregationScript.ToString()
    $itemIdCsv = $ItemIds -join ","

    $script:BlizzardPriceState.Status = "RUNNING"
    $script:BlizzardPriceState.LastAttempt = $Now
    $script:BlizzardPriceState.LastTargetSignature = $TargetSignature
    $script:BlizzardPriceState.RequestedItems = $ItemIds.Count
    $script:BlizzardPriceState.LastError = ""
    Update-PriceCacheSummary -Now $Now

    $script:BlizzardPriceJob = Start-Job -Name "AIFishBot-BlizzardAH" -ArgumentList @(
        $region, $realm, $connectedRealmId, $timeoutSeconds, $priceMetric, $itemIdCsv, $aggregatorText, $clientId, $clientSecret
    ) -ScriptBlock {
        param(
            [string]$Region, [string]$Realm, [int]$ConnectedRealmId,
            [int]$TimeoutSeconds, [string]$PriceMetric, [string]$ItemIdCsv,
            [string]$AggregatorText, [string]$ClientId, [string]$ClientSecret
        )
        $ErrorActionPreference = "Stop"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        [int[]]$ItemIds = @($ItemIdCsv -split "," | Where-Object { $_ -match "^\d+$" } | ForEach-Object { [int]$_ })

        if ([string]::IsNullOrWhiteSpace($ClientId) -or [string]::IsNullOrWhiteSpace($ClientSecret)) {
            throw "A Blizzard OAuth azonosito vagy titok hianyzik."
        }

        $credentialBytes = [Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $ClientId, $ClientSecret))
        $basic = [Convert]::ToBase64String($credentialBytes)
        $tokenUri = "https://$Region.battle.net/oauth/token"
        $tokenResponse = Invoke-RestMethod -Uri $tokenUri -Method Post -Headers @{ Authorization = "Basic $basic" } `
            -ContentType "application/x-www-form-urlencoded" -Body "grant_type=client_credentials" -TimeoutSec $TimeoutSeconds
        if (-not $tokenResponse.access_token) { throw "A Blizzard OAuth nem adott access tokent." }

        $namespace = "dynamic-$Region"
        $apiHeaders = @{
            Authorization = "Bearer $($tokenResponse.access_token)"
            "Battlenet-Namespace" = $namespace
        }
        if ($ConnectedRealmId -le 0) {
            $realmSlug = ($Realm.ToLowerInvariant() -replace "[^a-z0-9]+", "-").Trim("-")
            $realmUri = "https://$Region.api.blizzard.com/data/wow/realm/$realmSlug`?namespace=$namespace&locale=en_GB"
            $realmData = Invoke-RestMethod -Uri $realmUri -Headers $apiHeaders -TimeoutSec $TimeoutSeconds
            $href = [string]$realmData.connected_realm.href
            if ($href -notmatch "/connected-realm/(\d+)") { throw "A connected realm ID nem oldhato fel: $Realm" }
            $ConnectedRealmId = [int]$Matches[1]
        }

        $endpoints = @(
            [PSCustomObject]@{
                Source = "REALM"
                Uri = "https://$Region.api.blizzard.com/data/wow/connected-realm/$ConnectedRealmId/auctions`?namespace=$namespace&locale=en_GB"
            },
            [PSCustomObject]@{
                Source = "COMMODITY"
                Uri = "https://$Region.api.blizzard.com/data/wow/auctions/commodities`?namespace=$namespace&locale=en_GB"
            }
        )

        $aggregate = [scriptblock]::Create($AggregatorText)
        $stats = @{}
        $warnings = New-Object System.Collections.Generic.List[string]
        $completedEndpoints = 0
        foreach ($endpoint in $endpoints) {
            try {
                $payload = Invoke-RestMethod -Uri $endpoint.Uri -Headers $apiHeaders -TimeoutSec $TimeoutSeconds
                $stats = & $aggregate $payload.auctions $ItemIds $stats $endpoint.Source
                $completedEndpoints++
                Remove-Variable payload -ErrorAction SilentlyContinue
            } catch {
                $warnings.Add("$($endpoint.Source): $($_.Exception.Message)")
            }
        }
        if ($completedEndpoints -eq 0) { throw ($warnings -join " | ") }

        $prices = foreach ($key in ($stats.Keys | Sort-Object { [int]$_ })) {
            $stat = $stats[$key]
            $weightedCopper = if ([int64]$stat.Quantity -gt 0) { [double]$stat.WeightedCopper / [double]$stat.Quantity } else { [double]$stat.MinCopper }
            $selectedCopper = if ($PriceMetric -eq "WeightedAverage") { $weightedCopper } else { [double]$stat.MinCopper }
            [PSCustomObject]@{
                ItemId = [int]$stat.ItemId
                PriceGold = $selectedCopper / 10000.0
                MinBuyoutGold = [double]$stat.MinCopper / 10000.0
                WeightedAverageGold = $weightedCopper / 10000.0
                AvailableQuantity = [int64]$stat.Quantity
                Listings = [int]$stat.Listings
                AuctionSource = (@($stat.Sources.Keys | Sort-Object) -join "+")
            }
        }

        [PSCustomObject]@{
            Kind = "BLIZZARD_AH_RESULT"
            Success = $true
            ConnectedRealmId = $ConnectedRealmId
            RetrievedAt = Get-Date
            RequestedItems = $ItemIds.Count
            Prices = @($prices)
            Warnings = @($warnings)
        }
    }
    Write-Log -Level INFO -Message "Blizzard AH hatterlekeres elindult: $($ItemIds.Count) item ID"
}

function Update-BlizzardAuctionPrices {
    param([datetime]$Now)

    if (-not $Config.Price.BlizzardEnabled) {
        $script:BlizzardPriceState.Status = "DISABLED"
        Update-PriceCacheSummary -Now $Now
        return
    }

    if ($script:BlizzardPriceJob) {
        if ($script:BlizzardPriceJob.State -in @("Running", "NotStarted")) { return }
        try {
            $received = @(Receive-Job -Job $script:BlizzardPriceJob -ErrorAction Stop)
            $result = $received | Where-Object { $_.Kind -eq "BLIZZARD_AH_RESULT" } | Select-Object -Last 1
            if (-not $result -or -not $result.Success) { throw "A Blizzard AH job nem adott ervenyes eredmenyt." }

            $newPrices = @{}
            foreach ($row in @($result.Prices)) {
                $itemId = [int]$row.ItemId
                $priceGold = ConvertTo-PositivePriceNumber $row.PriceGold
                if ($itemId -le 0 -or $null -eq $priceGold) { continue }
                $newPrices[[string]$itemId] = [PSCustomObject]@{
                    PriceGold = [double]$priceGold
                    Source = "BLIZZARD_$([string]$row.AuctionSource)"
                    AuctionSource = [string]$row.AuctionSource
                    ItemId = $itemId
                    MinBuyoutGold = [double]$row.MinBuyoutGold
                    WeightedAverageGold = [double]$row.WeightedAverageGold
                    AvailableQuantity = [int64]$row.AvailableQuantity
                    Listings = [int]$row.Listings
                }
            }
            $freshPriceCount = $newPrices.Count
            $hasWarnings = @($result.Warnings).Count -gt 0
            if ($hasWarnings) {
                # Ha csak az egyik Blizzard adatfolyam sikerult, a masikbol szarmazo
                # elozo (cache-elt) arakat megtartjuk a kovetkezo sikeres frissitesig.
                $mergedPrices = @{}
                foreach ($key in $script:BlizzardPricesById.Keys) { $mergedPrices[$key] = $script:BlizzardPricesById[$key] }
                foreach ($key in $newPrices.Keys) { $mergedPrices[$key] = $newPrices[$key] }
                $script:BlizzardPricesById = $mergedPrices
            } else {
                $script:BlizzardPricesById = $newPrices
            }
            $script:BlizzardPriceState.ConnectedRealmId = [int]$result.ConnectedRealmId
            $script:BlizzardPriceState.LastUpdated = [datetime]$result.RetrievedAt
            $script:BlizzardPriceState.FoundItems = $freshPriceCount
            $script:BlizzardPriceState.RequestedItems = [int]$result.RequestedItems
            $script:BlizzardPriceState.Status = if ($hasWarnings) { "ONLINE_PARTIAL" } else { "ONLINE" }
            $script:BlizzardPriceState.LastError = if ($hasWarnings) { @($result.Warnings) -join " | " } else { "" }
            $retryMinutes = if ($hasWarnings) { $Config.Price.BlizzardRetryMinutes } else { $Config.Price.BlizzardRefreshMinutes }
            $script:BlizzardPriceState.NextAttempt = $Now.AddMinutes($retryMinutes)
            Add-BlizzardPriceHistorySnapshot -Timestamp ([datetime]$result.RetrievedAt) -FreshPrices $newPrices -ConnectedRealmId ([int]$result.ConnectedRealmId)
            Export-BlizzardPriceCache
            Write-Log -Level INFO -Message "Blizzard AH arak frissitve: $freshPriceCount/$($result.RequestedItems) item ID"
        } catch {
            $script:BlizzardPriceState.Status = "ERROR"
            $script:BlizzardPriceState.LastError = $_.Exception.Message
            $script:BlizzardPriceState.NextAttempt = $Now.AddMinutes($Config.Price.BlizzardRetryMinutes)
            Write-LogException -Context "Blizzard AH hatterlekeres" -ErrorRecord $_
        } finally {
            try { Remove-Job -Job $script:BlizzardPriceJob -Force -ErrorAction SilentlyContinue } catch { }
            $script:BlizzardPriceJob = $null
            Update-PriceCacheSummary -Now $Now
        }
    }

    if ($script:BlizzardPriceJob -or $Now -lt $script:BlizzardPriceState.NextAttempt) { return }
    $itemIds = [int[]]@(Get-BlizzardTargetItemIds)
    if ($itemIds.Count -eq 0) {
        $script:BlizzardPriceState.Status = "WAITING_FOR_ITEM_IDS"
        $script:BlizzardPriceState.NextAttempt = $Now.AddMinutes(1)
        Update-PriceCacheSummary -Now $Now
        return
    }

    $signature = $itemIds -join ","
    $targetsChanged = $signature -ne $script:BlizzardPriceState.LastTargetSignature
    $refreshDue = -not $script:BlizzardPriceState.LastUpdated -or
        (($Now - $script:BlizzardPriceState.LastUpdated).TotalMinutes -ge $Config.Price.BlizzardRefreshMinutes)
    if ($targetsChanged -or $refreshDue) {
        Start-BlizzardAuctionPriceJob -Now $Now -ItemIds $itemIds -TargetSignature $signature
    }
}

function Get-AggregatedLootState {
    $counts = @{}
    $itemIds = @{}
    foreach ($client in $script:Clients.Values) {
        foreach ($name in $client.FishCounts.Keys) {
            $counts[$name] = [int]($counts[$name]) + [int]$client.FishCounts[$name]
        }
        foreach ($name in $client.FishItemIds.Keys) {
            if (-not $itemIds.ContainsKey($name)) { $itemIds[$name] = [int]$client.FishItemIds[$name] }
        }
    }
    return [PSCustomObject]@{ Counts = $counts; ItemIds = $itemIds }
}

function Export-BootyBayBrokerInventory {
    param([datetime]$Now, $LootState)

    $items = @()
    foreach ($name in ($LootState.Counts.Keys | Sort-Object)) {
        $itemId = if ($LootState.ItemIds.ContainsKey($name)) { [int]$LootState.ItemIds[$name] } else { 0 }
        if ($itemId -le 0) { continue }
        $count = [int]$LootState.Counts[$name]
        $items += [PSCustomObject][ordered]@{
            itemId       = $itemId
            count        = $count
            unboundCount = $count
            name         = $name
        }
    }

    $export = [PSCustomObject][ordered]@{
        type         = "bootybaybroker_inventory"
        version      = 2
        includesBank = $false
        character    = [PSCustomObject][ordered]@{
            name    = "AI-FishBot"
            realm   = $Config.Price.Realm
            region  = $Config.Price.Region.ToLowerInvariant()
            faction = $Config.Price.Faction
        }
        items        = $items
    }
    $json = $export | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($Config.Price.InventoryExportPath, $json, (New-Object System.Text.UTF8Encoding($false)))
    Write-Log -Level INFO -Message "BBB inventory export frissitve: $($items.Count) item ID"
}

function Update-PriceImportTemplate {
    param($LootState)

    $existing = @()
    if (Test-Path -LiteralPath $Config.Price.PriceImportPath) {
        try { $existing = @(Import-Csv -LiteralPath $Config.Price.PriceImportPath -ErrorAction Stop) } catch { $existing = @() }
    }
    $byName = @{}
    foreach ($row in $existing) {
        $name = [string](Get-RowValue -Row $row -Names @("ItemName", "name", "Name"))
        if ($name) { $byName[$name] = $row }
    }

    $added = 0
    foreach ($name in ($LootState.Counts.Keys | Sort-Object)) {
        if ($byName.ContainsKey($name)) { continue }
        $itemId = if ($LootState.ItemIds.ContainsKey($name)) { [int]$LootState.ItemIds[$name] } else { "" }
        $row = [PSCustomObject][ordered]@{
            ItemId          = $itemId
            ItemName        = $name
            UnitPriceGold   = ""
            UnitPriceCopper = ""
            Source          = ""
            LastUpdated     = ""
        }
        $existing += $row
        $byName[$name] = $row
        $added++
    }

    if ($added -gt 0 -or -not (Test-Path -LiteralPath $Config.Price.PriceImportPath)) {
        $normalized = foreach ($row in ($existing | Sort-Object { [string](Get-RowValue -Row $_ -Names @("ItemName", "name", "Name")) })) {
            [PSCustomObject][ordered]@{
                ItemId          = Get-RowValue -Row $row -Names @("ItemId", "itemId", "blizzard_id", "BlizzardId")
                ItemName        = Get-RowValue -Row $row -Names @("ItemName", "name", "Name")
                UnitPriceGold   = Get-RowValue -Row $row -Names @("UnitPriceGold", "PriceGold", "Gold")
                UnitPriceCopper = Get-RowValue -Row $row -Names @("UnitPriceCopper", "effective_price", "market_value", "unit_price", "buyout")
                Source          = Get-RowValue -Row $row -Names @("Source", "source")
                LastUpdated     = Get-RowValue -Row $row -Names @("LastUpdated", "last_scan_at")
            }
        }
        @($normalized) | Export-Csv -LiteralPath $Config.Price.PriceImportPath -NoTypeInformation -Encoding UTF8
        Write-Log -Level INFO -Message "BBB arimport sablon frissitve: +$added uj tetel"
    }
}

function Update-BootyBayBrokerArtifacts {
    param([datetime]$Now)
    $lootState = Get-AggregatedLootState
    Export-BootyBayBrokerInventory -Now $Now -LootState $lootState
    Update-PriceImportTemplate -LootState $lootState
    Import-BootyBayBrokerPrices -Now $Now -Force
    Update-BlizzardAuctionPrices -Now $Now
}

# Regi nev kompatibilitasa: a GUI-frissites mar minden item arat importalja.
function Update-WyrmfishPrice {
    param([datetime]$Now)
    Import-BootyBayBrokerPrices -Now $Now
    Update-BlizzardAuctionPrices -Now $Now
}

# ==============================================================================
# 9) REVENUE ENGINE
# ==============================================================================

function ConvertTo-SafeNumber {
    param([double]$Value, [double]$FallbackValue = 0)
    if ([double]::IsNaN($Value) -or [double]::IsInfinity($Value)) { return $FallbackValue }
    return $Value
}

function Add-LootCounts {
    param([hashtable]$Target, [hashtable]$Source)
    if (-not $Source) { return }
    foreach ($name in $Source.Keys) {
        $Target[$name] = [int]($Target[$name]) + [int]$Source[$name]
    }
}

function Add-LootItemIds {
    param([hashtable]$Target, [hashtable]$Source)
    if (-not $Source) { return }
    foreach ($name in $Source.Keys) {
        if (-not $Target.ContainsKey($name) -and [int]$Source[$name] -gt 0) {
            $Target[$name] = [int]$Source[$name]
        }
    }
}

function Get-LootGoldBreakdown {
    param([hashtable]$LootCounts, [hashtable]$LootItemIds)

    $total = 0.0
    $pricedTypes = 0
    $unpricedTypes = 0
    $pricedQuantity = 0
    $unpricedQuantity = 0
    $unpricedNames = @()
    $unitPrices = @{}
    if (-not $LootCounts) {
        return [PSCustomObject]@{
            TotalGold = 0.0; TotalTypes = 0; PricedTypes = 0; UnpricedTypes = 0
            PricedQuantity = 0; UnpricedQuantity = 0; UnpricedNames = @(); UnitPrices = @{}
        }
    }

    foreach ($name in $LootCounts.Keys) {
        $count = [int]$LootCounts[$name]
        $itemId = if ($LootItemIds -and $LootItemIds.ContainsKey($name)) { [int]$LootItemIds[$name] } else { 0 }
        $quote = Get-ItemUnitPrice -ItemName $name -ItemId $itemId
        $unitPrice = [double]$quote.PriceGold
        if ($unitPrice -gt 0) {
            $total += $count * $unitPrice
            $pricedTypes++
            $pricedQuantity += $count
            $unitPrices[$name] = [PSCustomObject]@{ ItemId = $itemId; Gold = $unitPrice; Source = $quote.Source }
        } else {
            $unpricedTypes++
            $unpricedQuantity += $count
            $unpricedNames += "$name x$count"
        }
    }

    return [PSCustomObject]@{
        TotalGold       = $total
        TotalTypes      = $LootCounts.Count
        PricedTypes     = $pricedTypes
        UnpricedTypes   = $unpricedTypes
        PricedQuantity  = $pricedQuantity
        UnpricedQuantity = $unpricedQuantity
        UnpricedNames   = @($unpricedNames | Sort-Object)
        UnitPrices      = $unitPrices
    }
}

function Get-LootGoldTotal {
    param([hashtable]$LootCounts, [hashtable]$LootItemIds)
    return (Get-LootGoldBreakdown -LootCounts $LootCounts -LootItemIds $LootItemIds).TotalGold
}

function Get-RevenueStats {
    param([hashtable]$LootCounts, [hashtable]$LootItemIds, [double]$ActiveHours)

    $eurPerGold  = if ($Config.Revenue.GoldPerEuro -gt 0) { 1.0 / [double]$Config.Revenue.GoldPerEuro } else { 0 }
    $breakdown   = Get-LootGoldBreakdown -LootCounts $LootCounts -LootItemIds $LootItemIds
    $goldTotal   = $breakdown.TotalGold
    $goldPerHour = if ($ActiveHours -gt 0) { $goldTotal / $ActiveHours } else { 0 }
    $eurPerHour  = $goldPerHour * $eurPerGold
    $hufPerHour  = $eurPerHour * $Config.Revenue.EurToHuf
    $hufTotal    = ($goldTotal * $eurPerGold) * $Config.Revenue.EurToHuf

    return [PSCustomObject]@{
        GoldTotal     = ConvertTo-SafeNumber $goldTotal
        GoldPerHour   = ConvertTo-SafeNumber $goldPerHour
        EurPerHour    = ConvertTo-SafeNumber $eurPerHour
        HufPerHour    = ConvertTo-SafeNumber $hufPerHour
        HufTotal      = ConvertTo-SafeNumber $hufTotal
        Projection6h  = ConvertTo-SafeNumber ($hufPerHour * 6)
        Projection12h = ConvertTo-SafeNumber ($hufPerHour * 12)
        Projection24h = ConvertTo-SafeNumber ($hufPerHour * 24)
        Projection7d  = ConvertTo-SafeNumber ($hufPerHour * 24 * 7)
        TotalItemTypes = $breakdown.TotalTypes
        PricedItemTypes = $breakdown.PricedTypes
        UnpricedItemTypes = $breakdown.UnpricedTypes
        PricedQuantity = $breakdown.PricedQuantity
        UnpricedQuantity = $breakdown.UnpricedQuantity
        UnpricedNames = $breakdown.UnpricedNames
        UnitPrices = $breakdown.UnitPrices
    }
}

# ==============================================================================
# 10) TARGET ENGINE
# ==============================================================================

function Get-TargetProgress {
    param($Revenue)

    $current = $Revenue.HufTotal
    $target  = [Math]::Max($Config.Target.TargetHuf, 0)
    $remaining = [Math]::Max($target - $current, 0)
    $progressPct = if ($target -gt 0) { [Math]::Min(($current / $target) * 100, 100) } else { 0 }

    $hufPerGold = (1.0 / [Math]::Max([double]$Config.Revenue.GoldPerEuro, 0.0001)) * $Config.Revenue.EurToHuf
    $neededGold = if ($hufPerGold -gt 0) { [Math]::Ceiling($remaining / $hufPerGold) } else { 0 }
    $hufPerWyrmfish = $script:PriceCache.Price * $hufPerGold
    $neededWyrmfish = if ($hufPerWyrmfish -gt 0) { [Math]::Ceiling($remaining / $hufPerWyrmfish) } else { 0 }
    $hasEta = $Revenue.HufPerHour -gt 0
    $etaHours = if ($hasEta) { $remaining / $Revenue.HufPerHour } else { $null }

    return [PSCustomObject]@{
        Target         = $target
        Current        = $current
        Remaining      = $remaining
        ProgressPct    = ConvertTo-SafeNumber $progressPct
        NeededGold     = $neededGold
        NeededWyrmfish = $neededWyrmfish
        EtaHours       = $etaHours
        HasEta         = $hasEta
    }
}

# ==============================================================================
# 11) METRICS ENGINE
# ==============================================================================

function Update-ClientTimeAccumulators {
    param($Client, [double]$DeltaSeconds)

    # Vedelem hosszabb GUI-akadas / rendszer-alvas utan: ne adjon hozza irrealis idot.
    $DeltaSeconds = [Math]::Min([Math]::Max($DeltaSeconds, 0), 5.0)
    if ($DeltaSeconds -le 0) { return }

    if (-not (Test-ClientAutomationEnabled -Client $Client)) {
        $Client.PausedTimeSeconds += $DeltaSeconds
    } elseif ($Client.NeedsManualHelp -or $Client.IsRecovering -or -not $Client.ProcessAlive) {
        $Client.PausedTimeSeconds += $DeltaSeconds
    } elseif ($Client.IsSyncing) {
        $Client.ReloadTimeSeconds += $DeltaSeconds
    } else {
        $Client.ActiveTimeSeconds += $DeltaSeconds
    }
}

function Get-ClientMetrics {
    param($Client)

    $activeHours = $Client.ActiveTimeSeconds / 3600.0
    $fishPerHour = if ($activeHours -gt 0) { $Client.HookCount / $activeHours } else { 0 }
    $wyrmCount = 0
    if ($Client.FishCounts.ContainsKey($Config.Loot.HighlightFishName)) {
        $wyrmCount = $Client.FishCounts[$Config.Loot.HighlightFishName]
    }
    $wyrmPerHour = if ($activeHours -gt 0) { $wyrmCount / $activeHours } else { 0 }

    return [PSCustomObject]@{
        ActiveHours     = $activeHours
        FishPerHour     = ConvertTo-SafeNumber $fishPerHour
        WyrmfishCount   = $wyrmCount
        WyrmfishPerHour = ConvertTo-SafeNumber $wyrmPerHour
    }
}

# ==============================================================================
# 12) ANOMALY DETECTOR (a GUI-refresh temposaval fut)
# ==============================================================================

function Add-Alert {
    param([uint32]$TargetPid, [string]$Severity, [string]$Reason)

    $entry = [PSCustomObject]@{
        Timestamp = Get-Date
        PID       = $TargetPid
        Severity  = $Severity
        Reason    = $Reason
    }
    $script:Alerts.Add($entry) | Out-Null
    if ($script:Alerts.Count -gt $Config.Gui.AlertHistoryLimit) {
        $script:Alerts.RemoveRange(0, $script:Alerts.Count - $Config.Gui.AlertHistoryLimit)
    }
}

function Test-ClientAnomalies {
    param($Client, [datetime]$Now, [double]$AvgFishPerHour)

    $Client.ProcessAlive = Test-ClientProcess -Client $Client

    $newStatus = "OK"
    $reason = ""

    if (-not $Client.ProcessAlive) {
        $newStatus = "ERROR"; $reason = "WoW process eltunt"
    }
    elseif ($Client.ContainsKey("ControlState") -and $Client.ControlState -eq "STOPPED") {
        $newStatus = "STOPPED"; $reason = "Felhasznalo altal leallitva"
    }
    elseif ($Client.ContainsKey("ControlState") -and $Client.ControlState -eq "PAUSED") {
        $newStatus = "PAUSED"; $reason = "Felhasznalo altal szuneteltetve"
    }
    elseif ($Client.NeedsManualHelp) {
        $newStatus = "MANUAL"; $reason = if ($Client.RecoveryReason) { $Client.RecoveryReason } else { "Kezi beavatkozas szukseges" }
    }
    elseif ($Client.IsRecovering) {
        $newStatus = "WARNING"; $reason = "Reconnect: $($Client.RecoveryState), probalkozas $($Client.RecoveryAttempt)/$($Config.Recovery.MaxAttempts)"
    }
    elseif ($Config.Recovery.Enabled -and $Client.NetworkTelemetryAvailable -eq $false) {
        $newStatus = "WARNING"; $reason = "Hálózati telemetria nem elerheto - auto reconnect tiltva"
    }
    elseif ($Config.Recovery.Enabled -and $Client.NetworkBaseline.Count -eq 0 -and
            (($Now - $Client.NetworkLearnStarted).TotalSeconds -ge $Config.Recovery.NetworkLearnTimeoutSeconds)) {
        $newStatus = "WARNING"; $reason = "Szerverkapcsolat nem tanulhato meg - auto reconnect tiltva"
    }
    elseif ($Config.Loot.Enabled -and $Client.LootReloadState -eq "BindFailed") {
        $newStatus = "WARNING"; $reason = "Loot fajl automatikus parositasa sikertelen"
    }
    elseif ($Config.Loot.Enabled -and ($Client.LootLastMessage -like "Addon adat ures*" -or
            $Client.LootLastMessage -like "Regi addon*")) {
        $newStatus = "WARNING"; $reason = $Client.LootLastMessage
    }
    elseif ($Config.Loot.Enabled -and $Client.FirstUnsyncedCatchAt -and
            (($Now - $Client.FirstUnsyncedCatchAt).TotalMinutes -ge ($Config.Loot.MaxUnsyncedMinutes + 2))) {
        $newStatus = "WARNING"; $reason = "Loot sync kesik: $($Client.HookCount - $Client.LastLootSyncHookCount) fogasi esemeny fuggoben"
    }
    elseif (($Now - $Client.LastActivity).TotalMinutes -ge $Config.General.NoCatchWarningMinutes) {
        $newStatus = "WARNING"; $reason = "Nincs fogas $($Config.General.NoCatchWarningMinutes) perce"
    }
    else {
        $metrics = Get-ClientMetrics -Client $Client
        if ($metrics.ActiveHours -ge 0.15 -and $AvgFishPerHour -gt 0 -and
            $metrics.FishPerHour -lt ($AvgFishPerHour * ($Config.General.FishRateDropThresholdPct / 100.0))) {
            $newStatus = "WARNING"; $reason = "Fish/hour az atlag alatt"
        }
        elseif ($Config.Loot.Enabled -and $Client.LastSavedVarUpdate -and
                ($Now - $Client.LastSavedVarUpdate).TotalMinutes -ge 60) {
            $newStatus = "WARNING"; $reason = "Loot adat nem frissult 60 perce"
        }
    }

    $prevStatus = $Client.Status
    $Client.Status = $newStatus
    $Client.StatusReason = $reason

    if ($newStatus -ne $prevStatus) {
        if ($newStatus -eq "OK") {
            Write-Log -Level INFO -Message "[$($Client.PID)] Allapot helyreallt: OK"
        }
        elseif ($newStatus -eq "WARNING" -and $prevStatus -eq "OK") {
            Add-Alert -TargetPid $Client.PID -Severity "WARNING" -Reason $reason
            Send-ClientWarningEvent -Client $Client
            Write-Log -Level WARNING -Message "[$($Client.PID)] $reason"
        }
        elseif ($newStatus -eq "ERROR" -or $newStatus -eq "MANUAL") {
            Add-Alert -TargetPid $Client.PID -Severity $newStatus -Reason $reason
            Send-ClientErrorEvent -Client $Client
            Write-Log -Level ERROR -Message "[$($Client.PID)] $reason"
        }
    }
}

$script:Alerts = New-Object System.Collections.Generic.List[object]

# ==============================================================================
# 13) NOTIFICATION ENGINE (Discord, throttle-va)
# ==============================================================================

$script:NotifyThrottle = @{}

function Send-DiscordMessage {
    param([string]$Msg)
    if (-not $Config.Notification.Enabled -or -not $Config.Notification.DiscordWebhook) { return }
    try {
        $headers = @{ "Content-Type" = "application/json" }
        $body = @{ content = $Msg } | ConvertTo-Json
        Invoke-RestMethod -Uri $Config.Notification.DiscordWebhook -Method POST -Headers $headers -Body $body `
            -TimeoutSec $Config.Notification.TimeoutSeconds | Out-Null
    } catch {
        Write-LogException -Context "Discord kuldes" -ErrorRecord $_
    }
}

function Send-ThrottledNotification {
    param([string]$Key, [string]$Message)
    $last = $script:NotifyThrottle[$Key]
    if ($last -and ((Get-Date) - $last).TotalMinutes -lt $Config.Notification.ThrottleMinutes) { return }
    Send-DiscordMessage -Msg $Message
    $script:NotifyThrottle[$Key] = Get-Date
}

function Send-SessionStartedEvent {
    if ($Config.Notification.OnStart) {
        Send-DiscordMessage -Msg "**AI-FishBot Monitor v2.8** Session inditva ($script:SessionId) - $($script:Clients.Count) kliens."
    }
}
function Send-SessionStoppedEvent {
    param([string]$Summary)
    if ($Config.Notification.OnStop) {
        Send-DiscordMessage -Msg "**AI-FishBot Monitor v2.8** Session vege ($script:SessionId).`n$Summary"
    }
}
function Send-ClientWarningEvent {
    param($Client)
    Send-ThrottledNotification -Key "warn-$($Client.PID)" -Message "**AI-FishBot Monitor v2.8** [$($Client.PID)] WARNING: $($Client.StatusReason)"
}
function Send-ClientErrorEvent {
    param($Client)
    Send-ThrottledNotification -Key "err-$($Client.PID)" -Message "**AI-FishBot Monitor v2.8** [$($Client.PID)] $($Client.Status): $($Client.StatusReason)"
}
function Send-TargetReachedEvent {
    Send-ThrottledNotification -Key "target-reached" -Message "**AI-FishBot Monitor v2.8** CEL ELERVE! ($($Config.Target.TargetHuf) Ft)"
}

# ==============================================================================
# 14) SESSION / REPORT ENGINE
# ==============================================================================

$script:SessionStartTime    = Get-Date
$script:MonitoringStartTime = $null
$script:CsvPath             = Join-Path $Config.Logging.Directory ("session_{0}.csv" -f $script:SessionId)
$script:JsonPath            = Join-Path $Config.Logging.Directory ("session_{0}.json" -f $script:SessionId)
$script:LastReportTime      = Get-Date

function Add-ReportSnapshot {
    param([datetime]$Now)
    try {
        $snapshotRows = @()
        foreach ($clientPid in $script:Clients.Keys) {
            $client = $script:Clients[$clientPid]
            $metrics = Get-ClientMetrics -Client $client
            $revenue = Get-RevenueStats -LootCounts $client.FishCounts -LootItemIds $client.FishItemIds -ActiveHours $metrics.ActiveHours

            $snapshotRows += [PSCustomObject]@{
                Timestamp       = $Now
                Client          = $clientPid
                ControlState    = if ($client.ContainsKey("ControlState")) { $client.ControlState } else { "RUNNING" }
                NetworkConnected = $client.NetworkConnected
                RecoveryState   = $client.RecoveryState
                RecoveryAttempt = $client.RecoveryAttempt
                LootSyncState   = $client.LootReloadState
                LootAddonVersion = $client.LootAddonVersion
                PendingLootHooks = [Math]::Max($client.HookCount - $client.LastLootSyncHookCount, 0)
                SyncedLootItems = $client.LastLootItemTotal
                LastLootSync    = $client.LastSavedVarUpdate
                Fish            = $client.HookCount
                Wyrmfish        = $metrics.WyrmfishCount
                FishPerHour     = [Math]::Round($metrics.FishPerHour, 2)
                WyrmfishPerHour = [Math]::Round($metrics.WyrmfishPerHour, 2)
                Price           = $script:PriceCache.Price
                PriceSource     = $script:PriceCache.Source
                BlizzardStatus  = $script:BlizzardPriceState.Status
                BlizzardConnectedRealmId = $script:BlizzardPriceState.ConnectedRealmId
                BlizzardLastUpdated = $script:BlizzardPriceState.LastUpdated
                LootGoldTotal   = [Math]::Round($revenue.GoldTotal, 2)
                GoldPerHour     = [Math]::Round($revenue.GoldPerHour, 2)
                EurPerHour      = [Math]::Round($revenue.EurPerHour, 2)
                HufPerHour      = [Math]::Round($revenue.HufPerHour, 2)
                PricedItemTypes = $revenue.PricedItemTypes
                UnpricedItemTypes = $revenue.UnpricedItemTypes
                UnpricedItems   = ($revenue.UnpricedNames -join "; ")
                LootCountsJson  = ($client.FishCounts | ConvertTo-Json -Compress)
                LootItemIdsJson = ($client.FishItemIds | ConvertTo-Json -Compress)
                UnitPricesJson  = ($revenue.UnitPrices | ConvertTo-Json -Compress -Depth 4)
            }
        }
        if ($snapshotRows.Count -gt 0) {
            if (Test-Path -LiteralPath $script:CsvPath) {
                $snapshotRows | Export-Csv -LiteralPath $script:CsvPath -NoTypeInformation -Append -Encoding UTF8
            } else {
                $snapshotRows | Export-Csv -LiteralPath $script:CsvPath -NoTypeInformation -Encoding UTF8
            }
        }
    } catch {
        Write-LogException -Context "Add-ReportSnapshot" -ErrorRecord $_
    }
}

function Export-SessionJsonSummary {
    try {
        $totalFish = 0
        $totalWyrm = 0
        $totalLootCounts = @{}
        $totalLootItemIds = @{}
        foreach ($client in $script:Clients.Values) {
            $totalFish += $client.HookCount
            Add-LootCounts -Target $totalLootCounts -Source $client.FishCounts
            Add-LootItemIds -Target $totalLootItemIds -Source $client.FishItemIds
            if ($client.FishCounts.ContainsKey($Config.Loot.HighlightFishName)) {
                $totalWyrm += $client.FishCounts[$Config.Loot.HighlightFishName]
            }
        }
        $activeHoursTotal = (($script:Clients.Values | ForEach-Object { $_.ActiveTimeSeconds }) | Measure-Object -Sum).Sum / 3600.0
        $revenue = Get-RevenueStats -LootCounts $totalLootCounts -LootItemIds $totalLootItemIds -ActiveHours $activeHoursTotal

        $summary = [PSCustomObject]@{
            SessionId       = $script:SessionId
            SessionStart    = $script:SessionStartTime
            SessionEnd      = Get-Date
            ClientCount     = $script:Clients.Count
            TotalFish       = $totalFish
            TotalWyrmfish   = $totalWyrm
            WyrmfishPerHour = if ($activeHoursTotal -gt 0) { [Math]::Round($totalWyrm / $activeHoursTotal, 2) } else { 0 }
            Price           = $script:PriceCache.Price
            PriceSource     = $script:PriceCache.Source
            BlizzardStatus  = $script:BlizzardPriceState.Status
            BlizzardConnectedRealmId = $script:BlizzardPriceState.ConnectedRealmId
            BlizzardLastUpdated = $script:BlizzardPriceState.LastUpdated
            BlizzardLastError = $script:BlizzardPriceState.LastError
            TotalLoot       = $totalLootCounts
            LootItemIds     = $totalLootItemIds
            UnitPrices      = $revenue.UnitPrices
            PricedItemTypes = $revenue.PricedItemTypes
            UnpricedItemTypes = $revenue.UnpricedItemTypes
            UnpricedItems   = $revenue.UnpricedNames
            RevenueGold     = [Math]::Round($revenue.GoldTotal, 2)
            RevenueHuf      = [Math]::Round($revenue.HufTotal, 0)
            ClientStates    = @($script:Clients.Values | ForEach-Object {
                [PSCustomObject]@{
                    PID = $_.PID
                    ControlState = if ($_.ContainsKey("ControlState")) { $_.ControlState } else { "RUNNING" }
                    NetworkConnected = $_.NetworkConnected
                    RecoveryState = $_.RecoveryState
                    RecoveryAttempt = $_.RecoveryAttempt
                    RecoveryReason = $_.RecoveryReason
                    LootSyncState = $_.LootReloadState
                    LootAddonVersion = $_.LootAddonVersion
                    PendingLootHooks = [Math]::Max($_.HookCount - $_.LastLootSyncHookCount, 0)
                    SyncedLootItems = $_.LastLootItemTotal
                    LootLastMessage = $_.LootLastMessage
                }
            })
            Warnings        = @($script:Alerts | ForEach-Object { "$($_.Timestamp) [$($_.Severity)] [$($_.PID)] $($_.Reason)" })
        }

        $summary | ConvertTo-Json -Depth 6 | Out-File -FilePath $script:JsonPath -Force -Encoding UTF8
        return $summary
    } catch {
        Write-LogException -Context "Export-SessionJsonSummary" -ErrorRecord $_
        return [PSCustomObject]@{ TotalFish = 0; TotalWyrmfish = 0; RevenueHuf = 0 }
    }
}

# ==============================================================================
# 15) MONITOR ENGINE (gyors tick)
# ==============================================================================

$script:LastMonitorTick = $null
$script:MonitorBusy     = $false
$script:NextAudioPoll   = Get-Date

function Invoke-MonitorTick {
    if ($script:MonitorBusy) { return "OK" }
    $script:MonitorBusy = $true

    try {
        $now = Get-Date
        if (-not $script:LastMonitorTick) { $script:LastMonitorTick = $now }
        $delta = ($now - $script:LastMonitorTick).TotalSeconds
        $script:LastMonitorTick = $now

        $activePids = @($script:Clients.Keys)
        try { Update-NetworkTelemetry -Pids $activePids -Now $now }
        catch { Write-LogException -Context "Network telemetry" -ErrorRecord $_ }

        foreach ($clientPid in $activePids) {
            $client = $script:Clients[$clientPid]
            try {
                Update-ClientTimeAccumulators -Client $client -DeltaSeconds $delta

                if (-not (Test-ClientProcess -Client $client)) {
                    $client.ProcessAlive = $false
                    if ($script:RecoveryOwnerPid -eq $client.PID) { $script:RecoveryOwnerPid = $null }
                    continue
                }
                $client.ProcessAlive = $true

                # PAUSE/STOP eseten a kapcsolatot tovabbra is latjuk, de ehhez
                # a PID-hez sem fishing, sem reload, sem recovery input nem mehet.
                if (-not (Test-ClientAutomationEnabled -Client $client)) { continue }

                # --- adaptiv reconnect: a halozati allapot minden lepes utan visszacsatol ---
                Update-ClientRecoveryState -Client $client -Now $now
                if ($client.NeedsManualHelp -or $client.IsRecovering) { continue }

                # --- loot reload allapotgep ---
                Update-LootReloadState -Client $client -Now $now
                if ($client.IsSyncing) { continue }

                # --- buffok ---
                Update-ClientBuffs -Client $client -Now $now

                # --- fazis-allapotgep ---
                if ($now -ge $client.NextActionTime) {
                    switch ($client.Phase) {

                        "NeedCast" {
                            if ($Config.General.UseWeakAura) {
                                # WeakAura mod: retry-logika egy klienesen belul marad, de
                                # mindig max 1 dobas/tick (nincs blokkolo while+Sleep tobbszor).
                                if ($client.RangeCount -ge $Config.General.FishingRetries) {
                                    Write-Log -Level WARNING -Message "[$clientPid] $($Config.General.FishingRetries) sikertelen dobas - kihagyva ebben a korben"
                                    $client.RangeCount = 0
                                    $client.NextActionTime = $now.AddSeconds(3)
                                } else {
                                    $queued = Queue-Input -TargetPid $clientPid -Type "Cast" -Priority $script:InputPriority.Cast
                                    if ($queued) {
                                        $client.RangeCount++
                                        $client.RestartTotal++
                                        $client.NextActionTime = $now.AddMilliseconds((Get-Random -Minimum 1000 -Maximum 1500))
                                    }
                                }
                            } else {
                                Queue-Input -TargetPid $clientPid -Type "Cast" -Priority $script:InputPriority.Cast | Out-Null
                                # Complete-Input allitja at AwaitingBite-ra siker eseten; addig
                                # a dedup megvedi a tobbszoros queue-olastol.
                            }
                        }

                        "AwaitingBite" {
                            if ($now -gt $client.CastDeadline) {
                                $client.Phase = "NeedCast"
                                $client.NextActionTime = $now
                                $client.RangeCount = 0
                                $client.NoBiteStreak++

                                if ($client.NoBiteStreak -eq $Config.General.NoBiteStreakLimit) {
                                    if ($client.NetworkConnected -eq $true) {
                                        Write-Log -Level WARNING -Message "[$clientPid] $($client.NoBiteStreak) kapás kimaradt, de a szerverkapcsolat el - reconnect nem indul"
                                    } elseif ($client.NetworkBaseline.Count -eq 0 -and -not $Config.Recovery.FallbackToNoBiteOnly) {
                                        Write-Log -Level WARNING -Message "[$clientPid] Kapasok kimaradtak, de nincs megtanult kapcsolat - automatikus jelszobeiras tiltva"
                                    }
                                }
                            }
                        }

                        "ClickBobber" {
                            Queue-Input -TargetPid $clientPid -Type "Bobber" -Priority $script:InputPriority.Bobber | Out-Null
                        }

                        "PostCatch" {
                            $client.Phase = "NeedCast"
                            $client.NextActionTime = $now
                        }

                        default {
                            Write-Log -Level WARNING -Message "[$clientPid] Ismeretlen fazis: $($client.Phase) - visszaallitas NeedCast-ra"
                            $client.Phase = "NeedCast"
                            $client.NextActionTime = $now
                        }
                    }
                }
            } catch {
                Write-LogException -Context "[$clientPid] Client tick" -ErrorRecord $_
                # Egy kliens hibaja ne allitsa le a tobbit - folytatjuk a kovetkezovel.
            }
        }

        # --- kozos harapas-lekerdezes az osszes varakozo kliensre egyszerre ---
        try {
            $awaitingPids = @($activePids | Where-Object {
                $c = $script:Clients[$_]
                (Test-ClientAutomationEnabled -Client $c) -and
                (-not $c.NeedsManualHelp) -and (-not $c.IsRecovering) -and
                (-not $c.IsSyncing) -and $c.ProcessAlive -and $c.Phase -eq "AwaitingBite" -and
                $now -ge $c.NextActionTime -and $now -le $c.CastDeadline
            })
            if ($awaitingPids.Count -gt 0 -and $now -ge $script:NextAudioPoll) {
                $script:NextAudioPoll = $now.AddMilliseconds($Config.Audio.PollIntervalMs)
                $peaks = Get-ClientAudioPeaks -Pids $awaitingPids
                $threshold = $Config.Audio.Sensitivity * 10
                foreach ($clientPid in $awaitingPids) {
                    if ($peaks.ContainsKey($clientPid) -and $peaks[$clientPid] -ge $threshold) {
                        $script:Clients[$clientPid].Phase = "ClickBobber"
                    }
                }
            }
        } catch {
            Write-LogException -Context "Audio poll" -ErrorRecord $_
        }

        # --- input queue feldolgozas: max 1 elem/tick ---
        try { Process-InputQueue } catch { Write-LogException -Context "Process-InputQueue" -ErrorRecord $_ }

        if ($Config.General.AutoStop -and
            (($now - $script:SessionStartTime).TotalMinutes -ge $Config.General.AutoStopMinutes)) {
            return "AUTOSTOP"
        }
        return "OK"
    } finally {
        $script:MonitorBusy = $false
    }
}

# ==============================================================================
# 16) GUI ENGINE
# ==============================================================================

function New-InfoLabel {
    param($Parent, [ref]$Y, [string]$Text, [int]$X = 15)
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Text
    $lbl.AutoSize = $true
    $lbl.Location = New-Object System.Drawing.Point($X, $Y.Value)
    $lbl.Font = New-Object System.Drawing.Font("Consolas", 9)
    $Parent.Controls.Add($lbl)
    $Y.Value += 20
    return $lbl
}

function Update-ControlButtons {
    if (-not $script:GuiControls) { return }
    $pid = $script:SelectedClientPid
    $client = if ($pid) { $script:Clients[$pid] } else { $null }
    if (-not $client) {
        $script:GuiControls.StartButton.Enabled = $false
        $script:GuiControls.PauseButton.Enabled = $false
        $script:GuiControls.StopButton.Enabled = $false
        return
    }
    $state = if ($client.ContainsKey("ControlState")) { [string]$client.ControlState } else { "RUNNING" }
    $script:GuiControls.StartButton.Enabled = ($state -ne "RUNNING")
    $script:GuiControls.PauseButton.Enabled = ($state -eq "RUNNING")
    $script:GuiControls.StopButton.Enabled = ($state -ne "STOPPED")
}

function Build-MainForm {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "AI-FishBot Monitor v2.8 - PID vezerles es AH eladasi tanacsado"
    $form.Size = New-Object System.Drawing.Size(1500, 950)
    $form.MinimumSize = New-Object System.Drawing.Size(1100, 820)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "Sizable"
    $form.MaximizeBox = $true

    $headerBox = New-Object System.Windows.Forms.GroupBox
    $headerBox.Text = "AI-FishBot Monitor v2.8 - valassz PID sort, majd START / PAUSE / STOP"
    $headerBox.Location = New-Object System.Drawing.Point(10, 10)
    $headerBox.Size = New-Object System.Drawing.Size(1460, 70)
    $headerBox.Anchor = "Top,Left,Right"
    $form.Controls.Add($headerBox)
    $y = [ref]20
    $lblRuntime = New-InfoLabel -Parent $headerBox -Y $y -Text "Runtime: 00:00:00"
    $lblClients = New-InfoLabel -Parent $headerBox -Y $y -Text "Clients: 0"
    $lblStatus  = New-InfoLabel -Parent $headerBox -Y $y -Text "Status: RUNNING"
    $lblQueue   = New-Object System.Windows.Forms.Label
    $lblQueue.Text = "Input Queue: 0 | Busy: NO"
    $lblQueue.AutoSize = $true
    $lblQueue.Location = New-Object System.Drawing.Point(300, 20)
    $lblQueue.Font = New-Object System.Drawing.Font("Consolas", 9)
    $headerBox.Controls.Add($lblQueue)

    $lblSelectedPid = New-Object System.Windows.Forms.Label
    $lblSelectedPid.Text = "Kivalasztott PID: nincs"
    $lblSelectedPid.AutoSize = $true
    $lblSelectedPid.Location = New-Object System.Drawing.Point(600, 22)
    $lblSelectedPid.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
    $headerBox.Controls.Add($lblSelectedPid)

    $btnStart = New-Object System.Windows.Forms.Button
    $btnStart.Text = "START"
    $btnStart.Size = New-Object System.Drawing.Size(95, 30)
    $btnStart.Location = New-Object System.Drawing.Point(1080, 20)
    $btnStart.Anchor = "Top,Right"
    $btnStart.BackColor = [System.Drawing.Color]::LightGreen
    $headerBox.Controls.Add($btnStart)
    $btnPause = New-Object System.Windows.Forms.Button
    $btnPause.Text = "PAUSE"
    $btnPause.Size = New-Object System.Drawing.Size(95, 30)
    $btnPause.Location = New-Object System.Drawing.Point(1180, 20)
    $btnPause.Anchor = "Top,Right"
    $btnPause.BackColor = [System.Drawing.Color]::LightYellow
    $headerBox.Controls.Add($btnPause)
    $btnStop = New-Object System.Windows.Forms.Button
    $btnStop.Text = "STOP"
    $btnStop.Size = New-Object System.Drawing.Size(95, 30)
    $btnStop.Location = New-Object System.Drawing.Point(1280, 20)
    $btnStop.Anchor = "Top,Right"
    $btnStop.BackColor = [System.Drawing.Color]::MistyRose
    $headerBox.Controls.Add($btnStop)
    $btnStart.Enabled = $false
    $btnPause.Enabled = $false
    $btnStop.Enabled = $false

    $statsLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $statsLayout.Location = New-Object System.Drawing.Point(10, 90)
    $statsLayout.Size = New-Object System.Drawing.Size(1460, 330)
    $statsLayout.Anchor = "Top,Left,Right"
    $statsLayout.ColumnCount = 3
    $statsLayout.RowCount = 2
    [void]$statsLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 33)))
    [void]$statsLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 34)))
    [void]$statsLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 33)))
    [void]$statsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 52)))
    [void]$statsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 48)))
    $form.Controls.Add($statsLayout)

    $totalBox = New-Object System.Windows.Forms.GroupBox
    $totalBox.Text = "Total Statistics"
    $totalBox.Dock = "Fill"
    $statsLayout.Controls.Add($totalBox, 0, 0)
    $y = [ref]20
    $lblTotalFish   = New-InfoLabel -Parent $totalBox -Y $y -Text "Total Fish: 0"
    $lblTotalWyrm   = New-InfoLabel -Parent $totalBox -Y $y -Text "Total Wyrmfish: 0"
    $lblFishPerHour = New-InfoLabel -Parent $totalBox -Y $y -Text "Fish/hour: 0"
    $lblWyrmPerHour = New-InfoLabel -Parent $totalBox -Y $y -Text "Wyrmfish/hour: 0"
    $lblGoldPerHour = New-InfoLabel -Parent $totalBox -Y $y -Text "Gold/hour: 0"
    $lblEurPerHour  = New-InfoLabel -Parent $totalBox -Y $y -Text "EUR/hour: 0"
    $lblHufPerHour  = New-InfoLabel -Parent $totalBox -Y $y -Text "HUF/hour: 0"

    $priceBox = New-Object System.Windows.Forms.GroupBox
    $priceBox.Text = "Osszes fogas / arak"
    $priceBox.Dock = "Fill"
    $statsLayout.Controls.Add($priceBox, 1, 0)
    $y = [ref]20
    $lblPrice        = New-InfoLabel -Parent $priceBox -Y $y -Text "Arazva: 0/0 fajta"
    $lblPriceSource  = New-InfoLabel -Parent $priceBox -Y $y -Text "Arforras: -"
    $lblTotalValue   = New-InfoLabel -Parent $priceBox -Y $y -Text "Total value: -"
    $lblProj6h       = New-InfoLabel -Parent $priceBox -Y $y -Text "6h projection: -"
    $lblProj24h      = New-InfoLabel -Parent $priceBox -Y $y -Text "24h projection: -"
    $lblProj7d       = New-InfoLabel -Parent $priceBox -Y $y -Text "7d projection: -"
    $lblPriceUpdated = New-InfoLabel -Parent $priceBox -Y $y -Text "Last updated: -"

    $targetBox = New-Object System.Windows.Forms.GroupBox
    $targetBox.Text = "Target"
    $targetBox.Dock = "Fill"
    $statsLayout.Controls.Add($targetBox, 0, 1)
    $y = [ref]20
    $lblTargetVal  = New-InfoLabel -Parent $targetBox -Y $y -Text ("TARGET: {0} Ft" -f $Config.Target.TargetHuf)
    $lblTargetCur  = New-InfoLabel -Parent $targetBox -Y $y -Text "CURRENT: 0 Ft"
    $lblTargetRem  = New-InfoLabel -Parent $targetBox -Y $y -Text "REMAINING: 0 Ft"
    $lblTargetNeed = New-InfoLabel -Parent $targetBox -Y $y -Text "NEEDED VALUE: 0 gold"
    $lblTargetEta  = New-InfoLabel -Parent $targetBox -Y $y -Text "ETA: --"
    $targetBar = New-Object System.Windows.Forms.ProgressBar
    $targetBar.Location = New-Object System.Drawing.Point(15, $y.Value)
    $targetBar.Size = New-Object System.Drawing.Size(450, 20)
    $targetBar.Minimum = 0
    $targetBar.Maximum = 100
    $targetBox.Controls.Add($targetBar)

    $sessionBox = New-Object System.Windows.Forms.GroupBox
    $sessionBox.Text = "Session"
    $sessionBox.Dock = "Fill"
    $statsLayout.Controls.Add($sessionBox, 1, 1)
    $y = [ref]20
    $lblSessStart      = New-InfoLabel -Parent $sessionBox -Y $y -Text "Session start: -"
    $lblSessMonStart   = New-InfoLabel -Parent $sessionBox -Y $y -Text "Monitoring start: -"
    $lblSessActive     = New-InfoLabel -Parent $sessionBox -Y $y -Text "Active time: -"
    $lblSessPaused     = New-InfoLabel -Parent $sessionBox -Y $y -Text "Paused time: -"
    $lblSessReload     = New-InfoLabel -Parent $sessionBox -Y $y -Text "Reload/maintenance time: -"
    $lblSessUpdate     = New-InfoLabel -Parent $sessionBox -Y $y -Text "Last update: -"

    $sellBox = New-Object System.Windows.Forms.GroupBox
    $sellBox.Text = "Kijelolt item - arhistorika es eladasi jelzes"
    $sellBox.Dock = "Fill"
    $statsLayout.Controls.Add($sellBox, 2, 0)
    $statsLayout.SetRowSpan($sellBox, 2)
    $y = [ref]22
    $lblSellItem       = New-InfoLabel -Parent $sellBox -Y $y -Text "Item: valassz az also listabol"
    $lblSellCount      = New-InfoLabel -Parent $sellBox -Y $y -Text "Mennyiseg / ID: -"
    $lblSellCurrent    = New-InfoLabel -Parent $sellBox -Y $y -Text "Aktualis ar: -"
    $lblSellRange      = New-InfoLabel -Parent $sellBox -Y $y -Text "Historikus min / max: -"
    $lblSellAverage    = New-InfoLabel -Parent $sellBox -Y $y -Text "Atlag / felso 25% kuszob: -"
    $lblSellBestDay    = New-InfoLabel -Parent $sellBox -Y $y -Text "Altalaban legjobb nap: -"
    $lblSellWindow     = New-InfoLabel -Parent $sellBox -Y $y -Text "Kovetkezo eladasi ablak: -"
    $lblSellSamples    = New-InfoLabel -Parent $sellBox -Y $y -Text "Mintak: -"
    $lblSellSignal     = New-InfoLabel -Parent $sellBox -Y $y -Text "JELZES: ADATGYUJTES"
    $lblSellSignal.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
    $lblSellNote = New-Object System.Windows.Forms.Label
    $lblSellNote.Text = "A becsles sajat Blizzard AH mintakbol tanul; nem garantalt eladasi ar."
    $lblSellNote.AutoSize = $true
    $lblSellNote.Location = New-Object System.Drawing.Point(15, 245)
    $lblSellNote.ForeColor = [System.Drawing.Color]::DimGray
    $sellBox.Controls.Add($lblSellNote)

    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Location = New-Object System.Drawing.Point(10, 430)
    $grid.Size = New-Object System.Drawing.Size(1460, 210)
    $grid.Anchor = "Top,Left,Right"
    $grid.ReadOnly = $true
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.RowHeadersVisible = $false
    $grid.AutoSizeColumnsMode = "Fill"
    $grid.SelectionMode = "FullRowSelect"
    $grid.MultiSelect = $false
    [void]$grid.Columns.Add("Client", "PID")
    [void]$grid.Columns.Add("Control", "Vezerles")
    [void]$grid.Columns.Add("Keys", "Dobas/Kapas")
    [void]$grid.Columns.Add("Status", "Status")
    [void]$grid.Columns.Add("Network", "Kapcsolat")
    [void]$grid.Columns.Add("Recovery", "Recovery")
    [void]$grid.Columns.Add("Reason", "Reason")
    [void]$grid.Columns.Add("Fish", "Fish")
    [void]$grid.Columns.Add("Wyrm", "Wyrmfish")
    [void]$grid.Columns.Add("LootSync", "Loot sync")
    [void]$grid.Columns.Add("FishHour", "Fish/h")
    [void]$grid.Columns.Add("WyrmHour", "Wyrm/h")
    [void]$grid.Columns.Add("RevenueHour", "HUF/h")
    [void]$grid.Columns.Add("ActiveTime", "Active time")
    [void]$grid.Columns.Add("LastActivity", "Last activity")
    [void]$grid.Columns.Add("InputPending", "Input")
    $form.Controls.Add($grid)

    $bottomTabs = New-Object System.Windows.Forms.TabControl
    $bottomTabs.Location = New-Object System.Drawing.Point(10, 650)
    $bottomTabs.Size = New-Object System.Drawing.Size(1460, 250)
    $bottomTabs.Anchor = "Top,Bottom,Left,Right"
    $form.Controls.Add($bottomTabs)

    $itemTab = New-Object System.Windows.Forms.TabPage
    $itemTab.Text = "Fogott itemek - kattints egy sorra"
    $bottomTabs.TabPages.Add($itemTab)
    $itemGrid = New-Object System.Windows.Forms.DataGridView
    $itemGrid.Dock = "Fill"
    $itemGrid.ReadOnly = $true
    $itemGrid.AllowUserToAddRows = $false
    $itemGrid.AllowUserToDeleteRows = $false
    $itemGrid.RowHeadersVisible = $false
    $itemGrid.SelectionMode = "FullRowSelect"
    $itemGrid.MultiSelect = $false
    $itemGrid.AutoSizeColumnsMode = "Fill"
    [void]$itemGrid.Columns.Add("ItemName", "Item")
    [void]$itemGrid.Columns.Add("ItemId", "ID")
    [void]$itemGrid.Columns.Add("Quantity", "Db")
    [void]$itemGrid.Columns.Add("Current", "Aktualis ar")
    [void]$itemGrid.Columns.Add("HistoryMin", "Hist. min")
    [void]$itemGrid.Columns.Add("HistoryMax", "Hist. max")
    [void]$itemGrid.Columns.Add("HistoryAverage", "Hist. atlag")
    [void]$itemGrid.Columns.Add("BestDay", "Legjobb nap")
    [void]$itemGrid.Columns.Add("SellSignal", "Eladasi jelzes")
    $itemTab.Controls.Add($itemGrid)

    $blizzardTab = New-Object System.Windows.Forms.TabPage
    $blizzardTab.Text = "Blizzard API"
    $bottomTabs.TabPages.Add($blizzardTab)

    $lblBlizzardId = New-Object System.Windows.Forms.Label
    $lblBlizzardId.Text = "Client ID:"
    $lblBlizzardId.Location = New-Object System.Drawing.Point(18, 24)
    $lblBlizzardId.AutoSize = $true
    $blizzardTab.Controls.Add($lblBlizzardId)
    $txtBlizzardId = New-Object System.Windows.Forms.TextBox
    $txtBlizzardId.Location = New-Object System.Drawing.Point(120, 20)
    $txtBlizzardId.Size = New-Object System.Drawing.Size(520, 25)
    $txtBlizzardId.Text = [string]$script:BlizzardClientId
    $blizzardTab.Controls.Add($txtBlizzardId)

    $lblBlizzardSecret = New-Object System.Windows.Forms.Label
    $lblBlizzardSecret.Text = "Client Secret:"
    $lblBlizzardSecret.Location = New-Object System.Drawing.Point(18, 64)
    $lblBlizzardSecret.AutoSize = $true
    $blizzardTab.Controls.Add($lblBlizzardSecret)
    $txtBlizzardSecret = New-Object System.Windows.Forms.TextBox
    $txtBlizzardSecret.Location = New-Object System.Drawing.Point(120, 60)
    $txtBlizzardSecret.Size = New-Object System.Drawing.Size(520, 25)
    $txtBlizzardSecret.UseSystemPasswordChar = $true
    $txtBlizzardSecret.Text = [string]$script:BlizzardClientSecret
    $blizzardTab.Controls.Add($txtBlizzardSecret)

    $chkShowSecret = New-Object System.Windows.Forms.CheckBox
    $chkShowSecret.Text = "Secret mutatasa"
    $chkShowSecret.Location = New-Object System.Drawing.Point(660, 62)
    $chkShowSecret.AutoSize = $true
    $chkShowSecret.Add_CheckedChanged({ $txtBlizzardSecret.UseSystemPasswordChar = -not $chkShowSecret.Checked })
    $blizzardTab.Controls.Add($chkShowSecret)

    $btnSaveBlizzard = New-Object System.Windows.Forms.Button
    $btnSaveBlizzard.Text = "Mentes + AH frissites"
    $btnSaveBlizzard.Location = New-Object System.Drawing.Point(120, 105)
    $btnSaveBlizzard.Size = New-Object System.Drawing.Size(180, 34)
    $blizzardTab.Controls.Add($btnSaveBlizzard)
    $lblBlizzardGuiStatus = New-Object System.Windows.Forms.Label
    $lblBlizzardGuiStatus.Text = "API allapot: -"
    $lblBlizzardGuiStatus.Location = New-Object System.Drawing.Point(320, 112)
    $lblBlizzardGuiStatus.AutoSize = $true
    $blizzardTab.Controls.Add($lblBlizzardGuiStatus)
    $lblBlizzardHint = New-Object System.Windows.Forms.Label
    $lblBlizzardHint.Text = "A mentes Windows-felhasznalohoz kotott titkositassal tortenik."
    $lblBlizzardHint.Location = New-Object System.Drawing.Point(120, 155)
    $lblBlizzardHint.AutoSize = $true
    $lblBlizzardHint.ForeColor = [System.Drawing.Color]::DimGray
    $blizzardTab.Controls.Add($lblBlizzardHint)

    $btnSaveBlizzard.Add_Click({
        try {
            Save-BlizzardCredentials -ClientId $txtBlizzardId.Text -ClientSecret $txtBlizzardSecret.Text
            if ($script:BlizzardPriceJob) {
                Stop-Job -Job $script:BlizzardPriceJob -ErrorAction SilentlyContinue
                Remove-Job -Job $script:BlizzardPriceJob -Force -ErrorAction SilentlyContinue
                $script:BlizzardPriceJob = $null
            }
            $script:BlizzardPriceState.NextAttempt = Get-Date
            $script:BlizzardPriceState.LastTargetSignature = ""
            $script:BlizzardPriceState.Status = "READY"
            $script:BlizzardPriceState.LastError = ""
            Update-BlizzardAuctionPrices -Now (Get-Date)
            $lblBlizzardGuiStatus.Text = "API allapot: mentes kesz, AH frissites inditva"
        } catch {
            $lblBlizzardGuiStatus.Text = "API hiba: $($_.Exception.Message)"
            Write-LogException -Context "Blizzard GUI credential mentes" -ErrorRecord $_
        }
    })

    $alertTab = New-Object System.Windows.Forms.TabPage
    $alertTab.Text = "Riasztasok"
    $bottomTabs.TabPages.Add($alertTab)
    $alertList = New-Object System.Windows.Forms.ListBox
    $alertList.Dock = "Fill"
    $alertList.Font = New-Object System.Drawing.Font("Consolas", 9)
    $alertTab.Controls.Add($alertList)

    $grid.Add_SelectionChanged({
        if ($grid.SelectedRows.Count -gt 0) {
            $value = $grid.SelectedRows[0].Cells["Client"].Value
            $selected = [uint32]0
            if ([uint32]::TryParse([string]$value, [ref]$selected)) {
                $script:SelectedClientPid = $selected
                $lblSelectedPid.Text = "Kivalasztott PID: $selected"
                $clientForButtons = $script:Clients[$selected]
                $controlStateForButtons = if ($clientForButtons -and $clientForButtons.ContainsKey("ControlState")) { [string]$clientForButtons.ControlState } else { "RUNNING" }
                $btnStart.Enabled = ($controlStateForButtons -ne "RUNNING")
                $btnPause.Enabled = ($controlStateForButtons -eq "RUNNING")
                $btnStop.Enabled = ($controlStateForButtons -ne "STOPPED")
            }
        }
    })
    $btnStart.Add_Click({
        if ($script:SelectedClientPid) {
            if (Set-ClientControlState -TargetPid $script:SelectedClientPid -State "RUNNING") {
                $lblSelectedPid.Text = "Kivalasztott PID: $($script:SelectedClientPid) | STARTED"
                Invoke-GuiRefresh
            }
            Update-ControlButtons
        } else { $lblSelectedPid.Text = "Kivalasztott PID: elobb kattints egy klienssorra" }
    })
    $btnPause.Add_Click({
        if ($script:SelectedClientPid) {
            if (Set-ClientControlState -TargetPid $script:SelectedClientPid -State "PAUSED") {
                $lblSelectedPid.Text = "Kivalasztott PID: $($script:SelectedClientPid) | PAUSED"
                Invoke-GuiRefresh
            }
            Update-ControlButtons
        } else { $lblSelectedPid.Text = "Kivalasztott PID: elobb kattints egy klienssorra" }
    })
    $btnStop.Add_Click({
        if ($script:SelectedClientPid) {
            if (Set-ClientControlState -TargetPid $script:SelectedClientPid -State "STOPPED") {
                $lblSelectedPid.Text = "Kivalasztott PID: $($script:SelectedClientPid) | STOPPED"
                Invoke-GuiRefresh
            }
            Update-ControlButtons
        } else { $lblSelectedPid.Text = "Kivalasztott PID: elobb kattints egy klienssorra" }
    })
    $itemGrid.Add_SelectionChanged({
        if ($itemGrid.SelectedRows.Count -gt 0 -and $itemGrid.SelectedRows[0].Tag) {
            $script:SelectedLootItemName = [string]$itemGrid.SelectedRows[0].Tag.ItemName
        }
    })

    $script:GuiControls = @{
        Form         = $form
        SelectedPid  = $lblSelectedPid
        StartButton  = $btnStart
        PauseButton  = $btnPause
        StopButton   = $btnStop
        BottomTabs   = $bottomTabs
        Runtime      = $lblRuntime
        Clients      = $lblClients
        Status       = $lblStatus
        Queue        = $lblQueue
        TotalFish    = $lblTotalFish
        TotalWyrm    = $lblTotalWyrm
        FishPerHour  = $lblFishPerHour
        WyrmPerHour  = $lblWyrmPerHour
        GoldPerHour  = $lblGoldPerHour
        EurPerHour   = $lblEurPerHour
        HufPerHour   = $lblHufPerHour
        Price        = $lblPrice
        PriceSource  = $lblPriceSource
        TotalValue   = $lblTotalValue
        Proj6h       = $lblProj6h
        Proj24h      = $lblProj24h
        Proj7d       = $lblProj7d
        PriceUpdated = $lblPriceUpdated
        TargetVal    = $lblTargetVal
        TargetCur    = $lblTargetCur
        TargetRem    = $lblTargetRem
        TargetNeed   = $lblTargetNeed
        TargetEta    = $lblTargetEta
        TargetBar    = $targetBar
        SessStart    = $lblSessStart
        SessMonStart = $lblSessMonStart
        SessActive   = $lblSessActive
        SessPaused   = $lblSessPaused
        SessReload   = $lblSessReload
        SessUpdate   = $lblSessUpdate
        Grid         = $grid
        ItemGrid     = $itemGrid
        SellItem     = $lblSellItem
        SellCount    = $lblSellCount
        SellCurrent  = $lblSellCurrent
        SellRange    = $lblSellRange
        SellAverage  = $lblSellAverage
        SellBestDay  = $lblSellBestDay
        SellWindow   = $lblSellWindow
        SellSamples  = $lblSellSamples
        SellSignal   = $lblSellSignal
        AlertList    = $alertList
        BlizzardIdText = $txtBlizzardId
        BlizzardSecretText = $txtBlizzardSecret
        BlizzardGuiStatus = $lblBlizzardGuiStatus
    }
    $script:GridRowMap = @{}
    $script:ItemGridRowMap = @{}
    $script:SelectedLootItemName = $null

    return $form
}

function Format-Huf {
    param([double]$Value)
    return "{0:N0} Ft" -f $Value
}

function Format-Duration {
    param([double]$TotalSeconds)
    $ts = [TimeSpan]::FromSeconds([Math]::Max($TotalSeconds, 0))
    return "{0:D2}:{1:D2}:{2:D2}" -f [int]$ts.TotalHours, $ts.Minutes, $ts.Seconds
}

function Update-ClientGridRow {
    param($Grid, [uint32]$TargetPid, [object[]]$Values, [string]$Status)

    if ($script:GridRowMap.ContainsKey($TargetPid)) {
        $rowIdx = $script:GridRowMap[$TargetPid]
        if ($rowIdx -lt $Grid.Rows.Count) {
            for ($i = 0; $i -lt $Values.Count; $i++) {
                $Grid.Rows[$rowIdx].Cells[$i].Value = $Values[$i]
            }
        } else {
            $rowIdx = $Grid.Rows.Add($Values)
            $script:GridRowMap[$TargetPid] = $rowIdx
        }
    } else {
        $rowIdx = $Grid.Rows.Add($Values)
        $script:GridRowMap[$TargetPid] = $rowIdx
    }

    $color = switch ($Status) {
        "ERROR"   { [System.Drawing.Color]::MistyRose }
        "WARNING" { [System.Drawing.Color]::LightYellow }
        "MANUAL"  { [System.Drawing.Color]::LightGray }
        "PAUSED"  { [System.Drawing.Color]::LightBlue }
        "STOPPED" { [System.Drawing.Color]::Gainsboro }
        default   { [System.Drawing.Color]::White }
    }
    $Grid.Rows[$rowIdx].DefaultCellStyle.BackColor = $color
}

function Format-GoldPrice {
    param([double]$Value)
    if ($Value -le 0) { return "-" }
    return "{0:N2} g" -f $Value
}

function Get-SellSignalColor {
    param([string]$SignalCode)
    $color = switch ($SignalCode) {
        "SELL_NOW" { [System.Drawing.Color]::LightGreen }
        "HOLD"     { [System.Drawing.Color]::LightSkyBlue }
        "WAIT"     { [System.Drawing.Color]::LightYellow }
        "SELL_OK"  { [System.Drawing.Color]::Honeydew }
        "NO_PRICE" { [System.Drawing.Color]::MistyRose }
        default    { [System.Drawing.Color]::Gainsboro }
    }
    return $color
}

function Update-SelectedItemDetails {
    param($Gui)
    $selectedTag = $null
    foreach ($row in $Gui.ItemGrid.Rows) {
        if ($row.Tag -and [string]$row.Tag.ItemName -eq [string]$script:SelectedLootItemName) {
            $selectedTag = $row.Tag
            break
        }
    }
    if (-not $selectedTag) {
        $Gui.SellItem.Text = "Item: valassz az also listabol"
        $Gui.SellSignal.Text = "JELZES: ADATGYUJTES"
        $Gui.SellSignal.BackColor = [System.Drawing.Color]::Transparent
        return
    }

    $a = $selectedTag.Analysis
    $quote = $selectedTag.Quote
    $Gui.SellItem.Text = "Item: $($selectedTag.ItemName)"
    $Gui.SellCount.Text = "Mennyiseg: $($selectedTag.Quantity) db | ID: $($selectedTag.ItemId) | forras: $($quote.Source)"
    $Gui.SellCurrent.Text = "Aktualis ar: $(Format-GoldPrice $a.CurrentPrice) | atlaghoz: $([Math]::Round($a.ChangeFromAveragePct, 1))%"
    $Gui.SellRange.Text = "Historikus min / max: $(Format-GoldPrice $a.MinPrice) / $(Format-GoldPrice $a.MaxPrice)"
    $Gui.SellAverage.Text = "Atlag / felso 25% kuszob: $(Format-GoldPrice $a.AveragePrice) / $(Format-GoldPrice $a.SellThreshold)"
    $Gui.SellBestDay.Text = "Altalaban legjobb nap: $($a.BestDayName) (atlag: $(Format-GoldPrice $a.BestDayAverage))"
    $windowText = if ($null -eq $a.DaysUntilBest) {
        "nincs eleg adat"
    } elseif ([int]$a.DaysUntilBest -eq 0) {
        "ma"
    } elseif ([int]$a.DaysUntilBest -eq 1) {
        "holnap"
    } else {
        "$($a.DaysUntilBest) nap mulva"
    }
    $Gui.SellWindow.Text = "Kovetkezo eladasi ablak: $windowText"
    $Gui.SellSamples.Text = "Mintak: $($a.SampleCount) | kulon nap: $($a.DistinctDays) | bizalom: $($a.Confidence)"
    $Gui.SellSignal.Text = "JELZES: $($a.SignalText)"
    $Gui.SellSignal.BackColor = Get-SellSignalColor -SignalCode $a.SignalCode
}

function Update-LootItemGrid {
    param($Gui, [hashtable]$LootCounts, [hashtable]$LootItemIds, [datetime]$Now)
    if (-not $Gui.ItemGrid) { return }

    foreach ($name in @($LootCounts.Keys | Sort-Object)) {
        $itemId = if ($LootItemIds.ContainsKey($name)) { [int]$LootItemIds[$name] } else { 0 }
        $quantity = [int]$LootCounts[$name]
        $quote = Get-ItemUnitPrice -ItemName $name -ItemId $itemId
        $analysis = Get-ItemPriceAnalysis -ItemId $itemId -CurrentPrice ([double]$quote.PriceGold) -Now $Now
        $values = @(
            $name, $itemId, $quantity, (Format-GoldPrice $analysis.CurrentPrice),
            (Format-GoldPrice $analysis.MinPrice), (Format-GoldPrice $analysis.MaxPrice),
            (Format-GoldPrice $analysis.AveragePrice), $analysis.BestDayName, $analysis.SignalText
        )
        if ($script:ItemGridRowMap.ContainsKey($name) -and $script:ItemGridRowMap[$name] -lt $Gui.ItemGrid.Rows.Count) {
            $rowIndex = $script:ItemGridRowMap[$name]
            for ($i = 0; $i -lt $values.Count; $i++) { $Gui.ItemGrid.Rows[$rowIndex].Cells[$i].Value = $values[$i] }
        } else {
            $rowIndex = $Gui.ItemGrid.Rows.Add($values)
            $script:ItemGridRowMap[$name] = $rowIndex
        }
        $tag = [PSCustomObject]@{
            ItemName = $name; ItemId = $itemId; Quantity = $quantity
            Quote = $quote; Analysis = $analysis
        }
        $Gui.ItemGrid.Rows[$rowIndex].Tag = $tag
        $Gui.ItemGrid.Rows[$rowIndex].DefaultCellStyle.BackColor = Get-SellSignalColor -SignalCode $analysis.SignalCode
    }

    if (-not $script:SelectedLootItemName -and $Gui.ItemGrid.Rows.Count -gt 0) {
        $first = $Gui.ItemGrid.Rows[0]
        if ($first.Tag) {
            $script:SelectedLootItemName = [string]$first.Tag.ItemName
            $first.Selected = $true
        }
    }
    Update-SelectedItemDetails -Gui $Gui
}

$script:TargetReachedNotified = $false
$script:GuiBusy = $false

function Invoke-GuiRefresh {
    if ($script:GuiBusy) { return }
    $script:GuiBusy = $true

    try {
        $now = Get-Date
        $gui = $script:GuiControls

        try { Update-WyrmfishPrice -Now $now } catch { Write-LogException -Context "Update-WyrmfishPrice" -ErrorRecord $_ }

        $totalFish = 0
        $totalWyrm = 0
        $totalLootCounts = @{}
        $totalLootItemIds = @{}
        $totalActiveHours = 0.0
        $fishPerHourValues = @()

        foreach ($client in $script:Clients.Values) {
            $m = Get-ClientMetrics -Client $client
            $fishPerHourValues += $m.FishPerHour
        }
        $avgFishPerHour = if ($fishPerHourValues.Count -gt 0) { ($fishPerHourValues | Measure-Object -Average).Average } else { 0 }

        foreach ($client in $script:Clients.Values) {
            try { Test-ClientAnomalies -Client $client -Now $now -AvgFishPerHour $avgFishPerHour }
            catch { Write-LogException -Context "[$($client.PID)] Test-ClientAnomalies" -ErrorRecord $_ }

            $totalFish += $client.HookCount
            $totalActiveHours += ($client.ActiveTimeSeconds / 3600.0)
            Add-LootCounts -Target $totalLootCounts -Source $client.FishCounts
            Add-LootItemIds -Target $totalLootItemIds -Source $client.FishItemIds
            if ($client.FishCounts.ContainsKey($Config.Loot.HighlightFishName)) {
                $totalWyrm += $client.FishCounts[$Config.Loot.HighlightFishName]
            }
        }

        $totalRevenue = Get-RevenueStats -LootCounts $totalLootCounts -LootItemIds $totalLootItemIds -ActiveHours $totalActiveHours
        $script:PriceCache.PricedItems = $totalRevenue.PricedItemTypes
        $script:PriceCache.MissingItems = $totalRevenue.UnpricedItemTypes
        $target = Get-TargetProgress -Revenue $totalRevenue

        if ($target.ProgressPct -ge 100 -and -not $script:TargetReachedNotified) {
            Send-TargetReachedEvent
            $script:TargetReachedNotified = $true
        }

        $gui.Runtime.Text = "Runtime: " + (Format-Duration -TotalSeconds ($now - $script:SessionStartTime).TotalSeconds)
        $gui.Clients.Text = "Clients: $($script:Clients.Count)"
        $runningCount = @($script:Clients.Values | Where-Object { Test-ClientAutomationEnabled -Client $_ }).Count
        $pausedCount = @($script:Clients.Values | Where-Object { $_.ContainsKey("ControlState") -and $_.ControlState -eq "PAUSED" }).Count
        $stoppedCount = @($script:Clients.Values | Where-Object { $_.ContainsKey("ControlState") -and $_.ControlState -eq "STOPPED" }).Count
        $gui.Status.Text  = "Status: RUNNING $runningCount | PAUSED $pausedCount | STOPPED $stoppedCount"
        $gui.Queue.Text   = "Input Queue: $($script:InputQueue.Count) | Busy: " + $(if ($script:InputBusy) { "YES" } else { "NO" })
        if ($gui.BlizzardGuiStatus) {
            $apiMsg = "API allapot: $($script:BlizzardPriceState.Status)"
            if ($script:BlizzardPriceState.LastError) { $apiMsg += " | $($script:BlizzardPriceState.LastError)" }
            $gui.BlizzardGuiStatus.Text = $apiMsg
        }
        Update-ControlButtons

        $totalFishPerHour = if ($totalActiveHours -gt 0) { $totalFish / $totalActiveHours } else { 0 }
        $totalWyrmPerHour = if ($totalActiveHours -gt 0) { $totalWyrm / $totalActiveHours } else { 0 }
        $gui.TotalFish.Text   = "Total Fish: $totalFish"
        $gui.TotalWyrm.Text   = "Total Wyrmfish: $totalWyrm"
        $gui.FishPerHour.Text = "Fish/hour: {0:N1}" -f (ConvertTo-SafeNumber $totalFishPerHour)
        $gui.WyrmPerHour.Text = "Wyrmfish/hour: {0:N1}" -f (ConvertTo-SafeNumber $totalWyrmPerHour)
        $gui.GoldPerHour.Text = "Gold/hour: {0:N1}" -f $totalRevenue.GoldPerHour
        $gui.EurPerHour.Text  = "EUR/hour: {0:N2}" -f $totalRevenue.EurPerHour
        $gui.HufPerHour.Text  = "HUF/hour: " + (Format-Huf $totalRevenue.HufPerHour)

        $gui.Price.Text        = "Arazva: $($totalRevenue.PricedItemTypes)/$($totalRevenue.TotalItemTypes) fajta | arazatlan: $($totalRevenue.UnpricedQuantity) db"
        $gui.PriceSource.Text  = "Arforras: $($script:PriceCache.Source)"
        $gui.TotalValue.Text   = "Total value: {0:N1} gold | {1}" -f $totalRevenue.GoldTotal, (Format-Huf $totalRevenue.HufTotal)
        $gui.Proj6h.Text       = "6h projection: " + (Format-Huf $totalRevenue.Projection6h)
        $gui.Proj24h.Text      = "24h projection: " + (Format-Huf $totalRevenue.Projection24h)
        $gui.Proj7d.Text       = "7d projection: " + (Format-Huf $totalRevenue.Projection7d)
        $missingPreview = if ($totalRevenue.UnpricedNames.Count -gt 0) {
            (@($totalRevenue.UnpricedNames | Select-Object -First 2) -join "; ") + $(if ($totalRevenue.UnpricedNames.Count -gt 2) { "; ..." } else { "" })
        } else { "nincs" }
        $gui.PriceUpdated.Text = "Arlista: " + $(if ($script:PriceCache.LastUpdated) { $script:PriceCache.LastUpdated.ToString("HH:mm:ss") } else { "-" }) + " | hianyzo: $missingPreview"
        Update-LootItemGrid -Gui $gui -LootCounts $totalLootCounts -LootItemIds $totalLootItemIds -Now $now

        $gui.TargetVal.Text  = "TARGET: " + (Format-Huf $target.Target)
        $gui.TargetCur.Text  = "CURRENT: " + (Format-Huf $target.Current)
        $gui.TargetRem.Text  = "REMAINING: " + (Format-Huf $target.Remaining)
        $gui.TargetNeed.Text = "NEEDED VALUE: {0:N0} gold" -f $target.NeededGold
        $gui.TargetEta.Text  = "ETA: " + $(if ($target.HasEta) { Format-Duration -TotalSeconds ($target.EtaHours * 3600) } else { "--" })
        $gui.TargetBar.Value = [Math]::Max(0, [Math]::Min(100, [int]$target.ProgressPct))

        $totalPaused = (($script:Clients.Values | ForEach-Object { $_.PausedTimeSeconds }) | Measure-Object -Sum).Sum
        $totalReload = (($script:Clients.Values | ForEach-Object { $_.ReloadTimeSeconds }) | Measure-Object -Sum).Sum
        $gui.SessStart.Text    = "Session start: " + $script:SessionStartTime.ToString("yyyy-MM-dd HH:mm:ss")
        $gui.SessMonStart.Text = "Monitoring start: " + $(if ($script:MonitoringStartTime) { $script:MonitoringStartTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "-" })
        $gui.SessActive.Text   = "Active time: " + (Format-Duration -TotalSeconds ($totalActiveHours * 3600))
        $gui.SessPaused.Text   = "Paused time: " + (Format-Duration -TotalSeconds $totalPaused)
        $gui.SessReload.Text   = "Reload/maintenance time: " + (Format-Duration -TotalSeconds $totalReload)
        $gui.SessUpdate.Text   = "Last update: " + $now.ToString("HH:mm:ss")

        foreach ($clientPid in ($script:Clients.Keys | Sort-Object)) {
            $client = $script:Clients[$clientPid]
            $m = Get-ClientMetrics -Client $client
            $rev = Get-RevenueStats -LootCounts $client.FishCounts -LootItemIds $client.FishItemIds -ActiveHours $m.ActiveHours

            $pendingInput = "-"
            $pendingItem = $script:InputQueue | Where-Object { $_.PID -eq $clientPid } | Select-Object -First 1
            if ($pendingItem) { $pendingInput = "$($pendingItem.Type) pending" }

            $lastActivityStr = if ($client.LastActivity) { $client.LastActivity.ToString("HH:mm:ss") } else { "-" }
            $pendingLoot = [Math]::Max($client.HookCount - $client.LastLootSyncHookCount, 0)
            $lastLootSync = if ($client.LastSavedVarUpdate) { $client.LastSavedVarUpdate.ToString("HH:mm:ss") } else { "-" }

            Update-ClientGridRow -Grid $gui.Grid -TargetPid $clientPid -Status $client.Status -Values @(
                $clientPid,
                $(if ($client.ContainsKey("ControlState")) { $client.ControlState } else { "RUNNING" }),
                "$($client.Keybinds.Cast)/$($client.Keybinds.Bobber)",
                $client.Status,
                $(if ($client.NetworkConnected -eq $true) { "ONLINE" } elseif ($client.NetworkConnected -eq $false) { "OFFLINE" } else { "LEARNING" }),
                "$($client.RecoveryState) $($client.RecoveryAttempt)/$($Config.Recovery.MaxAttempts)",
                $client.StatusReason,
                $client.HookCount,
                $m.WyrmfishCount,
                "$($client.LootReloadState) v$($client.LootAddonVersion) p:$pendingLoot i:$($client.LastLootItemTotal) $lastLootSync",
                ("{0:N1}" -f $m.FishPerHour),
                ("{0:N1}" -f $m.WyrmfishPerHour),
                ("{0:N0}" -f $rev.HufPerHour),
                (Format-Duration -TotalSeconds $client.ActiveTimeSeconds),
                $lastActivityStr,
                $pendingInput
            )
        }

        $gui.AlertList.Items.Clear()
        $recentAlerts = $script:Alerts | Select-Object -Last $Config.Gui.AlertDisplayCount
        foreach ($alert in $recentAlerts) {
            [void]$gui.AlertList.Items.Add(("{0:HH:mm:ss} [{1}] [{2}] {3}" -f $alert.Timestamp, $alert.Severity, $alert.PID, $alert.Reason))
        }

        if (($now - $script:LastReportTime).TotalSeconds -ge $Config.Gui.ReportIntervalSeconds) {
            Add-ReportSnapshot -Now $now
            $script:LastReportTime = $now
        }
    } catch {
        Write-LogException -Context "Invoke-GuiRefresh" -ErrorRecord $_
    } finally {
        $script:GuiBusy = $false
    }
}

# ==============================================================================
# CONFIG VALIDATION
# ==============================================================================

function Test-Configuration {
    $errors = New-Object System.Collections.Generic.List[string]

    if ($Config.Gui.MonitorIntervalMs -lt 20) { $errors.Add("Gui.MonitorIntervalMs tul alacsony (min 20ms)") }
    if ($Config.Gui.RefreshIntervalMs -lt $Config.Gui.MonitorIntervalMs) { $errors.Add("Gui.RefreshIntervalMs nem lehet kisebb, mint MonitorIntervalMs") }
    if ($Config.General.MaxClients -lt 8) { $errors.Add("General.MaxClients legalabb 8 legyen") }
    if ($Config.General.ProcessCheckIntervalSeconds -lt 1) { $errors.Add("General.ProcessCheckIntervalSeconds legalabb 1 legyen") }
    if ($Config.General.FocusSettleMilliseconds -lt 10) { $errors.Add("General.FocusSettleMilliseconds tul alacsony (min 10ms)") }
    foreach ($pair in @(
        @{ Name = "CastKey"; Value = $Config.General.CastKey },
        @{ Name = "BobberKey"; Value = $Config.General.BobberKey },
        @{ Name = "LogoutKey"; Value = $Config.General.LogoutKey }
    )) {
        if (-not (Test-KeySpec -KeySpec $pair.Value)) { $errors.Add("Ervenytelen alap billentyu ($($pair.Name)): $($pair.Value)") }
    }
    if ($Config.Audio.PollIntervalMs -lt 50) { $errors.Add("Audio.PollIntervalMs tul alacsony (min 50ms)") }
    if ($Config.General.NoBiteStreakLimit -lt 1) { $errors.Add("General.NoBiteStreakLimit legalabb 1 legyen") }
    if ($Config.Recovery.NetworkPollSeconds -lt 1) { $errors.Add("Recovery.NetworkPollSeconds legalabb 1 legyen") }
    if ($Config.Recovery.NetworkLearnTimeoutSeconds -lt $Config.Recovery.NetworkPollSeconds) { $errors.Add("Recovery.NetworkLearnTimeoutSeconds tul alacsony") }
    if ($Config.Recovery.DisconnectConfirmSeconds -lt $Config.Recovery.NetworkPollSeconds) { $errors.Add("Recovery.DisconnectConfirmSeconds legyen legalabb egy network poll") }
    if ($Config.Recovery.StableConnectionSeconds -lt 1) { $errors.Add("Recovery.StableConnectionSeconds legalabb 1 legyen") }
    if ($Config.Recovery.MaxAttempts -lt 1) { $errors.Add("Recovery.MaxAttempts legalabb 1 legyen") }
    if (@($Config.Recovery.BackoffSeconds).Count -eq 0 -or @($Config.Recovery.BackoffSeconds | Where-Object { $_ -le 0 }).Count -gt 0) {
        $errors.Add("Recovery.BackoffSeconds csak pozitiv ertekeket tartalmazhat")
    }
    if (@($Config.Recovery.ActionPlan).Count -eq 0) { $errors.Add("Recovery.ActionPlan nem lehet ures") }
    foreach ($step in @($Config.Recovery.ActionPlan)) {
        if ($step.Type -notin @("Key", "Password")) { $errors.Add("Ismeretlen recovery lepes tipus: $($step.Type)") }
        if ($step.Type -eq "Key" -and -not (Test-KeySpec -KeySpec ([string]$step.Key))) { $errors.Add("Ervenytelen recovery billentyu: $($step.Key)") }
        if ([double]$step.WaitForConnectionSeconds -lt 1) { $errors.Add("Recovery varakozas legalabb 1 masodperc legyen: $($step.Name)") }
    }
    foreach ($port in @($Config.Recovery.ServerPorts) + @($Config.Recovery.IgnoreRemotePorts)) {
        if ([int]$port -lt 1 -or [int]$port -gt 65535) { $errors.Add("Ervenytelen recovery halozati port: $port") }
    }
    if ($Config.Price.FallbackPrice -le 0) { $errors.Add("Price.FallbackPrice legyen pozitiv") }
    if ($Config.Price.ImportPollSeconds -lt 1) { $errors.Add("Price.ImportPollSeconds legalabb 1 legyen") }
    if ($Config.Price.BlizzardRefreshMinutes -lt 5) { $errors.Add("Price.BlizzardRefreshMinutes legalabb 5 legyen") }
    if ($Config.Price.BlizzardRetryMinutes -lt 1) { $errors.Add("Price.BlizzardRetryMinutes legalabb 1 legyen") }
    if ($Config.Price.BlizzardTimeoutSeconds -lt 30) { $errors.Add("Price.BlizzardTimeoutSeconds legalabb 30 legyen") }
    if ($Config.Price.BlizzardPriceMetric -notin @("MinimumBuyout", "WeightedAverage")) { $errors.Add("Price.BlizzardPriceMetric: MinimumBuyout vagy WeightedAverage") }
    if ($Config.Price.PriceHistoryMaxDays -lt 7) { $errors.Add("Price.PriceHistoryMaxDays legalabb 7 legyen") }
    if ($Config.Price.SellMinimumSamples -lt 3) { $errors.Add("Price.SellMinimumSamples legalabb 3 legyen") }
    if ($Config.Price.SellMinimumDistinctDays -lt 2) { $errors.Add("Price.SellMinimumDistinctDays legalabb 2 legyen") }
    if ($Config.Price.SellNowPercentile -lt 0.5 -or $Config.Price.SellNowPercentile -gt 1) { $errors.Add("Price.SellNowPercentile 0.5 es 1 kozott legyen") }
    if ($Config.Price.SellExpectedRisePct -lt 0) { $errors.Add("Price.SellExpectedRisePct nem lehet negativ") }
    if ($Config.Price.Faction -notin @("Alliance", "Horde")) { $errors.Add("Price.Faction csak Alliance vagy Horde lehet") }
    if ([string]::IsNullOrWhiteSpace($Config.Price.Realm)) { $errors.Add("Price.Realm nem lehet ures") }
    if ([string]::IsNullOrWhiteSpace($Config.Price.Region)) { $errors.Add("Price.Region nem lehet ures") }
    if ($Config.Target.TargetHuf -lt 0) { $errors.Add("Target.TargetHuf nem lehet negativ") }
    if ($Config.Revenue.GoldPerEuro -le 0) { $errors.Add("Revenue.GoldPerEuro legyen pozitiv") }
    if ($Config.Revenue.EurToHuf -le 0) { $errors.Add("Revenue.EurToHuf legyen pozitiv") }
    if ($Config.Gui.ReportIntervalSeconds -lt 5) { $errors.Add("Gui.ReportIntervalSeconds tul alacsony (min 5s)") }
    if ($Config.Loot.Enabled -and $Config.Loot.ReloadEveryCatches -lt 1) { $errors.Add("Loot.ReloadEveryCatches legalabb 1 legyen") }
    if ($Config.Loot.Enabled -and $Config.Loot.MaxUnsyncedMinutes -lt 0.5) { $errors.Add("Loot.MaxUnsyncedMinutes legalabb 0.5 legyen") }
    if ($Config.Loot.Enabled -and [string]::IsNullOrWhiteSpace($Config.Loot.RequiredAddonVersion)) { $errors.Add("Loot.RequiredAddonVersion nem lehet ures") }
    if ($Config.Loot.ReloadSpacingSeconds -lt $Config.Loot.ReloadSettleSeconds) { $errors.Add("Loot.ReloadSpacingSeconds legyen legalabb akkora, mint ReloadSettleSeconds") }
    foreach ($itemName in $Config.Price.AdditionalItemPrices.Keys) {
        if ([double]$Config.Price.AdditionalItemPrices[$itemName] -le 0) { $errors.Add("AdditionalItemPrices ar legyen pozitiv: $itemName") }
    }
    if ($Config.Client.UsePi -and -not $Config.Client.PicoComPort) { $errors.Add("Client.UsePi be van kapcsolva, de nincs PicoComPort") }
    if ($Config.Recovery.AllowPasswordTyping -and [string]::IsNullOrEmpty($wowPassword)) {
        Write-Log -Level WARNING -Message "Recovery.AllowPasswordTyping=true, de nincs AIFISHBOT_WOW_PASSWORD - a Password lepes kimarad."
    }
    if ($Config.Recovery.FallbackToNoBiteOnly -and $Config.Recovery.AllowPasswordTyping) {
        Write-Log -Level WARNING -Message "BIZTONSAGI FIGYELMEZTETES: no-bite fallback es automatikus jelszobeiras egyszerre engedelyezve."
    }
    if ($Config.Notification.Enabled -and -not $Config.Notification.DiscordWebhook) {
        Write-Log -Level WARNING -Message "Notification.Enabled=true, de nincs AIFISHBOT_DISCORD_WEBHOOK - a Discord ertesitesek nem fognak menni."
    }
    foreach ($idx in $Config.Client.BuffsEnabled) {
        $b = $Config.Client.Buffs[$idx]
        if (-not $b) { $errors.Add("BuffsEnabled hivatkozik egy nem letezo buff ID-re: $idx") ; continue }
        if (-not (Test-KeySpec -KeySpec $b.Keybind)) { $errors.Add("Buff #$idx : ervenytelen Keybind ($($b.Keybind))") }
        if ($b.CastTimeSeconds -lt 0) { $errors.Add("Buff #$idx : negativ CastTimeSeconds") }
        if ($b.DurationMinutes -le 0) { $errors.Add("Buff #$idx : DurationMinutes legyen pozitiv") }
    }

    if ($errors.Count -gt 0) {
        $msg = "Konfiguracios hiba(k):`n" + ($errors -join "`n")
        Write-Log -Level ERROR -Message $msg
        [System.Windows.Forms.MessageBox]::Show($msg, "AI-FishBot Monitor v2.8 - Config hiba", "OK", "Error") | Out-Null
        return $false
    }
    return $true
}

# ==============================================================================
# CLEAN SHUTDOWN
# ==============================================================================

$script:MonitorStopped = $false

function Stop-Monitor {
    if ($script:MonitorStopped) { return }
    $script:MonitorStopped = $true

    try { $monitorTimer.Stop() } catch { }
    try { $guiTimer.Stop() } catch { }
    try {
        if ($script:BlizzardPriceJob) {
            Stop-Job -Job $script:BlizzardPriceJob -ErrorAction SilentlyContinue
            Remove-Job -Job $script:BlizzardPriceJob -Force -ErrorAction SilentlyContinue
            $script:BlizzardPriceJob = $null
        }
    } catch { Write-LogException -Context "Blizzard AH job leallitas" -ErrorRecord $_ }

    try {
        if ($script:PicoPort -and $script:PicoPort.IsOpen) { $script:PicoPort.Close() }
    } catch { Write-LogException -Context "SerialPort close" -ErrorRecord $_ }
    try { Export-PriceHistory }
    catch { Write-LogException -Context "Zaro AH arhistorika export" -ErrorRecord $_ }

    $summaryText = "Total Fish: - | Total Wyrmfish: - | Revenue: -"
    try {
        Add-ReportSnapshot -Now (Get-Date)
    } catch { Write-LogException -Context "Zaro report snapshot" -ErrorRecord $_ }

    try {
        $summary = Export-SessionJsonSummary
        $summaryText = "Total Fish: $($summary.TotalFish) | Total Wyrmfish: $($summary.TotalWyrmfish) | Revenue: $($summary.RevenueHuf) Ft"
    } catch { Write-LogException -Context "Zaro JSON export" -ErrorRecord $_ }

    try { Send-SessionStoppedEvent -Summary $summaryText } catch { Write-LogException -Context "Session stopped notification" -ErrorRecord $_ }

    Write-Log -Level INFO -Message "Monitor leallitva. $summaryText"
}

# ==============================================================================
# 17) ENTRY POINT
# ==============================================================================

if (-not (Test-Configuration)) { Exit 1 }

Ensure-NAudio

if ($Config.Client.UsePi) {
    try {
        $script:PicoPort = New-Object System.IO.Ports.SerialPort $Config.Client.PicoComPort, 115200, None, 8, one
        $script:PicoPort.Open()
    } catch {
        Write-LogException -Context "Pi csatlakozas" -ErrorRecord $_
        [System.Windows.Forms.MessageBox]::Show("Pi csatlakozas sikertelen: $($_.Exception.Message)", "AI-FishBot Monitor v2.8", "OK", "Error") | Out-Null
        Exit 1
    }
}

$selectedPids = Show-ClientSelectorDialog
if ($selectedPids.Count -eq 0) {
    Write-Log -Level INFO -Message "Nincs kivalasztott kliens - kilepes."
    Exit 0
}
if ($selectedPids.Count -gt $Config.General.MaxClients) {
    $msg = "Legfeljebb $($Config.General.MaxClients) kliens valaszthato ebben a kiadasban. Kivalasztva: $($selectedPids.Count)."
    Write-Log -Level ERROR -Message $msg
    [System.Windows.Forms.MessageBox]::Show($msg, "AI-FishBot Monitor v2.8", "OK", "Error") | Out-Null
    Exit 1
}

if ($Config.Client.ShowKeybindEditorEveryStart) {
    $keybindAssignments = Show-ClientKeybindDialog -Pids $selectedPids
    if (-not $keybindAssignments) {
        Write-Log -Level INFO -Message "Billentyubeallitas megszakitva - kilepes."
        Exit 0
    }
} else {
    $savedSlots = Import-KeybindSlots
    $byPid = @{}
    for ($slot = 0; $slot -lt $selectedPids.Count; $slot++) {
        $source = if ($slot -lt $savedSlots.Count) { $savedSlots[$slot] } else { $null }
        $byPid[[uint32]$selectedPids[$slot]] = Copy-KeybindMap -Source $source
    }
    $keybindAssignments = [PSCustomObject]@{ ByPid = $byPid; Slots = $savedSlots }
}

foreach ($clientPid in $selectedPids) {
    $script:Clients[$clientPid] = New-ClientState -WowPid $clientPid -Keybinds $keybindAssignments.ByPid[$clientPid]
}

try { [void](Import-BlizzardCredentials) }
catch { Write-LogException -Context "Kezdeti Blizzard credential import" -ErrorRecord $_ }

try { Import-PriceHistory }
catch { Write-LogException -Context "Kezdeti AH arhistorika import" -ErrorRecord $_ }
try { Import-BlizzardPriceCache }
catch { Write-LogException -Context "Kezdeti Blizzard AH cache import" -ErrorRecord $_ }
try { Update-BootyBayBrokerArtifacts -Now (Get-Date) }
catch { Write-LogException -Context "Kezdeti BootyBayBroker export/import" -ErrorRecord $_ }

Write-Log -Level INFO -Message "Session inditva: $script:SessionId, $($script:Clients.Count) kliens"
Send-SessionStartedEvent

$script:MonitoringStartTime = Get-Date

$mainForm = Build-MainForm

$monitorTimer = New-Object System.Windows.Forms.Timer
$monitorTimer.Interval = $Config.Gui.MonitorIntervalMs
$monitorTimer.Add_Tick({
    try {
        $result = Invoke-MonitorTick
        if ($result -eq "AUTOSTOP") {
            Write-Log -Level INFO -Message "AutoStop ido elerve."
            $mainForm.Close()
        }
    } catch {
        Write-LogException -Context "MonitorTimer.Tick" -ErrorRecord $_
    }
})

$guiTimer = New-Object System.Windows.Forms.Timer
$guiTimer.Interval = $Config.Gui.RefreshIntervalMs
$guiTimer.Add_Tick({
    try { Invoke-GuiRefresh }
    catch { Write-LogException -Context "GuiTimer.Tick" -ErrorRecord $_ }
})

$mainForm.Add_FormClosing({ Stop-Monitor })

$monitorTimer.Start()
$guiTimer.Start()

[System.Windows.Forms.Application]::Run($mainForm)

<#
================================================================================
 CHANGELOG (v2.7 -> v2.8)
================================================================================
- A kliensracs kijelolt PID-jere kulon START, PAUSE es STOP gomb; szuneteltetett
  vagy leallitott klienshez sem fishing, sem reload, sem recovery input nem megy.
- Szabadon atmeretezheto es maximalhato foablak, rugalmas felso statisztikai
  elrendezessel es meretezodo kliens-/itemtablakkal.
- Kijelolheto teljes fogaslista aktualis arral, historikus minimum/maximum/
  atlaggal, altalaban legerosebb hetnappal es szines eladasi jelzessel.
- Tartosan mentett, 120 napos Blizzard AH arhistorika. A heti minta napi
  medianokbol tanul, a jelzes pedig mintaszamot es bizalmi szintet is mutat.
- ELADAS MOST jelzes felso ar-percentilisnel; 1-2 napon beluli, tortenelmileg
  jobb nap es legalabb 5% vart emelkedes eseten megtartasi javaslat.

================================================================================
 CHANGELOG (v2.6 -> v2.7)
================================================================================
- Blizzard OAuth client-credentials hitelesites kizarolag kornyezeti valtozobol;
  a client secret nem kerul fajlba, cache-be vagy naploba.
- Minden kifogott item ID automatikus keresese a kapcsolt realm aukcioiban es
  a Retail EU-regios commodity aukciokban, minimum darabar normalizalassal.
- A nagy AH-pillanatkepek kulon PowerShell-jobban dolgozodnak fel, igy a nyolc
  kliens hangfigyelese, input queue-ja es GUI-ja nem blokkol.
- Uj item ID azonnali frissitest indit; egyebkent orankenti arfrissites, hiba
  eseten 5 perces ujraproba, valamint titkot nem tartalmazo helyi ar-cache.
- A teljes loot ertek, gold/HUF ora, projekciok, target progress es ETA a
  Blizzard-arakat hasznalja; manualis es BBB/CSV arak biztonsagos fallbackek.

================================================================================
 CHANGELOG (v2.5 -> v2.6)
================================================================================
- AIFishLootTracker v1.3 az item neve mellett a Blizzard item ID-t is menti.
- Minden loot sync utan frissul a BootyBayBroker-kompatibilis teljes fogas JSON.
- A bootybaybroker-price-import.csv minden uj fogasfajtat automatikusan felvesz,
  a kitoltott arakat pedig a program 5 masodpercen belul ujratolti.
- A gold/HUF/ora, teljes ertek, projekciok, target progress es ETA mar az osszes
  arazott fogas osszegebol szamolodik, nem csak a Wyrmfishbol.
- Az arazatlan tetelek kulon darab- es fajtaszammal, valamint CSV/JSON listaval
  jelennek meg; nem torzitjak csendben a szamitast.

================================================================================
 CHANGELOG (v2.4 -> v2.5)
================================================================================
- A csatolt regi naploban lathato egy-elemes input queue hiba a javitott
  kiadasban nincs jelen; emiatt a /reload es loot sync nem tud beragadni.
- Azonnali catches_<session>.csv journal minden sikeresen elkuldott
  bobber-kattintasrol, az itemnev-szinkrontol fuggetlenul.
- Loot item sync 100 helyett 10 fogasi esemeny utan, de legkesobb 3 percen
  belul; sikertelen olvasasnal a pending szamlalo nem veszik el.
- A session CSV percenkent frissul es loot sync diagnosztikat is tartalmaz.
- GUI Loot sync oszlop: allapot, pending fogasok, szinkronizalt itemek es az
  utolso sikeres SavedVariables-olvasas ideje.
- AIFishLootTracker v1.2: LOOT_READY/LOOT_OPENED API es CHAT_MSG_LOOT fallback,
  forraskozti deduplikacioval, plain sandbox chat tamogatassal es status
  diagnosztikaval.

================================================================================
 CHANGELOG (v2.3 -> v2.4)
================================================================================
- A no-bite sorozat onmagaban tobbe nem indit jelszobeirast.
- A program kliensenkent megtanulja a WoW szerver TCP endpointjat, es csak
  tartos, megerositett kapcsolatvesztesnel indit recovery-t.
- Konfiguralhato ActionPlan; minden lepes utan kapcsolat-visszaellenorzes,
  igy a mar helyreallt kliens nem kap tovabbi statikus billentyuparancsot.
- Egyidejuleg egy recovery tulajdonos; a tobbi kliens sorban var.
- Adaptiv backoff, stabilitasi ido, maximum probalkozas es MANUAL atadas.
- Gyors, kb. nehany ezredmasodperces Windows TCP-tabla olvasas, hogy a 8
  kliens kapcsolatfigyelese ne blokkolja a hangmintavetelezest.
- Halozati telemetriahiba eseten a recovery megall, a fuggoben levo inputokat
  torli, es csak friss visszacsatolas utan folytathato.
- Jelszobeiras alapbol tiltva; csak AllowPasswordTyping=true es kornyezeti
  valtozoban megadott jelszo eseten hajthato vegre.
- GUI/CSV/JSON kliensenkenti kapcsolat- es recovery-allapotot is mutat.

================================================================================
 CHANGELOG (v2.2 -> v2.3)
================================================================================
- Indulaskori, kliensenkenti billentyuszerkeszto legfeljebb 8 PID-hez.
- A dobás, kapas, kilepes es buff billentyuk a kliens allapotaban tarolodnak;
  a futasi logika mar nem a globalis F6-F10 ertekeket hasznalja.
- Slotonkenti profilmentes a client-keybinds.json fajlba.
- CTRL/SHIFT/ALT modositok es F1-F24, alfanumerikus, valamint gyakori specialis
  billentyuk tamogatasa.
- A foablak kliensenkent kijelzi a Dobas/Kapas kiosztast.

================================================================================
 CHANGELOG (v2 -> v2.1)
================================================================================

JAVÍTVA
- NAudio.Core/Wasapi betöltés: fust-teszt hozzáadva induláskor, hogy korán,
  érthető hibával bukjon el, ne az első valódi poll-nál.
- Get-ClientAudioPeaks: session-enkénti try/catch, egy hibás session többé nem
  akaszthatja meg a teljes hangfigyelést.
- Test-ClientProcess: központi, mindenhonnan ezt hívja a kód (korábban szórt
  Get-Process hívások voltak Anomaly Detectorban és a monitorban).
- CSV/JSON export minden lépése saját try/catch-csel - egy hiba nem akadályozza
  meg a többi mentését, session zárásnál mindig próbálkozik.
- Discord webhook: -TimeoutSec hozzáadva, hiba esetén csak logol, sosem dob
  tovább kivételt.
- Loot parser: kezeli az üres/nemlétező/zárolt fájlt, csak az AIFishLootDB
  blokkon belül keres (nem fog meg véletlenül más Lua táblát), és sikertelen
  parse esetén NEM írja felül a korábbi adatot.
- Reconnect state machine: NoBiteStreak és ReconnectAttempts most már
  garantáltan resetelődik sikeres fogásnál; NeedsManualHelp után egyetlen
  input sem mehet ki a kliensnek (Queue-Input maga is elutasítja).
- Jelszó soha nem kerül logba (a Recovery-típusú input logsorok "[REDACTED]"-et
  írnak ki payload helyett); üres jelszónál a recovery azonnal ERROR/manual-help
  állapotba tesz, nem próbálkozik értelmetlen inputtal.

OPTIMALIZÁLVA
- A régi blokkoló minták (Start-Sleep a state machine-ben, buff 10x1mp-es
  ciklusa, weakAura retry while+Sleep) mind eltűntek - minden input a Queue-n
  megy át, a monitor tick sosem vár SendKeys-re hosszabb ideig, mint egy
  fókusz-váltás (kb. 60ms).
- DataGridView: nem törli és építi újra a sorokat minden frissítésnél -
  helyben frissíti a meglévő sorok celláit (Update-ClientGridRow).
- $script:MonitorBusy / $script:GuiBusy / $script:InputBusy őrök: egy tick
  nem tud saját magába belépni, még akkor sem, ha valamiért elhúzódna.
- Idő-akkumulátor delta maximum 5 másodpercre korlátozva, hogy egy hosszabb
  UI-akadás ne adjon hozzá irreális aktív időt.
- Összesített fish/hour és Wyrmfish/hour a teljes (fish/aktív-óra) hányadosból
  számolódik, nem a kliensenkénti ráták átlagából.

ÚJ VÉDELEM
- Test-Configuration: induláskor ellenőrzi az intervallumokat, buff configot,
  price/target/revenue beállításokat - hibás config esetén érthető
  hibaüzenettel, tisztán leáll, mielőtt bármi elindulna.
- Stop-Monitor: központi, idempotens leállító függvény (timers, serial port,
  riport mentés, Discord értesítés) - a FormClosing csak ezt hívja.
- ConvertTo-SafeNumber: minden revenue/target számítás védett NaN/Infinity
  ellen.
- Alert lista maximum 200 elemre korlátozva (Config.Gui.AlertHistoryLimit),
  a GUI az utolsó 20-at mutatja.
- Anomaly Detector: állapotátmenet-alapú (OK->WARNING, ->ERROR/MANUAL),
  helyreállásnál új figyelmeztetés újra kiküldhető - nincs folyamatos spam.
- Price Engine: Source most "FALLBACK" vagy "PROVIDER" (nem csak "OFFLINE"
  szöveg), külön Online true/false mező is van hozzá.

INPUT QUEUE
- Központi $script:InputQueue + Queue-Input / Process-InputQueue /
  Invoke-InputAction / Complete-Input függvények - MINDEN SendKeys-hívás
  ezen megy át, nincs többé szórt Focus-Client+SendKeys a kódban.
- Duplikációvédelem: $script:PendingInputKeys (kulcs: "PID|Type") - amíg egy
  adott kliensnek adott típusú inputja fut/vár, nem kerül be újabb ugyanolyan.
- Prioritás: Recovery(0) > Bobber(1) > Cast(2) > Buff(3) > Maintenance(4,
  Reload/ChatCommand/Logout) - Sort-Object Priority, CreatedAt dönti el a
  sorrendet.
- Retry: RetryCount mezővel, max 3 próbálkozás (script:MaxInputRetries),
  NINCS retry-loop - a queue elem egyszerűen a queue-ban marad a következő
  tickig.
- Process-InputQueue egy hívásban LEGFELJEBB EGY elemet dolgoz fel, hogy egy
  tick soha ne blokkoljon SendKeys-halmozódás miatt.
- GUI-ban látható: "Input Queue: N | Busy: YES/NO" a fejlécben, és
  kliensenként az "Input" oszlopban (pl. "Cast pending").

ELLENŐRZÖTT KOMPATIBILITÁS
- Windows PowerShell 5.1 (ComObject wscript.shell, System.Windows.Forms,
  System.Drawing, [ref] paraméterek, hashtable-alapú állapotkezelés - nincs
  PS 5.1-ben hiányzó nyelvi elem, pl. nincs osztály/enum használva).
- WinForms: két System.Windows.Forms.Timer, DataGridView in-place frissítés,
  FormClosing -> Stop-Monitor.
- NAudio 2.2.1 (NAudio.Core + NAudio.Wasapi), induláskori fust-teszttel.
================================================================================
#>
