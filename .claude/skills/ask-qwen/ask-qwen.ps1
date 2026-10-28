# Sends a prompt to the local Qwen model served by LM Studio.
# Usage:
#   ask-qwen.ps1 -Prompt "..." [-InputFile path] [-OutFile path] [-Model name] [-MaxTokens n]
param(
  [Parameter(Mandatory = $true)][string]$Prompt,
  [string]$InputFile,
  [string]$OutFile,
  [string]$Model = "qwen2.5-coder-7b-instruct",
  [int]$MaxTokens = 2048
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Optional: append a file's content to the prompt (code to document, text to summarize...)
$content = $Prompt
if ($InputFile) {
  $content += "`n`n---`n" + (Get-Content -Raw -Encoding UTF8 $InputFile)
}

$body = @{
  model       = $Model
  messages    = @(
    @{ role = "system"; content = "You are a precise assistant. Output only the requested content, no preamble, no closing remarks. Do not wrap the output in markdown code fences unless explicitly asked." },
    @{ role = "user"; content = $content }
  )
  temperature = 0.2
  max_tokens  = $MaxTokens
} | ConvertTo-Json -Depth 5

try {
  $resp = Invoke-WebRequest -Uri "http://localhost:1234/v1/chat/completions" -Method Post `
    -ContentType "application/json; charset=utf-8" `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
    -UseBasicParsing -TimeoutSec 600
} catch {
  [Console]::Error.WriteLine("ERROR: LM Studio unreachable on localhost:1234 (server stopped or model not loaded?). " + $_.Exception.Message)
  exit 1
}

# Decode as UTF-8 explicitly so accents survive
$json   = [System.Text.Encoding]::UTF8.GetString($resp.RawContentStream.ToArray()) | ConvertFrom-Json
$answer = $json.choices[0].message.content

if ($OutFile) {
  $full = [System.IO.Path]::GetFullPath($OutFile)
  [System.IO.File]::WriteAllText($full, $answer, (New-Object System.Text.UTF8Encoding $false))
  Write-Output "OK: $OutFile written ($($answer.Length) chars)"
} else {
  Write-Output $answer
}