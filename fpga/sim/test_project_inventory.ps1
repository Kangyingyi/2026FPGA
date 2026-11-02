$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$gprj = Join-Path $root 'ble_music_keyboard.gprj'
$cst = Join-Path $root 'src\ble_music_keyboard.cst'
if (-not (Test-Path $gprj)) { throw 'missing project file' }
if (-not (Test-Path $cst)) { throw 'missing constraints file' }
$xml = [xml](Get-Content -Raw $gprj)
$paths = @($xml.Project.FileList.File | ForEach-Object { $_.path })
foreach ($required in @('src/top.v','src/uart_rx.v','src/uart_tx.v','src/ble_protocol_rx.v','src/ble_protocol_tx.v','src/ble_command_router.v','src/key_filter_8.v','src/score_ram.v','src/guide_controller.v','src/led_guide.v','src/polyphonic_timbre.v','src/i2s_tx.v','src/record_sampler.v','src/record_packetizer.v','src/tx_arbiter.v','src/ble_music_keyboard.cst','src/timing.sdc')) {
    if ($paths -notcontains $required) { throw "project source missing: $required" }
}
foreach ($pin in @('V22','Y12','C19','C18','P19','R19','T21','U21','P16','R17','R18','T18','Y17','AB17','AA16')) {
    if (-not (Select-String -Path $cst -Pattern "IO_LOC.*$pin" -Quiet)) { throw "constraint pin missing: $pin" }
}
foreach ($required in @('src/audio_delay.v','src/legato_pitch.v','src/legato_dds.v','src/glide_dds.v','src/vibrato_dds.v','src/optical_pluck_trigger.v','src/polyphonic_pluck.v','src/pressure_led.v','src/ads1115_reader.v')) {
    if ($paths -notcontains $required) { throw "project source missing: $required" }
}
foreach ($required in @('src/hdmi_monitor.v','src/spectrum_detector.v','src/spectrum_dft.v','src/spectrum_peak_metric.v','src/ui_data.v','src/waveform_history.v','src/video_timing_720p.v','src/font_rom.v','src/hdmi_ui.v','src/dvi_tx/DVI_TX_Top.v','src/pll/TMDS_PLL_60HZ.v')) {
    if ($paths -notcontains $required) { throw "HDMI project source missing: $required" }
}
foreach ($path in $paths) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $path))) { throw "project file does not exist: $path" }
}
foreach ($pin in @('J14,H14','J15,H15','K17,J17','G15,G16','K13')) {
    if (-not (Select-String -Path $cst -SimpleMatch -Pattern $pin -Quiet)) { throw "HDMI pin missing: $pin" }
}
if (-not (Select-String -Path $cst -Pattern 'IO_LOC "OPTICAL_IN" C15' -Quiet)) { throw 'optical pin missing' }
Write-Output 'PROJECT_INVENTORY_PASS'
