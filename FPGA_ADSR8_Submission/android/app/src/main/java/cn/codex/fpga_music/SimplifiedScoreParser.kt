package cn.codex.fpga_music

/** Draft converter for printed numbered notation. Values 0..6 address K1..K7. */
internal object SimplifiedScoreParser {
    data class Line(val top: Int, val left: Int, val text: String, val height: Int = 20)
    data class Result(val formatted: String, val count: Int, val truncated: Boolean,
                      val rows: List<String> = emptyList(), val rejected: Int = 0)

    fun convert(lines: List<Line>, durationUnits: Int): Result {
        require(durationUnits in 1..65535)
        // Reject mixed tokens instead of stripping notes out of timestamps,
        // battery percentages, lyrics or unsupported musical symbols.
        val candidates = lines.filter { line ->
            line.height > 0 && line.text.any { it in '1'..'7' } &&
                line.text.all { it in '1'..'7' || it.isWhitespace() || it in "|·•." }
        }.distinctBy { listOf(it.top, it.left, it.text) }
        val groups = mutableListOf<MutableList<Line>>()
        for (line in candidates.sortedBy { it.top + it.height / 2.0 }) {
            val center = line.top + line.height / 2.0
            val group = groups.minByOrNull { row ->
                kotlin.math.abs(center - row.map { it.top + it.height / 2.0 }.average())
            }
            val sameRow = group != null &&
                kotlin.math.abs(center - group.map { it.top + it.height / 2.0 }.average()) <=
                maxOf(2.0, minOf(line.height.toDouble(), group.map { it.height }.average()) * .45)
            if (sameRow) group!!.add(line) else groups.add(mutableListOf(line))
        }
        // Short fragments are retained inside a musical row, not as isolated counters.
        val musicalRows = groups.filter { row -> row.sumOf { it.text.count { c -> c in '1'..'7' } } >= 3 }
        if (musicalRows.isEmpty()) return Result("", 0, false, rejected = lines.size)
        val dominant = musicalRows.maxBy { row -> row.sumOf { it.text.count { c -> c in '1'..'7' } } }
            .map { it.height }.sorted().let { it[it.size / 2] }.toDouble()
        val selected = musicalRows.filter { row ->
            row.map { it.height }.average() / dominant in .65..1.5
        }.sortedBy { row -> row.map { it.top + it.height / 2.0 }.average() }
        val rows = selected.map { row ->
            row.sortedBy { it.left }.joinToString("") { it.text.filter { c -> c in '1'..'7' } }
        }
        val notes = rows.joinToString("").map { it.digitToInt() - 1 }
        val accepted = notes.take(64)
        return Result(accepted.joinToString(",") { "$it:$durationUnits" }, accepted.size, notes.size > 64,
            rows, lines.size - selected.sumOf { it.size })
    }
}
