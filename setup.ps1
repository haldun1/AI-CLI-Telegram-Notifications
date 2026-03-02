<#
.SYNOPSIS
Automated setup wizard for AI-CLI-Telegram-Notifications.

.DESCRIPTION
Configures environment variables, automatically fetches Telegram Chat ID,
installs the notification scripts, and updates config files for Codex, Claude, and Gemini.
#>

$ErrorActionPreference = "Stop"
$HomeDir = [System.Environment]::GetFolderPath('UserProfile')
$HomeDirFS = $HomeDir -replace '\\', '/' # Forward-slash version for JSON configs

function Get-ChatIdFromUpdate {
    param($Update)

    foreach ($Field in @("message", "edited_message", "channel_post", "edited_channel_post")) {
        $Message = $Update.$Field
        if ($null -ne $Message -and $null -ne $Message.chat -and $null -ne $Message.chat.id) {
            return $Message.chat.id
        }
    }

    return $null
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] $Object,
        [int]$Depth = 10
    )

    $json = $Object | ConvertTo-Json -Depth $Depth
    # Normalize overly padded colon spacing from Windows PowerShell JSON output.
    $json = $json -replace '":\s{2,}', '": '
    Set-Content -Path $Path -Value $json -Encoding UTF8
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " AI CLI Telegram Notifications - Setup Wizard" -ForegroundColor Cyan
Write-Host "==================================================`n" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# STEP 0: Reuse Existing Telegram Environment Variables
# ---------------------------------------------------------------------------
$BotToken = $null
$ChatId = $null
$ExistingBotToken = [System.Environment]::GetEnvironmentVariable("TELEGRAM_BOT_TOKEN", "User")
$ExistingChatId = [System.Environment]::GetEnvironmentVariable("TELEGRAM_CHAT_ID", "User")
$ReuseExistingTelegramConfig = $false

if (-not [string]::IsNullOrWhiteSpace($ExistingBotToken) -and -not [string]::IsNullOrWhiteSpace($ExistingChatId)) {
    Write-Host "STEP 0: Existing Telegram configuration detected" -ForegroundColor Yellow
    Write-Host "Found TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID in your user environment."
    do {
        $ReuseInput = Read-Host "Reuse existing token and chat ID and skip manual entry? (Y/n)"
        if ([string]::IsNullOrWhiteSpace($ReuseInput) -or $ReuseInput -match '^[Yy]$') {
            $ReuseExistingTelegramConfig = $true
            $BotToken = $ExistingBotToken
            $ChatId = $ExistingChatId
            Write-Host "Reusing existing TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID." -ForegroundColor Green
            break
        } elseif ($ReuseInput -match '^[Nn]$') {
            $ReuseExistingTelegramConfig = $false
            break
        } else {
            Write-Host "Please answer with Y or N." -ForegroundColor Red
        }
    } while ($true)
}

# ---------------------------------------------------------------------------
# STEP 1: Telegram Bot Token
# ---------------------------------------------------------------------------
if (-not $ReuseExistingTelegramConfig) {
    Write-Host "STEP 1: Telegram Bot Token" -ForegroundColor Yellow
    Write-Host "1. Open Telegram and message @BotFather"
    Write-Host "2. Send /newbot and follow the prompts to create a bot"
    Write-Host "3. Copy the HTTP API Token"
    $BotToken = Read-Host "`nPaste your Bot Token here"

    if ([string]::IsNullOrWhiteSpace($BotToken)) {
        Write-Host "Error: Bot Token cannot be empty. Exiting." -ForegroundColor Red
        exit 1
    }
}

