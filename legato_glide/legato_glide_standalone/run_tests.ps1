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
    $sources = @(Get-ChildItem -Path 'src\*.v' -File -ErrorAction SilentlyContinue | ForEach-Object FullName)
    $tests = @(Get-ChildItem -Path 'sim\tb_*.v' -File | Sort-Object Name)
    $compile = & $vlog -vlog01compat -work simlib @sources @($tests | ForEach-Object FullName) 2>&1
    $compileCode = $LASTEXITCODE
    $compileText = $compile -join "`n"
    if ($compileCode -ne 0 -or $compileText -notmatch 'Errors:\s*0,\s*Warnings:\s*0') {
        Write-Output $compileText
        throw 'Verilog compile failed'
    }
    foreach ($test in $tests) {
        $case = $test.BaseName
        $result = & $vsim -c -lib simlib $case -do 'run -all; quit -f' 2>&1
        $code = $LASTEXITCODE
        $output = $result -join "`n"
        $pass = $case.ToUpperInvariant() + '_PASS'
        if ($code -ne 0 -or $output -notmatch 'Errors:\s*0,\s*Warnings:\s*0' -or
            $output -notmatch [regex]::Escape($pass) -or $output -match '\*\* (Fatal|Error):') {
            Write-Output $output
            throw "$case failed"
        }
        Write-Output "$case PASS"
    }
} finally {
    Pop-Location
}
