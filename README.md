# AI-CLI-Telegram-Notifications

Get a Telegram message on your phone whenever an AI CLI tool finishes responding to your prompt. Walk away from your desk, come back when you're needed.

Supports **Codex CLI**, **Claude Code**, and **Gemini CLI** on Windows (PowerShell).

---

## How it works

Each CLI tool has a hook system that runs a script when the agent finishes a turn. These scripts send a Telegram message with the agent's response so you know exactly what it did — without watching the terminal.

---

## Prerequisites

- Windows 11 with PowerShell
- One of: [Codex CLI](https://github.com/openai/codex), [Claude Code](https://code.claude.com), [Gemini CLI](https://github.com/google-gemini/gemini-cli)
- A Telegram bot (see setup below)

---

## Step 1: Create a Telegram Bot

1. Open Telegram and search for **@BotFather**
2. Send `/newbot` and follow the prompts
3. Copy the **bot token** it gives you (looks like `123456:ABC-DEF...`)
4. Start a chat with your new bot, then visit:
   ```
   https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates
   ```
5. Send any message to your bot, refresh the URL, and find your **chat ID** in the response (a number like `8303032448`)

---

## Step 2: Set Environment Variables

Store your credentials as Windows user environment variables so they're never hardcoded in scripts:

```powershell
[System.Environment]::SetEnvironmentVariable("TELEGRAM_BOT_TOKEN", "your-bot-token-here", "User")
[System.Environment]::SetEnvironmentVariable("TELEGRAM_CHAT_ID", "your-chat-id-here", "User")
```

Restart any open PowerShell windows after running these.

---

## Step 3: Choose your tool

### Codex CLI

**Create** `~/.codex/codex-telegram-notify.ps1`:

```powershell
if ($env:TG_OFF) { exit 0 }

$BOT_TOKEN = $env:TELEGRAM_BOT_TOKEN
$CHAT_ID   = $env:TELEGRAM_CHAT_ID

$payload = $args[-1] | ConvertFrom-Json
if ($payload.type -ne "agent-turn-complete") { exit 0 }

$response = $payload.'last-assistant-message'
if (-not $response) { $response = "Task complete." }
if ($response.Length -gt 4000) { $response = $response.Substring(0, 4000) + "`n`n[truncated]" }

$body = @{
    chat_id = $CHAT_ID
    text    = "Codex finished:`n`n$response"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" `
    -Method Post -Body $body -ContentType "application/json; charset=utf-8"
```

**Add to** `~/.codex/config.toml` (must be before any `[section]` headers):

```toml
notify = ["powershell", "-File", "C:\\Users\\YOUR_USERNAME\\.codex\\codex-telegram-notify.ps1"]

[tui]
notifications = ["agent-turn-complete"]
```

---

### Claude Code

**Create** `~/.claude/claude-telegram-notify.ps1`:

```powershell
if ($env:TG_OFF) { exit 0 }

$BOT_TOKEN = $env:TELEGRAM_BOT_TOKEN
$CHAT_ID   = $env:TELEGRAM_CHAT_ID

$inputJson = $input | Out-String | ConvertFrom-Json
$transcript = $inputJson.transcript_path

$lastMessage = "Task complete."
if ($transcript -and (Test-Path $transcript)) {
    $lines = Get-Content $transcript | Where-Object { $_ -ne "" }
    foreach ($line in $lines) {
        try {
            $entry = $line | ConvertFrom-Json
            if ($entry.type -eq "assistant") {
                $content = $entry.message.content
                if ($content -is [array]) {
                    $text = ($content | Where-Object { $_.type -eq "text" } | Select-Object -Last 1).text
                    if ($text) { $lastMessage = $text }
                }
            }
        } catch {}
    }
}

if ($lastMessage.Length -gt 4000) { $lastMessage = $lastMessage.Substring(0, 4000) + "`n`n[truncated]" }

$body = @{
    chat_id = $CHAT_ID
    text    = "Claude Code finished:`n`n$lastMessage"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" `
    -Method Post -Body $body -ContentType "application/json; charset=utf-8"
```

**Update** `~/.claude/settings.json` — add the `hooks` block to your existing file:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -File C:/Users/YOUR_USERNAME/.claude/claude-telegram-notify.ps1"
          }
        ]
      }
    ]
  }
}
```

> **Note:** Use forward slashes (`/`) in the command path, not backslashes. Claude Code strips backslashes.

---

### Gemini CLI

**Create** `~/.gemini/gemini-telegram-notify.ps1`:

```powershell
if ($env:TG_OFF) { exit 0 }

$BOT_TOKEN = $env:TELEGRAM_BOT_TOKEN
$CHAT_ID   = $env:TELEGRAM_CHAT_ID

$inputJson = $input | Out-String | ConvertFrom-Json
$response  = $inputJson.prompt_response

if (-not $response) { $response = "Task complete." }
if ($response.Length -gt 4000) { $response = $response.Substring(0, 4000) + "`n`n[truncated]" }

$body = @{
    chat_id = $CHAT_ID
    text    = "Gemini finished:`n`n$response"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" `
    -Method Post -Body $body -ContentType "application/json; charset=utf-8"
```

**Update** `~/.gemini/settings.json` — add the `hooks` block to your existing file:

```json
{
  "hooks": {
    "AfterAgent": [
      {
        "matcher": "",
        "hooks": [
          {
            "name": "telegram-notify",
            "type": "command",
            "command": "powershell -File C:/Users/YOUR_USERNAME/.gemini/gemini-telegram-notify.ps1"
          }
        ]
      }
    ]
  }
}
```

---

## Step 4: Toggle notifications on/off

Add these functions to your PowerShell profile so you can quickly pause notifications when you don't need them.

Open your profile:
```powershell
notepad $PROFILE
```

If the file doesn't exist, create it first:
```powershell
New-Item -Path $PROFILE -ItemType File -Force
```

Add these lines:
```powershell
function tg-off { $env:TG_OFF = "1" }
function tg-on  { Remove-Item Env:TG_OFF -ErrorAction SilentlyContinue }
```

Reload the profile:
```powershell
. $PROFILE
```

Now you can type `tg-off` or `tg-on` in any terminal. The toggle is session-scoped — opening a new terminal automatically re-enables notifications.

To check current status:
```powershell
$env:TG_OFF   # prints "1" if off, nothing if on
```

---

## What each tool sends you

| Tool | Response included | Source |
|------|-----------------|--------|
| Codex CLI | ✅ Full response | `last-assistant-message` in hook payload |
| Claude Code | ✅ Full response | Read from session transcript JSONL |
| Gemini CLI | ✅ Full response | `prompt_response` in hook payload |

---

## Troubleshooting

**No message received:**
- Check that your bot token and chat ID env vars are set: `$env:TELEGRAM_BOT_TOKEN`
- Make sure you've started a conversation with your bot in Telegram
- Check that `TG_OFF` isn't set: `$env:TG_OFF`

**Claude Code: "argument does not exist" error:**
- Use forward slashes in the path in `settings.json`, not backslashes

**Codex: notify line not working:**
- The `notify =` line must appear before any `[section]` headers in `config.toml`

**Messages show "Task complete." instead of the response:**
- Add debug logging to the script to inspect the raw payload (see the `notify-debug.log` approach in the scripts)

**Emoji showing as garbled text:**
- Make sure you're using `ConvertTo-Json` + `-ContentType "application/json; charset=utf-8"` when calling the Telegram API

---

## Contributing

PRs welcome! Especially interested in:
- macOS / Linux bash equivalents
- Support for other CLI tools with hook systems
- Other notification platforms (Slack, Discord, etc.)
