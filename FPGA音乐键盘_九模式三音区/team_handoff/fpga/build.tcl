set project_dir [file normalize [file dirname [info script]]]
open_project [file join $project_dir ble_music_keyboard.gprj]
set_option -use_cpu_as_gpio 1
run syn
run pnr
exit