# ---------------------------------------------------------------------------
# STEP 2: Automatic Chat ID Retrieval
# ---------------------------------------------------------------------------
if (-not $ReuseExistingTelegramConfig) {
    Write-Host "`nSTEP 2: Connecting to Telegram..." -ForegroundColor Yellow
    Write-Host "Open a chat with your NEW bot in Telegram and send it ANY message (e.g., 'hello')."
    Write-Host "Waiting for your message (30-second timeout)..." -ForegroundColor Cyan

    $Offset = 0
    $MaxWaitSeconds = 30
    $PollTimeoutSeconds = 2
    $StartedAt = Get-Date
    $Deadline = (Get-Date).AddSeconds($MaxWaitSeconds)

    while ($null -eq $ChatId) {
        $ElapsedSeconds = [int]((Get-Date) - $StartedAt).TotalSeconds
        $RemainingSeconds = [Math]::Max(0, $MaxWaitSeconds - $ElapsedSeconds)
        $PercentComplete = [Math]::Min(100, [int](($ElapsedSeconds * 100) / $MaxWaitSeconds))
        Write-Progress -Activity "Waiting for Telegram message" -Status "$RemainingSeconds second(s) remaining" -PercentComplete $PercentComplete

        if ((Get-Date) -gt $Deadline) {
            Write-Progress -Activity "Waiting for Telegram message" -Completed
            Write-Host "`nTimed out after $MaxWaitSeconds seconds waiting for a Telegram message." -ForegroundColor Red
            Write-Host "Please send a message to your bot and re-run setup." -ForegroundColor Red
            exit 1
        }

        try {
            $Response = Invoke-RestMethod -Uri "https://api.telegram.org/bot$BotToken/getUpdates?offset=$Offset&timeout=$PollTimeoutSeconds" -Method Get -ErrorAction Stop
            if ($Response.ok -and $Response.result.Count -gt 0) {
                foreach ($Update in @($Response.result | Sort-Object -Property update_id)) {
                    if ($Update.update_id -ge $Offset) {
                        $Offset = $Update.update_id + 1
                    }

                    $DetectedChatId = Get-ChatIdFromUpdate -Update $Update
                    if ($null -ne $DetectedChatId) {
                        $ChatId = $DetectedChatId
                    }
                }
            }
        } catch {
            Write-Progress -Activity "Waiting for Telegram message" -Completed
            Write-Host "Error checking Telegram API. Please ensure your token is correct." -ForegroundColor Red
            exit 1
        }
    }
    Write-Progress -Activity "Waiting for Telegram message" -Completed

    Write-Host "`nSuccess! Found Chat ID: $ChatId" -ForegroundColor Green

    do {
        $UseDetectedChatId = Read-Host "Use Chat ID '$ChatId'? (Y/n)"
        if ([string]::IsNullOrWhiteSpace($UseDetectedChatId) -or $UseDetectedChatId -match '^[Yy]$') {
            $ChatIdConfirmed = $true
        } elseif ($UseDetectedChatId -match '^[Nn]$') {
            $ManualChatId = Read-Host "Enter the Chat ID to use (numbers only; may start with '-')"
            if ($ManualChatId -match '^-?\d+$') {
                $ChatId = $ManualChatId
                $ChatIdConfirmed = $true
                Write-Host "Using manually provided Chat ID: $ChatId" -ForegroundColor Green
            } else {
                $ChatIdConfirmed = $false
                Write-Host "Invalid Chat ID. Please enter only digits, with optional leading '-'." -ForegroundColor Red
            }
        } else {
            $ChatIdConfirmed = $false
            Write-Host "Please answer with Y or N." -ForegroundColor Red
        }
    } while (-not $ChatIdConfirmed)
}

# ---------------------------------------------------------------------------
# STEP 3: Message Character Limit
# ---------------------------------------------------------------------------
Write-Host "`nSTEP 3: Message Character Limit" -ForegroundColor Yellow
Write-Host "Telegram allows a maximum of 4096 characters per message."
Write-Host "Default limit is 4000 to leave room for a truncation suffix."

$DefaultCharLimit = 4000
do {
    $LimitInput = Read-Host "Press Enter to keep $DefaultCharLimit, or enter a custom limit (1-4096)"
    if ([string]::IsNullOrWhiteSpace($LimitInput)) {
        $MessageCharLimit = $DefaultCharLimit
        $LimitValid = $true
    } elseif (($LimitInput -match '^\d+$') -and ([int]$LimitInput -ge 1) -and ([int]$LimitInput -le 4096)) {
        $MessageCharLimit = [int]$LimitInput
        $LimitValid = $true
    } else {
        $LimitValid = $false
        Write-Host "Invalid value. Enter a number from 1 to 4096." -ForegroundColor Red
    }
} while (-not $LimitValid)

Write-Host "Using message character limit: $MessageCharLimit" -ForegroundColor Green

# ---------------------------------------------------------------------------
# STEP 4: Set Environment Variables
# ---------------------------------------------------------------------------
Write-Host "`nSTEP 4: Saving Environment Variables..." -ForegroundColor Yellow
[System.Environment]::SetEnvironmentVariable("TELEGRAM_BOT_TOKEN", $BotToken, "User")
[System.Environment]::SetEnvironmentVariable("TELEGRAM_CHAT_ID", $ChatId, "User")
[System.Environment]::SetEnvironmentVariable("TELEGRAM_MESSAGE_CHAR_LIMIT", "$MessageCharLimit", "User")
$env:TELEGRAM_BOT_TOKEN = $BotToken
$env:TELEGRAM_CHAT_ID = $ChatId
$env:TELEGRAM_MESSAGE_CHAR_LIMIT = "$MessageCharLimit"
Write-Host "Variables saved to your Windows User profile." -ForegroundColor Green

