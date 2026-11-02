$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$report = Join-Path $root 'impl\gwsynthesis\ble_music_keyboard_syn_resource.html'
if (-not (Test-Path -LiteralPath $report)) { throw 'Run Gowin synthesis first' }
$html = Get-Content -LiteralPath $report -Raw
$start = $html.IndexOf('|--spectrum_detector_inst')
if ($start -lt 0) { throw 'Spectrum detector missing from synthesis report' }
$segment = $html.Substring($start, [Math]::Min(800, $html.Length - $start))
$values = @([regex]::Matches($segment, '<td align = "center">(\d+|-)</td>') | ForEach-Object { $_.Groups[1].Value })
if ($values.Count -lt 5) { throw 'Cannot parse detector resource row' }
$dsp = [int]$values[3]
Write-Output "SPECTRUM_DETECTOR_DSP=$dsp"
if ($dsp -gt 2) { throw "Detector exceeds two-DSP budget: $dsp" }
Write-Output 'DSP_BUDGET_PASS'
