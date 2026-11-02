set project_dir [file normalize [file dirname [info script]]]
open_project [file join $project_dir legato_glide_standalone.gprj]
run all
exit