# ---------------------------------------------------------------------------
# STEP 5: Install Scripts and Update Configs
# ---------------------------------------------------------------------------
Write-Host "`nSTEP 5: Installing hooks for detected tools..." -ForegroundColor Yellow

$RepoRoot = $PSScriptRoot
$AnyToolDetected = $false

Write-Host "Choose which CLI tool(s) to configure:" -ForegroundColor Cyan
Write-Host "  1) All detected tools"
Write-Host "  2) Codex CLI only"
Write-Host "  3) Claude Code only"
Write-Host "  4) Gemini CLI only"

$SelectionMap = @{
    "1" = "All"
    "2" = "Codex"
    "3" = "Claude"
    "4" = "Gemini"
}

do {
    $Choice = Read-Host "Enter 1, 2, 3, or 4"
    $SelectedTarget = $SelectionMap[$Choice]
    if (-not $SelectedTarget) {
        Write-Host "Invalid choice. Please enter 1, 2, 3, or 4." -ForegroundColor Red
    }
} while (-not $SelectedTarget)

$SetupCodex = $SelectedTarget -in @("All", "Codex")
$SetupClaude = $SelectedTarget -in @("All", "Claude")
$SetupGemini = $SelectedTarget -in @("All", "Gemini")

Write-Host "Selected: $SelectedTarget" -ForegroundColor Green

# --- CODEX CLI ---
$CodexDir = Join-Path $HomeDir ".codex"
if ($SetupCodex -and (Test-Path $CodexDir)) {
    $AnyToolDetected = $true
    Write-Host "Detected Codex CLI. Installing..." -ForegroundColor Cyan
    Copy-Item -Path (Join-Path $RepoRoot "codex\codex-telegram-notify.ps1") -Destination $CodexDir -Force
    
    $CodexConfig = Join-Path $CodexDir "config.toml"
    if (-not (Test-Path $CodexConfig)) {
        Set-Content -Path $CodexConfig -Value "" -Encoding UTF8
    }

    $ConfigContent = Get-Content $CodexConfig -Raw
    $NotifyLine = 'notify = ["powershell", "-ExecutionPolicy", "Bypass", "-File", "' + $CodexDir.Replace('\', '\\') + '\\codex-telegram-notify.ps1"]'
    $NotifyPattern = '(?m)^notify\s*=\s*\[.*\]\s*$'

    if ($ConfigContent -match $NotifyPattern) {
        $ConfigContent = [regex]::Replace($ConfigContent, $NotifyPattern, $NotifyLine, 1)
    } else {
        $ConfigContent = "$NotifyLine`r`n`r`n$ConfigContent"
    }

    $AgentEvent = '"agent-turn-complete"'
    if ($ConfigContent -notmatch [regex]::Escape($AgentEvent)) {
        $NotificationsMatch = [regex]::Match($ConfigContent, '(?m)^notifications\s*=\s*\[(?<items>[^\]]*)\]\s*$')

        if ($NotificationsMatch.Success) {
            $ExistingItems = @(
                $NotificationsMatch.Groups["items"].Value -split "," |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ -ne "" }
            )
            if ($ExistingItems -notcontains $AgentEvent) {
                $NewItems = @($ExistingItems + $AgentEvent) | Select-Object -Unique
                $NewLine = "notifications = [$($NewItems -join ', ')]"
                $ConfigContent = $ConfigContent.Remove($NotificationsMatch.Index, $NotificationsMatch.Length).Insert($NotificationsMatch.Index, $NewLine)
            }
        } elseif ($ConfigContent -match '(?m)^\[tui\]\s*$') {
            $ConfigContent = [regex]::Replace(
                $ConfigContent,
                '(?m)^\[tui\]\s*$',
                "[tui]`r`nnotifications = [$AgentEvent]",
                1
            )
        } else {
            $ConfigContent = $ConfigContent.TrimEnd() + "`r`n`r`n[tui]`r`nnotifications = [$AgentEvent]`r`n"
        }
    }

    Set-Content -Path $CodexConfig -Value $ConfigContent -Encoding UTF8
    Write-Host "  -> Updated ~/.codex/config.toml" -ForegroundColor Green
} elseif ($SetupCodex) {
    Write-Host "Codex CLI selected, but ~/.codex was not found. Skipping Codex setup." -ForegroundColor Yellow
}

