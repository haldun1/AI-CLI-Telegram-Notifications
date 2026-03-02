<#
.SYNOPSIS
Uninstall wizard for AI-CLI-Telegram-Notifications.

.DESCRIPTION
Removes hooks, optional script files, optional profile toggles, and optional
Telegram environment variables added by this project.
#>

$ErrorActionPreference = "Stop"
$HomeDir = [System.Environment]::GetFolderPath("UserProfile")

function Confirm-Choice {
    param(
        [Parameter(Mandatory = $true)] [string]$Prompt,
        [bool]$DefaultYes = $true
    )

    $hint = if ($DefaultYes) { "(Y/n)" } else { "(y/N)" }
    do {
        $inputValue = Read-Host "$Prompt $hint"
        if ([string]::IsNullOrWhiteSpace($inputValue)) {
            return $DefaultYes
        }
        if ($inputValue -match "^[Yy]$") { return $true }
        if ($inputValue -match "^[Nn]$") { return $false }
        Write-Host "Please answer with Y or N." -ForegroundColor Red
    } while ($true)
}

function Backup-File {
    param([Parameter(Mandatory = $true)] [string]$Path)
    $backupPath = "$Path.bak.$((Get-Date).ToString('yyyyMMddHHmmss'))"
    Copy-Item -Path $Path -Destination $backupPath -Force
    return $backupPath
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] $Object,
        [int]$Depth = 10
    )

    $json = $Object | ConvertTo-Json -Depth $Depth
    $json = $json -replace '":\s{2,}', '": '
    Set-Content -Path $Path -Value $json -Encoding UTF8
}

$script:Removed = @()
$script:Skipped = @()
$script:Failed = @()

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " AI CLI Telegram Notifications - Uninstall Wizard" -ForegroundColor Cyan
Write-Host "==================================================`n" -ForegroundColor Cyan

$CodexDir = Join-Path $HomeDir ".codex"
$ClaudeDir = Join-Path $HomeDir ".claude"
$GeminiDir = Join-Path $HomeDir ".gemini"
$CodexConfig = Join-Path $CodexDir "config.toml"
$ClaudeConfig = Join-Path $ClaudeDir "settings.json"
$GeminiConfig = Join-Path $GeminiDir "settings.json"
$ProfilePath = $PROFILE

Write-Host "Detected paths:" -ForegroundColor Yellow
Write-Host "  Codex config:  $CodexConfig (exists: $(Test-Path $CodexConfig))"
Write-Host "  Claude config: $ClaudeConfig (exists: $(Test-Path $ClaudeConfig))"
Write-Host "  Gemini config: $GeminiConfig (exists: $(Test-Path $GeminiConfig))"
Write-Host "  Profile:       $ProfilePath (exists: $(Test-Path $ProfilePath))"
Write-Host ""

Write-Host "Choose which CLI tool(s) to uninstall:" -ForegroundColor Yellow
Write-Host "  1) All detected tools"
Write-Host "  2) Codex only"
Write-Host "  3) Claude only"
Write-Host "  4) Gemini only"

$SelectionMap = @{
    "1" = "All"
    "2" = "Codex"
    "3" = "Claude"
    "4" = "Gemini"
}

do {
    $choice = Read-Host "Enter 1, 2, 3, or 4"
    $SelectedTarget = $SelectionMap[$choice]
    if (-not $SelectedTarget) {
        Write-Host "Invalid choice. Please enter 1, 2, 3, or 4." -ForegroundColor Red
    }
} while (-not $SelectedTarget)

$DoCodex = $SelectedTarget -in @("All", "Codex")
$DoClaude = $SelectedTarget -in @("All", "Claude")
$DoGemini = $SelectedTarget -in @("All", "Gemini")

$RemoveHooks = Confirm-Choice -Prompt "Remove hook/config entries from selected tools?" -DefaultYes $true
$RemoveScripts = Confirm-Choice -Prompt "Remove installed notifier script files from selected tools?" -DefaultYes $true
$RemoveProfileToggles = Confirm-Choice -Prompt "Remove tg-on/tg-off toggle block from your PowerShell profile?" -DefaultYes $true
$RemoveEnvVars = Confirm-Choice -Prompt "Clear TELEGRAM_* user environment variables?" -DefaultYes $false

