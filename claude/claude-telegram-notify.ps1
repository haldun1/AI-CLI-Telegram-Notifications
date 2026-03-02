if (-not $env:TG_ON) { exit 0 }

$BOT_TOKEN = $env:TELEGRAM_BOT_TOKEN
$CHAT_ID   = $env:TELEGRAM_CHAT_ID
$SUFFIX = "`n`n[truncated]"
$MAX_CHARS = 4000
if ($env:TELEGRAM_MESSAGE_CHAR_LIMIT -match '^\d+$') {
    $MAX_CHARS = [Math]::Min([int]$env:TELEGRAM_MESSAGE_CHAR_LIMIT, 4096)
}
if ($MAX_CHARS -lt 1) { $MAX_CHARS = 1 }

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

if ($lastMessage.Length -gt $MAX_CHARS) {
    $KeepLen = [Math]::Max(0, $MAX_CHARS - $SUFFIX.Length)
    $lastMessage = $lastMessage.Substring(0, $KeepLen) + $SUFFIX
}
if ($lastMessage.Length -gt $MAX_CHARS) {
    $lastMessage = $lastMessage.Substring(0, $MAX_CHARS)
}

$body = @{
    chat_id = $CHAT_ID
    text    = "Claude Code finished:`n`n$lastMessage"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" `
    -Method Post -Body $body -ContentType "application/json; charset=utf-8"