# --- CLAUDE CODE ---
$ClaudeDir = Join-Path $HomeDir ".claude"
if ($SetupClaude -and (Test-Path $ClaudeDir)) {
    $AnyToolDetected = $true
    Write-Host "Detected Claude Code. Installing..." -ForegroundColor Cyan
    Copy-Item -Path (Join-Path $RepoRoot "claude\claude-telegram-notify.ps1") -Destination $ClaudeDir -Force
    
    $ClaudeConfig = Join-Path $ClaudeDir "settings.json"
    if (-not (Test-Path $ClaudeConfig)) {
        Set-Content -Path $ClaudeConfig -Value "{}" -Encoding UTF8
    }

    $ClaudeRaw = Get-Content $ClaudeConfig -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($ClaudeRaw)) {
        $Settings = [pscustomobject]@{}
    } else {
        try {
            $Settings = $ClaudeRaw | ConvertFrom-Json
        } catch {
            $BackupPath = "$ClaudeConfig.bak.$((Get-Date).ToString('yyyyMMddHHmmss'))"
            Copy-Item -Path $ClaudeConfig -Destination $BackupPath -Force
            Write-Host "  -> Invalid JSON found in ~/.claude/settings.json; backed up to $BackupPath and recreated." -ForegroundColor Yellow
            $Settings = [pscustomobject]@{}
        }
    }

    if ($null -eq $Settings.hooks) { $Settings | Add-Member -MemberType NoteProperty -Name "hooks" -Value ([pscustomobject]@{}) }
    if ($null -eq $Settings.hooks.Stop) { $Settings.hooks | Add-Member -MemberType NoteProperty -Name "Stop" -Value @() }

    $ExpectedClaudeCommand = "powershell -ExecutionPolicy Bypass -File $HomeDirFS/.claude/claude-telegram-notify.ps1"
    $HookExists = $false
    $HookUpdated = $false
    foreach ($StopEntry in @($Settings.hooks.Stop)) {
        foreach ($Hook in @($StopEntry.hooks)) {
            if ($Hook.command -match "claude-telegram-notify.ps1") {
                $HookExists = $true
                if ($Hook.command -ne $ExpectedClaudeCommand) {
                    $Hook.command = $ExpectedClaudeCommand
                    $HookUpdated = $true
                }
            }
        }
    }

    if (-not $HookExists) {
        $NewHook = @{
            matcher = ""
            hooks = @( @{ type = "command"; command = $ExpectedClaudeCommand } )
        }
        $Settings.hooks.Stop += $NewHook
        $HookUpdated = $true
    }

    if ($HookUpdated) {
        Write-JsonFile -Path $ClaudeConfig -Object $Settings -Depth 10
        Write-Host "  -> Updated ~/.claude/settings.json" -ForegroundColor Green
    } else {
        Write-Host "  -> Claude config already has the hook." -ForegroundColor Gray
    }
} elseif ($SetupClaude) {
    Write-Host "Claude Code selected, but ~/.claude was not found. Skipping Claude setup." -ForegroundColor Yellow
}

# --- GEMINI CLI ---
$GeminiDir = Join-Path $HomeDir ".gemini"
if ($SetupGemini -and (Test-Path $GeminiDir)) {
    $AnyToolDetected = $true
    Write-Host "Detected Gemini CLI. Installing..." -ForegroundColor Cyan
    Copy-Item -Path (Join-Path $RepoRoot "gemini\gemini-telegram-notify.ps1") -Destination $GeminiDir -Force
    
    $GeminiConfig = Join-Path $GeminiDir "settings.json"
    if (-not (Test-Path $GeminiConfig)) {
        Set-Content -Path $GeminiConfig -Value "{}" -Encoding UTF8
    }

    $GeminiRaw = Get-Content $GeminiConfig -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($GeminiRaw)) {
        $Settings = [pscustomobject]@{}
    } else {
        try {
            $Settings = $GeminiRaw | ConvertFrom-Json
        } catch {
            $BackupPath = "$GeminiConfig.bak.$((Get-Date).ToString('yyyyMMddHHmmss'))"
            Copy-Item -Path $GeminiConfig -Destination $BackupPath -Force
            Write-Host "  -> Invalid JSON found in ~/.gemini/settings.json; backed up to $BackupPath and recreated." -ForegroundColor Yellow
            $Settings = [pscustomobject]@{}
        }
    }

    if ($null -eq $Settings.hooks) { $Settings | Add-Member -MemberType NoteProperty -Name "hooks" -Value ([pscustomobject]@{}) }
    if ($null -eq $Settings.hooks.AfterAgent) { $Settings.hooks | Add-Member -MemberType NoteProperty -Name "AfterAgent" -Value @() }

    $ExpectedGeminiCommand = "powershell -ExecutionPolicy Bypass -File $HomeDirFS/.gemini/gemini-telegram-notify.ps1"
    $HookExists = $false
    $HookUpdated = $false
    foreach ($AfterAgentEntry in @($Settings.hooks.AfterAgent)) {
        foreach ($Hook in @($AfterAgentEntry.hooks)) {
            if ($Hook.command -match "gemini-telegram-notify.ps1") {
                $HookExists = $true
                if ($Hook.command -ne $ExpectedGeminiCommand) {
                    $Hook.command = $ExpectedGeminiCommand
                    $HookUpdated = $true
                }
            }
        }
    }

    if (-not $HookExists) {
        $NewHook = @{
            matcher = ""
            hooks = @( @{ name = "telegram-notify"; type = "command"; command = $ExpectedGeminiCommand } )
        }
        $Settings.hooks.AfterAgent += $NewHook
        $HookUpdated = $true
    }

    if ($HookUpdated) {
        Write-JsonFile -Path $GeminiConfig -Object $Settings -Depth 10
        Write-Host "  -> Updated ~/.gemini/settings.json" -ForegroundColor Green
    } else {
        Write-Host "  -> Gemini config already has the hook." -ForegroundColor Gray
    }
} elseif ($SetupGemini) {
    Write-Host "Gemini CLI selected, but ~/.gemini was not found. Skipping Gemini setup." -ForegroundColor Yellow
}