# ---------------------------------------------------------------------------
# Codex cleanup
# ---------------------------------------------------------------------------
if ($DoCodex -and $RemoveHooks) {
    if (Test-Path $CodexConfig) {
        try {
            $content = Get-Content $CodexConfig -Raw
            $original = $content

            $content = [regex]::Replace(
                $content,
                '(?mi)^notify\s*=\s*\[.*(?:codex-telegram-notify\.ps1|telegram-notify\.ps1).*\]\s*\r?\n?',
                ""
            )

            $notificationsMatch = [regex]::Match($content, '(?m)^notifications\s*=\s*\[(?<items>[^\]]*)\]\s*$')
            if ($notificationsMatch.Success) {
                $items = @(
                    $notificationsMatch.Groups["items"].Value -split "," |
                    ForEach-Object { $_.Trim() } |
                    Where-Object { $_ -ne "" }
                )
                $remaining = @($items | Where-Object { $_ -ne '"agent-turn-complete"' })
                if ($remaining.Count -ne $items.Count) {
                    if ($remaining.Count -eq 0) {
                        $content = $content.Remove($notificationsMatch.Index, $notificationsMatch.Length)
                    } else {
                        $newLine = "notifications = [$($remaining -join ', ')]"
                        $content = $content.Remove($notificationsMatch.Index, $notificationsMatch.Length).Insert($notificationsMatch.Index, $newLine)
                    }
                }
            }

            if ($content -ne $original) {
                $bak = Backup-File -Path $CodexConfig
                Set-Content -Path $CodexConfig -Value $content -Encoding UTF8
                $script:Removed += "Codex config entries removed ($CodexConfig)"
                $script:Removed += "Backup created: $bak"
            } else {
                $script:Skipped += "Codex config had no project entries to remove"
            }
        } catch {
            $script:Failed += "Codex config cleanup failed: $($_.Exception.Message)"
        }
    } else {
        $script:Skipped += "Codex config not found"
    }
}

if ($DoCodex -and $RemoveScripts) {
    $codexScripts = @(
        (Join-Path $CodexDir "codex-telegram-notify.ps1"),
        (Join-Path $CodexDir "telegram-notify.ps1")
    )
    foreach ($path in $codexScripts) {
        if (Test-Path $path) {
            try {
                Remove-Item -Path $path -Force
                $script:Removed += "Removed file: $path"
            } catch {
                $script:Failed += "Failed removing ${path}: $($_.Exception.Message)"
            }
        } else {
            $script:Skipped += "File not found: $path"
        }
    }
}

# ---------------------------------------------------------------------------
# Claude cleanup
# ---------------------------------------------------------------------------
if ($DoClaude -and $RemoveHooks) {
    if (Test-Path $ClaudeConfig) {
        try {
            $raw = Get-Content $ClaudeConfig -Raw -ErrorAction SilentlyContinue
            if ([string]::IsNullOrWhiteSpace($raw)) {
                $script:Skipped += "Claude settings.json is empty"
            } else {
                $settings = $raw | ConvertFrom-Json
                $changed = $false
                if ($null -ne $settings.hooks -and $null -ne $settings.hooks.Stop) {
                    $newStop = @()
                    foreach ($entry in @($settings.hooks.Stop)) {
                        $hasProjectHook = $false
                        foreach ($hook in @($entry.hooks)) {
                            if ($hook.command -match "claude-telegram-notify\.ps1") {
                                $hasProjectHook = $true
                            }
                        }
                        if ($hasProjectHook) {
                            $changed = $true
                        } else {
                            $newStop += $entry
                        }
                    }
                    $settings.hooks.Stop = @($newStop)
                }

                if ($changed) {
                    $bak = Backup-File -Path $ClaudeConfig
                    Write-JsonFile -Path $ClaudeConfig -Object $settings -Depth 10
                    $script:Removed += "Claude hook entries removed ($ClaudeConfig)"
                    $script:Removed += "Backup created: $bak"
                } else {
                    $script:Skipped += "Claude config had no project hook entries to remove"
                }
            }
        } catch {
            $bak = Backup-File -Path $ClaudeConfig
            $script:Failed += "Claude config parse/cleanup failed; backup created: $bak"
        }
    } else {
        $script:Skipped += "Claude config not found"
    }
}

if ($DoClaude -and $RemoveScripts) {
    $path = Join-Path $ClaudeDir "claude-telegram-notify.ps1"
    if (Test-Path $path) {
        try {
            Remove-Item -Path $path -Force
            $script:Removed += "Removed file: $path"
        } catch {
            $script:Failed += "Failed removing ${path}: $($_.Exception.Message)"
        }
    } else {
        $script:Skipped += "File not found: $path"
    }
}

