# AI-CLI-Telegram-Notifications

Get a Telegram message when an AI CLI finishes responding.

Supports **Codex CLI**, **Claude Code**, and **Gemini CLI** on Windows (PowerShell).

---

## Privacy and security

This project sends AI responses to Telegram. Treat that as external data transfer.

- Do not use this on sensitive prompts/responses unless your policy allows sending that content to Telegram.
- Your bot token is stored as a Windows user environment variable.
- During setup, always confirm the detected chat ID before saving.

---

## Quick start

```powershell
cd path\to\AI-CLI-Telegram-Notifications
.\setup.ps1
```

Then follow the prompts:
1. Paste your bot token
2. Message your bot once
3. Confirm or edit detected chat ID
4. Confirm or set message character limit (max `4096`)
5. Choose which CLI tool(s) to configure

Restart PowerShell when setup finishes.

---

## Automated setup (recommended)

Run:

```powershell
.\setup.ps1
```

The wizard will:

1. Ask for Telegram bot token.
2. Auto-detect chat ID from Telegram updates.
3. Ask you to confirm that chat ID, or enter a different one.
4. Ask you to keep default message limit (`4000`) or set a custom value (`1`-`4096`).
5. Save:
   - `TELEGRAM_BOT_TOKEN`
   - `TELEGRAM_CHAT_ID`
   - `TELEGRAM_MESSAGE_CHAR_LIMIT`
6. Let you choose:
   - All detected tools
   - Codex only
   - Claude only
   - Gemini only
7. Install hook scripts and update tool configs.
8. Add `tg-on` / `tg-off` to your PowerShell profile.

---

## Manual setup

Use this if you do not want to run `setup.ps1`.

### Step 1: Create bot and get chat ID

1. Open Telegram and message **@BotFather**
2. Run `/newbot` and copy your token
3. Start a chat with your bot and send any message
4. Open:
   ```
   https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates
   ```
5. Find your `chat.id`

### Step 2: Set environment variables

```powershell
[System.Environment]::SetEnvironmentVariable("TELEGRAM_BOT_TOKEN", "your-bot-token", "User")
[System.Environment]::SetEnvironmentVariable("TELEGRAM_CHAT_ID", "your-chat-id", "User")
[System.Environment]::SetEnvironmentVariable("TELEGRAM_MESSAGE_CHAR_LIMIT", "4000", "User")
```

`TELEGRAM_MESSAGE_CHAR_LIMIT` must be between `1` and `4096`.

### Step 3: Install scripts and hook config

#### Codex CLI

```powershell
Copy-Item .\codex\codex-telegram-notify.ps1 "$HOME\.codex\codex-telegram-notify.ps1" -Force
```

Add to `~/.codex/config.toml` (before any `[section]` headers):

```toml
notify = ["powershell", "-File", "C:\\Users\\YOUR_USERNAME\\.codex\\codex-telegram-notify.ps1"]

[tui]
notifications = ["agent-turn-complete"]
```

#### Claude Code

```powershell
Copy-Item .\claude\claude-telegram-notify.ps1 "$HOME\.claude\claude-telegram-notify.ps1" -Force
```

Add hook in `~/.claude/settings.json`:

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

Use forward slashes (`/`) in Claude command paths.

#### Gemini CLI

```powershell
Copy-Item .\gemini\gemini-telegram-notify.ps1 "$HOME\.gemini\gemini-telegram-notify.ps1" -Force
```

Add hook in `~/.gemini/settings.json`:

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

### Step 4: Toggle notifications (default: off)

Add to your PowerShell profile:

```powershell
function tg-on  { $env:TG_ON = "1" }
function tg-off { Remove-Item Env:TG_ON -ErrorAction SilentlyContinue }
```

Reload profile:

```powershell
. $PROFILE
```

Notifications are OFF by default.  
`tg-on` only affects the current terminal session. Run `tg-on` and your CLI in the same shell window.

---

## Troubleshooting

**No message received**
- Verify: `$env:TELEGRAM_BOT_TOKEN`, `$env:TELEGRAM_CHAT_ID`
- Confirm `TG_ON` is set in the current session (`$env:TG_ON`)
- Confirm you messaged the bot from the same chat ID you configured

**Too-short or too-long messages**
- Check `$env:TELEGRAM_MESSAGE_CHAR_LIMIT`
- Allowed range is `1` to `4096`

**Codex not notifying**
- Ensure both `notify = ...` and `notifications = ["agent-turn-complete"]` exist in `~/.codex/config.toml`

**`tg-on` not working in Codex**
- Ensure `~/.codex/config.toml` points to `~/.codex/codex-telegram-notify.ps1` (not an older `telegram-notify.ps1` path)
- Run `tg-on` in the same terminal session where you start `codex`

---

## Contributing

PRs are welcome.
