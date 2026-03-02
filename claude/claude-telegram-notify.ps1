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
