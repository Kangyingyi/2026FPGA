param([string]$ModelSimBin = 'D:\App_for_study\intelFPGA_lite\18.1\modelsim_ase\win32aloem')

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
    $compile = & $vlog -vlog01compat -work simlib (Get-ChildItem src\*.v).FullName (Get-ChildItem sim\tb_*.v).FullName 2>&1
    $compileCode = $LASTEXITCODE
    $compileText = $compile -join "`n"
    if ($compileCode -ne 0 -or $compileText -notmatch 'Errors:\s*0,\s*Warnings:\s*0') {
        Write-Output $compileText
        throw 'Verilog compile failed'
    }
    foreach ($case in @('tb_glide_voice_pitch', 'tb_glide_audio', 'tb_note_map', 'tb_i2s_framing')) {
        $result = & $vsim -c -lib simlib $case -do 'run -all; quit -f' 2>&1
        $code = $LASTEXITCODE
        $output = $result -join "`n"
        if ($code -ne 0 -or $output -notmatch 'Errors:\s*0,\s*Warnings:\s*0' -or
            $output -notmatch 'TB_(GLIDE_\w+|NOTE_MAP|I2S_FRAMING)_PASS' -or $output -match '\*\* (Fatal|Error):') {
            Write-Output $output
            throw "$case failed"
        }
        Write-Output "$case PASS"
    }
} finally {
    Pop-Location
}
