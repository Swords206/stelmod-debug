<#
.SYNOPSIS
    stelmod-debug - Universal Stellaris Mod Log Analyzer (Windows PowerShell)

.DESCRIPTION
    A tool for Stellaris mod developers to quickly check logs for errors,
    filter by mod prefix, and validate log freshness.

.PARAMETER Command
    The command to run: setup, errors, game, all, fresh, summary, help

.PARAMETER Lines
    Number of lines to show (default: 50)

.EXAMPLE
    .\stelmod-debug.ps1 setup
    .\stelmod-debug.ps1 all
    .\stelmod-debug.ps1 game -Lines 100
#>

param(
    [Parameter(Position=0)]
    [string]$Command = "help",

    [Parameter()]
    [int]$Lines = 50
)

$ErrorActionPreference = "SilentlyContinue"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigFile = Join-Path $ScriptDir "config.json"

# Default config
$Config = @{
    ModPrefix = "YOUR_MOD"
    StellarisDocs = ""
    ModFolder = ""
    TailLines = 50
    ExtraPatterns = @()
}

# ---------------------------------------------------------------------------
# Popular Stellaris Locations (Windows)
# ---------------------------------------------------------------------------

$PopularPaths = @(
    # Standard Documents
    "$env:USERPROFILE\Documents\Paradox Interactive\Stellaris"
    # OneDrive Documents
    "$env:USERPROFILE\OneDrive\Documents\Paradox Interactive\Stellaris"
    # Alternative OneDrive paths
    "$env:OneDrive\Documents\Paradox Interactive\Stellaris"
    # Common secondary drives (D: through H:)
    "D:\Documents\Paradox Interactive\Stellaris"
    "E:\Documents\Paradox Interactive\Stellaris"
    "F:\Documents\Paradox Interactive\Stellaris"
    "G:\Documents\Paradox Interactive\Stellaris"
    "H:\Documents\Paradox Interactive\Stellaris"
    # Games folder variations
    "D:\Games\Paradox Interactive\Stellaris"
    "E:\Games\Paradox Interactive\Stellaris"
    "F:\Games\Paradox Interactive\Stellaris"
    # SteamLibrary locations (user data still goes to Documents usually)
    "D:\SteamLibrary\steamapps\common\Stellaris"
    "E:\SteamLibrary\steamapps\common\Stellaris"
)

# ---------------------------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------------------------

function Write-ColorLine {
    param(
        [string]$Text,
        [ConsoleColor]$Color = "White"
    )
    Write-Host $Text -ForegroundColor $Color
}

function Write-Header {
    Write-Host ""
    Write-ColorLine "================================================================" Cyan
    Write-ColorLine "  stelmod-debug - Stellaris Mod Log Analyzer" White
    Write-ColorLine "================================================================" Cyan
    Write-Host ""
}

function Write-Section {
    param([string]$Title)
    Write-ColorLine "----------------------------------------------------------------" Yellow
    Write-ColorLine "  $Title" White
    Write-ColorLine "----------------------------------------------------------------" Yellow
}

$script:ConfigLoaded = $false
$script:ConfigLoadAttempted = $false

function Load-Config {
    # Only attempt load once per session
    if ($script:ConfigLoadAttempted) { return $script:ConfigLoaded }
    $script:ConfigLoadAttempted = $true

    if (Test-Path $ConfigFile) {
        try {
            $jsonContent = Get-Content $ConfigFile -Raw -Encoding UTF8
            # Remove BOM if present
            $jsonContent = $jsonContent -replace '^\xEF\xBB\xBF', '' -replace '^\uFEFF', ''

            # Convert JSON to object (works in PowerShell 5.1+)
            $jsonObj = $jsonContent | ConvertFrom-Json

            # Convert PSObject to hashtable manually (for PS 5.1 compatibility)
            $script:Config = @{}
            $jsonObj.PSObject.Properties | ForEach-Object {
                if ($_.Value -is [System.Array]) {
                    $script:Config[$_.Name] = @($_.Value)
                } else {
                    $script:Config[$_.Name] = $_.Value
                }
            }

            $script:ConfigLoaded = $true
            return $true
        } catch {
            Write-ColorLine "Warning: config.json is corrupted or invalid - $_" Yellow
            $script:ConfigLoaded = $false
            return $false
        }
    }
    # File doesn't exist - this is normal for first run, no warning needed
    $script:ConfigLoaded = $false
    return $false
}

function Save-Config {
    $json = $Config | ConvertTo-Json -Depth 3
    # Use .NET to write without BOM (PowerShell 5.1 UTF8 adds BOM)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($ConfigFile, $json, $utf8NoBom)
}

$script:ConfigChecked = $false
$script:ConfigValid = $false

function Test-Config {
    # Only show error messages once per session
    if ($script:ConfigChecked) { return $script:ConfigValid }
    $script:ConfigChecked = $true

    if ($Config.ModPrefix -eq "YOUR_MOD") {
        Write-ColorLine "[X] MOD_PREFIX not configured" Red
        Write-ColorLine "    Run: .\stelmod-debug.ps1 setup" Yellow
        $script:ConfigValid = $false
        return $false
    }
    if (-not $Config.StellarisDocs -or -not (Test-Path $Config.StellarisDocs)) {
        Write-ColorLine "[X] Stellaris folder not found: $($Config.StellarisDocs)" Red
        Write-ColorLine "    Run: .\stelmod-debug.ps1 setup" Yellow
        $script:ConfigValid = $false
        return $false
    }
    $script:ConfigValid = $true
    return $true
}

