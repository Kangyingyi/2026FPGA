# Gowin command-line build for the HDMI hardware monitor.
set project_dir [file normalize [file dirname [info script]]]
open_project [file join $project_dir competition_polyphonic_hdmi.gprj]
run all
exit
