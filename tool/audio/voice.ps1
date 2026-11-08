# Speaks each voice line to a WAV file with the Windows speech engine.
# Placeholder voice-over only: replace with recorded en_GB voice before
# release (SRS 10, open question 3).
#
# Usage: powershell -File voice.ps1 <lines.json> <output dir>
# lines.json is an object of { "fileName": "text to speak" }.
param([string]$Lines, [string]$OutDir)

Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$voices = $synth.GetInstalledVoices() | ForEach-Object { $_.VoiceInfo.Name }
foreach ($preferred in @('Microsoft Hazel Desktop', 'Microsoft Zira Desktop')) {
    if ($voices -contains $preferred) { $synth.SelectVoice($preferred); break }
}
# A little slower than normal, for young listeners.
$synth.Rate = -2

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$map = Get-Content -Raw -Encoding UTF8 $Lines | ConvertFrom-Json
foreach ($entry in $map.PSObject.Properties) {
    $path = Join-Path $OutDir ($entry.Name + '.wav')
    $synth.SetOutputToWaveFile($path)
    $synth.Speak($entry.Value)
}
$synth.SetOutputToNull()
Write-Output ("Voice: " + $synth.Voice.Name)