function Get-LogPaths {
    $errorLog = Join-Path $Config.StellarisDocs "logs\error.log"
    $gameLog = Join-Path $Config.StellarisDocs "logs\game.log"
    return @{
        ErrorLog = $errorLog
        GameLog = $gameLog
    }
}

function Show-FolderPicker {
    param([string]$Description = "Select Stellaris User Data Folder")

    Add-Type -AssemblyName System.Windows.Forms
    $browser = New-Object System.Windows.Forms.FolderBrowserDialog
    $browser.Description = $Description
    $browser.ShowNewFolderButton = $false

    # Try to set initial directory to a detected path
    foreach ($path in $PopularPaths) {
        if (Test-Path $path) {
            $browser.SelectedPath = $path
            break
        }
    }

    $result = $browser.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $browser.SelectedPath
    }
    return $null
}

function Find-StellarisFolder {
    Write-ColorLine "Searching for Stellaris folder..." Cyan

    $found = @()
    foreach ($path in $PopularPaths) {
        if (Test-Path $path) {
            $logsPath = Join-Path $path "logs"
            if (Test-Path $logsPath) {
                $resolved = (Resolve-Path $path).Path
                $alreadyFound = $false
                foreach ($f in $found) {
                    if ($f -eq $resolved) { $alreadyFound = $true; break }
                }
                if (-not $alreadyFound) {
                    $found += $resolved
                    Write-ColorLine "  [OK] Found: $resolved" Green
                }
            }
        }
    }

    return ,$found
}

# ---------------------------------------------------------------------------
# Command: Setup
# ---------------------------------------------------------------------------

