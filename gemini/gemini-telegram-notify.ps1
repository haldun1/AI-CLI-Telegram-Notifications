if ($env:TG_OFF) { exit 0 }

$BOT_TOKEN = $env:TELEGRAM_BOT_TOKEN
$CHAT_ID   = $env:TELEGRAM_CHAT_ID
$SUFFIX = "`n`n[truncated]"
$MAX_CHARS = 4000
if ($env:TELEGRAM_MESSAGE_CHAR_LIMIT -match '^\d+$') {
    $MAX_CHARS = [Math]::Min([int]$env:TELEGRAM_MESSAGE_CHAR_LIMIT, 4096)
}
if ($MAX_CHARS -lt 1) { $MAX_CHARS = 1 }

$inputJson = $input | Out-String | ConvertFrom-Json
$response  = $inputJson.prompt_response

if (-not $response) { $response = "Task complete." }
if ($response.Length -gt $MAX_CHARS) {
    $KeepLen = [Math]::Max(0, $MAX_CHARS - $SUFFIX.Length)
    $response = $response.Substring(0, $KeepLen) + $SUFFIX
}
if ($response.Length -gt $MAX_CHARS) {
    $response = $response.Substring(0, $MAX_CHARS)
}

$body = @{
    chat_id = $CHAT_ID
    text    = "Gemini finished:`n`n$response"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" `
    -Method Post -Body $body -ContentType "application/json; charset=utf-8"
