param(
    [string]$ModelSimBin = 'D:\App_for_study\intelFPGA_lite\18.1\modelsim_ase\win32aloem'
)

$ErrorActionPreference = 'Stop'
$vlib = Join-Path $ModelSimBin 'vlib.exe'
$vlog = Join-Path $ModelSimBin 'vlog.exe'
$vsim = Join-Path $ModelSimBin 'vsim.exe'
foreach ($tool in @($vlib, $vlog, $vsim)) {
    if (-not (Test-Path -LiteralPath $tool)) { throw "ModelSim tool not found: $tool" }
}

Push-Location -LiteralPath $PSScriptRoot
try {
    if (-not (Test-Path -LiteralPath 'simlib')) {
        & $vlib simlib | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'vlib failed' }
    }
    $compile = & $vlog -vlog01compat -work simlib 'src\pitch_vibrato.v' 'sim\tb_pitch_vibrato.v' 2>&1
    $compileCode = $LASTEXITCODE
    $compileText = $compile -join "`n"
    if ($compileCode -ne 0 -or $compileText -notmatch 'Errors:\s*0,\s*Warnings:\s*0') {
        Write-Output $compileText
        throw 'Vibrato package compilation failed'
    }
    $result = & $vsim -c -lib simlib tb_pitch_vibrato -do 'run -all; quit -f' 2>&1
    $resultCode = $LASTEXITCODE
    $resultText = $result -join "`n"
    if ($resultCode -ne 0 -or $resultText -notmatch 'TB_PITCH_VIBRATO_PACKAGE_PASS' -or
        $resultText -notmatch 'Errors:\s*0,\s*Warnings:\s*0' -or
        $resultText -match '\*\* (Fatal|Error):') {
        Write-Output $resultText
        throw 'Vibrato package simulation failed'
    }
    Write-Output 'VIBRATO_PACKAGE_PASS (compile: 0 errors, 0 warnings; simulation: 0 errors, 0 warnings)'
} finally {
    Pop-Location
}