function Invoke-Setup {
    Write-Header
    Write-Section "Configuration Setup"
    Write-Host ""

    # Step 1: Find or select Stellaris folder
    Write-ColorLine "Step 1: Locate Stellaris User Data" Cyan
    Write-Host ""

    # Search for Stellaris folders inline
    Write-ColorLine "Searching for Stellaris folder..." Cyan
    $detectedPaths = New-Object System.Collections.Generic.List[string]

    foreach ($path in $PopularPaths) {
        if (Test-Path $path) {
            $logsPath = Join-Path $path "logs"
            if (Test-Path $logsPath) {
                $resolved = (Resolve-Path $path).Path
                if (-not $detectedPaths.Contains($resolved)) {
                    $detectedPaths.Add($resolved)
                    Write-ColorLine "  [OK] Found: $resolved" Green
                }
            }
        }
    }

    if ($detectedPaths.Count -gt 0) {
        Write-Host ""
        Write-ColorLine "Found $($detectedPaths.Count) potential location(s):" White

        for ($i = 0; $i -lt $detectedPaths.Count; $i++) {
            Write-ColorLine "  [$($i+1)] $($detectedPaths[$i])" Cyan
        }
        Write-ColorLine "  [B] Browse for different folder..." Yellow
        Write-Host ""

        $choice = Read-Host "Select option (1-$($detectedPaths.Count) or B)"

        if ($choice -eq "B" -or $choice -eq "b") {
            $selectedPath = Show-FolderPicker -Description "Select your Stellaris user data folder (contains logs and mod folders)"
        } elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $detectedPaths.Count) {
            $selectedPath = $detectedPaths[[int]$choice - 1]
        } else {
            Write-ColorLine "Invalid selection" Red
            return
        }
    } else {
        Write-ColorLine "No Stellaris folder auto-detected." Yellow
        Write-ColorLine "Opening folder browser..." Cyan
        $selectedPath = Show-FolderPicker -Description "Select your Stellaris user data folder (contains logs and mod folders)"
    }

    if (-not $selectedPath) {
        Write-ColorLine "[X] No folder selected. Setup cancelled." Red
        return
    }

    # Validate the folder has logs
    $logsPath = Join-Path $selectedPath "logs"
    if (-not (Test-Path $logsPath)) {
        Write-ColorLine "[!] Warning: No logs folder found in $selectedPath" Yellow
        Write-ColorLine "    This folder may not be correct, or Stellaris has not been run yet." Yellow
    }

    $Config.StellarisDocs = $selectedPath
    Write-ColorLine "[OK] Selected: $selectedPath" Green
    Write-Host ""

    # Step 2: Select mod FIRST
    Write-ColorLine "Step 2: Select Your Mod" Cyan
    Write-Host ""

    # Parse .mod files to find LOCAL mods (not Workshop)
    $modPath = Join-Path $selectedPath "mod"
    $localMods = @()

    if (Test-Path $modPath) {
        $modFiles = Get-ChildItem $modPath -Filter "*.mod" -File
        foreach ($modFile in $modFiles) {
            $content = Get-Content $modFile.FullName -Raw
            # Check if it's a local mod (has path=) not workshop (has archive=)
            if ($content -match 'path\s*=' -and $content -notmatch 'archive\s*=') {
                $modName = "Unknown"
                $modFolder = ""

                # Extract name
                if ($content -match 'name\s*=\s*"([^"]+)"') {
                    $modName = $matches[1]
                }
                # Extract path and get folder name
                if ($content -match 'path\s*=\s*"([^"]+)"') {
                    $modFolder = Split-Path $matches[1] -Leaf
                }

                if ($modFolder) {
                    $localMods += @{
                        Name = $modName
                        Folder = $modFolder
                    }
                }
            }
        }

        if ($localMods.Count -gt 0) {
            Write-ColorLine "Local development mods found:" Cyan
            Write-Host ""
            # Option 1 = All mods (recommended)
            Write-ColorLine "  [1] ALL MODS (Recommended)" Green
            Write-Host ""
            # Individual mods start at 2
            for ($i = 0; $i -lt $localMods.Count; $i++) {
                $mod = $localMods[$i]
                Write-ColorLine "  [$($i+2)] $($mod.Name)" White
                Write-ColorLine "      Folder: $($mod.Folder)" Gray
            }
            Write-Host ""
            Write-ColorLine "  [0] Skip (manual setup)" Yellow
            Write-Host ""
            Write-ColorLine "Tip: Enter multiple numbers separated by commas (e.g., 2,3,4)" Gray
            Write-Host ""

            $modChoice = Read-Host "Select mod(s)"

            if ($modChoice -eq "1") {
                # All mods
                $Config.ModFolder = ($localMods | ForEach-Object { $_.Folder }) -join ","
                $Config.ModFolders = $localMods | ForEach-Object { $_.Folder }
                $Config.ModNames = ($localMods | ForEach-Object { $_.Name }) -join ", "
                Write-ColorLine "[OK] All $($localMods.Count) mods selected" Green
            } elseif ($modChoice -match '^[\d,\s]+$') {
                # Parse comma-separated numbers (offset by 1 since individual mods start at 2)
                $selections = $modChoice -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
                $selectedMods = @()
                $selectedFolders = @()
                $selectedNames = @()

                foreach ($sel in $selections) {
                    $idx = $sel - 2  # Offset since mods start at option 2
                    if ($idx -ge 0 -and $idx -lt $localMods.Count) {
                        $selectedMods += $localMods[$idx]
                        $selectedFolders += $localMods[$idx].Folder
                        $selectedNames += $localMods[$idx].Name
                    }
                }

                if ($selectedMods.Count -gt 0) {
                    $Config.ModFolder = $selectedFolders -join ","
                    $Config.ModFolders = $selectedFolders
                    $Config.ModNames = $selectedNames -join ", "
                    Write-ColorLine "[OK] Selected $($selectedMods.Count) mod(s):" Green
                    foreach ($mod in $selectedMods) {
                        Write-ColorLine "    - $($mod.Name)" Gray
                    }
                }
            } elseif ($modChoice -ne "0") {
                Write-ColorLine "[SKIP] No valid selection" Yellow
            }
        } else {
            Write-ColorLine "No local development mods found." Yellow
            Write-ColorLine "Workshop mods are ignored (you can't edit those)." Gray
        }
    } else {
        Write-ColorLine "Mod folder not found: $modPath" Yellow
    }

    Write-Host ""

    # Step 3: Detect and select log prefix(es)
    Write-ColorLine "Step 3: Set Your Log Prefix(es)" Cyan
    Write-Host ""

    # Scan selected mod folders for log prefixes
    $detectedPrefixes = @{}
    $foldersToScan = @()

    # Rebuild modPath to ensure it's in scope
    $modBasePath = Join-Path $selectedPath "mod"

    if ($Config.ModFolder) {
        $foldersToScan = $Config.ModFolder -split ','
    }

    if ($foldersToScan.Count -gt 0) {
        Write-ColorLine "Scanning mods for log prefixes..." Cyan

        foreach ($folder in $foldersToScan) {
            $scanPath = Join-Path $modBasePath $folder
            Write-ColorLine "  Scanning: $scanPath" Gray
            if (Test-Path $scanPath) {
                $txtFiles = Get-ChildItem $scanPath -Recurse -Filter "*.txt" -File -ErrorAction SilentlyContinue
                Write-ColorLine "  Found $($txtFiles.Count) files" Gray
                foreach ($file in $txtFiles) {
                    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
                    if ($content) {
                        # Find log = "[PREFIX]" or log = "PREFIX:" or log = "PREFIX " patterns
                        # Pattern 1: [PREFIX] in brackets
                        $matches1 = [regex]::Matches($content, 'log\s*=\s*"\[([A-Za-z0-9_]+)\]')
                        foreach ($match in $matches1) {
                            $prefix = $match.Groups[1].Value.ToUpper()
                            if ($prefix.Length -ge 2 -and $prefix.Length -le 10) {
                                if (-not $detectedPrefixes.ContainsKey($prefix)) {
                                    $detectedPrefixes[$prefix] = 0
                                }
                                $detectedPrefixes[$prefix]++
                            }
                        }
                        # Pattern 2: PREFIX: or PREFIX  at start (e.g., "LN:" or "LN ")
                        $matches2 = [regex]::Matches($content, 'log\s*=\s*"([A-Z][A-Z0-9_]{1,8})[\s:]')
                        foreach ($match in $matches2) {
                            $prefix = $match.Groups[1].Value.ToUpper()
                            if ($prefix.Length -ge 2 -and $prefix.Length -le 10) {
                                if (-not $detectedPrefixes.ContainsKey($prefix)) {
                                    $detectedPrefixes[$prefix] = 0
                                }
                                $detectedPrefixes[$prefix]++
                            }
                        }
                    }
                }
            }
        }
    }

    $prefixList = @($detectedPrefixes.Keys | Sort-Object { $detectedPrefixes[$_] } -Descending)

    if ($prefixList.Count -gt 0) {
        Write-ColorLine "Detected log prefixes:" Green
        Write-Host ""
        # Option 1 = All prefixes (recommended)
        Write-ColorLine "  [1] ALL PREFIXES (Recommended)" Green
        Write-Host ""
        # Individual prefixes start at 2
        for ($i = 0; $i -lt $prefixList.Count -and $i -lt 10; $i++) {
            $p = $prefixList[$i]
            Write-ColorLine "  [$($i+2)] $p  ($($detectedPrefixes[$p]) occurrences)" White
        }
        Write-Host ""
        Write-ColorLine "  [0] Enter manually" Yellow
        Write-Host ""

        $prefixChoice = Read-Host "Select prefix(es) (e.g., 1 or 2,3,4)"

        if ($prefixChoice -eq "1") {
            $Config.ModPrefix = $prefixList -join "|"
            Write-ColorLine "[OK] All prefixes: $($Config.ModPrefix)" Green
        } elseif ($prefixChoice -eq "0") {
            $manualPrefix = Read-Host "Enter prefix(es) manually"
            if ($manualPrefix) {
                $Config.ModPrefix = ($manualPrefix -split '[,\s]+' | ForEach-Object { $_.Trim().ToUpper() } | Where-Object { $_ }) -join "|"
            }
            Write-ColorLine "[OK] Prefix set: $($Config.ModPrefix)" Green
        } elseif ($prefixChoice -match '^[\d,\s]+$') {
            $selections = $prefixChoice -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
            $selectedPrefixes = @()
            foreach ($sel in $selections) {
                $idx = $sel - 2  # Offset since prefixes start at option 2
                if ($idx -ge 0 -and $idx -lt $prefixList.Count) {
                    $selectedPrefixes += $prefixList[$idx]
                }
            }
            if ($selectedPrefixes.Count -gt 0) {
                $Config.ModPrefix = $selectedPrefixes -join "|"
                Write-ColorLine "[OK] Prefix set: $($Config.ModPrefix)" Green
            }
        }
    } else {
        Write-ColorLine "No prefixes auto-detected. Enter manually:" Yellow
        Write-ColorLine "Example: log = [LN] message  -->  enter: LN" Gray
        Write-Host ""
        $manualPrefix = Read-Host "Log prefix(es)"
        if ($manualPrefix) {
            $Config.ModPrefix = ($manualPrefix -split '[,\s]+' | ForEach-Object { $_.Trim().ToUpper() } | Where-Object { $_ }) -join "|"
        }
        Write-ColorLine "[OK] Prefix set: $($Config.ModPrefix)" Green
    }

    Write-Host ""

    # Step 4: Common Stellaris modding errors to watch
    Write-ColorLine "Step 4: Stellaris Error Patterns" Cyan
    Write-Host ""
    Write-ColorLine "================================================================" Yellow
    Write-ColorLine "  NOTE: These patterns are monitored IN ADDITION TO your" White
    Write-ColorLine "  mod prefix ($($Config.ModPrefix)). Default patterns help" White
    Write-ColorLine "  catch common Stellaris scripting errors." White
    Write-ColorLine "================================================================" Yellow
    Write-Host ""
    Write-ColorLine "Common Stellaris modding errors to monitor:" White
    Write-Host ""
    Write-ColorLine "  [1] ALL PATTERNS (Recommended)" Green
    Write-Host ""
    Write-ColorLine "  [2] Script Errors" Yellow
    Write-ColorLine "      undefined, Unknown, Invalid, not found" Gray
    Write-Host ""
    Write-ColorLine "  [3] Missing References" Yellow
    Write-ColorLine "      missing, expected, Could not find" Gray
    Write-Host ""
    Write-ColorLine "  [4] Trigger/Effect Errors" Yellow
    Write-ColorLine "      Unexpected, invalid trigger, invalid effect" Gray
    Write-Host ""
    Write-ColorLine "  [5] Scope Errors" Yellow
    Write-ColorLine "      wrong scope, no scope, invalid scope" Gray
    Write-Host ""
    Write-ColorLine "  [6] Localisation" Yellow
    Write-ColorLine "      Missing localization, no localization" Gray
    Write-Host ""
    Write-ColorLine "  [0] None / Skip" White
    Write-Host ""

    Write-ColorLine "Tip: Combine options with commas (e.g., 2,3,5)" Gray
    Write-Host ""

    $patternChoice = Read-Host "Select (1-6 or 0)"

    # Define pattern sets
    $patternSets = @{
        "1" = @("undefined", "Unknown", "Invalid", "not found", "missing", "expected", "Unexpected", "invalid trigger", "invalid effect", "wrong scope", "no scope", "Could not")
        "2" = @("undefined", "Unknown", "Invalid", "not found")
        "3" = @("missing", "expected", "Could not find", "Could not open")
        "4" = @("Unexpected", "invalid trigger", "invalid effect", "is not valid")
        "5" = @("wrong scope", "no scope", "invalid scope", "scope mismatch")
        "6" = @("Missing localization", "no localization", "MISSING")
    }

    $extraPatterns = @()

    if ($patternChoice -eq "1") {
        # All patterns
        $extraPatterns = $patternSets["1"]
    } elseif ($patternChoice -match '^[\d,\s]+$' -and $patternChoice -ne "0") {
        # Parse comma-separated selections
        $selections = $patternChoice -split '[,\s]+' | Where-Object { $_ -match '^[2-6]$' } | Select-Object -Unique
        foreach ($sel in $selections) {
            $extraPatterns += $patternSets[$sel]
        }
        $extraPatterns = $extraPatterns | Select-Object -Unique
    }

    if ($extraPatterns.Count -gt 0) {
        $Config.ExtraPatterns = $extraPatterns
        Write-ColorLine "[OK] Monitoring $($extraPatterns.Count) error patterns" Green
    } else {
        Write-ColorLine "[OK] No extra patterns selected" Yellow
    }

    # Save config
    Save-Config

    Write-Host ""
    Write-ColorLine "================================================================" Green
    Write-ColorLine "  [OK] Configuration Saved!" Green
    Write-ColorLine "================================================================" Green
    Write-Host ""
    Write-ColorLine "Test your setup:" Cyan
    Write-ColorLine "  .\stelmod-debug.ps1 all      # Full log check" White
    Write-ColorLine "  .\stelmod-debug.ps1 errors   # Just errors" White
    Write-ColorLine "  .\stelmod-debug.ps1 game     # Just game log" White
    Write-Host ""

    # Step 5: Offer to launch live monitor
    Write-ColorLine "================================================================" Cyan
    Write-ColorLine "  LIVE LOG MONITOR" White
    Write-ColorLine "================================================================" Cyan
    Write-Host ""
    Write-ColorLine "Would you like to open a LIVE log monitor window?" White
    Write-ColorLine "This will watch your game.log in real-time as you play." Gray
    Write-Host ""
    Write-ColorLine "  [Y] Yes - Open live monitor now" Green
    Write-ColorLine "  [N] No  - I will run manually later" Yellow
    Write-Host ""

    $monitorChoice = Read-Host "Launch live monitor? (Y/N)"

    if ($monitorChoice -eq "Y" -or $monitorChoice -eq "y") {
        Start-LiveMonitor
        Start-FocusWindow
        Write-ColorLine "[OK] Monitor windows launched!" Green
        Write-Host ""

        # Show status in this window (Window 1 - Config/Status)
        Show-ConfigStatus
    } else {
        Write-ColorLine "[OK] You can run 'stelmod-debug.bat monitor' anytime to start it" Cyan
    }
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Config Status Display (Window 1 - stays open)
# ---------------------------------------------------------------------------

