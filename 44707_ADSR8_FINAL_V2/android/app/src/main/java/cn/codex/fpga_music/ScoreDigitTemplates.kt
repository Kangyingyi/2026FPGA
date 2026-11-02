package cn.codex.fpga_music

/** Black/white templates extracted from the supplied printed score, 32 x 48 pixels each. */
internal object ScoreDigitTemplates {
    const val WIDTH = 32
    const val HEIGHT = 48
    val packed = mapOf(
        1 to "AAAB4AAAD/gAAf/+AAf//gB///8B////D////z///////////////3//n/9//h//P/Af/wcAH/8AAB//AAAf/wAAH/8AAB//AAAf/wAAH/8AAB//AAAf/wAAH/8AAB//AAAf/wAAH/8AAB//AAAf/wAAH/8AAB//AAAf/wAAH/8AAB//AAAf/wAAH/8AAB//AAAf/wAAH/8AAB//AAAf/wAAH/8AAB//AAAf/wAAH/8AAB//AAAf/wAAH/8AAA/8",
        2 to "AAuAAAD/+AAP//+AH///wD////B////4f///+H////w/AB/+PgAH/gAAA/4AAAP+AAAB/wAAAf8AAAH/AAAB/wAAAf4AAAH+AAAD/gAAA/4AAAf+AAAH/AAAD/gAAB/4AAA/8AAAf+AAAH/gAAD/wAAB/4AAA/+AAAf+AAAP/gAAH/gAAD/4AAB/4AAA/+AAA/+AAAf/AAAP/wAAH/wAAD/8AAB/8AAAf/////////////////////////9/////",
        3 to "AB/AAAD//AAP//+AH///wD////B////4f////D////w/AA/+AAAH/gAAA/4AAAP+AAAB/gAAAf4AAAH+AAAB/gAAA/4AAAP8AAAP+AAAP/gA///wAP//4AH//4AB//4AAf//wAH///AA///4AAA//AAAD/4AAAP+AAAD/gAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAf8AAAP/OAAD/v8AD/7////8/////P////j////wP///wB///4AA//gA",
        5 to "A///+A////gP///8H////B////wf///8H///+D/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/wAAAP8AAAD/AAAA/w/gAP///AD///4A////gP///8H////h////4P8Af/j4AB/4AAAP+AAAB/wAAAf8AAAH/AAAB/wAAAP8AAAH/AAAA/wAAAf8AAAH/AAAB/wAAAf8AAAP+OAAH/nwAD/5/wH/8////+P////B////gP///wD///4AD//wA",
        6 to "AAA8AAAD/4AAH//wAD//+AD///wB///8Af///AP///wH/gB4D/gAAA/4AAAP4AAAH+AAAD/gAAA/wAAAP8AAAD/AAAA/gAAAf4P+AH+H/4B/H//Afz//8H9///h/f//4//4f/P/wA/7/8AP+/+AB///AAf//wAD/f8AA/3+AAH9/gAB/f4AAfz+AAH8/gAD/P8AA/z/AAf8f4AH+H+AB/g/4B/4H/3/8B///+AP///AB///wAP//wAB//4AAD/wA",
        7 to "f////H////7/////////////////////P////wAAAf8AAAP+AAAD/gAAB/4AAAf8AAAP+AAAD/gAAB/wAAAf8AAAP+AAAD/gAAB/wAAAf8AAAP+AAAD/gAAB/wAAAf8AAAH/AAAH/gAAB/wAAAf8AAAP/AAAH/gAAB/wAAAf8AAAP/AAAH/gAAB/wAAAf8AAAP/AAAD/gAAA/wAAAf8AAAP/AAAD/gAAA/4AAAf8AAAP+AAAD/gAAAf4AAAD8AAA",
    )
}