if (-not $AnyToolDetected) {
    if ($SelectedTarget -eq "All") {
        Write-Host "No supported CLI config directories were detected (~/.codex, ~/.claude, ~/.gemini)." -ForegroundColor Yellow
        Write-Host "Install at least one CLI tool, then re-run setup to install hooks automatically." -ForegroundColor Yellow
    } else {
        Write-Host "$SelectedTarget was selected, but its config directory was not detected." -ForegroundColor Yellow
        Write-Host "Install/configure $SelectedTarget first, then re-run setup." -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# STEP 6: Add Profile Toggles
# ---------------------------------------------------------------------------
Write-Host "`nSTEP 6: Adding 'tg-on' and 'tg-off' toggles to PowerShell profile..." -ForegroundColor Yellow
if (-not (Test-Path (Split-Path -Parent $PROFILE))) {
    New-Item -Path (Split-Path -Parent $PROFILE) -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path $PROFILE)) {
    New-Item -Path $PROFILE -ItemType File -Force | Out-Null
}

$ProfileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
$ToggleCode = "# AI-CLI-Telegram-Notifications Toggles`nfunction tg-on  { `$env:TG_ON = `"1`" }`nfunction tg-off { Remove-Item Env:TG_ON -ErrorAction SilentlyContinue }"
$TogglePattern = '(?ms)^# AI-CLI-Telegram-Notifications Toggles\r?\n(?:function\s+tg-(?:on|off)\s*\{[^\r\n]*\}\r?\n?){1,4}'

if ($ProfileContent -match "(?m)^# AI-CLI-Telegram-Notifications Toggles$") {
    $UpdatedProfile = [regex]::Replace($ProfileContent, $TogglePattern, $ToggleCode, 1)
    if ($UpdatedProfile -eq $ProfileContent) {
        $UpdatedProfile = $ProfileContent.TrimEnd() + "`r`n`r`n$ToggleCode`r`n"
    }
    Set-Content -Path $PROFILE -Value $UpdatedProfile -Encoding UTF8
    Write-Host "Toggles updated." -ForegroundColor Green
} elseif ($ProfileContent -notmatch "(?m)^function tg-on\b" -and $ProfileContent -notmatch "(?m)^function tg-off\b") {
    Add-Content -Path $PROFILE -Value ("`r`n$ToggleCode`r`n")
    Write-Host "Toggles added." -ForegroundColor Green
} else {
    Add-Content -Path $PROFILE -Value ("`r`n# AI-CLI-Telegram-Notifications Toggles`r`nfunction tg-on  { `$env:TG_ON = `"1`" }`r`nfunction tg-off { Remove-Item Env:TG_ON -ErrorAction SilentlyContinue }`r`n")
    Write-Host "Toggles added as AI-CLI-Telegram-Notifications block." -ForegroundColor Yellow
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host " Setup Complete!" -ForegroundColor Green
Write-Host " Please restart your PowerShell terminal for the"
Write-Host " profile aliases and environment variables to load."
Write-Host "==================================================" -ForegroundColor Cyan