function Show-ConfigStatus {
    Write-Host ""
    Write-ColorLine "================================================================" Green
    Write-ColorLine "  CONFIGURATION STATUS - Keep this window open" White
    Write-ColorLine "================================================================" Green
    Write-Host ""
    Write-ColorLine "  Mod:      $($Config.ModNames)" Cyan
    Write-ColorLine "  Prefix:   [$($Config.ModPrefix)]" Cyan
    Write-ColorLine "  Patterns: $($Config.ExtraPatterns.Count) error patterns" Yellow
    Write-Host ""
    Write-ColorLine "  Stellaris: $($Config.StellarisDocs)" Gray
    Write-Host ""
    Write-ColorLine "----------------------------------------------------------------" DarkGray
    Write-Host ""
    Write-ColorLine "  [Window 2] LOG WATCHER  - game.log + error.log combined" Cyan
    Write-ColorLine "  [Window 3] FOCUS ALERTS - Critical issues popup" Yellow
    Write-Host ""
    Write-ColorLine "----------------------------------------------------------------" DarkGray
    Write-Host ""
    Write-ColorLine "  Press any key to return to menu..." Gray
    Write-Host ""
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ---------------------------------------------------------------------------
# Live Monitor Function (Window 2 - Combined game.log + error.log)
# ---------------------------------------------------------------------------

function Start-LiveMonitor {
    $gameLog = Join-Path $Config.StellarisDocs "logs\game.log"
    $errorLog = Join-Path $Config.StellarisDocs "logs\error.log"
    $prefix = $Config.ModPrefix
    $modFolder = $Config.ModFolder  # For error filtering

    # Get mod name for display
    $modName = "Unknown Mod"
    if ($Config.ModNames) {
        $modName = $Config.ModNames
    } elseif ($Config.ModFolder) {
        $modName = $Config.ModFolder -replace ',', ', '
    }

    # Get pattern count
    $patternCount = 0
    if ($Config.ExtraPatterns) {
        $patternCount = $Config.ExtraPatterns.Count
    }

    # Build the combined monitor script
    $monitorScript = @"
`$Host.UI.RawUI.WindowTitle = '[2] LOG WATCHER - $modName'
Write-Host ''
Write-Host '================================================================' -ForegroundColor Cyan
Write-Host '  [WINDOW 2] LOG WATCHER - Combined Logs' -ForegroundColor White
Write-Host '================================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host '  Mod:      $modName' -ForegroundColor Green
Write-Host '  Folder:   $modFolder' -ForegroundColor Cyan
Write-Host ''
Write-Host '  Watching: game.log + error.log' -ForegroundColor Gray
Write-Host '  Filter:   Errors with mod folder only' -ForegroundColor Magenta
Write-Host '================================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Press Ctrl+C to stop' -ForegroundColor Yellow
Write-Host ''
Write-Host '----------------------------------------------------------------' -ForegroundColor DarkGray
Write-Host ''

# Check if Stellaris is running
`$stellarisRunning = Get-Process -Name 'stellaris' -ErrorAction SilentlyContinue
if (-not `$stellarisRunning) {
    Write-Host '[!] Stellaris is NOT running' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  [1] Launch Stellaris (Steam)' -ForegroundColor Green
    Write-Host '  [2] Continue without launching' -ForegroundColor White
    Write-Host ''
    `$launchChoice = Read-Host 'Select (1 or 2)'

    if (`$launchChoice -eq '1') {
        Write-Host ''
        Write-Host 'Launching Stellaris via Steam...' -ForegroundColor Cyan
        Start-Process 'steam://rungameid/281990'
        Write-Host '[OK] Game launching! Waiting for logs...' -ForegroundColor Green
        Write-Host ''
    }
    Write-Host '----------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host ''
} else {
    Write-Host '[OK] Stellaris is running - monitoring...' -ForegroundColor Green
    Write-Host ''
}

# Monitor both logs using jobs
`$gameJob = Start-Job -ScriptBlock {
    param(`$path, `$prefix)
    Get-Content -Path `$path -Wait -Tail 5 | ForEach-Object {
        if (`$_ -match "\[`$prefix\]" -or `$_ -match "`$prefix[\s:]") {
            Write-Output "GAME|`$_"
        }
    }
} -ArgumentList '$gameLog', '$prefix'

# ERROR JOB: Only match errors from YOUR mod (by folder name)
# Dynamic - uses mod folder from config
`$errorJob = Start-Job -ScriptBlock {
    param(`$path, `$modFolder)
    Get-Content -Path `$path -Wait -Tail 5 | ForEach-Object {
        # Simple check: does error contain mod folder name?
        if (`$_ -like "*`$modFolder*") {
            Write-Output "ERROR|`$_"
        }
    }
} -ArgumentList '$errorLog', '$modFolder'

while (`$true) {
    # Check game log job
    `$gameOutput = Receive-Job -Job `$gameJob
    foreach (`$line in `$gameOutput) {
        `$content = `$line -replace '^GAME\|', ''
        if (`$content -match 'ERROR|FAIL') {
            Write-Host "[GAME] `$content" -ForegroundColor Red
        } elseif (`$content -match 'WARNING|WARN') {
            Write-Host "[GAME] `$content" -ForegroundColor Yellow
        } elseif (`$content -match 'SUCCESS|COMPLETE') {
            Write-Host "[GAME] `$content" -ForegroundColor Green
        } else {
            Write-Host "[GAME] `$content" -ForegroundColor Cyan
        }
    }

    # Check error log job
    `$errorOutput = Receive-Job -Job `$errorJob
    foreach (`$line in `$errorOutput) {
        `$content = `$line -replace '^ERROR\|', ''
        Write-Host "[ERR!] `$content" -ForegroundColor Red
    }

    Start-Sleep -Milliseconds 500
}
"@

    # Encode the script for passing to new PowerShell window
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($monitorScript)
    $encodedCommand = [Convert]::ToBase64String($bytes)

    # Launch new PowerShell window with the monitor
    Start-Process powershell.exe -ArgumentList "-NoExit", "-EncodedCommand", $encodedCommand
}