# ---------------------------------------------------------------------------
# Gemini cleanup
# ---------------------------------------------------------------------------
if ($DoGemini -and $RemoveHooks) {
    if (Test-Path $GeminiConfig) {
        try {
            $raw = Get-Content $GeminiConfig -Raw -ErrorAction SilentlyContinue
            if ([string]::IsNullOrWhiteSpace($raw)) {
                $script:Skipped += "Gemini settings.json is empty"
            } else {
                $settings = $raw | ConvertFrom-Json
                $changed = $false
                if ($null -ne $settings.hooks -and $null -ne $settings.hooks.AfterAgent) {
                    $newAfterAgent = @()
                    foreach ($entry in @($settings.hooks.AfterAgent)) {
                        $hasProjectHook = $false
                        foreach ($hook in @($entry.hooks)) {
                            if ($hook.command -match "gemini-telegram-notify\.ps1") {
                                $hasProjectHook = $true
                            }
                        }
                        if ($hasProjectHook) {
                            $changed = $true
                        } else {
                            $newAfterAgent += $entry
                        }
                    }
                    $settings.hooks.AfterAgent = @($newAfterAgent)
                }

                if ($changed) {
                    $bak = Backup-File -Path $GeminiConfig
                    Write-JsonFile -Path $GeminiConfig -Object $settings -Depth 10
                    $script:Removed += "Gemini hook entries removed ($GeminiConfig)"
                    $script:Removed += "Backup created: $bak"
                } else {
                    $script:Skipped += "Gemini config had no project hook entries to remove"
                }
            }
        } catch {
            $bak = Backup-File -Path $GeminiConfig
            $script:Failed += "Gemini config parse/cleanup failed; backup created: $bak"
        }
    } else {
        $script:Skipped += "Gemini config not found"
    }
}

if ($DoGemini -and $RemoveScripts) {
    $path = Join-Path $GeminiDir "gemini-telegram-notify.ps1"
    if (Test-Path $path) {
        try {
            Remove-Item -Path $path -Force
            $script:Removed += "Removed file: $path"
        } catch {
            $script:Failed += "Failed removing ${path}: $($_.Exception.Message)"
        }
    } else {
        $script:Skipped += "File not found: $path"
    }
}

# ---------------------------------------------------------------------------
# Profile toggle cleanup
# ---------------------------------------------------------------------------
if ($RemoveProfileToggles) {
    if (Test-Path $ProfilePath) {
        try {
            $profileRaw = Get-Content $ProfilePath -Raw -ErrorAction SilentlyContinue
            $original = $profileRaw

            $managedPattern = '(?ms)^# AI-CLI-Telegram-Notifications Toggles\r?\n(?:function\s+tg-(?:on|off)\s*\{[^\r\n]*\}\r?\n?){1,4}'
            $profileRaw = [regex]::Replace($profileRaw, $managedPattern, "")

            $legacyPattern = '(?m)^\s*function\s+tg-(?:on|off)\s*\{[^\r\n]*TG_(?:ON|OFF)[^\r\n]*\}\s*\r?\n?'
            $profileRaw = [regex]::Replace($profileRaw, $legacyPattern, "")

            if ($profileRaw -ne $original) {
                $bak = Backup-File -Path $ProfilePath
                Set-Content -Path $ProfilePath -Value $profileRaw.TrimEnd() -Encoding UTF8
                $script:Removed += "Profile toggles removed ($ProfilePath)"
                $script:Removed += "Backup created: $bak"
            } else {
                $script:Skipped += "No project toggle block found in profile"
            }
        } catch {
            $script:Failed += "Profile cleanup failed: $($_.Exception.Message)"
        }
    } else {
        $script:Skipped += "PowerShell profile not found"
    }
}

# ---------------------------------------------------------------------------
# Environment variable cleanup
# ---------------------------------------------------------------------------
if ($RemoveEnvVars) {
    foreach ($name in @("TELEGRAM_BOT_TOKEN", "TELEGRAM_CHAT_ID", "TELEGRAM_MESSAGE_CHAR_LIMIT")) {
        try {
            [System.Environment]::SetEnvironmentVariable($name, $null, "User")
            Remove-Item "Env:$name" -ErrorAction SilentlyContinue
            $script:Removed += "Cleared env var: $name"
        } catch {
            $script:Failed += "Failed clearing env var ${name}: $($_.Exception.Message)"
        }
    }
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host " Uninstall Summary" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan

if ($script:Removed.Count -gt 0) {
    Write-Host "`nRemoved:" -ForegroundColor Green
    foreach ($item in $script:Removed) { Write-Host "  - $item" }
}

if ($script:Skipped.Count -gt 0) {
    Write-Host "`nSkipped:" -ForegroundColor Yellow
    foreach ($item in $script:Skipped) { Write-Host "  - $item" }
}

if ($script:Failed.Count -gt 0) {
    Write-Host "`nFailed:" -ForegroundColor Red
    foreach ($item in $script:Failed) { Write-Host "  - $item" }
    exit 1
}

Write-Host "`nDone." -ForegroundColor Green
