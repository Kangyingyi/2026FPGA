$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$iverilog = 'C:\iverilog\bin\iverilog.exe'
$vvp = 'C:\iverilog\bin\vvp.exe'
if (-not (Test-Path -LiteralPath $iverilog) -or -not (Test-Path -LiteralPath $vvp)) {
    throw 'Icarus Verilog was not found under C:\iverilog\bin'
}

$tests = @(
    @{ Name='tb_adsr_presets'; Files=@('*') },
    @{ Name='tb_uart_loopback'; Files=@('uart_tx.v','uart_rx.v') },
    @{ Name='tb_ble_protocol'; Files=@('ble_protocol_rx.v','ble_command_router.v','ble_protocol_tx.v') },
    @{ Name='tb_protocol_tx'; Files=@('ble_protocol_tx.v') },
    @{ Name='tb_guide_controller'; Files=@('key_filter_8.v','score_ram.v','guide_controller.v','led_guide.v') },
    @{ Name='tb_polyphonic_audio'; Files=@('polyphonic_timbre.v','instrument_voice.v','expressive_osc.v','timbre_rom.v','sine_lut.v') },
    @{ Name='tb_record_stream'; Files=@('record_sampler.v','record_packetizer.v') },
    @{ Name='tb_mode_commands'; Files=@('ble_protocol_rx.v','ble_command_router.v') },
    @{ Name='tb_octave_engines'; Files=@('*') },
    @{ Name='tb_audio_delay'; Files=@('audio_delay.v') },
    @{ Name='tb_waveform_history'; Files=@('waveform_history.v') },
    @{ Name='tb_spectrum_detector'; Files=@('spectrum_detector.v') },
    @{ Name='tb_tx_arbiter'; Files=@('tx_arbiter.v') },
    @{ Name='tb_top_smoke'; Files=@('*') },
    @{ Name='tb_top_mode_uart'; Files=@('*') },
    @{ Name='tb_optical_pluck_chain'; Files=@('*') },
    @{ Name='tb_top_hdmi_integration'; Files=@('*') }
)

foreach ($test in $tests) {
    $rtl = if ($test.Files[0] -eq '*') { @(Get-ChildItem (Join-Path $root 'src') -Filter '*.v' | ForEach-Object FullName) }
           else { @($test.Files | ForEach-Object { Join-Path $root ('src\' + $_) }) }
    $sources = @((Join-Path $root ('sim\' + $test.Name + '.v'))) + $rtl
    if ($test.Files[0] -eq '*') {
        $sources += Join-Path $root 'sim\hdmi_ip_stubs.v'
    }
    $output = Join-Path $root ('sim\' + $test.Name + '.vvp')
    & $iverilog -g2012 -s $test.Name -o $output $sources
    if ($LASTEXITCODE -ne 0) { throw "$($test.Name) compile failed" }
    & $vvp $output
    if ($LASTEXITCODE -ne 0) { throw "$($test.Name) failed" }
}

& (Join-Path $root 'sim\test_project_inventory.ps1')
Write-Output 'ALL_TESTS_PASS'