# ---------------------------------------------------------------------------
# Focus Window Function (Window 3 - Critical Alerts)
# ---------------------------------------------------------------------------

function Start-FocusWindow {
    $errorLog = Join-Path $Config.StellarisDocs "logs\error.log"
    $gameLog = Join-Path $Config.StellarisDocs "logs\game.log"
    $prefix = $Config.ModPrefix
    $modFolder = $Config.ModFolder  # For error filtering

    # Get mod name for display
    $modName = "Unknown Mod"
    if ($Config.ModNames) {
        $modName = $Config.ModNames
    }

    # Build the focus alert script
    $focusScript = @"
`$Host.UI.RawUI.WindowTitle = '[3] FOCUS ALERTS - $modName'
Write-Host ''
Write-Host '================================================================' -ForegroundColor Yellow
Write-Host '  [WINDOW 3] FOCUS ALERTS - Critical Issues Only' -ForegroundColor White
Write-Host '================================================================' -ForegroundColor Yellow
Write-Host ''
Write-Host '  Mod:      $modName' -ForegroundColor Green
Write-Host '  Folder:   $modFolder' -ForegroundColor Cyan
Write-Host ''
Write-Host '  Shows: ERRORS from YOUR mod only' -ForegroundColor Red
Write-Host '  (Vanilla errors filtered out)' -ForegroundColor DarkGray
Write-Host '  Silent when everything is OK' -ForegroundColor Gray
Write-Host ''
Write-Host '================================================================' -ForegroundColor Yellow
Write-Host ''
Write-Host 'Waiting for issues...' -ForegroundColor DarkGray
Write-Host ''

`$alertCount = 0
`$modFolder = '$modFolder'

# Monitor error.log for critical issues FROM YOUR MOD ONLY
# Simple check: does error contain mod folder name?
Get-Content -Path '$errorLog' -Wait -Tail 0 | ForEach-Object {
    if (`$_ -like "*`$modFolder*") {
        `$alertCount++
        Write-Host ''
        Write-Host '!!! ALERT #' -NoNewline -ForegroundColor Red
        Write-Host `$alertCount -NoNewline -ForegroundColor White
        Write-Host ' !!!' -ForegroundColor Red
        Write-Host '----------------------------------------------------------------' -ForegroundColor Red
        Write-Host `$_ -ForegroundColor Yellow
        Write-Host '----------------------------------------------------------------' -ForegroundColor Red
        Write-Host ''

        # Flash/beep for attention
        [Console]::Beep(800, 200)
    }
}
"@

    # Encode and launch
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($focusScript)
    $encodedCommand = [Convert]::ToBase64String($bytes)
    Start-Process powershell.exe -ArgumentList "-NoExit", "-EncodedCommand", $encodedCommand
}

# ---------------------------------------------------------------------------
# Command: Errors
# ---------------------------------------------------------------------------

function Invoke-Errors {
    Load-Config | Out-Null
    if (-not (Test-Config)) { return }

    Write-Header
    Write-Section "Error Log - Mod-Related Entries"

    $paths = Get-LogPaths
    Write-ColorLine "File: $($paths.ErrorLog)" Gray
    Write-ColorLine "Filter: $($Config.ModPrefix) (case-insensitive)" Gray
    Write-Host ""

    if (-not (Test-Path $paths.ErrorLog)) {
        Write-ColorLine "No error log found. Game may not have been run yet." Yellow
        return
    }

    $pattern = $Config.ModPrefix
    $matchResults = Select-String -Path $paths.ErrorLog -Pattern $pattern -AllMatches |
               Select-Object -Last $Config.TailLines

    if ($matchResults.Count -eq 0) {
        Write-ColorLine "[OK] No errors found matching $($Config.ModPrefix)" Green
    } else {
        $total = (Select-String -Path $paths.ErrorLog -Pattern $pattern -AllMatches).Count
        Write-ColorLine "Found $total error(s) matching $($Config.ModPrefix):" Red
        Write-Host ""

        foreach ($m in $matchResults) {
            $line = $m.Line
            if ($line -match "Error|ERROR") {
                Write-ColorLine $line Red
            } elseif ($line -match "Warning|WARNING") {
                Write-ColorLine $line Yellow
            } else {
                Write-ColorLine $line White
            }
        }
    }
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: Game
# ---------------------------------------------------------------------------

function Invoke-Game {
    Load-Config | Out-Null
    if (-not (Test-Config)) { return }

    Write-Header
    Write-Section "Game Log - Mod Entries"

    $paths = Get-LogPaths
    Write-ColorLine "File: $($paths.GameLog)" Gray
    Write-ColorLine "Filter: [$($Config.ModPrefix)]" Gray
    Write-Host ""

    if (-not (Test-Path $paths.GameLog)) {
        Write-ColorLine "No game log found. Game may not have been run yet." Yellow
        return
    }

    $pattern = "\[$($Config.ModPrefix)\]"
    $matchResults = Select-String -Path $paths.GameLog -Pattern $pattern -AllMatches |
               Select-Object -Last $Config.TailLines

    if ($matchResults.Count -eq 0) {
        Write-ColorLine "No entries found matching [$($Config.ModPrefix)]" Yellow
        Write-ColorLine "Tip: Run your mod init event in-game to generate logs" Gray
    } else {
        $total = (Select-String -Path $paths.GameLog -Pattern $pattern -AllMatches).Count
        Write-ColorLine "Found $total entries matching [$($Config.ModPrefix)]:" Cyan
        Write-Host ""

        foreach ($m in $matchResults) {
            $line = $m.Line
            if ($line -match "ERROR|FAIL") {
                Write-ColorLine $line Red
            } elseif ($line -match "WARNING|WARN") {
                Write-ColorLine $line Yellow
            } elseif ($line -match "SUCCESS|COMPLETE") {
                Write-ColorLine $line Green
            } elseif ($line -match "DEBUG") {
                Write-ColorLine $line Magenta
            } else {
                Write-ColorLine $line White
            }
        }
    }

    # Check extra patterns
    if ($Config.ExtraPatterns -and $Config.ExtraPatterns.Count -gt 0) {
        Write-Host ""
        Write-Section "Extra Pattern Matches"

        $extraPattern = $Config.ExtraPatterns -join "|"
        $extraResults = Select-String -Path $paths.GameLog -Pattern $extraPattern -AllMatches |
                        Select-Object -Last 20

        if ($extraResults.Count -gt 0) {
            foreach ($m in $extraResults) {
                Write-ColorLine $m.Line Yellow
            }
        } else {
            Write-ColorLine "No matches for extra patterns" Green
        }
    }

    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: Fresh
# ---------------------------------------------------------------------------

function Invoke-Fresh {
    Load-Config | Out-Null
    if (-not (Test-Config)) { return }

    Write-Header
    Write-Section "Log Freshness Check"
    Write-Host ""

    $paths = Get-LogPaths

    # Get log timestamp
    if (Test-Path $paths.GameLog) {
        $logTime = (Get-Item $paths.GameLog).LastWriteTime
        Write-ColorLine "Game Log:  $($logTime.ToString('yyyy-MM-dd HH:mm:ss'))" Cyan
    } else {
        Write-ColorLine "Game log not found" Red
        return
    }

    # Get mod folder timestamp
    if ($Config.ModFolder) {
        $modPath = Join-Path $Config.StellarisDocs "mod\$($Config.ModFolder)"
        if (Test-Path $modPath) {
            $newestFile = Get-ChildItem $modPath -Recurse -File -Filter "*.txt" |
                          Sort-Object LastWriteTime -Descending |
                          Select-Object -First 1

            if ($newestFile) {
                $modTime = $newestFile.LastWriteTime
                Write-ColorLine "Mod Sync:  $($modTime.ToString('yyyy-MM-dd HH:mm:ss'))" Cyan
                Write-ColorLine "  Latest: $($newestFile.Name)" Gray
                Write-Host ""

                if ($logTime -gt $modTime) {
                    Write-ColorLine "[OK] FRESH - Logs are AFTER mod sync" Green
                } else {
                    Write-ColorLine "[!] STALE - Logs are BEFORE mod sync" Red
                    Write-ColorLine "    Reload game to get fresh logs" Yellow
                }
            }
        } else {
            Write-ColorLine "Mod folder not found: $modPath" Yellow
        }
    } else {
        Write-ColorLine "Configure ModFolder for freshness comparison" Gray
    }

    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: All
# ---------------------------------------------------------------------------

function Invoke-All {
    Invoke-Fresh
    Invoke-Errors
    Invoke-Game
}

# ---------------------------------------------------------------------------
# Command: Summary
# ---------------------------------------------------------------------------

function Invoke-Summary {
    Load-Config | Out-Null
    if (-not (Test-Config)) { return }

    Write-Header
    Write-Section "Log Summary"
    Write-Host ""

    $paths = Get-LogPaths

    # Count errors
    if (Test-Path $paths.ErrorLog) {
        $errorCount = (Select-String -Path $paths.ErrorLog -Pattern $Config.ModPrefix -AllMatches).Count
        if ($errorCount -gt 0) {
            Write-ColorLine "[!] Errors:      $errorCount" Red
        } else {
            Write-ColorLine "[OK] Errors:     0" Green
        }
    }

    # Count game log entries
    if (Test-Path $paths.GameLog) {
        $pattern = "\[$($Config.ModPrefix)\]"
        $gameEntries = Select-String -Path $paths.GameLog -Pattern $pattern -AllMatches
        $gameCount = $gameEntries.Count
        Write-ColorLine "Log entries: $gameCount" Cyan

        if ($gameCount -gt 0) {
            $warnCount = ($gameEntries | Where-Object { $_.Line -match "WARNING|WARN" }).Count
            $failCount = ($gameEntries | Where-Object { $_.Line -match "FAIL|ERROR" }).Count
            $successCount = ($gameEntries | Where-Object { $_.Line -match "SUCCESS|COMPLETE" }).Count

            Write-ColorLine "Warnings:    $warnCount" Yellow
            Write-ColorLine "Failures:    $failCount" Red
            Write-ColorLine "Success:     $successCount" Green
        }
    }

    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: Monitor
# ---------------------------------------------------------------------------

function Invoke-Monitor {
    Load-Config | Out-Null
    if (-not (Test-Config)) { return }

    Write-Header
    Write-Section "Launching Live Monitor (2 Windows)"
    Write-Host ""
    Write-ColorLine "Opening monitor windows..." Cyan
    Write-ColorLine "Mod: $($Config.ModNames)" Gray
    Write-ColorLine "Prefix: [$($Config.ModPrefix)]" Gray
    Write-Host ""

    Start-LiveMonitor
    Start-FocusWindow

    Write-ColorLine "[OK] 2 Monitor windows opened!" Green
    Write-ColorLine "     [Window 2] LOG WATCHER  - game.log + error.log" Cyan
    Write-ColorLine "     [Window 3] FOCUS ALERTS - Critical errors with beep" Yellow
    Write-ColorLine "" White
    Write-ColorLine "     Press Ctrl+C in those windows to stop monitoring" Gray
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Command: Help
# ---------------------------------------------------------------------------

function Invoke-Help {
    Write-Header
    Write-Host "USAGE:" -ForegroundColor White
    Write-Host "  .\stelmod-debug.ps1 [command]"
    Write-Host ""
    Write-Host "COMMANDS:" -ForegroundColor White
    Write-ColorLine "  setup     Configure with GUI folder picker" Cyan
    Write-ColorLine "  errors    Show error log entries for your mod" Cyan
    Write-ColorLine "  game      Show game log entries matching mod prefix" Cyan
    Write-ColorLine "  all       Show freshness + errors + game logs" Cyan
    Write-ColorLine "  fresh     Check if logs are fresh vs mod sync time" Cyan
    Write-ColorLine "  summary   Quick stats on log contents" Cyan
    Write-ColorLine "  monitor   Open LIVE log monitor in new window" Yellow
    Write-ColorLine "  help      Show this help message" Cyan
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor White
    Write-Host "  .\stelmod-debug.ps1 setup    # First-time configuration"
    Write-Host "  .\stelmod-debug.ps1 all      # Full log check"
    Write-Host "  .\stelmod-debug.ps1 game     # Game log only"
    Write-Host ""
    Write-Host "FIRST TIME?" -ForegroundColor Yellow
    Write-Host "  Run: .\stelmod-debug.ps1 setup"
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Load config if exists
Load-Config | Out-Null

# Update tail lines from parameter
if ($Lines -gt 0) {
    $Config.TailLines = $Lines
}

# Execute command
switch ($Command.ToLower()) {
    "setup"   { Invoke-Setup }
    "errors"  { Invoke-Errors }
    "game"    { Invoke-Game }
    "all"     { Invoke-All }
    "fresh"   { Invoke-Fresh }
    "summary" { Invoke-Summary }
    "monitor" { Invoke-Monitor }
    "help"    { Invoke-Help }
    default   {
        Write-ColorLine "Unknown command: $Command" Red
        Write-Host "Run: .\stelmod-debug.ps1 help"
    }
}
