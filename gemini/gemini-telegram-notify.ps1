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
